# FAAR POS — Enterprise Point of Sale & Inventory Platform

A cross-platform, offline-first mobile Point of Sale (POS) and inventory platform designed for retail stores, multi-branch warehouses, and service businesses worldwide. Built with **Flutter (v3.22+)** and **FastAPI / PostgreSQL**, featuring pure-Dart deterministic financial mathematics and Bluetooth hardware integration.

---

## Key Architecture & Capabilities

### 1. Multi-Country Deterministic Tax Engine
* **Pure-Dart `TaxEngine`:** Guarantees zero floating-point drift by utilizing `package:decimal` and `package:rational` exclusively.
* **Intra-Region vs Inter-Region Dynamic Split:** Auto-calculates **CGST (9%) + SGST (9%)** for domestic sales (e.g. Kerala Intra-State) and **IGST (18%)** for inter-state transfers.
* **Dual Calculation Modes:** Supports both **Tax-Exclusive** (base + calculated tax) and **Tax-Inclusive** (extracts taxable base from gross sticker price using exact rational math).
* **Deterministic Rounding:** Strict `ROUND_HALF_UP` banking precision to 2 decimal places.

### 2. Offline-First Native SQLite Persistence
* **High-Concurrency WAL Mode:** Powered by native `sqlite3` in Write-Ahead Logging mode for instant reads during background writes.
* **Double-Entry Inventory Ledger:** All inventory movements (`sale`, `restock`, `damage`, `adjustment`) are logged to an immutable append-only ledger (`inventory_logs`) in atomic transactions.
* **Sequential Invoicing:** Generates collision-proof sequential invoice numbers (e.g. `FAAR-202608-00001`) with customizable store prefixes.
* **Offline Sync Queue:** Failed or offline transactions are queued in `sync_queue` and drained by `SyncService` with exponential backoff retries when connectivity is restored.

### 3. Hardware & Peripherals Integration
* **Bluetooth Thermal Printer Discovery & Pairing:** Direct BLE scanning, characteristic discovery, and MTU chunking via `flutter_blue_plus`.
* **Universal ESC/POS Binary Builder:** Formats receipts dynamically for both **58mm (2-inch standard)** and **80mm (3-inch wide)** roll widths with test print capabilities.
* **Camera Barcode & SKU Scanner:** Live camera viewfinder with reticle overlay, torch toggle, camera switcher, and instant SQLite catalog lookup via `mobile_scanner`.

### 4. Multi-Store & Staff Administration
* **Multi-Branch Expansion:** Add multiple outlets or warehouses, assign separate invoice numbering sequences, and switch active terminals on the fly.
* **Role-Based Access Control (RBAC):** Staff accounts (`org_admin`, `branch_admin`, `manager`, `cashier`) with quick 4-digit PIN authentication.
* **Real-Time Analytics & Reports:** Real-time Dashboard, End-of-Day (EOD) summaries, date-filterable Sales Reports, and itemized GST tax audit logs.

---

## Directory Structure

```
faar_pos/
├── mobile/faar_pos_app/             # Flutter POS Application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/              # AppConfig (Environment & Demo flags)
│   │   │   ├── services/            # Bluetooth Printer, Sync, Connectivity, Talker
│   │   │   ├── theme/               # Dark theme tokens & typography
│   │   │   └── router/              # GoRouter configuration & route guards
│   │   ├── data/
│   │   │   └── local/               # SQLite database, migrations & DAOs
│   │   ├── domain/
│   │   │   ├── entities/            # Business model entities
│   │   │   └── services/            # Pure Dart TaxEngine
│   │   └── presentation/
│   │       ├── providers/           # Riverpod state management
│   │       ├── screens/             # Auth, Dashboard, POS, Admin, Reports
│   │       └── widgets/             # Barcode scanner modal, status indicators
│   └── test/                        # Comprehensive unit & widget tests (25 passing)
│
├── backend/                         # FastAPI Cloud Backend
│   ├── app/
│   │   ├── api/v1/                  # Auth, Products, Transactions, Sync endpoints
│   │   ├── core/                    # Security, JWT tokens, Async SQLAlchemy database
│   │   ├── models/                  # Declarative models with soft deletes
│   │   └── services/                # Backend tax calculation & invoice generators
│   ├── alembic/                     # Database migrations
│   └── Dockerfile                   # Multi-stage production container
│
└── .github/workflows/ci.yml         # Automated GitHub Actions test & build pipeline
```

---

## Getting Started

### Mobile App Development

```powershell
# Navigate to mobile app
cd mobile/faar_pos_app

# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run all 25 unit & widget tests
flutter test

# Run app on connected device / emulator
flutter run
```

### Backend Development

```bash
# Navigate to backend
cd backend

# Start local PostgreSQL & Redis
docker-compose up -d

# Run FastAPI dev server
uvicorn app.main:app --reload --port 8080
```

---

## Release Building

### Android Release APK

```powershell
# Create signing key properties from template
cp android/key.properties.example android/key.properties

# Build Release APK
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`
