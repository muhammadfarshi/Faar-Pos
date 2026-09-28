import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/product_entity.dart';
import '../../providers/catalog_provider.dart';
import 'stock_adjustment_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _movementTypeFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAdjustStockForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StockAdjustmentDialog(),
    );
  }

  Widget _buildStatusChip(ProductEntity product) {
    Color color;
    String text;
    if (product.isOutOfStock) {
      color = FaarPosTheme.kDanger;
      text = 'Out of Stock';
    } else if (product.isLowStock) {
      color = FaarPosTheme.kWarning;
      text = 'Low Stock';
    } else {
      color = FaarPosTheme.kSuccess;
      text = 'In Stock';
    }

    return Chip(
      label: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(databaseChangeListenerProvider);
    
    final products = AppDatabase.instance.getAllProducts();
    final logs = AppDatabase.instance.getInventoryLogs(movementType: _movementTypeFilter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Current Stock'),
            Tab(text: 'Movement Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Current Stock Tab
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: FaarPosTheme.kTextSecondary),
                columns: const [
                  DataColumn(label: Text('Product Name')),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('On Hand')),
                  DataColumn(label: Text('Threshold')),
                  DataColumn(label: Text('Status')),
                ],
                rows: products.map((product) {
                  return DataRow(
                    cells: [
                      DataCell(Text(product.name)),
                      DataCell(Text(product.sku)),
                      DataCell(Text('${product.stockQuantity} ${product.unitOfMeasure}')),
                      DataCell(Text(product.lowStockThreshold.toString())),
                      DataCell(_buildStatusChip(product)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Movement Log Tab
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text('Filter by: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _movementTypeFilter,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Movements')),
                          DropdownMenuItem(value: 'sale', child: Text('Sale')),
                          DropdownMenuItem(value: 'restock', child: Text('Restock')),
                          DropdownMenuItem(value: 'damage', child: Text('Damage')),
                          DropdownMenuItem(value: 'adjustment', child: Text('Manual Adjustment')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _movementTypeFilter = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('No inventory movements found', style: TextStyle(color: FaarPosTheme.kTextSecondary)))
                    : ListView.builder(
                        itemCount: logs.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final delta = log['quantity_delta'] as int;
                          final date = DateTime.tryParse(log['created_at'].toString()) ?? DateTime.now();
                          final dateStr = DateFormat('MMM dd, yyyy HH:mm').format(date);
                          final isPositive = delta > 0;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('${log['product_name']} (${log['product_sku']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Type: ${log['movement_type']} • Date: $dateStr'),
                                  if (log['notes'] != null && log['notes'].toString().isNotEmpty)
                                    Text('Notes: ${log['notes']}'),
                                ],
                              ),
                              trailing: Text(
                                '${isPositive ? '+' : ''}$delta',
                                style: TextStyle(
                                  color: isPositive ? FaarPosTheme.kSuccess : FaarPosTheme.kDanger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdjustStockForm,
        icon: const Icon(Icons.inventory),
        label: const Text('Adjust Stock'),
      ),
    );
  }
}
