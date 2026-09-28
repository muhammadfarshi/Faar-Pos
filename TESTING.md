# FAAR POS — Quality Assurance & Testing Suite

## 1. Test Suite Coverage (25 Automated Tests)

| Test Module | Coverage Scope | Result |
|---|---|---|
| `tax_engine_test.dart` | Pure Dart GST calculation, Intra/Inter state routing, Rounding | ✅ Passed |
| `app_database_test.dart` | SQLite product queries, Barcode lookups, Atomic sales | ✅ Passed |
| `extended_database_test.dart` | Multi-Store branches, Staff RBAC, Stock adjustments, Logs | ✅ Passed |
| `printer_service_test.dart` | ESC/POS 58mm & 80mm binary formatting, Test print bytes | ✅ Passed |
| `pos_flow_test.dart` | Catalog UI rendering, CartNotifier GST calculation, Empty states | ✅ Passed |
| `sqlite3_test.dart` | Native SQLite engine in-memory & file storage | ✅ Passed |

---

## 2. Running Automated Tests

```powershell
# Run all Flutter tests
cd mobile/faar_pos_app
flutter test

# Run static analysis
flutter analyze
```

---

## 3. Critical Offline Sale Acceptance Flow
1. **Device Offline:** Disconnect network adapter.
2. **Create Sale:** Add products to cart, specify discount, select payment method, complete sale.
3. **Receipt Generation:** Sequential invoice `FAAR-YYYYMM-XXXXX` is generated and stock is decremented locally.
4. **App Restart:** Close application completely and reopen. All transactions and inventory logs remain intact in local SQLite.
5. **Reconnect:** Network restored. Background `SyncService` drains `sync_queue` to backend using idempotency keys with zero duplicates.
