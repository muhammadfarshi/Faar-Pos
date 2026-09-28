import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'branch_management_screen.dart';
import 'user_management_screen.dart';
import 'product_management_screen.dart';
import 'tax_settings_screen.dart';
import 'printer_settings_screen.dart';
import 'inventory_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Store Administration'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/pos/catalog'),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.store), text: 'Stores & Branches'),
              Tab(icon: Icon(Icons.people), text: 'Staff & Users'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Catalog & Products'),
              Tab(icon: Icon(Icons.request_quote), text: 'GST & Taxes'),
              Tab(icon: Icon(Icons.print), text: 'Thermal Printers'),
              Tab(icon: Icon(Icons.warehouse), text: 'Inventory & Logs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BranchManagementScreen(),
            UserManagementScreen(),
            ProductManagementScreen(),
            TaxSettingsScreen(),
            PrinterSettingsScreen(),
            InventoryScreen(),
          ],
        ),
      ),
    );
  }
}
