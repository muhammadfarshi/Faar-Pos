import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:faar_pos_app/data/local/app_database.dart';
import 'package:faar_pos_app/presentation/providers/cart_provider.dart';
import 'package:faar_pos_app/presentation/screens/pos/cart_pane.dart';
import 'package:faar_pos_app/presentation/screens/pos/catalog_pane.dart';

void main() {
  late AppDatabase inMemoryDb;

  setUp(() {
    final sqlite = sqlite3.openInMemory();
    inMemoryDb = AppDatabase.inMemory(sqlite);
  });

  tearDown(() {
    inMemoryDb.close();
  });

  testWidgets('CatalogPane displays products from SQLite and adds to Cart', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CatalogPane(),
          ),
        ),
      ),
    );

    // Allow FutureProvider to resolve
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(TextField), findsOneWidget); // Search bar
    expect(find.text('Brass Fixtures'), findsWidgets);
  });

  testWidgets('CartPane shows empty state when cart has no items', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CartPane(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Cart is empty'), findsOneWidget);
  });

  test('CartNotifier adds item and calculates GST breakdown correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final product = inMemoryDb.getProductByBarcodeOrSku('BRS-001')!;

    // Initial cart is empty
    expect(container.read(cartItemCountProvider), 0);

    // Add 1 item
    container.read(cartProvider.notifier).addItem(product);

    expect(container.read(cartItemCountProvider), 1);
    final subtotal = container.read(cartSubtotalProvider);
    expect(subtotal, product.basePriceDecimal);

    // Verify GST 18% (9% CGST + 9% SGST)
    final taxTotal = container.read(cartTaxTotalProvider);
    expect(taxTotal.toStringAsFixed(2), '225.00'); // 18% of 1250 = 225

    final grandTotal = container.read(cartGrandTotalProvider);
    expect(grandTotal.toStringAsFixed(2), '1475.00'); // 1250 + 225 = 1475
  });
}
