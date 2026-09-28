import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/pos/barcode_scanner_modal.dart';
import '../../providers/catalog_provider.dart';
import '../admin/stock_adjustment_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for DB changes to rebuild dashboard
    ref.watch(databaseChangeListenerProvider);

    final summary = AppDatabase.instance.getTodaySummary();
    final recentTx = AppDatabase.instance.getRecentTransactions(limit: 10);
    final lowStock = AppDatabase.instance.getLowStockProducts();
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: () => BarcodeScannerModal.show(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Action Strip
            _buildQuickActions(context),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Today\'s Business Summary'),
            const SizedBox(height: 12),
            _buildSummaryGrid(context, summary),
            const SizedBox(height: 28),

            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeaderWithAction(
                          context,
                          title: 'Recent Transactions',
                          actionLabel: 'View All',
                          onAction: () => context.go('/reports'),
                        ),
                        const SizedBox(height: 12),
                        _buildRecentTransactions(context, recentTx),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeaderWithAction(
                          context,
                          title: 'Low Stock Alerts',
                          actionLabel: 'Manage',
                          onAction: () => context.go('/admin'),
                        ),
                        const SizedBox(height: 12),
                        _buildLowStock(context, lowStock),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeaderWithAction(
                    context,
                    title: 'Recent Transactions',
                    actionLabel: 'View All',
                    onAction: () => context.go('/reports'),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentTransactions(context, recentTx),
                  const SizedBox(height: 28),

                  _buildSectionHeaderWithAction(
                    context,
                    title: 'Low Stock Alerts',
                    actionLabel: 'Manage',
                    onAction: () => context.go('/admin'),
                  ),
                  const SizedBox(height: 12),
                  _buildLowStock(context, lowStock),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionButton(
            icon: Icons.add_shopping_cart,
            label: 'New Sale',
            color: FaarPosTheme.kPrimary,
            onTap: () => context.go('/pos/catalog'),
          ),
          const SizedBox(width: 10),
          _QuickActionButton(
            icon: Icons.qr_code_scanner,
            label: 'Scan Barcode',
            color: FaarPosTheme.kSuccess,
            onTap: () => BarcodeScannerModal.show(context),
          ),
          const SizedBox(width: 10),
          _QuickActionButton(
            icon: Icons.inventory,
            label: 'Adjust Stock',
            color: FaarPosTheme.kWarning,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const StockAdjustmentDialog(),
              );
            },
          ),
          const SizedBox(width: 10),
          _QuickActionButton(
            icon: Icons.bar_chart,
            label: 'EOD Reports',
            color: FaarPosTheme.kPrimaryVariant,
            onTap: () => context.go('/reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderWithAction(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SectionHeader(title: title),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel, style: const TextStyle(color: FaarPosTheme.kPrimary, fontSize: 12)),
              const Icon(Icons.chevron_right, size: 16, color: FaarPosTheme.kPrimary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(BuildContext context, Map<String, dynamic> summary) {
    final txCount = summary['tx_count'] as int;
    final totalRevenue = summary['total_revenue'] as double;
    final totalTax = summary['total_tax'] as double;
    final avgValue = txCount > 0 ? totalRevenue / txCount : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        return GridView.count(
          crossAxisCount: isSmall ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isSmall ? 1.6 : 2.0,
          children: [
            _SummaryCard(
              title: 'Total Sales',
              value: '$txCount bills',
              icon: Icons.receipt_long,
              color: FaarPosTheme.kPrimary,
            ),
            _SummaryCard(
              title: 'Total Revenue',
              value: '₹${totalRevenue.toStringAsFixed(2)}',
              icon: Icons.payments,
              color: FaarPosTheme.kSuccess,
            ),
            _SummaryCard(
              title: 'Tax Collected',
              value: '₹${totalTax.toStringAsFixed(2)}',
              icon: Icons.account_balance,
              color: FaarPosTheme.kWarning,
            ),
            _SummaryCard(
              title: 'Avg Ticket',
              value: '₹${avgValue.toStringAsFixed(2)}',
              icon: Icons.analytics,
              color: FaarPosTheme.kPrimaryVariant,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentTransactions(BuildContext context, List<TransactionEntity> transactions) {
    if (transactions.isEmpty) {
      return Card(
        color: FaarPosTheme.kSurface,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 40, color: FaarPosTheme.kTextSecondary),
                const SizedBox(height: 8),
                const Text('No sales completed today yet', style: TextStyle(color: FaarPosTheme.kTextSecondary)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => context.go('/pos/catalog'),
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Start First Sale'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      color: FaarPosTheme.kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: FaarPosTheme.kCardBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: FaarPosTheme.kDivider),
        itemBuilder: (context, index) {
          final tx = transactions[index];
          final time = DateFormat.jm().format(tx.createdAt);
          return ListTile(
            onTap: () => context.push('/pos/receipt', extra: tx),
            leading: CircleAvatar(
              backgroundColor: FaarPosTheme.kPrimary.withValues(alpha: 0.15),
              child: const Icon(Icons.receipt, color: FaarPosTheme.kPrimary, size: 20),
            ),
            title: Text(tx.receiptNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${tx.customerName ?? 'Walk-in Customer'} • $time', style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${tx.grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: FaarPosTheme.kPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: FaarPosTheme.kSurfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tx.paymentMethod.toUpperCase(),
                    style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLowStock(BuildContext context, List<Map<String, dynamic>> lowStock) {
    if (lowStock.isEmpty) {
      return Card(
        color: FaarPosTheme.kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: FaarPosTheme.kCardBorder),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: FaarPosTheme.kSuccess, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All Stock Levels Healthy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('No products currently below threshold', style: TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      color: FaarPosTheme.kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: FaarPosTheme.kCardBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lowStock.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: FaarPosTheme.kDivider),
        itemBuilder: (context, index) {
          final item = lowStock[index];
          final quantity = item['stock_quantity'] as int;
          final threshold = item['low_stock_threshold'] as int;
          final isOut = quantity <= 0;

          return ListTile(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const StockAdjustmentDialog(),
              );
            },
            title: Text(item['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('SKU: ${item['sku']}', style: const TextStyle(fontSize: 11, color: FaarPosTheme.kTextSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isOut ? FaarPosTheme.kDanger : FaarPosTheme.kWarning).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: (isOut ? FaarPosTheme.kDanger : FaarPosTheme.kWarning).withValues(alpha: 0.4)),
              ),
              child: Text(
                isOut ? 'OUT ($quantity)' : 'LOW ($quantity/$threshold)',
                style: TextStyle(
                  color: isOut ? FaarPosTheme.kDanger : FaarPosTheme.kWarning,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FaarPosTheme.kSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FaarPosTheme.kCardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FaarPosTheme.kTextPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FaarPosTheme.kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: FaarPosTheme.kCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: FaarPosTheme.kTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FaarPosTheme.kTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
