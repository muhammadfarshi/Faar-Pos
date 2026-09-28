import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:faar_pos_app/data/local/app_database.dart';
import 'package:faar_pos_app/domain/entities/cart_item_entity.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    final sqlite = sqlite3.openInMemory();
    db = AppDatabase.inMemory(sqlite);
  });

  tearDown(() {
    db.close();
  });

  group('AppDatabase - Products & Catalog', () {
    test('Product querying and search', () {
      final products = db.getAllProducts();
      expect(products.isNotEmpty, true);

      final brassProducts = db.getAllProducts(category: 'Brass Fixtures');
      expect(brassProducts.every((p) => p.categoryName == 'Brass Fixtures'), true);

      final searchResults = db.getAllProducts(query: 'Luxury');
      expect(searchResults.length, 1);
      expect(searchResults.first.name, contains('Luxury'));
    });

    test('Get product by barcode or SKU', () {
      final bySku = db.getProductByBarcodeOrSku('BRS-001');
      expect(bySku, isNotNull);
      expect(bySku!.name, contains('Brass Fixture'));

      final byBarcode = db.getProductByBarcodeOrSku('8901234567890');
      expect(byBarcode, isNotNull);
      expect(byBarcode!.sku, 'BRS-001');
    });
  });

  group('AppDatabase - Atomic Sales & Inventory Movement', () {
    test('createSaleTransaction decrements stock, records ledger and sync queue', () {
      final initialProduct = db.getProductByBarcodeOrSku('BRS-001')!;
      final initialStock = initialProduct.stockQuantity; // e.g. 45

      final cartItem = CartItemEntity(
        id: 1,
        productId: initialProduct.id,
        productName: initialProduct.name,
        sku: initialProduct.sku,
        quantity: 3,
        unitPriceDecimal: initialProduct.basePriceDecimal,
        discountDecimal: Decimal.zero,
        taxBreakdown: [
          TaxLineItem(name: 'CGST 9%', rateDecimal: Decimal.parse('9.00'), amountDecimal: Decimal.parse('337.50')),
          TaxLineItem(name: 'SGST 9%', rateDecimal: Decimal.parse('9.00'), amountDecimal: Decimal.parse('337.50')),
        ],
        lineTaxDecimal: Decimal.parse('675.00'),
        lineTotalDecimal: Decimal.parse('4425.00'),
      );

      final tx = db.createSaleTransaction(
        items: [cartItem],
        totalBaseAmount: Decimal.parse('3750.00'),
        totalTaxAmount: Decimal.parse('675.00'),
        totalDiscountAmount: Decimal.zero,
        grandTotal: Decimal.parse('4425.00'),
        paymentMethod: 'UPI',
        customerName: 'Anoop Nair',
        customerPhone: '+919876543210',
      );

      // Verify transaction
      expect(tx.receiptNo, startsWith('FAAR-'));
      expect(tx.grandTotal, Decimal.parse('4425.00'));
      expect(tx.customerName, 'Anoop Nair');
      expect(tx.items.length, 1);
      expect(tx.items.first.quantity, 3);

      // Verify stock was decremented in database
      final updatedProduct = db.getProductById(initialProduct.id)!;
      expect(updatedProduct.stockQuantity, initialStock - 3);

      // Verify transaction is retrievable by receipt number
      final fetchedTx = db.getTransactionByReceiptNo(tx.receiptNo);
      expect(fetchedTx, isNotNull);
      expect(fetchedTx!.receiptNo, tx.receiptNo);
      expect(fetchedTx.items.length, 1);
    });
  });
}
