import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/printer_service.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../providers/cart_provider.dart';

class ReceiptScreen extends ConsumerWidget {
  final TransactionEntity? transaction;

  const ReceiptScreen({super.key, this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If passed directly via router extra or fetch latest transaction from DB
    final tx = transaction ?? AppDatabase.instance.getRecentTransactions(limit: 1).firstOrNull;

    if (tx == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No recent receipt found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/pos/catalog'),
                child: const Text('Go to Catalog'),
              ),
            ],
          ),
        ),
      );
    }

    final storeName = AppDatabase.instance.getSetting('store_name') ?? 'FAAR POS Flagship Store';
    final storeGstin = AppDatabase.instance.getSetting('store_gstin') ?? '32AAACB1234F1Z0';
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Invoice / Receipt'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Receipt',
            onPressed: () {
              final buffer = StringBuffer();
              buffer.writeln('==============================');
              buffer.writeln('      $storeName');
              buffer.writeln('      GSTIN: $storeGstin');
              buffer.writeln('==============================');
              buffer.writeln('Invoice: ${tx.receiptNo}');
              buffer.writeln('Date: ${dateFormat.format(tx.createdAt)}');
              buffer.writeln('Payment: ${tx.paymentMethod.toUpperCase()}');
              if (tx.customerName != null) buffer.writeln('Customer: ${tx.customerName}');
              buffer.writeln('------------------------------');
              for (final item in tx.items) {
                buffer.writeln('${item.productNameSnapshot} x${item.quantity}  ₹${item.lineTotal.toStringAsFixed(2)}');
              }
              buffer.writeln('------------------------------');
              buffer.writeln('Subtotal: ₹${tx.totalBaseAmount.toStringAsFixed(2)}');
              buffer.writeln('GST Tax:  ₹${tx.totalTaxAmount.toStringAsFixed(2)}');
              buffer.writeln('GRAND TOTAL: ₹${tx.grandTotal.toStringAsFixed(2)}');
              buffer.writeln('==============================');
              buffer.writeln('  Thank you for your business!');

              Clipboard.setData(ClipboardData(text: buffer.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tax invoice copied to clipboard! Ready to share via WhatsApp/SMS.'),
                  backgroundColor: FaarPosTheme.kSuccess,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Thermal Receipt Paper Card
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Store Header
                  Center(
                    child: Text(
                      storeName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'GSTIN: $storeGstin',
                      style: const TextStyle(color: Colors.black87, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Center(
                    child: Text(
                      'TAX INVOICE',
                      style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDashedLine(),
                  const SizedBox(height: 10),

                  // Invoice Meta
                  _buildReceiptRow('Invoice No:', tx.receiptNo, isBold: true),
                  const SizedBox(height: 4),
                  _buildReceiptRow('Date & Time:', dateFormat.format(tx.createdAt)),
                  const SizedBox(height: 4),
                  _buildReceiptRow('Payment:', '${tx.paymentMethod.toUpperCase()} (Completed)'),

                  if (tx.customerName != null && tx.customerName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildReceiptRow('Customer:', tx.customerName!),
                  ],
                  if (tx.customerPhone != null && tx.customerPhone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildReceiptRow('Phone:', tx.customerPhone!),
                  ],

                  const SizedBox(height: 10),
                  _buildDashedLine(),
                  const SizedBox(height: 10),

                  // Items Table Header
                  Row(
                    children: const [
                      Expanded(flex: 4, child: Text('ITEM', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'monospace'))),
                      Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'monospace'))),
                      Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'monospace'))),
                      Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'monospace'))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildDashedLine(),
                  const SizedBox(height: 8),

                  // Items
                  for (final item in tx.items) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productNameSnapshot,
                                  style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                ),
                                Text(
                                  item.skuSnapshot,
                                  style: const TextStyle(color: Colors.black54, fontSize: 9, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.unitPrice.toStringAsFixed(2),
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.black, fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.lineTotal.toStringAsFixed(2),
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  _buildDashedLine(),
                  const SizedBox(height: 8),

                  // Totals
                  _buildReceiptRow('Taxable Amount:', '₹${tx.totalBaseAmount.toStringAsFixed(2)}'),
                  if (tx.totalDiscountAmount > Decimal.zero) ...[
                    const SizedBox(height: 4),
                    _buildReceiptRow('Discount:', '-₹${tx.totalDiscountAmount.toStringAsFixed(2)}'),
                  ],
                  const SizedBox(height: 4),
                  _buildReceiptRow('Total GST Tax:', '₹${tx.totalTaxAmount.toStringAsFixed(2)}'),

                  const SizedBox(height: 8),
                  _buildDashedLine(),
                  const SizedBox(height: 8),

                  // Grand Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'GRAND TOTAL:',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                      ),
                      Text(
                        '₹${tx.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'monospace'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _buildDashedLine(),
                  const SizedBox(height: 12),

                  // Footer
                  const Center(
                    child: Text(
                      'Thank You! Please Visit Again',
                      style: TextStyle(color: Colors.black87, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Powered by FAAR POS',
                      style: TextStyle(color: Colors.black45, fontSize: 9, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final printer = PrinterService.instance.connectedPrinter;

                      if (printer == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('No Bluetooth thermal printer connected.'),
                            backgroundColor: FaarPosTheme.kWarning,
                            action: SnackBarAction(
                              label: 'Printers',
                              textColor: Colors.white,
                              onPressed: () => context.go('/admin'),
                            ),
                          ),
                        );
                        return;
                      }

                      final paperSetting = AppDatabase.instance.getSetting('printer_paper_size') ?? '58';
                      final pSize = paperSetting == '80' ? PrinterPaperSize.mm80 : PrinterPaperSize.mm58;

                      final bytes = await PrinterService.instance.generateReceiptBytes(tx, paperSize: pSize);
                      final ok = await PrinterService.instance.printBytes(bytes);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Receipt sent to ${printer.name}!'
                                : 'Failed to send receipt to printer.'),
                            backgroundColor: ok ? FaarPosTheme.kSuccess : FaarPosTheme.kDanger,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print Receipt'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(cartProvider.notifier).clearCart();
                      context.go('/pos/catalog');
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('New Sale'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 2.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black38),
              ),
            );
          }),
        );
      },
    );
  }
}
