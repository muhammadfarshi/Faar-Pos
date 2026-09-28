import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/transaction_entity.dart';

class GstReportScreen extends ConsumerStatefulWidget {
  const GstReportScreen({super.key});

  @override
  ConsumerState<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends ConsumerState<GstReportScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final transactions = AppDatabase.instance.getTransactionsByDateRange(_fromDate, _toDate.add(const Duration(days: 1)));

    double totalTaxable = 0.0;
    double totalCgst = 0.0;
    double totalSgst = 0.0;
    double totalIgst = 0.0;
    double totalTax = 0.0;

    for (final tx in transactions) {
      totalTaxable += tx.totalBaseAmount.toDouble();
      totalTax += tx.totalTaxAmount.toDouble();

      for (final item in tx.items) {
        for (final tax in item.taxBreakdown) {
          final name = (tax['name'] as String?)?.toLowerCase() ?? '';
          final amount = double.tryParse(tax['amount']?.toString() ?? '0') ?? 0.0;
          if (name.contains('cgst')) {
            totalCgst += amount;
          } else if (name.contains('sgst')) {
            totalSgst += amount;
          } else if (name.contains('igst')) {
            totalIgst += amount;
          }
        }
      }
    }

    // fallback approximation if taxBreakdown isn't fully populated
    if (totalTax > 0 && totalCgst == 0 && totalSgst == 0 && totalIgst == 0) {
      totalCgst = totalTax / 2;
      totalSgst = totalTax / 2;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDateRangePicker(),
          const SizedBox(height: 16),
          _buildSummaryGrid(totalTaxable, totalCgst, totalSgst, totalIgst, totalTax),
          const SizedBox(height: 16),
          Expanded(child: _buildDataTable(transactions)),
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

  Widget _buildSummaryGrid(double taxable, double cgst, double sgst, double igst, double tax) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth < 600 ? 2 : 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.0,
          children: [
            _SummaryCard('Taxable Amt', taxable),
            _SummaryCard('CGST', cgst),
            _SummaryCard('SGST', sgst),
            _SummaryCard('IGST', igst),
            _SummaryCard('Total Tax', tax, color: FaarPosTheme.kWarning),
          ],
        );
      },
    );
  }

  Widget _buildDataTable(List<TransactionEntity> transactions) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions in selected range.'));
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Receipt No')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Taxable')),
              DataColumn(label: Text('CGST')),
              DataColumn(label: Text('SGST')),
              DataColumn(label: Text('IGST')),
              DataColumn(label: Text('Total Tax')),
            ],
            rows: transactions.map((tx) {
              double cgst = 0, sgst = 0, igst = 0;
              for (final item in tx.items) {
                for (final tax in item.taxBreakdown) {
                  final name = (tax['name'] as String?)?.toLowerCase() ?? '';
                  final amount = double.tryParse(tax['amount']?.toString() ?? '0') ?? 0.0;
                  if (name.contains('cgst')) {
                    cgst += amount;
                  } else if (name.contains('sgst')) {
                    sgst += amount;
                  } else if (name.contains('igst')) {
                    igst += amount;
                  }
                }
              }
              if (tx.totalTaxAmount.toDouble() > 0 && cgst == 0 && sgst == 0 && igst == 0) {
                cgst = tx.totalTaxAmount.toDouble() / 2;
                sgst = tx.totalTaxAmount.toDouble() / 2;
              }

              return DataRow(
                cells: [
                  DataCell(Text(tx.receiptNo)),
                  DataCell(Text(DateFormat.yMd().format(tx.createdAt))),
                  DataCell(Text('₹${tx.totalBaseAmount.toStringAsFixed(2)}')),
                  DataCell(Text('₹${cgst.toStringAsFixed(2)}')),
                  DataCell(Text('₹${sgst.toStringAsFixed(2)}')),
                  DataCell(Text('₹${igst.toStringAsFixed(2)}')),
                  DataCell(Text('₹${tx.totalTaxAmount.toStringAsFixed(2)}')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color? color;

  const _SummaryCard(this.title, this.amount, {this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FaarPosTheme.kSurfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: FaarPosTheme.kTextSecondary)),
            const SizedBox(height: 4),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color ?? FaarPosTheme.kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
