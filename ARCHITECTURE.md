# FAAR POS — System Architecture & Design Specification

## 1. High-Level Architectural Overview

FAAR POS is designed as a high-performance, offline-first Point of Sale (POS) and inventory platform. The architecture separates local operational execution from cloud persistence, guaranteeing continuous checkout operations even during prolonged internet disconnects.

```
+-------------------------------------------------------------------------+
|                              FAAR POS CLIENT                            |
|                              (Flutter 3.22+)                            |
+--------------------+-------------------------------+--------------------+
                     |                               |
       +-------------v-------------+   +-------------v-------------+
       |      HARDWARE ENGINE      |   |    FINANCIAL & TAX ENGINE |
       |  - flutter_blue_plus      |   |  - Pure Dart (Decimal)    |
       |  - esc_pos_utils_plus     |   |  - Intra CGST/SGST Split  |
       |  - mobile_scanner         |   |  - Inter IGST Routing     |
       |  - 58mm/80mm ESC/POS      |   |  - Tax Inclusive/Exclusive|
       +-------------+-------------+   +-------------+-------------+
                     |                               |
       +-------------v-------------------------------v-------------+
       |               OFFLINE-FIRST LOCAL STORAGE                 |
       |  - Native sqlite3 in Write-Ahead Logging (WAL) mode       |
       |  - Double-Entry Append-Only Inventory Ledger              |
       |  - Sequential Collision-Proof Invoicing Engine            |
       |  - Background Sync Queue with Exponential Backoff         |
       +-----------------------------+-----------------------------+
                                     | (HTTPS / REST)
                                     v
+-------------------------------------------------------------------------+
|                        CLOUD BACKEND INFRASTRUCTURE                     |
|                               (FastAPI)                                 |
+------------------------------------+------------------------------------+
|  - Async SQLAlchemy 2.0 Engine     |  - JWT Authentication & RBAC       |
|  - Idempotency Interceptor Layer   |  - Branch / Multi-Store Scoping    |
|  - Cloud SQL PostgreSQL Storage    |  - Real-Time Sales & GST Analytics |
+------------------------------------+------------------------------------+
```

---

## 2. Core Architectural Pillars

### 2.1 Pure Deterministic Financial Math
* **Zero Floating-Point Drift:** No monetary calculation uses `double` or `float`. All monetary representations are strictly modeled with `package:decimal` and `package:rational`.
* **Standard Half-Up Rounding:** All fractional cents/paise use deterministic `ROUND_HALF_UP` banking precision to 2 decimal places.

### 2.2 Native SQLite with WAL Mode
* **Instant Read/Write Concurrency:** The local SQLite database operates in WAL (Write-Ahead Logging) mode, allowing concurrent readers during atomic checkout transactions.
* **Double-Entry Inventory Accounting:** Stock changes are never direct quantity overwrites. Every alteration creates an immutable `inventory_logs` entry with a delta and post-movement audit balance.

### 2.3 Multi-Store Hierarchy
* Organizations can provision multiple branches with independent invoice sequence counters (`FAAR-`, `WH-`), distinct GSTINs, and branch-scoped staff access controls.
