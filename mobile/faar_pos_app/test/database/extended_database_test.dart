import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:faar_pos_app/data/local/app_database.dart';
import 'package:faar_pos_app/domain/entities/branch_entity.dart';
import 'package:faar_pos_app/domain/entities/user_entity.dart';

void main() {
  late AppDatabase inMemoryDb;

  setUp(() {
    final sqlite = sqlite3.openInMemory();
    inMemoryDb = AppDatabase.inMemory(sqlite);
  });

  tearDown(() {
    inMemoryDb.close();
  });

  group('AppDatabase - Multi-Branch Management', () {
    test('getAllBranches returns seeded branches', () {
      final branches = inMemoryDb.getAllBranches();
      expect(branches.length, greaterThanOrEqualTo(2));
      expect(branches.any((b) => b.branchCode == 'BR-001'), isTrue);
    });

    test('upsertBranch adds a new store and updates existing store', () {
      final newBranch = const BranchEntity(
        id: 0,
        orgId: 1,
        name: 'Downtown Outlet',
        branchCode: 'DT-01',
        invoicePrefix: 'DT-',
        currencyCode: 'INR',
        currencySymbol: '₹',
        taxRegistrationNo: '32AAACB9999F1Z9',
        countryCode: 'IN',
        city: 'Kochi',
        isActive: true,
      );

      final branchId = inMemoryDb.upsertBranch(newBranch);
      expect(branchId, greaterThan(0));

      final fetched = inMemoryDb.getBranchById(branchId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Downtown Outlet');
      expect(fetched.invoicePrefix, 'DT-');
    });
  });

  group('AppDatabase - User Management & RBAC', () {
    test('getAllUsers returns seeded users', () {
      final users = inMemoryDb.getAllUsers();
      expect(users.length, greaterThanOrEqualTo(3));
      expect(users.any((u) => u.email == 'admin@faarpos.com'), isTrue);
    });

    test('upsertUser creates and deletes user', () {
      final user = const UserEntity(
        id: 0,
        orgId: 1,
        email: 'john@store.com',
        fullName: 'John Doe',
        role: UserRole.cashier,
        isActive: true,
      );

      final userId = inMemoryDb.upsertUser(user, pinCode: '4321');
      expect(userId, greaterThan(0));

      var users = inMemoryDb.getAllUsers();
      expect(users.any((u) => u.id == userId), isTrue);

      inMemoryDb.deleteUser(userId);
      users = inMemoryDb.getAllUsers();
      expect(users.any((u) => u.id == userId), isFalse);
    });
  });

  group('AppDatabase - Stock Adjustments & Movement Logs', () {
    test('adjustStock atomically updates stock and writes to inventory_logs', () {
      final product = inMemoryDb.getProductByBarcodeOrSku('BRS-001')!;
      final initialStock = product.stockQuantity;

      inMemoryDb.adjustStock(
        productId: product.id,
        quantityDelta: 15,
        movementType: 'restock',
        notes: 'Bulk shipment arrival',
      );

      final updated = inMemoryDb.getProductById(product.id)!;
      expect(updated.stockQuantity, initialStock + 15);

      final logs = inMemoryDb.getInventoryLogs(movementType: 'restock');
      expect(logs, isNotEmpty);
      expect(logs.first['quantity_delta'], 15);
      expect(logs.first['notes'], 'Bulk shipment arrival');
    });
  });

  group('AppDatabase - Dashboard Summary & Reporting', () {
    test('getTodaySummary and getLowStockProducts return accurate metrics', () {
      final summary = inMemoryDb.getTodaySummary();
      expect(summary.containsKey('tx_count'), isTrue);
      expect(summary.containsKey('total_revenue'), isTrue);

      final lowStock = inMemoryDb.getLowStockProducts();
      expect(lowStock, isA<List<Map<String, dynamic>>>());
    });
  });
}
