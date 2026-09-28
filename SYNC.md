# FAAR POS — Offline Synchronization & Conflict Resolution

## 1. Overview
FAAR POS provides true offline-first operation. The client creates sales, generates receipts, and decrements inventory locally within atomic SQLite transactions. Transactions are queued in `sync_queue` and synced to the cloud backend.

---

## 2. Sync Protocol & Flow

```
+-------------------+
|  Cashier Sale     |
+---------+---------+
          |
          v
+-------------------------------------------------------+
|  Local Atomic SQLite Transaction                      |
|  1. Decrement product stock                           |
|  2. Insert transaction record                         |
|  3. Append double-entry inventory_logs entry          |
|  4. Enqueue in sync_queue with status = 'pending'     |
+---------------------------+---------------------------+
                            |
                            v
+-------------------------------------------------------+
|  ConnectivityService Detection                        |
|  - If online: Trigger SyncService                     |
|  - If offline: Retain in queue                        |
+---------------------------+---------------------------+
                            | (HTTP POST /transactions/sync-batch)
                            v
+-------------------------------------------------------+
|  FastAPI Backend Processing                           |
|  - Idempotency Key check                              |
|  - Validation & PostgreSQL commit                     |
|  - Returns 200 OK                                     |
+---------------------------+---------------------------+
                            |
                            v
+-------------------------------------------------------+
|  Mark Local sync_queue as 'synced'                    |
+-------------------------------------------------------+
```

---

## 3. Idempotency & Conflict Handling
* **Client UUID:** Each transaction generates a unique UUID upon creation.
* **Backend Idempotency Middleware:** If a transaction payload is retried due to network drops, the backend recognizes the idempotency key and returns the previously processed response without creating duplicate sales or double-decrementing stock.
* **Exponential Backoff:** If the backend is unreachable or returns 5xx errors, `SyncService` backs off exponentially (2s, 4s, 8s, 16s... up to 5 minutes) to conserve battery and bandwidth.
