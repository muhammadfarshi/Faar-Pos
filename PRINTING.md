# FAAR POS — Thermal Printing & Hardware Architecture

## 1. Overview
FAAR POS provides hardware abstraction for thermal receipt printers over Bluetooth Low Energy (BLE), with dynamic binary formatting via ESC/POS commands.

---

## 2. Printer Pipeline Architecture

```
+---------------------+
|  Transaction Entity |
+----------+----------+
           |
           v
+--------------------------------------------------------+
|  PrinterService.generateReceiptBytes()                 |
|  - Reads store settings (Name, Address, GSTIN)         |
|  - Formats headers, meta, table rows, totals, barcode  |
|  - Applies PaperSize: 58mm (32 chars) / 80mm (48 chars)|
|  - Generates binary ESC/POS command stream             |
+--------------------------+-----------------------------+
                           |
                           v
+--------------------------------------------------------+
|  PrinterService.printBytes()                           |
|  - Discovers writable GATT characteristic              |
|  - Splits binary into 120-byte chunks                  |
|  - Transmits sequentially over BLE with 15ms pauses    |
+--------------------------------------------------------+
```

---

## 3. Supported Paper Formats
* **58mm (2-inch roll):** Standard compact thermal printer (32 columns).
* **80mm (3-inch roll):** Wide format counter printer (48 columns).
