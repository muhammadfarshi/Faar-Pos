import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decimal/decimal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/tax_entity.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common/currency_text.dart';

class CartPane extends ConsumerWidget {
  const CartPane({super.key});

  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: FaarPosTheme.kDanger),
            SizedBox(width: 8),
            Text('Clear Cart?'),
          ],
        ),
        content: const Text('Are you sure you want to remove all items from the current active cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FaarPosTheme.kDanger),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(cartProvider.notifier).clearCart();
            },
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDialog(BuildContext context, WidgetRef ref) {
    final cartState = ref.read(cartProvider);
    final nameCtrl = TextEditingController(text: cartState.customerName ?? '');
    final phoneCtrl = TextEditingController(text: cartState.customerPhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).setCustomer(
                name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountTotalProvider);
    final taxTotal = ref.watch(cartTaxTotalProvider);
    final grandTotal = ref.watch(cartGrandTotalProvider);
    final taxBreakdown = ref.watch(cartAggregatedTaxBreakdownProvider);

    if (cartState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 72, color: FaarPosTheme.kTextSecondary),
              const SizedBox(height: 16),
              const Text(
                'Cart is empty',
                style: TextStyle(
                  color: FaarPosTheme.kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select items from the catalog or scan a product barcode to start a sale.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/pos/catalog'),
                icon: const Icon(Icons.storefront),
                label: const Text('Browse Products'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Supply Condition & Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: FaarPosTheme.kSurface,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Customer tag
                  InkWell(
                    onTap: () => _showCustomerDialog(context, ref),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: FaarPosTheme.kSurfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: FaarPosTheme.kCardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin, size: 16, color: FaarPosTheme.kPrimary),
                          const SizedBox(width: 6),
                          Text(
                            cartState.customerName ?? 'Add Customer',
                            style: TextStyle(
                              fontSize: 12,
                              color: cartState.customerName != null ? FaarPosTheme.kTextPrimary : FaarPosTheme.kTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, color: FaarPosTheme.kDanger, size: 20),
                        tooltip: 'Clear Cart',
                        onPressed: () => _showClearCartDialog(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Tax Region Switcher
              Row(
                children: [
                  const Text('GST Supply: ', style: TextStyle(fontSize: 11, color: FaarPosTheme.kTextSecondary)),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: const Text('Intra-State (CGST+SGST)', style: TextStyle(fontSize: 10)),
                    selected: cartState.supplyCondition == TaxCondition.intraRegion,
                    onSelected: (val) {
                      if (val) {
                        ref.read(cartProvider.notifier).setSupplyCondition(TaxCondition.intraRegion);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Inter-State (IGST)', style: TextStyle(fontSize: 10)),
                    selected: cartState.supplyCondition == TaxCondition.interRegion,
                    onSelected: (val) {
                      if (val) {
                        ref.read(cartProvider.notifier).setSupplyCondition(TaxCondition.interRegion);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: FaarPosTheme.kDivider),

        // Items list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: cartState.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: FaarPosTheme.kDivider),
            itemBuilder: (context, index) {
              final item = cartState.items[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Item Name & SKU
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.sku} • ₹${item.unitPriceDecimal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, color: FaarPosTheme.kTextSecondary),
                          ),
                        ],
                      ),
                    ),

                    // Quantity Stepper
                    Container(
                      decoration: BoxDecoration(
                        color: FaarPosTheme.kSurfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Icon(Icons.remove, size: 16, color: FaarPosTheme.kTextPrimary),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          InkWell(
                            onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Icon(Icons.add, size: 16, color: FaarPosTheme.kTextPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Line Total & Remove button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CurrencyText(
                          amount: item.lineTotalDecimal,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: FaarPosTheme.kPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: () => ref.read(cartProvider.notifier).removeItem(item.id),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.close, size: 16, color: FaarPosTheme.kDanger),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Financial Summary Footer
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(
            color: FaarPosTheme.kSurface,
            border: Border(top: BorderSide(color: FaarPosTheme.kDivider)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 13)),
                  CurrencyText(amount: subtotal, style: const TextStyle(fontSize: 13)),
                ],
              ),
              if (discount > Decimal.zero) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Discount', style: TextStyle(color: FaarPosTheme.kSuccess, fontSize: 13)),
                    CurrencyText(amount: discount, style: const TextStyle(color: FaarPosTheme.kSuccess, fontSize: 13)),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              // Itemized GST breakdown
              for (final tax in taxBreakdown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${tax.name} (${tax.rateDecimal}%)',
                        style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                      ),
                      CurrencyText(
                        amount: tax.amountDecimal,
                        style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total GST', style: TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 13)),
                  CurrencyText(amount: taxTotal, style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: FaarPosTheme.kDivider),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'GRAND TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: FaarPosTheme.kTextPrimary),
                  ),
                  CurrencyText(
                    amount: grandTotal,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: FaarPosTheme.kPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/pos/checkout');
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text(
                    'PROCEED TO CHECKOUT',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
