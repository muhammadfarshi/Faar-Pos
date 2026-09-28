import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/branch_entity.dart';
import '../../providers/catalog_provider.dart';

class BranchManagementScreen extends ConsumerStatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  ConsumerState<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends ConsumerState<BranchManagementScreen> {
  void _openBranchDialog([BranchEntity? branch]) {
    final nameCtrl = TextEditingController(text: branch?.name ?? '');
    final codeCtrl = TextEditingController(text: branch?.branchCode ?? '');
    final prefixCtrl = TextEditingController(text: branch?.invoicePrefix ?? 'FAAR-');
    final cityCtrl = TextEditingController(text: branch?.city ?? 'Kochi');
    final gstinCtrl = TextEditingController(text: branch?.taxRegistrationNo ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(branch == null ? 'Add Store / Branch' : 'Edit Store / Branch'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Branch / Store Name *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Branch Code (e.g. BR-002) *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Code required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: prefixCtrl,
                  decoration: const InputDecoration(labelText: 'Invoice Prefix (e.g. WH-) *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Prefix required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'City / Region'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: gstinCtrl,
                  decoration: const InputDecoration(labelText: 'GSTIN / Tax ID'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newBranch = BranchEntity(
                  id: branch?.id ?? 0,
                  orgId: 1,
                  name: nameCtrl.text.trim(),
                  branchCode: codeCtrl.text.trim(),
                  invoicePrefix: prefixCtrl.text.trim(),
                  currencyCode: 'INR',
                  currencySymbol: '₹',
                  taxRegistrationNo: gstinCtrl.text.trim().isNotEmpty ? gstinCtrl.text.trim() : null,
                  countryCode: 'IN',
                  city: cityCtrl.text.trim(),
                  isActive: true,
                );

                AppDatabase.instance.upsertBranch(newBranch);
                Navigator.of(ctx).pop();
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved store "${newBranch.name}"'),
                    backgroundColor: FaarPosTheme.kSuccess,
                  ),
                );
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _setActiveStore(BranchEntity b) {
    HapticFeedback.mediumImpact();
    AppDatabase.instance.setSetting('active_branch_id', b.id.toString());
    AppDatabase.instance.setSetting('store_name', b.name);
    AppDatabase.instance.setSetting('invoice_prefix', b.invoicePrefix);
    if (b.taxRegistrationNo != null && b.taxRegistrationNo!.isNotEmpty) {
      AppDatabase.instance.setSetting('store_gstin', b.taxRegistrationNo!);
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched active store to "${b.name}"'),
        backgroundColor: FaarPosTheme.kSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(databaseChangeListenerProvider);
    final branches = AppDatabase.instance.getAllBranches();
    final activeBranchId = int.tryParse(AppDatabase.instance.getSetting('active_branch_id') ?? '1') ?? 1;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBranchDialog(),
        icon: const Icon(Icons.add_business),
        label: const Text('Add Store'),
      ),
      body: branches.isEmpty
          ? const Center(child: Text('No stores configured'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: branches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final b = branches[index];
                final isActive = b.id == activeBranchId;

                return Card(
                  color: isActive ? FaarPosTheme.kPrimary.withValues(alpha: 0.1) : FaarPosTheme.kSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isActive ? FaarPosTheme.kPrimary : FaarPosTheme.kCardBorder,
                      width: isActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isActive ? FaarPosTheme.kPrimary : FaarPosTheme.kSurfaceElevated,
                          child: Icon(
                            Icons.store,
                            color: isActive ? Colors.white : FaarPosTheme.kTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    b.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isActive)
                                    const Chip(
                                      label: Text('ACTIVE STORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Code: ${b.branchCode} • Prefix: ${b.invoicePrefix} • ${b.city}',
                                style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                              ),
                              if (b.taxRegistrationNo != null)
                                Text(
                                  'GSTIN: ${b.taxRegistrationNo}',
                                  style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (!isActive)
                              TextButton(
                                onPressed: () => _setActiveStore(b),
                                child: const Text('Set Active'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _openBranchDialog(b),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
