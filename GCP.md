# FAAR POS — Google Cloud Platform (GCP) Deployment Architecture

## 1. Production Topology

```
+-------------------------------------------------------------+
|                     Google Cloud Platform                   |
|                                                             |
|   +-------------------+          +-----------------------+  |
|   |  Cloud Run        |  HTTPS   |  Cloud SQL            |  |
|   |  (FastAPI API)    +--------->|  (PostgreSQL 16)      |  |
|   +---------+---------+          +-----------------------+  |
|             |                                               |
|             v                                               |
|   +-------------------+          +-----------------------+  |
|   |  Secret Manager   |          |  Memorystore          |  |
|   |  (JWT / DB Keys)  |          |  (Redis 7 Cache)      |  |
|   +-------------------+          +-----------------------+  |
+-------------------------------------------------------------+
```

---

## 2. Cloud Run Service Deployment
```bash
# Build and deploy backend container to Google Cloud Run
gcloud run deploy faar-pos-backend \
  --source ./backend \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="PROJECT_NAME=FAAR POS,ENVIRONMENT=production" \
  --set-secrets="DATABASE_URL=faar-pos-db-url:latest,SECRET_KEY=faar-pos-jwt-secret:latest"
```

---

## 3. Database Migrations on Cloud SQL
Migrations run automatically on container startup or via Cloud Run jobs using Alembic:
```bash
alembic upgrade head
```
