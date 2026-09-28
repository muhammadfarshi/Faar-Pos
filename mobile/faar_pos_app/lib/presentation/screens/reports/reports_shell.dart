import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'eod_report_screen.dart';
import 'sales_report_screen.dart';
import 'gst_report_screen.dart';

class ReportsShell extends StatelessWidget {
  const ReportsShell({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          title: const Text('Reports'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'EOD'),
              Tab(text: 'Sales'),
              Tab(text: 'GST Tax'),
              Tab(text: 'Inventory'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EodReportScreen(),
            SalesReportScreen(),
            GstReportScreen(),
            Center(child: Text('Inventory Report (Phase 5)')),
          ],
        ),
      ),
    );
  }
}
