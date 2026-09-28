# FAAR POS — Security & Access Control Architecture

## 1. Authentication & Token Management
* **JWT Access & Refresh Tokens:** Short-lived access tokens (15 minutes) paired with cryptographically hashed refresh tokens (30 days).
* **Encrypted Storage:** On mobile clients, tokens and credentials are encrypted at rest using `FlutterSecureStorage` (Android Keystore / iOS Keychain).
* **Demarcated Demo Environment:** Production builds enforce `AppConfig.allowDemoFallback = false`, preventing bypass of real API endpoints.

---

## 2. Role-Based Access Control (RBAC)
* **`org_admin`:** Organization-wide superuser. Can provision branches, configure global tax groups, and view cross-store consolidation reports.
* **`branch_admin`:** Full branch administrative access (Products, Staff, Local Settings, Invoices).
* **`manager`:** Access to End-of-Day reports, sales audits, inventory adjustments, and transaction voiding.
* **`cashier`:** Fast point-of-sale checkout and receipt printing only.
