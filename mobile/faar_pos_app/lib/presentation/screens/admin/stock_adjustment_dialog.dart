import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/product_entity.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  const StockAdjustmentDialog({super.key});

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();

  ProductEntity? _selectedProduct;
  String _adjustmentType = 'Restock (+)';
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<String> _adjustmentTypes = [
    'Restock (+)',
    'Damage (-)',
    'Manual Adjustment (+/-)'
  ];

  late List<ProductEntity> _products;

  @override
  void initState() {
    super.initState();
    _products = AppDatabase.instance.getAllProducts();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveAdjustment() {
    if (_formKey.currentState!.validate()) {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a product')),
        );
        return;
      }

      int quantityDelta = int.tryParse(_quantityController.text) ?? 0;
      if (quantityDelta == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity cannot be 0')),
        );
        return;
      }

      String movementType = 'adjustment';
      if (_adjustmentType == 'Restock (+)') {
        movementType = 'restock';
        quantityDelta = quantityDelta.abs();
      } else if (_adjustmentType == 'Damage (-)') {
        movementType = 'damage';
        quantityDelta = -quantityDelta.abs();
      } else {
        movementType = 'adjustment';
      }

      try {
        AppDatabase.instance.adjustStock(
          productId: _selectedProduct!.id,
          quantityDelta: quantityDelta,
          movementType: movementType,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        );

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock adjusted successfully', style: TextStyle(color: FaarPosTheme.kSuccess))),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adjusting stock: $e', style: const TextStyle(color: FaarPosTheme.kDanger))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FaarPosTheme.kBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: FaarPosTheme.kSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: FaarPosTheme.kDivider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Adjust Stock',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<ProductEntity>(
                        initialValue: _selectedProduct,
                        decoration: const InputDecoration(labelText: 'Select Product *'),
                        isExpanded: true,
                        items: _products.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (${p.sku})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedProduct = val);
                        },
                        validator: (val) => val == null ? 'Product is required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _adjustmentType,
                        decoration: const InputDecoration(labelText: 'Adjustment Type *'),
                        items: _adjustmentTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _adjustmentType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity *',
                          hintText: _adjustmentType == 'Manual Adjustment (+/-)' 
                            ? 'Use - for reduction, + for addition' 
                            : 'Enter positive number',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Quantity is required';
                          if (int.tryParse(val) == null) return 'Must be a valid integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveAdjustment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FaarPosTheme.kPrimary,
                          foregroundColor: FaarPosTheme.kTextPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('SAVE ADJUSTMENT', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
