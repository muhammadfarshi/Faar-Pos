import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:decimal/decimal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/product_entity.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/tax_entity.dart';
import '../../core/services/talker_service.dart';

class AppDatabase {
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  late Database _db;
  bool _isInitialized = false;

  final _dbChangeController = StreamController<String>.broadcast();
  Stream<String> get tableChanges => _dbChangeController.stream;

  AppDatabase._();

  // For testing with an in-memory database
  AppDatabase.inMemory(Database db) {
    _instance = this;
    _db = db;
    _isInitialized = true;
    _createTables(_db);
    _seedDefaultDataIfEmpty();
  }

  Database get db {
    if (!_isInitialized) {
      throw StateError('Database must be initialized before access. Call initialize() first.');
    }
    return _db;
  }

  Future<void> initialize({String? customPath}) async {
    if (_isInitialized) return;

    try {
      final String dbPath;
      if (customPath != null) {
        dbPath = customPath;
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        final dbDir = Directory(p.join(docsDir.path, 'faar_pos_data'));
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
        }
        dbPath = p.join(dbDir.path, 'faar_pos.sqlite');
      }

      _db = sqlite3.open(dbPath);
      // Enable WAL mode for high concurrent read/write performance and resilience
      _db.execute('PRAGMA journal_mode = WAL;');
      _db.execute('PRAGMA foreign_keys = ON;');

      _createTables(_db);
      _runMigrations(_db);
      _seedDefaultDataIfEmpty();

      _isInitialized = true;
      AppLog.info('Local SQLite database initialized at $dbPath');
    } catch (e, st) {
      AppLog.error('Failed to initialize local SQLite database', e, st);
      rethrow;
    }
  }

  void _notifyChange(String table) {
    if (!_dbChangeController.isClosed) {
      _dbChangeController.add(table);
    }
  }

  void _createTables(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        name TEXT NOT NULL,
        sku TEXT NOT NULL UNIQUE,
        category_name TEXT NOT NULL DEFAULT 'General',
        unit_of_measure TEXT NOT NULL DEFAULT 'pcs',
        base_price TEXT NOT NULL,
        tax_group_id INTEGER,
        tax_group_json TEXT,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER NOT NULL DEFAULT 10,
        is_active INTEGER NOT NULL DEFAULT 1,
        barcode TEXT,
        image_url TEXT,
        hsn_code TEXT,
        is_tax_inclusive INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT
      );

      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        gstin TEXT,
        state_code TEXT,
        address TEXT,
        balance TEXT NOT NULL DEFAULT '0.00',
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        remote_id INTEGER,
        receipt_no TEXT NOT NULL UNIQUE,
        branch_id INTEGER NOT NULL DEFAULT 1,
        cashier_id INTEGER NOT NULL DEFAULT 1,
        transaction_type TEXT NOT NULL DEFAULT 'sale',
        customer_name TEXT,
        customer_phone TEXT,
        customer_gstin TEXT,
        place_of_supply_state TEXT,
        is_inter_state INTEGER NOT NULL DEFAULT 0,
        total_base_amount TEXT NOT NULL,
        total_tax_amount TEXT NOT NULL,
        total_discount_amount TEXT NOT NULL DEFAULT '0.00',
        grand_total TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        payment_reference TEXT,
        status TEXT NOT NULL DEFAULT 'completed',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_local_id TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        sku TEXT NOT NULL,
        hsn_code TEXT,
        quantity INTEGER NOT NULL,
        unit_price TEXT NOT NULL,
        discount_amount TEXT NOT NULL DEFAULT '0.00',
        tax_breakdown_json TEXT NOT NULL DEFAULT '[]',
        tax_total TEXT NOT NULL DEFAULT '0.00',
        line_total TEXT NOT NULL,
        FOREIGN KEY (transaction_local_id) REFERENCES transactions(local_id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS inventory_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL UNIQUE,
        product_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        movement_type TEXT NOT NULL,
        quantity_delta INTEGER NOT NULL,
        quantity_after INTEGER NOT NULL,
        notes TEXT,
        reference_receipt_no TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products(id)
      );

      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_local_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        address TEXT,
        city TEXT NOT NULL DEFAULT 'Kochi',
        state_code TEXT NOT NULL DEFAULT '32',
        country_code TEXT NOT NULL DEFAULT 'IN',
        phone TEXT,
        gstin TEXT,
        invoice_prefix TEXT NOT NULL DEFAULT 'FAAR-',
        invoice_next_seq INTEGER NOT NULL DEFAULT 1,
        currency_code TEXT NOT NULL DEFAULT 'INR',
        currency_symbol TEXT NOT NULL DEFAULT '₹',
        is_active INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL DEFAULT 'cashier',
        branch_id INTEGER,
        pin_code TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE IF NOT EXISTS tax_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rate TEXT NOT NULL,
        components_json TEXT NOT NULL DEFAULT '[]',
        is_compound INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      );

      CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
      CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
      CREATE INDEX IF NOT EXISTS idx_transactions_receipt_no ON transactions(receipt_no);
      CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);
      CREATE INDEX IF NOT EXISTS idx_inventory_logs_product_id ON inventory_logs(product_id);
    ''');
  }

  void _runMigrations(Database db) {
    // Current schema version is 1
    final current = db.select('SELECT version FROM schema_migrations WHERE version = 1');
    if (current.isEmpty) {
      db.execute('INSERT INTO schema_migrations (version, applied_at) VALUES (1, ?)', [DateTime.now().toIso8601String()]);
    }
  }

  void _seedDefaultDataIfEmpty() {
    final existing = _db.select('SELECT COUNT(*) as count FROM products');
    final count = existing.first['count'] as int;
    if (count > 0) return;

    // Seed default categories
    final catStmt = _db.prepare('INSERT OR IGNORE INTO categories (name, description, sort_order) VALUES (?, ?, ?)');
    catStmt.execute(['Brass Fixtures', 'Premium brass hardware', 1]);
    catStmt.execute(['Glass Panels', 'Architectural glass and mirrors', 2]);
    catStmt.execute(['Accessories', 'Mounting and installation kits', 3]);
    catStmt.dispose();

    // Default 18% GST tax group JSON
    final defaultGst18Json = jsonEncode({
      'id': 1,
      'name': 'GST 18%',
      'total_rate': '18.00',
      'is_compound': false,
      'components': [
        {'id': 1, 'name': 'CGST 9%', 'rate': '9.00', 'applies_to': 'intraRegion'},
        {'id': 2, 'name': 'SGST 9%', 'rate': '9.00', 'applies_to': 'intraRegion'},
        {'id': 3, 'name': 'IGST 18%', 'rate': '18.00', 'applies_to': 'interRegion'},
      ]
    });

    // Seed initial products
    final prodStmt = _db.prepare('''
      INSERT INTO products (
        name, sku, category_name, unit_of_measure, base_price, tax_group_id, tax_group_json,
        stock_quantity, low_stock_threshold, is_active, barcode, hsn_code, is_tax_inclusive
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    final seeds = [
      ['Brass Fixture Luxury A', 'BRS-001', 'Brass Fixtures', 'pcs', '1250.00', 1, defaultGst18Json, 45, 10, 1, '8901234567890', '7418', 0],
      ['Glass Panel 60x90 Tempered', 'GLS-001', 'Glass Panels', 'pcs', '3500.00', 1, defaultGst18Json, 8, 10, 1, '8901234567891', '7007', 0],
      ['Brass Handle Set Chrome', 'BRS-002', 'Brass Fixtures', 'set', '850.00', 1, defaultGst18Json, 20, 5, 1, '8901234567892', '7418', 0],
      ['Frosted Glass 30x60 Partition', 'GLS-002', 'Glass Panels', 'pcs', '1800.00', 1, defaultGst18Json, 0, 5, 1, '8901234567893', '7007', 0],
      ['Brass Door Knob Antique', 'BRS-003', 'Brass Fixtures', 'pcs', '450.00', 1, defaultGst18Json, 60, 15, 1, '8901234567894', '7418', 0],
      ['Tempered Glass 90x120 Clear', 'GLS-003', 'Glass Panels', 'pcs', '5200.00', 1, defaultGst18Json, 3, 5, 1, '8901234567895', '7007', 0],
      ['Brass Towel Rail 24 inch', 'BRS-004', 'Brass Fixtures', 'pcs', '2100.00', 1, defaultGst18Json, 12, 5, 1, '8901234567896', '7418', 0],
      ['Mirror Glass 60x60 Beveled', 'GLS-004', 'Glass Panels', 'pcs', '2800.00', 1, defaultGst18Json, 5, 5, 1, '8901234567897', '7009', 0],
    ];

    for (final p in seeds) {
      prodStmt.execute(p);
    }
    prodStmt.dispose();

    // Seed default branch
    final branchStmt = _db.prepare('''
      INSERT OR IGNORE INTO branches (
        id, name, code, address, city, state_code, country_code, phone, gstin,
        invoice_prefix, invoice_next_seq, currency_code, currency_symbol, is_active, is_default
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    branchStmt.execute([
      1, 'Main Flagship Store', 'BR-001', 'MG Road, Marine Drive', 'Kochi', '32', 'IN',
      '+91 98765 43210', '32AAACB1234F1Z0', 'FAAR-', 1, 'INR', '₹', 1, 1
    ]);
    branchStmt.execute([
      2, 'Warehouse & Supply Hub', 'BR-002', 'Industrial Area, Kalamassery', 'Kochi', '32', 'IN',
      '+91 98765 43211', '32AAACB1234F1Z0', 'WH-', 1, 'INR', '₹', 1, 0
    ]);
    branchStmt.dispose();

    // Seed default users
    final userStmt = _db.prepare('''
      INSERT OR IGNORE INTO users (id, name, email, role, branch_id, pin_code, is_active)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    userStmt.execute([1, 'System Administrator', 'admin@faarpos.com', 'org_admin', 1, '1234', 1]);
    userStmt.execute([2, 'Cashier Counter 1', 'cashier@faarpos.com', 'cashier', 1, '0000', 1]);
    userStmt.execute([3, 'Store Manager', 'manager@faarpos.com', 'manager', 1, '5678', 1]);
    userStmt.dispose();

    // Seed default tax groups
    final taxStmt = _db.prepare('''
      INSERT OR IGNORE INTO tax_groups (id, name, rate, components_json, is_compound, is_active)
      VALUES (?, ?, ?, ?, ?, ?)
    ''');
    taxStmt.execute([1, 'GST 18% (Standard)', '18.00', defaultGst18Json, 0, 1]);
    taxStmt.execute([2, 'GST 12% (Construction)', '12.00', jsonEncode({
      'id': 2, 'name': 'GST 12%', 'total_rate': '12.00', 'is_compound': false,
      'components': [
        {'id': 1, 'name': 'CGST 6%', 'rate': '6.00', 'applies_to': 'intraRegion'},
        {'id': 2, 'name': 'SGST 6%', 'rate': '6.00', 'applies_to': 'intraRegion'},
        {'id': 3, 'name': 'IGST 12%', 'rate': '12.00', 'applies_to': 'interRegion'},
      ]
    }), 0, 1]);
    taxStmt.execute([3, 'GST 5% (Essentials)', '5.00', jsonEncode({
      'id': 3, 'name': 'GST 5%', 'total_rate': '5.00', 'is_compound': false,
      'components': [
        {'id': 1, 'name': 'CGST 2.5%', 'rate': '2.50', 'applies_to': 'intraRegion'},
        {'id': 2, 'name': 'SGST 2.5%', 'rate': '2.50', 'applies_to': 'intraRegion'},
        {'id': 3, 'name': 'IGST 5%', 'rate': '5.00', 'applies_to': 'interRegion'},
      ]
    }), 0, 1]);
    taxStmt.execute([4, 'GST 0% (Exempt)', '0.00', jsonEncode({
      'id': 4, 'name': 'GST 0%', 'total_rate': '0.00', 'is_compound': false,
      'components': []
    }), 0, 1]);
    taxStmt.dispose();

    AppLog.info('Seeded default products, branches, users, taxes and store settings');
  }

  // ─── Products DAO ──────────────────────────────────────────────────────────

  List<ProductEntity> getAllProducts({String? query, String? category}) {
    String sql = 'SELECT * FROM products WHERE is_active = 1';
    final params = <Object?>[];

    if (category != null && category.isNotEmpty && category != 'All') {
      sql += ' AND category_name = ?';
      params.add(category);
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      sql += ' AND (LOWER(name) LIKE ? OR LOWER(sku) LIKE ? OR barcode LIKE ?)';
      params.addAll([q, q, q]);
    }

    sql += ' ORDER BY name ASC';
    final rows = _db.select(sql, params);
    return rows.map((r) => _mapRowToProduct(r)).toList();
  }

  ProductEntity? getProductById(int id) {
    final rows = _db.select('SELECT * FROM products WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _mapRowToProduct(rows.first);
  }

  ProductEntity? getProductByBarcodeOrSku(String code) {
    final rows = _db.select(
      'SELECT * FROM products WHERE (barcode = ? OR sku = ?) AND is_active = 1 LIMIT 1',
      [code, code],
    );
    if (rows.isEmpty) return null;
    return _mapRowToProduct(rows.first);
  }

  List<String> getCategories() {
    final rows = _db.select('SELECT DISTINCT category_name FROM products WHERE is_active = 1 ORDER BY category_name ASC');
    return rows.map((r) => r['category_name'] as String).toList();
  }

  int upsertProduct(ProductEntity p) {
    if (p.id > 0) {
      _db.execute('''
        UPDATE products SET
          name = ?, sku = ?, category_name = ?, unit_of_measure = ?, base_price = ?,
          tax_group_id = ?, stock_quantity = ?, low_stock_threshold = ?, is_active = ?,
          barcode = ?, image_url = ?
        WHERE id = ?
      ''', [
        p.name, p.sku, p.categoryName, p.unitOfMeasure, p.basePriceDecimal.toString(),
        p.taxGroupId, p.stockQuantity, p.lowStockThreshold, p.isActive ? 1 : 0,
        p.barcode, p.imageUrl, p.id,
      ]);
      _notifyChange('products');
      return p.id;
    } else {
      final stmt = _db.prepare('''
        INSERT INTO products (
          name, sku, category_name, unit_of_measure, base_price, tax_group_id,
          stock_quantity, low_stock_threshold, is_active, barcode, image_url
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      stmt.execute([
        p.name, p.sku, p.categoryName, p.unitOfMeasure, p.basePriceDecimal.toString(),
        p.taxGroupId, p.stockQuantity, p.lowStockThreshold, p.isActive ? 1 : 0,
        p.barcode, p.imageUrl,
      ]);
      stmt.dispose();
      final newId = _db.lastInsertRowId;
      _notifyChange('products');
      return newId;
    }
  }

  ProductEntity _mapRowToProduct(Row r) {
    return ProductEntity(
      id: r['id'] as int,
      name: r['name'] as String,
      sku: r['sku'] as String,
      categoryName: r['category_name'] as String,
      unitOfMeasure: r['unit_of_measure'] as String,
      basePriceDecimal: Decimal.parse(r['base_price'] as String),
      taxGroupId: r['tax_group_id'] as int?,
      stockQuantity: r['stock_quantity'] as int,
      lowStockThreshold: r['low_stock_threshold'] as int,
      isActive: (r['is_active'] as int) == 1,
      barcode: r['barcode'] as String?,
      imageUrl: r['image_url'] as String?,
    );
  }

  // ─── Transactions & Inventory DAO ──────────────────────────────────────────

  List<Map<String, dynamic>> getInventoryLogs({int limit = 100, String? movementType}) {
    String sql = '''
      SELECT il.*, p.name as product_name, p.sku as product_sku
      FROM inventory_logs il
      JOIN products p ON p.id = il.product_id
    ''';
    final params = <Object?>[];
    if (movementType != null && movementType.isNotEmpty) {
      sql += ' WHERE il.movement_type = ?';
      params.add(movementType);
    }
    sql += ' ORDER BY il.created_at DESC LIMIT ?';
    params.add(limit);
    final rows = _db.select(sql, params);
    return rows.map((r) => {
      'id': r['id'],
      'product_name': r['product_name'],
      'product_sku': r['product_sku'],
      'movement_type': r['movement_type'],
      'quantity_delta': r['quantity_delta'],
      'quantity_after': r['quantity_after'],
      'notes': r['notes'],
      'reference_receipt_no': r['reference_receipt_no'],
      'created_at': r['created_at'],
    }).toList();
  }

  void adjustStock({required int productId, required int quantityDelta, required String movementType, String? notes, int branchId = 1}) {
    _db.execute('BEGIN TRANSACTION');
    try {
      _db.execute('UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?', [quantityDelta, productId]);
      final row = _db.select('SELECT stock_quantity FROM products WHERE id = ?', [productId]).first;
      final after = row['stock_quantity'] as int;
      _db.execute('''
        INSERT INTO inventory_logs (local_id, product_id, branch_id, movement_type, quantity_delta, quantity_after, notes, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [const Uuid().v4(), productId, branchId, movementType, quantityDelta, after, notes, DateTime.now().toIso8601String()]);
      _db.execute('COMMIT');
      _notifyChange('products');
      _notifyChange('inventory_logs');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Atomically completes a checkout:
  /// 1. Generates unique sequential receipt number
  /// 2. Saves transaction and line items
  /// 3. Decrements product inventory
  /// 4. Writes immutable inventory movement ledger records
  /// 5. Enqueues to offline sync queue
  TransactionEntity createSaleTransaction({
    required List<CartItemEntity> items,
    required Decimal totalBaseAmount,
    required Decimal totalTaxAmount,
    required Decimal totalDiscountAmount,
    required Decimal grandTotal,
    required String paymentMethod,
    String? paymentReference,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    String? placeOfSupplyState,
    int branchId = 1,
    int cashierId = 1,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Cannot create sale transaction with empty items');
    }

    final localTxId = const Uuid().v4();
    final now = DateTime.now();

    // Atomic transaction block
    _db.execute('BEGIN TRANSACTION');
    try {
      // 1. Generate unique invoice number
      final nextSeq = _getAndIncrementInvoiceSeq();
      final prefix = getSetting('invoice_prefix') ?? 'FAAR-';
      final yearMonth = '${now.year}${now.month.toString().padLeft(2, '0')}';
      final receiptNo = '$prefix$yearMonth-${nextSeq.toString().padLeft(5, '0')}';

      final isInterState = placeOfSupplyState != null &&
          placeOfSupplyState != (getSetting('store_state_code') ?? '32');

      // 2. Insert transaction
      _db.execute('''
        INSERT INTO transactions (
          local_id, receipt_no, branch_id, cashier_id, transaction_type,
          customer_name, customer_phone, customer_gstin, place_of_supply_state,
          is_inter_state, total_base_amount, total_tax_amount, total_discount_amount,
          grand_total, payment_method, payment_reference, status, sync_status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        localTxId,
        receiptNo,
        branchId,
        cashierId,
        'sale',
        customerName,
        customerPhone,
        customerGstin,
        placeOfSupplyState,
        isInterState ? 1 : 0,
        totalBaseAmount.toString(),
        totalTaxAmount.toString(),
        totalDiscountAmount.toString(),
        grandTotal.toString(),
        paymentMethod,
        paymentReference,
        'completed',
        'pending',
        now.toIso8601String(),
      ]);

      final txId = _db.lastInsertRowId;
      final txItems = <TransactionItemEntity>[];

      final itemStmt = _db.prepare('''
        INSERT INTO transaction_items (
          transaction_local_id, product_id, product_name, sku, hsn_code,
          quantity, unit_price, discount_amount, tax_breakdown_json, tax_total, line_total
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      final updateStockStmt = _db.prepare('''
        UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?
      ''');

      final invLogStmt = _db.prepare('''
        INSERT INTO inventory_logs (
          local_id, product_id, branch_id, movement_type, quantity_delta,
          quantity_after, notes, reference_receipt_no, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      for (final item in items) {
        final taxBreakdownJson = jsonEncode(item.taxBreakdown.map((t) => t.toJson()).toList());

        itemStmt.execute([
          localTxId,
          item.productId,
          item.productName,
          item.sku,
          null, // hsnCode
          item.quantity,
          item.unitPriceDecimal.toString(),
          item.discountDecimal.toString(),
          taxBreakdownJson,
          item.lineTaxDecimal.toString(),
          item.lineTotalDecimal.toString(),
        ]);

        txItems.add(TransactionItemEntity(
          id: _db.lastInsertRowId,
          productId: item.productId,
          productNameSnapshot: item.productName,
          skuSnapshot: item.sku,
          quantity: item.quantity,
          unitPrice: item.unitPriceDecimal,
          discountAmount: item.discountDecimal,
          taxBreakdown: item.taxBreakdown.map((t) => t.toJson()).toList(),
          taxTotal: item.lineTaxDecimal,
          lineTotal: item.lineTotalDecimal,
        ));

        // Decrement stock & record ledger
        updateStockStmt.execute([item.quantity, item.productId]);

        final prodRow = _db.select('SELECT stock_quantity FROM products WHERE id = ?', [item.productId]).first;
        final currentStock = prodRow['stock_quantity'] as int;

        invLogStmt.execute([
          const Uuid().v4(),
          item.productId,
          branchId,
          'sale',
          -item.quantity,
          currentStock,
          'Sale at POS',
          receiptNo,
          now.toIso8601String(),
        ]);
      }

      itemStmt.dispose();
      updateStockStmt.dispose();
      invLogStmt.dispose();

      // 5. Enqueue to sync queue
      final payload = jsonEncode({
        'local_id': localTxId,
        'receipt_no': receiptNo,
        'branch_id': branchId,
        'cashier_id': cashierId,
        'grand_total': grandTotal.toString(),
        'items_count': items.length,
        'created_at': now.toIso8601String(),
      });

      _db.execute('''
        INSERT INTO sync_queue (entity_type, entity_local_id, payload_json, status, created_at)
        VALUES ('transaction', ?, ?, 'pending', ?)
      ''', [localTxId, payload, now.toIso8601String()]);

      _db.execute('COMMIT');

      _notifyChange('transactions');
      _notifyChange('products');
      _notifyChange('inventory_logs');
      _notifyChange('sync_queue');

      AppLog.info('Successfully created sale transaction: $receiptNo ($grandTotal)');

      return TransactionEntity(
        id: txId,
        receiptNo: receiptNo,
        transactionType: 'sale',
        customerName: customerName,
        customerPhone: customerPhone,
        totalBaseAmount: totalBaseAmount,
        totalTaxAmount: totalTaxAmount,
        totalDiscountAmount: totalDiscountAmount,
        grandTotal: grandTotal,
        paymentMethod: paymentMethod,
        paymentReference: paymentReference,
        status: 'completed',
        createdAt: now,
        items: txItems,
      );
    } catch (e, st) {
      _db.execute('ROLLBACK');
      AppLog.error('Failed to create sale transaction, rolled back', e, st);
      rethrow;
    }
  }

  int _getAndIncrementInvoiceSeq() {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', ['invoice_next_seq']);
    var seq = 1;
    if (rows.isNotEmpty) {
      seq = int.tryParse(rows.first['value'] as String) ?? 1;
    }
    _db.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', ['invoice_next_seq', (seq + 1).toString()]);
    return seq;
  }

  List<TransactionEntity> getRecentTransactions({int limit = 50}) {
    final rows = _db.select(
      'SELECT * FROM transactions ORDER BY id DESC LIMIT ?',
      [limit],
    );
    return rows.map((r) => _mapRowToTransaction(r)).toList();
  }

  TransactionEntity? getTransactionByReceiptNo(String receiptNo) {
    final rows = _db.select('SELECT * FROM transactions WHERE receipt_no = ? LIMIT 1', [receiptNo]);
    if (rows.isEmpty) return null;
    return _mapRowToTransaction(rows.first);
  }

  TransactionEntity _mapRowToTransaction(Row r) {
    final localId = r['local_id'] as String;
    final itemRows = _db.select('SELECT * FROM transaction_items WHERE transaction_local_id = ?', [localId]);

    final items = itemRows.map((ir) {
      final taxJson = ir['tax_breakdown_json'] as String;
      final parsedTaxes = (jsonDecode(taxJson) as List<dynamic>).cast<Map<String, dynamic>>();

      return TransactionItemEntity(
        id: ir['id'] as int,
        productId: ir['product_id'] as int,
        productNameSnapshot: ir['product_name'] as String,
        skuSnapshot: ir['sku'] as String,
        quantity: ir['quantity'] as int,
        unitPrice: Decimal.parse(ir['unit_price'] as String),
        discountAmount: Decimal.parse(ir['discount_amount'] as String),
        taxBreakdown: parsedTaxes,
        taxTotal: Decimal.parse(ir['tax_total'] as String),
        lineTotal: Decimal.parse(ir['line_total'] as String),
      );
    }).toList();

    return TransactionEntity(
      id: r['id'] as int,
      receiptNo: r['receipt_no'] as String,
      transactionType: r['transaction_type'] as String,
      customerName: r['customer_name'] as String?,
      customerPhone: r['customer_phone'] as String?,
      totalBaseAmount: Decimal.parse(r['total_base_amount'] as String),
      totalTaxAmount: Decimal.parse(r['total_tax_amount'] as String),
      totalDiscountAmount: Decimal.parse(r['total_discount_amount'] as String),
      grandTotal: Decimal.parse(r['grand_total'] as String),
      paymentMethod: r['payment_method'] as String,
      paymentReference: r['payment_reference'] as String?,
      status: r['status'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      items: items,
    );
  }

  Map<String, dynamic> getTodaySummary() {
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final rows = _db.select('''
      SELECT
        COUNT(*) as tx_count,
        COALESCE(SUM(CAST(grand_total AS REAL)), 0) as total_revenue,
        COALESCE(SUM(CAST(total_tax_amount AS REAL)), 0) as total_tax,
        COALESCE(SUM(CAST(total_discount_amount AS REAL)), 0) as total_discount
      FROM transactions
      WHERE created_at >= ? AND created_at <= ? AND status = 'completed'
    ''', ['${today}T00:00:00', '${today}T23:59:59.999']);
    final r = rows.first;
    return {
      'tx_count': (r['tx_count'] as num).toInt(),
      'total_revenue': (r['total_revenue'] as num).toDouble(),
      'total_tax': (r['total_tax'] as num).toDouble(),
      'total_discount': (r['total_discount'] as num).toDouble(),
    };
  }

  List<Map<String, dynamic>> getLowStockProducts() {
    final rows = _db.select('''
      SELECT id, name, sku, stock_quantity, low_stock_threshold
      FROM products
      WHERE is_active = 1 AND stock_quantity <= low_stock_threshold
      ORDER BY stock_quantity ASC
    ''');
    return rows.map((r) => {
      'id': r['id'],
      'name': r['name'],
      'sku': r['sku'],
      'stock_quantity': r['stock_quantity'],
      'low_stock_threshold': r['low_stock_threshold'],
    }).toList();
  }

  List<TransactionEntity> getTransactionsByDateRange(DateTime from, DateTime to) {
    final rows = _db.select(
      'SELECT * FROM transactions WHERE created_at >= ? AND created_at <= ? AND status = ? ORDER BY created_at DESC',
      [from.toIso8601String(), to.toIso8601String(), 'completed'],
    );
    return rows.map((r) => _mapRowToTransaction(r)).toList();
  }

  // ─── Settings DAO ──────────────────────────────────────────────────────────

  String? getSetting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  void setSetting(String key, String value) {
    _db.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', [key, value]);
    _notifyChange('settings');
  }

  // ─── Sync Queue DAO ────────────────────────────────────────────────────────
  
  List<Map<String, dynamic>> getPendingSyncItems({int limit = 50}) {
    final rows = _db.select(
      'SELECT * FROM sync_queue WHERE status = ? ORDER BY created_at ASC LIMIT ?',
      ['pending', limit],
    );
    return rows.map((r) => {
      'id': r['id'],
      'entity_type': r['entity_type'],
      'entity_local_id': r['entity_local_id'],
      'payload_json': r['payload_json'],
      'attempt_count': r['attempt_count'],
      'status': r['status'],
      'created_at': r['created_at'],
    }).toList();
  }

  void updateSyncItemStatus(int id, String status, {String? errorMessage}) {
    _db.execute(
      'UPDATE sync_queue SET status = ?, error_message = ?, attempt_count = attempt_count + 1, last_attempt_at = ? WHERE id = ?',
      [status, errorMessage, DateTime.now().toIso8601String(), id],
    );
    _notifyChange('sync_queue');
  }

  Map<String, int> getSyncQueueStats() {
    final rows = _db.select('SELECT status, COUNT(*) as cnt FROM sync_queue GROUP BY status');
    final stats = <String, int>{'pending': 0, 'synced': 0, 'failed': 0};
    for (final r in rows) {
      stats[r['status'] as String] = r['cnt'] as int;
    }
    return stats;
  }

  // ─── Branches DAO ──────────────────────────────────────────────────────────

  List<BranchEntity> getAllBranches() {
    final rows = _db.select('SELECT * FROM branches WHERE is_active = 1 ORDER BY id ASC');
    return rows.map((r) => BranchEntity(
      id: r['id'] as int,
      orgId: 1,
      name: r['name'] as String,
      branchCode: r['code'] as String,
      invoicePrefix: r['invoice_prefix'] as String,
      currencyCode: r['currency_code'] as String,
      currencySymbol: r['currency_symbol'] as String,
      taxRegistrationNo: r['gstin'] as String?,
      countryCode: r['country_code'] as String,
      city: r['city'] as String,
      isActive: (r['is_active'] as int) == 1,
    )).toList();
  }

  BranchEntity? getBranchById(int id) {
    final rows = _db.select('SELECT * FROM branches WHERE id = ? LIMIT 1', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return BranchEntity(
      id: r['id'] as int,
      orgId: 1,
      name: r['name'] as String,
      branchCode: r['code'] as String,
      invoicePrefix: r['invoice_prefix'] as String,
      currencyCode: r['currency_code'] as String,
      currencySymbol: r['currency_symbol'] as String,
      taxRegistrationNo: r['gstin'] as String?,
      countryCode: r['country_code'] as String,
      city: r['city'] as String,
      isActive: (r['is_active'] as int) == 1,
    );
  }

  int upsertBranch(BranchEntity b, {String address = '', String stateCode = '32', String phone = ''}) {
    if (b.id > 0) {
      _db.execute('''
        UPDATE branches SET
          name = ?, code = ?, address = ?, city = ?, state_code = ?,
          country_code = ?, phone = ?, gstin = ?, invoice_prefix = ?,
          currency_code = ?, currency_symbol = ?, is_active = ?
        WHERE id = ?
      ''', [
        b.name, b.branchCode, address, b.city, stateCode,
        b.countryCode, phone, b.taxRegistrationNo, b.invoicePrefix,
        b.currencyCode, b.currencySymbol, b.isActive ? 1 : 0, b.id,
      ]);
      _notifyChange('branches');
      return b.id;
    } else {
      final stmt = _db.prepare('''
        INSERT INTO branches (
          name, code, address, city, state_code, country_code, phone, gstin,
          invoice_prefix, currency_code, currency_symbol, is_active
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      stmt.execute([
        b.name, b.branchCode, address, b.city, stateCode,
        b.countryCode, phone, b.taxRegistrationNo, b.invoicePrefix,
        b.currencyCode, b.currencySymbol, b.isActive ? 1 : 0,
      ]);
      stmt.dispose();
      final newId = _db.lastInsertRowId;
      _notifyChange('branches');
      return newId;
    }
  }

  // ─── Users DAO ─────────────────────────────────────────────────────────────

  List<UserEntity> getAllUsers() {
    final rows = _db.select('SELECT * FROM users WHERE is_active = 1 ORDER BY id ASC');
    return rows.map((r) => UserEntity(
      id: r['id'] as int,
      orgId: 1,
      branchId: r['branch_id'] as int?,
      email: r['email'] as String,
      fullName: r['name'] as String,
      role: _parseRole(r['role'] as String),
      isActive: (r['is_active'] as int) == 1,
    )).toList();
  }

  UserRole _parseRole(String role) {
    switch (role) {
      case 'org_admin': return UserRole.orgAdmin;
      case 'branch_admin': return UserRole.branchAdmin;
      case 'manager': return UserRole.manager;
      default: return UserRole.cashier;
    }
  }

  int upsertUser(UserEntity u, {String pinCode = '0000'}) {
    if (u.id > 0) {
      _db.execute('''
        UPDATE users SET
          name = ?, email = ?, role = ?, branch_id = ?, is_active = ?
        WHERE id = ?
      ''', [
        u.fullName, u.email, u.role.name, u.branchId, u.isActive ? 1 : 0, u.id,
      ]);
      _notifyChange('users');
      return u.id;
    } else {
      final stmt = _db.prepare('''
        INSERT INTO users (name, email, role, branch_id, pin_code, is_active)
        VALUES (?, ?, ?, ?, ?, ?)
      ''');
      stmt.execute([
        u.fullName, u.email, u.role.name, u.branchId, pinCode, u.isActive ? 1 : 0,
      ]);
      stmt.dispose();
      final newId = _db.lastInsertRowId;
      _notifyChange('users');
      return newId;
    }
  }

  void deleteUser(int id) {
    _db.execute('UPDATE users SET is_active = 0 WHERE id = ?', [id]);
    _notifyChange('users');
  }

  // ─── Tax Groups DAO ────────────────────────────────────────────────────────

  List<TaxGroupEntity> getAllTaxGroups() {
    final rows = _db.select('SELECT * FROM tax_groups WHERE is_active = 1 ORDER BY id ASC');
    return rows.map((r) {
      final componentsJson = r['components_json'] as String;
      final rawComponents = (jsonDecode(componentsJson) as List<dynamic>).cast<Map<String, dynamic>>();

      final components = rawComponents.map((c) => TaxComponentEntity(
        id: c['id'] as int? ?? 1,
        name: c['name'] as String,
        rateDecimal: Decimal.parse(c['rate'].toString()),
        appliesToCondition: c['applies_to'] == 'interRegion'
            ? TaxCondition.interRegion
            : TaxCondition.intraRegion,
      )).toList();

      return TaxGroupEntity(
        id: r['id'] as int,
        name: r['name'] as String,
        totalRateDecimal: Decimal.parse(r['rate'] as String),
        isCompound: (r['is_compound'] as int) == 1,
        components: components,
      );
    }).toList();
  }

  int upsertTaxGroup(TaxGroupEntity g) {
    final componentsJson = jsonEncode(g.components.map((c) => {
      'id': c.id,
      'name': c.name,
      'rate': c.rateDecimal.toString(),
      'applies_to': c.appliesToCondition == TaxCondition.interRegion ? 'interRegion' : 'intraRegion',
    }).toList());

    if (g.id > 0) {
      _db.execute('''
        UPDATE tax_groups SET
          name = ?, rate = ?, components_json = ?, is_compound = ?
        WHERE id = ?
      ''', [
        g.name, g.totalRateDecimal.toString(), componentsJson, g.isCompound ? 1 : 0, g.id,
      ]);
      _notifyChange('tax_groups');
      return g.id;
    } else {
      final stmt = _db.prepare('''
        INSERT INTO tax_groups (name, rate, components_json, is_compound, is_active)
        VALUES (?, ?, ?, ?, 1)
      ''');
      stmt.execute([
        g.name, g.totalRateDecimal.toString(), componentsJson, g.isCompound ? 1 : 0,
      ]);
      stmt.dispose();
      final newId = _db.lastInsertRowId;
      _notifyChange('tax_groups');
      return newId;
    }
  }

  void close() {
    _dbChangeController.close();
    if (_isInitialized) {
      _db.dispose();
      _isInitialized = false;
    }
  }
}
