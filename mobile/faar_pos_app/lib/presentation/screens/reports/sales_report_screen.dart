import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/transaction_entity.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // In a real app we'd watch a provider, but we'll fetch direct for simplicity
    final transactions = AppDatabase.instance.getTransactionsByDateRange(_fromDate, _toDate.add(const Duration(days: 1)));

    int count = transactions.length;
    double totalRev = transactions.fold(0.0, (sum, tx) => sum + tx.grandTotal.toDouble());
    double totalTax = transactions.fold(0.0, (sum, tx) => sum + tx.totalTaxAmount.toDouble());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDateRangePicker(),
          const SizedBox(height: 16),
          _buildSummaryCards(count, totalRev, totalTax),
          const SizedBox(height: 16),
          Expanded(child: _buildTransactionList(transactions)),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    final df = DateFormat.yMMMd();
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _fromDate,
                firstDate: DateTime(2020),
                lastDate: _toDate,
              );
              if (picked != null) setState(() => _fromDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'From Date'),
              child: Text(df.format(_fromDate)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _toDate,
                firstDate: _fromDate,
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _toDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'To Date'),
              child: Text(df.format(_toDate)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(int count, double totalRev, double totalTax) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Sales Count', style: TextStyle(color: FaarPosTheme.kTextSecondary)),
                  const SizedBox(height: 8),
                  Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Revenue', style: TextStyle(color: FaarPosTheme.kTextSecondary)),
                  const SizedBox(height: 8),
                  Text('₹${totalRev.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: FaarPosTheme.kSuccess)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Tax', style: TextStyle(color: FaarPosTheme.kTextSecondary)),
                  const SizedBox(height: 8),
                  Text('₹${totalTax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: FaarPosTheme.kWarning)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<TransactionEntity> txs) {
    if (txs.isEmpty) {
      return const Center(child: Text('No transactions found.', style: TextStyle(color: FaarPosTheme.kTextSecondary)));
    }
    return Card(
      child: ListView.separated(
        itemCount: txs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final tx = txs[index];
          return ListTile(
            title: Text(tx.receiptNo),
            subtitle: Text('${DateFormat.yMd().add_jm().format(tx.createdAt)} • ${tx.customerName ?? 'Walk-in'}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${tx.items.length} items', style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12)),
                Text('₹${tx.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          );
        },
      ),
    );
  }
}
