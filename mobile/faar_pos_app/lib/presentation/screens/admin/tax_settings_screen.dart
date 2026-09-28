import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/tax_entity.dart';
import '../../providers/catalog_provider.dart';

class TaxSettingsScreen extends ConsumerStatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  ConsumerState<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends ConsumerState<TaxSettingsScreen> {
  void _openTaxGroupDialog([TaxGroupEntity? group]) {
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    final rateCtrl = TextEditingController(text: group?.totalRateDecimal.toString() ?? '18.00');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(group == null ? 'Add Tax Rate / Group' : 'Edit Tax Rate'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tax Group Name (e.g. GST 18%) *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rateCtrl,
                decoration: const InputDecoration(labelText: 'Total Rate % (e.g. 18.00) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Rate required';
                  if (Decimal.tryParse(v.trim()) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: Intra-state sales will automatically split rate into 50% CGST + 50% SGST. Inter-state sales will apply 100% IGST.',
                style: TextStyle(fontSize: 11, color: FaarPosTheme.kTextSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final totalRate = Decimal.parse(rateCtrl.text.trim());
                final halfRate = (totalRate / Decimal.fromInt(2)).toDecimal();

                final components = [
                  TaxComponentEntity(
                    id: 1,
                    name: 'CGST ${(halfRate).toStringAsFixed(1)}%',
                    rateDecimal: halfRate,
                    appliesToCondition: TaxCondition.intraRegion,
                  ),
                  TaxComponentEntity(
                    id: 2,
                    name: 'SGST ${(halfRate).toStringAsFixed(1)}%',
                    rateDecimal: halfRate,
                    appliesToCondition: TaxCondition.intraRegion,
                  ),
                  TaxComponentEntity(
                    id: 3,
                    name: 'IGST ${(totalRate).toStringAsFixed(1)}%',
                    rateDecimal: totalRate,
                    appliesToCondition: TaxCondition.interRegion,
                  ),
                ];

                final newGroup = TaxGroupEntity(
                  id: group?.id ?? 0,
                  name: nameCtrl.text.trim(),
                  totalRateDecimal: totalRate,
                  isCompound: false,
                  components: components,
                );

                AppDatabase.instance.upsertTaxGroup(newGroup);
                Navigator.of(ctx).pop();
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved tax rate "${newGroup.name}"'),
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

  @override
  Widget build(BuildContext context) {
    ref.watch(databaseChangeListenerProvider);
    final taxGroups = AppDatabase.instance.getAllTaxGroups();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaxGroupDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Tax Rate'),
      ),
      body: taxGroups.isEmpty
          ? const Center(child: Text('No tax rates configured'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: taxGroups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final g = taxGroups[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: FaarPosTheme.kPrimary.withValues(alpha: 0.15),
                          child: Text(
                            '${g.totalRateDecimal.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: FaarPosTheme.kPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                'Rate: ${g.totalRateDecimal}% • ${g.components.length} Tax Components',
                                style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _openTaxGroupDialog(g),
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
