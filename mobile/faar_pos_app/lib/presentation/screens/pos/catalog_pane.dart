import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../../domain/entities/product_entity.dart';
import '../../widgets/pos/barcode_scanner_modal.dart';
import '../../widgets/common/currency_text.dart';

class CatalogPane extends ConsumerStatefulWidget {
  const CatalogPane({super.key});

  @override
  ConsumerState<CatalogPane> createState() => _CatalogPaneState();
}

class _CatalogPaneState extends ConsumerState<CatalogPane> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final categories = ref.watch(categoriesProvider);
    final cartState = ref.watch(cartProvider);
    final grandTotal = ref.watch(cartGrandTotalProvider);
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      body: Column(
        children: [
          // Search bar & Barcode Scan
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
                    decoration: InputDecoration(
                      hintText: 'Search products, SKU, barcode...',
                      prefixIcon: const Icon(Icons.search, color: FaarPosTheme.kTextSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: FaarPosTheme.kTextSecondary),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(searchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: FaarPosTheme.kPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  tooltip: 'Scan Barcode',
                  onPressed: () => BarcodeScannerModal.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Category chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return FilterChip(
                    label: const Text('All Products'),
                    selected: selectedCategory == null,
                    onSelected: (_) => ref.read(selectedCategoryProvider.notifier).state = null,
                    selectedColor: FaarPosTheme.kPrimary.withValues(alpha: 0.2),
                    checkmarkColor: FaarPosTheme.kPrimary,
                  );
                }
                final cat = categories[index - 1];
                return FilterChip(
                  label: Text(cat),
                  selected: selectedCategory == cat,
                  onSelected: (_) => ref.read(selectedCategoryProvider.notifier).state = cat,
                  selectedColor: FaarPosTheme.kPrimary.withValues(alpha: 0.2),
                  checkmarkColor: FaarPosTheme.kPrimary,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Product grid
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                if (products.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: FaarPosTheme.kTextSecondary),
                        SizedBox(height: 16),
                        Text('No products found', style: TextStyle(color: FaarPosTheme.kTextSecondary)),
                      ],
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 4
                        : constraints.maxWidth > 600
                            ? 3
                            : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 80),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final cartItem = cartState.items.where((i) => i.productId == product.id).firstOrNull;
                        final qtyInCart = cartItem?.quantity ?? 0;

                        return _ProductCard(
                          product: product,
                          qtyInCart: qtyInCart,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(cartProvider.notifier).addItem(product);
                          },
                          onIncrement: () {
                            HapticFeedback.selectionClick();
                            ref.read(cartProvider.notifier).addItem(product);
                          },
                          onDecrement: () {
                            if (cartItem != null) {
                              HapticFeedback.selectionClick();
                              ref.read(cartProvider.notifier).updateQuantity(cartItem.id, qtyInCart - 1);
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Sticky Floating Checkout Bar for Mobile Phone
      bottomSheet: (!isTablet && cartState.items.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: FaarPosTheme.kSurface,
                border: const Border(top: BorderSide(color: FaarPosTheme.kCardBorder)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FaarPosTheme.kPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${cartState.items.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('Total:', style: TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12)),
                            ],
                          ),
                          CurrencyText(
                            amount: grandTotal,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: FaarPosTheme.kPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/pos/cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FaarPosTheme.kPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                      label: const Text('View Cart', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductEntity product;
  final int qtyInCart;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ProductCard({
    required this.product,
    required this.qtyInCart,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FaarPosTheme.kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: qtyInCart > 0 ? FaarPosTheme.kPrimary : FaarPosTheme.kCardBorder,
          width: qtyInCart > 0 ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: FaarPosTheme.kSurfaceElevated,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholderIcon()),
                          )
                        : _placeholderIcon(),
                  ),
                  if (qtyInCart > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: FaarPosTheme.kPrimary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          '$qtyInCart in cart',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: FaarPosTheme.kTextPrimary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.sku,
                    style: const TextStyle(
                      fontSize: 10,
                      color: FaarPosTheme.kTextSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StockBadge(
                        qty: product.stockQuantity,
                        threshold: product.lowStockThreshold,
                      ),
                      Text(
                        '₹${product.formattedPrice}',
                        style: const TextStyle(
                          color: FaarPosTheme.kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() => const Center(
    child: Icon(Icons.inventory_2_outlined, size: 36, color: FaarPosTheme.kTextSecondary),
  );
}

class _StockBadge extends StatelessWidget {
  final int qty;
  final int threshold;
  const _StockBadge({required this.qty, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String label;
    final Color fg;
    if (qty <= 0) {
      bg = FaarPosTheme.kDanger;
      label = 'Out';
      fg = Colors.white;
    } else if (qty <= threshold) {
      bg = FaarPosTheme.kWarning;
      label = 'Low';
      fg = Colors.black;
    } else {
      bg = FaarPosTheme.kSuccess;
      label = 'In Stock';
      fg = Colors.white;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: fg, fontWeight: FontWeight.bold)),
    );
  }
}
