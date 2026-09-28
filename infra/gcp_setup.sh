#!/bin/bash
# FAAR POS - Google Cloud Platform Setup Script
# Run this script to provision all required GCP infrastructure
# Prerequisites: gcloud CLI installed and authenticated

set -e  # Exit on any error

# ============================================================
# CONFIGURATION - Edit these values before running
# ============================================================
PROJECT_ID="faar-pos-$(date +%Y%m%d)"   # Or set your preferred project ID
REGION="us-central1"                      # Change to your preferred region
DB_INSTANCE="faar-pos-db"
DB_NAME="faar_pos"
DB_USER="faar_pos_user"
REDIS_INSTANCE="faar-pos-cache"
SERVICE_NAME="faar-pos-api"
ARTIFACT_REPO="faar-pos-images"

echo "=========================================="
echo "  FAAR POS - GCP Infrastructure Setup"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Region:     $REGION"
echo ""

# ============================================================
# 1. Create GCP Project
# ============================================================
echo "→ Creating GCP Project..."
gcloud projects create "$PROJECT_ID" --name="FAAR POS"
gcloud config set project "$PROJECT_ID"

echo "→ Enabling Billing (manual step required)..."
echo "  Please enable billing for project '$PROJECT_ID' at:"
echo "  https://console.cloud.google.com/billing/projects"
echo "  Then press Enter to continue..."
read -r

# ============================================================
# 2. Enable Required APIs
# ============================================================
echo "→ Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  vpcaccess.googleapis.com \
  servicenetworking.googleapis.com

# ============================================================
# 3. Create Artifact Registry for Docker Images
# ============================================================
echo "→ Creating Artifact Registry..."
gcloud artifacts repositories create "$ARTIFACT_REPO" \
  --repository-format=docker \
  --location="$REGION" \
  --description="FAAR POS Docker images"

# ============================================================
# 4. Create Cloud SQL PostgreSQL Instance
# ============================================================
echo "→ Creating Cloud SQL PostgreSQL instance (this takes ~5 minutes)..."
gcloud sql instances create "$DB_INSTANCE" \
  --database-version=POSTGRES_16 \
  --tier=db-f1-micro \
  --region="$REGION" \
  --storage-auto-increase \
  --storage-size=10GB \
  --backup-start-time=02:00 \
  --enable-point-in-time-recovery \
  --no-assign-ip \
  --network=default

echo "→ Creating database and user..."
DB_PASSWORD=$(openssl rand -base64 32)
gcloud sql databases create "$DB_NAME" --instance="$DB_INSTANCE"
gcloud sql users create "$DB_USER" \
  --instance="$DB_INSTANCE" \
  --password="$DB_PASSWORD"

echo "  Database password generated (save this!): $DB_PASSWORD"

# ============================================================
# 5. Create Cloud Memorystore Redis
# ============================================================
echo "→ Creating Redis instance..."
gcloud redis instances create "$REDIS_INSTANCE" \
  --size=1 \
  --region="$REGION" \
  --redis-version=redis_7_0 \
  --tier=basic

REDIS_HOST=$(gcloud redis instances describe "$REDIS_INSTANCE" \
  --region="$REGION" --format='get(host)')
REDIS_PORT=$(gcloud redis instances describe "$REDIS_INSTANCE" \
  --region="$REGION" --format='get(port)')

# ============================================================
# 6. Create VPC Connector (for Cloud Run → Cloud SQL/Redis)
# ============================================================
echo "→ Creating VPC Serverless Access Connector..."
gcloud compute networks vpc-access connectors create faar-pos-connector \
  --network=default \
  --region="$REGION" \
  --range=10.8.0.0/28 \
  --min-throughput=200 \
  --max-throughput=300

# ============================================================
# 7. Store Secrets in Secret Manager
# ============================================================
echo "→ Storing secrets in Secret Manager..."
SECRET_KEY=$(openssl rand -base64 64)
DB_CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE" --format='get(connectionName)')
DATABASE_URL="postgresql+asyncpg://${DB_USER}:${DB_PASSWORD}@/${DB_NAME}?host=/cloudsql/${DB_CONNECTION_NAME}"
REDIS_URL="redis://${REDIS_HOST}:${REDIS_PORT}"

echo -n "$SECRET_KEY" | gcloud secrets create faar-pos-secret-key --data-file=-
echo -n "$DATABASE_URL" | gcloud secrets create faar-pos-database-url --data-file=-
echo -n "$REDIS_URL" | gcloud secrets create faar-pos-redis-url --data-file=-

# Grant Cloud Run service account access to secrets
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='get(projectNumber)')
SA="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
for secret in faar-pos-secret-key faar-pos-database-url faar-pos-redis-url; do
  gcloud secrets add-iam-policy-binding "$secret" \
    --member="$SA" \
    --role="roles/secretmanager.secretAccessor"
done

# ============================================================
# 8. Build and Push Docker Image
# ============================================================
echo "→ Building and pushing Docker image..."
IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/${SERVICE_NAME}:latest"
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Build from backend directory
cd "$(dirname "$0")/../backend"
docker build -t "$IMAGE_URL" .
docker push "$IMAGE_URL"

# ============================================================
# 9. Deploy to Cloud Run
# ============================================================
echo "→ Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --image="$IMAGE_URL" \
  --platform=managed \
  --region="$REGION" \
  --allow-unauthenticated \
  --port=8080 \
  --min-instances=0 \
  --max-instances=10 \
  --concurrency=80 \
  --cpu=1 \
  --memory=512Mi \
  --timeout=60 \
  --vpc-connector=faar-pos-connector \
  --vpc-egress=private-ranges-only \
  --add-cloudsql-instances="$DB_CONNECTION_NAME" \
  --set-env-vars="PROJECT_NAME=FAAR POS,ENVIRONMENT=production" \
  --set-secrets="SECRET_KEY=faar-pos-secret-key:latest,DATABASE_URL=faar-pos-database-url:latest,REDIS_URL=faar-pos-redis-url:latest"

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" --format='get(status.url)')

# ============================================================
# 10. Summary
# ============================================================
echo ""
echo "=========================================="
echo "  FAAR POS Deployment Complete!"
echo "=========================================="
echo "API URL:        $SERVICE_URL"
echo "Health Check:   $SERVICE_URL/health"
echo "API Docs:       $SERVICE_URL/docs"
echo ""
echo "⚠️  IMPORTANT - Save these credentials securely:"
echo "Database Password: $DB_PASSWORD"
echo "Secret Key:        $SECRET_KEY"
echo "Project ID:        $PROJECT_ID"
echo ""
echo "Next: Run database migrations:"
echo "  gcloud run jobs create faar-pos-migrate \\"
echo "    --image=$IMAGE_URL \\"
echo "    --command=alembic,upgrade,head \\"
echo "    --region=$REGION \\"
echo "    --set-secrets=DATABASE_URL=faar-pos-database-url:latest \\"
echo "    --execute-now"
