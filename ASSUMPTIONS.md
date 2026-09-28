# FAAR POS — Production Assumptions & Business Defaults

This document records the architectural and business assumptions made for production readiness.

---

## 1. Taxation & Regional Rules
* **Default GST Jurisdiction:** Defaults to Indian GST rules (State Code `32` - Kerala) as the initial seed, but state codes, tax rates, and component structures are 100% configurable per branch or per country.
* **Intra-State vs Inter-State:** If buyer state matches branch state (or if buyer state is null for retail B2C over-the-counter sales), the transaction is treated as **Intra-State (CGST 50% + SGST 50%)**. If buyer state differs, it is treated as **Inter-State (IGST 100%)**.
* **Tax Inclusivity:** Individual products can be designated as either tax-inclusive (sticker price includes GST) or tax-exclusive (GST added on top of base price).

---

## 2. Inventory Ledgering
* **Movement Types:** Classified as `sale`, `restock`, `damage`, `adjustment`, `transfer_in`, `transfer_out`, and `return`.
* **Negative Stock Prevention:** The UI warns on low/out-of-stock conditions while preserving cashier speed for urgent transactions.

---

## 3. Hardware & Peripherals
* **Thermal Paper Roll Defaults:** Supports both 58mm (2-inch standard) and 80mm (3-inch wide) ESC/POS printers. The default setting is 58mm.
* **Printer Interface:** Primary support is Bluetooth Low Energy (BLE) with MTU chunking, with architecture extensible to USB and Network/Wi-Fi printing.
