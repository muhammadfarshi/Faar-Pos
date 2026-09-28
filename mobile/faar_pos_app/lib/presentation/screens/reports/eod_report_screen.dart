import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class EodReportScreen extends StatelessWidget {
  const EodReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Today'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Load Report'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildSummaryCard('Total Revenue', '\$1,200.00'),
              _buildSummaryCard('Transactions', '45'),
              _buildSummaryCard('Tax Collected', '\$120.00'),
              _buildSummaryCard('Avg Order', '\$26.67'),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Payment Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Mock PaymentMethodBar
          Container(height: 20, color: FaarPosTheme.kPrimary, width: double.infinity),
          const SizedBox(height: 24),
          const Text('Top Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DataTable(
            columns: const [
              DataColumn(label: Text('Rank')),
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('Units')),
              DataColumn(label: Text('Revenue')),
            ],
            rows: const [
              DataRow(cells: [
                DataCell(Text('1')),
                DataCell(Text('Product A')),
                DataCell(Text('20')),
                DataCell(Text('\$200.00')),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value) {
    return Card(
      color: FaarPosTheme.kSurface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(color: FaarPosTheme.kTextSecondary)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: FaarPosTheme.kPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
