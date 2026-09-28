# FAAR POS — Database Schema & Data Dictionary

## 1. Local SQLite Schema (Client-Side)

### 1.1 `products`
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Local Product ID |
| `name` | TEXT NOT NULL | Display name |
| `sku` | TEXT NOT NULL UNIQUE | Stock Keeping Unit |
| `category_name` | TEXT NOT NULL | Category group |
| `unit_of_measure` | TEXT NOT NULL | e.g. `pcs`, `set`, `kg` |
| `base_price` | TEXT NOT NULL | Decimal string representation |
| `tax_group_id` | INTEGER | FK to tax group |
| `tax_group_json` | TEXT | Snapshot of tax rates & components |
| `stock_quantity` | INTEGER NOT NULL | Current balance |
| `low_stock_threshold` | INTEGER NOT NULL | Alert trigger quantity |
| `barcode` | TEXT | EAN-13, UPC, Code-128 |
| `hsn_code` | TEXT | Harmonized System of Nomenclature |
| `is_tax_inclusive` | INTEGER NOT NULL | 1 if price includes tax, 0 otherwise |
| `is_active` | INTEGER NOT NULL | 1 for active catalog items |

### 1.2 `transactions`
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Transaction record ID |
| `receipt_no` | TEXT NOT NULL UNIQUE | Sequential receipt number |
| `transaction_type` | TEXT NOT NULL | `sale` or `refund` |
| `customer_name` | TEXT | Buyer name |
| `customer_gstin` | TEXT | Buyer tax registration number |
| `total_base_amount` | TEXT NOT NULL | Total taxable base |
| `total_tax_amount` | TEXT NOT NULL | Total GST collected |
| `total_discount_amount` | TEXT NOT NULL | Total discounts applied |
| `grand_total` | TEXT NOT NULL | Final invoice total |
| `payment_method` | TEXT NOT NULL | `cash`, `upi`, `card`, etc. |
| `status` | TEXT NOT NULL | `completed`, `voided`, `refunded` |
| `created_at` | TEXT NOT NULL | ISO-8601 creation timestamp |
| `is_synced` | INTEGER NOT NULL | 1 if synced to cloud backend |

### 1.3 `inventory_logs` (Immutable Movement Ledger)
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Movement record ID |
| `local_id` | TEXT NOT NULL UNIQUE | UUID of movement |
| `product_id` | INTEGER NOT NULL | Product FK |
| `branch_id` | INTEGER NOT NULL | Branch FK |
| `movement_type` | TEXT NOT NULL | `sale`, `restock`, `damage`, `adjustment` |
| `quantity_delta` | INTEGER NOT NULL | +/- Delta |
| `quantity_after` | INTEGER NOT NULL | Resulting balance |
| `notes` | TEXT | Reason / Audit context |
| `reference_receipt_no`| TEXT | Linked sale receipt (if applicable) |
| `created_at` | TEXT NOT NULL | Movement timestamp |

### 1.4 `branches`, `users`, `tax_groups`, `sync_queue`, `settings`
Detailed table definitions for multi-store configuration, staff accounts, tax groups, sync retry queues, and terminal settings.
