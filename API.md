# FAAR POS — REST API Specification

FastAPI backend API endpoints and contracts.

---

## Base URLs
* **Local Development:** `http://localhost:8080/api/v1`
* **Android Emulator:** `http://10.0.2.2:8080/api/v1`
* **Production Cloud Run:** `https://api.faarpos.com/api/v1`

---

## Endpoints

### 1. Authentication (`/auth`)
* `POST /auth/login` → Authenticate staff member with email & password or PIN. Returns `{access_token, refresh_token, user, branch}`.
* `POST /auth/refresh` → Exchange refresh token for fresh short-lived JWT access token.
* `POST /auth/logout` → Invalidate active token and increment token version.
* `GET /auth/me` → Retrieve authenticated user profile and permissions.

### 2. Transactions & Sync (`/transactions`)
* `POST /transactions` → Create new sale or refund transaction.
  * **Headers:** `Idempotency-Key: <UUID>`
  * **Payload:** `{receipt_no, items: [...], total_base_amount, total_tax_amount, grand_total, payment_method}`
* `POST /transactions/sync-batch` → Bulk upload queued offline transactions.
* `GET /transactions` → Paginated list of store transactions with date and payment filters.
* `GET /transactions/{id}` → Single transaction with itemized tax breakdown.
* `POST /transactions/{id}/void` → Void an existing transaction (Manager+ role).

### 3. Inventory & Catalog (`/products`, `/inventory`)
* `GET /products` → Paginated catalog with live stock levels.
* `POST /products` → Create or update catalog item.
* `GET /inventory` → Current stock table per branch.
* `POST /inventory/adjustment` → Manual audit adjustment, restock, or damage log.
* `GET /inventory/log` → Paginated ledger movements.

### 4. Reports & Analytics (`/reports`)
* `GET /reports/eod` → End-of-Day summary for selected date.
* `GET /reports/sales` → Aggregated sales report with date range.
* `GET /reports/tax-summary` → CGST, SGST, IGST tax breakdown audit report.
