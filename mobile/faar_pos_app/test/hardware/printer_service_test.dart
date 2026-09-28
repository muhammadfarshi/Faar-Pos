import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:faar_pos_app/core/services/printer_service.dart';
import 'package:faar_pos_app/data/local/app_database.dart';
import 'package:faar_pos_app/domain/entities/transaction_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase inMemoryDb;

  setUp(() {
    final sqlite = sqlite3.openInMemory();
    inMemoryDb = AppDatabase.inMemory(sqlite);
  });

  tearDown(() {
    inMemoryDb.close();
  });

  test('PrinterService generates valid 58mm ESC/POS receipt bytes', () async {
    final tx = TransactionEntity(
      id: 1,
      receiptNo: 'FAAR-202608-00001',
      transactionType: 'sale',
      customerName: 'Acme Traders',
      totalBaseAmount: Decimal.parse('1000.00'),
      totalTaxAmount: Decimal.parse('180.00'),
      totalDiscountAmount: Decimal.zero,
      grandTotal: Decimal.parse('1180.00'),
      paymentMethod: 'UPI',
      status: 'completed',
      createdAt: DateTime(2026, 8, 15, 14, 30),
      items: [
        TransactionItemEntity(
          id: 1,
          productId: 1,
          productNameSnapshot: 'Brass Fixture Luxury A',
          skuSnapshot: 'BRS-001',
          quantity: 1,
          unitPrice: Decimal.parse('1000.00'),
          discountAmount: Decimal.zero,
          taxBreakdown: [
            {'name': 'CGST 9%', 'rate': '9.00', 'amount': '90.00'},
            {'name': 'SGST 9%', 'rate': '9.00', 'amount': '90.00'},
          ],
          taxTotal: Decimal.parse('180.00'),
          lineTotal: Decimal.parse('1180.00'),
        ),
      ],
    );

    final bytes58 = await PrinterService.instance.generateReceiptBytes(
      tx,
      paperSize: PrinterPaperSize.mm58,
    );

    expect(bytes58, isNotEmpty);
    expect(bytes58.length, greaterThan(50));
  });

  test('PrinterService generates valid 80mm wide ESC/POS receipt bytes', () async {
    final tx = TransactionEntity(
      id: 1,
      receiptNo: 'FAAR-202608-00002',
      transactionType: 'sale',
      totalBaseAmount: Decimal.parse('5000.00'),
      totalTaxAmount: Decimal.parse('900.00'),
      totalDiscountAmount: Decimal.zero,
      grandTotal: Decimal.parse('5900.00'),
      paymentMethod: 'Cash',
      status: 'completed',
      createdAt: DateTime.now(),
      items: [],
    );

    final bytes80 = await PrinterService.instance.generateReceiptBytes(
      tx,
      paperSize: PrinterPaperSize.mm80,
    );

    expect(bytes80, isNotEmpty);
  });

  test('PrinterService generates test print bytes', () async {
    final testBytes = await PrinterService.instance.generateTestReceiptBytes();
    expect(testBytes, isNotEmpty);
  });
}
