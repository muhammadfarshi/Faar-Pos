import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decimal/decimal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/tax_entity.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common/currency_text.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod = 'Cash';
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerGstinCtrl = TextEditingController();
  final _tenderedCtrl = TextEditingController();

  Decimal _amountTendered = Decimal.zero;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'name': 'Cash', 'icon': Icons.payments_outlined},
    {'name': 'UPI / QR', 'icon': Icons.qr_code_2},
    {'name': 'Card', 'icon': Icons.credit_card},
    {'name': 'Net Banking', 'icon': Icons.account_balance},
  ];

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _customerNameCtrl.text = cart.customerName ?? '';
    _customerPhoneCtrl.text = cart.customerPhone ?? '';
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerGstinCtrl.dispose();
    _tenderedCtrl.dispose();
    super.dispose();
  }

  void _onTenderedChanged(String val) {
    setState(() {
      _amountTendered = Decimal.tryParse(val.trim()) ?? Decimal.zero;
    });
  }

  void _setTenderedPreset(Decimal amount) {
    _tenderedCtrl.text = amount.toStringAsFixed(0);
    _onTenderedChanged(_tenderedCtrl.text);
  }

  Future<void> _completeSale(Decimal grandTotal, Decimal subtotal, Decimal taxTotal, Decimal discountTotal) async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot checkout with empty cart')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final transaction = AppDatabase.instance.createSaleTransaction(
        items: cartState.items,
        totalBaseAmount: subtotal,
        totalTaxAmount: taxTotal,
        totalDiscountAmount: discountTotal,
        grandTotal: grandTotal,
        paymentMethod: _paymentMethod,
        customerName: _customerNameCtrl.text.trim().isNotEmpty ? _customerNameCtrl.text.trim() : null,
        customerPhone: _customerPhoneCtrl.text.trim().isNotEmpty ? _customerPhoneCtrl.text.trim() : null,
        customerGstin: _customerGstinCtrl.text.trim().isNotEmpty ? _customerGstinCtrl.text.trim() : null,
        placeOfSupplyState: cartState.supplyCondition == TaxCondition.interRegion ? 'Other' : '32',
      );

      // Clear Riverpod cart state
      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        context.go('/pos/receipt', extra: transaction);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete sale: $e'),
            backgroundColor: FaarPosTheme.kDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discountTotal = ref.watch(cartDiscountTotalProvider);
    final taxTotal = ref.watch(cartTaxTotalProvider);
    final grandTotal = ref.watch(cartGrandTotalProvider);

    final changeDue = _amountTendered > grandTotal ? _amountTendered - grandTotal : Decimal.zero;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout & Payment'),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total Payable Card
                Card(
                  color: FaarPosTheme.kSurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: FaarPosTheme.kPrimary, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL AMOUNT DUE',
                          style: TextStyle(
                            fontSize: 12,
                            color: FaarPosTheme.kTextSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CurrencyText(
                          amount: grandTotal,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 34,
                            color: FaarPosTheme.kPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${cartState.items.length} unique items • ${cartState.items.fold(0, (s, i) => s + i.quantity)} total units',
                          style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Method Selector
                const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                Row(
                  children: _paymentMethods.map((pm) {
                    final isSelected = _paymentMethod == pm['name'];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Material(
                          color: isSelected ? FaarPosTheme.kPrimary.withValues(alpha: 0.15) : FaarPosTheme.kSurface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => setState(() => _paymentMethod = pm['name'] as String),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? FaarPosTheme.kPrimary : FaarPosTheme.kCardBorder,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    pm['icon'] as IconData,
                                    color: isSelected ? FaarPosTheme.kPrimary : FaarPosTheme.kTextSecondary,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    pm['name'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? FaarPosTheme.kPrimary : FaarPosTheme.kTextPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Cash Tender & Change Due Section (Visible when Cash is selected)
                if (_paymentMethod == 'Cash') ...[
                  Card(
                    color: FaarPosTheme.kSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: FaarPosTheme.kCardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash Tendered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _tenderedCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: _onTenderedChanged,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.currency_rupee),
                              hintText: 'Enter amount received...',
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Tender Presets
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                label: const Text('Exact'),
                                onPressed: () => _setTenderedPreset(grandTotal),
                              ),
                              ActionChip(
                                label: const Text('₹100'),
                                onPressed: () => _setTenderedPreset(Decimal.fromInt(100)),
                              ),
                              ActionChip(
                                label: const Text('₹500'),
                                onPressed: () => _setTenderedPreset(Decimal.fromInt(500)),
                              ),
                              ActionChip(
                                label: const Text('₹1000'),
                                onPressed: () => _setTenderedPreset(Decimal.fromInt(1000)),
                              ),
                              ActionChip(
                                label: const Text('₹2000'),
                                onPressed: () => _setTenderedPreset(Decimal.fromInt(2000)),
                              ),
                            ],
                          ),
                          if (_amountTendered > Decimal.zero) ...[
                            const SizedBox(height: 16),
                            const Divider(color: FaarPosTheme.kDivider),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Change Return to Customer:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                CurrencyText(
                                  amount: changeDue,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: changeDue >= Decimal.zero ? FaarPosTheme.kSuccess : FaarPosTheme.kDanger,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Customer Details Section
                Card(
                  color: FaarPosTheme.kSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: FaarPosTheme.kCardBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customer Invoice Info (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customerPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customerGstinCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Customer GSTIN (B2B)',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Complete Sale Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _completeSale(grandTotal, subtotal, taxTotal, discountTotal),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FaarPosTheme.kSuccess,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: const Text(
                      'COMPLETE SALE & PRINT RECEIPT',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
