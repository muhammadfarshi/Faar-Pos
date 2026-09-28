import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/product_entity.dart';
import '../../../domain/entities/tax_entity.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductEntity? product;

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;
  late TextEditingController _barcodeController;
  late TextEditingController _hsnController;

  String _selectedCategory = 'General';
  String _selectedUom = 'pcs';
  int? _selectedTaxGroupId;
  final List<String> _uomOptions = ['pcs', 'set', 'kg', 'm', 'sqft'];
  List<String> _categories = [];
  List<TaxGroupEntity> _taxGroups = [];

  @override
  void initState() {
    super.initState();
    _categories = AppDatabase.instance.getCategories();
    if (!_categories.contains('General')) {
      _categories.insert(0, 'General');
    }
    _taxGroups = AppDatabase.instance.getAllTaxGroups();

    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    _priceController = TextEditingController(text: widget.product?.basePriceDecimal.toStringAsFixed(2) ?? '');
    _stockController = TextEditingController(text: widget.product?.stockQuantity.toString() ?? '0');
    _thresholdController = TextEditingController(text: widget.product?.lowStockThreshold.toString() ?? '10');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    _hsnController = TextEditingController();

    if (widget.product != null) {
      if (_categories.contains(widget.product!.categoryName)) {
        _selectedCategory = widget.product!.categoryName;
      }
      if (_uomOptions.contains(widget.product!.unitOfMeasure)) {
        _selectedUom = widget.product!.unitOfMeasure;
      }
      _selectedTaxGroupId = widget.product!.taxGroupId;
    } else if (_taxGroups.isNotEmpty) {
      _selectedTaxGroupId = _taxGroups.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _barcodeController.dispose();
    _hsnController.dispose();
    super.dispose();
  }

  void _saveProduct() {
    if (_formKey.currentState!.validate()) {
      try {
        final price = Decimal.tryParse(_priceController.text) ?? Decimal.zero;
        if (price <= Decimal.zero) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Price must be greater than 0')),
          );
          return;
        }

        final stock = int.tryParse(_stockController.text) ?? 0;
        final threshold = int.tryParse(_thresholdController.text) ?? 10;

        final productToSave = ProductEntity(
          id: widget.product?.id ?? 0,
          name: _nameController.text.trim(),
          sku: _skuController.text.trim(),
          categoryName: _selectedCategory,
          unitOfMeasure: _selectedUom,
          basePriceDecimal: price,
          taxGroupId: _selectedTaxGroupId,
          stockQuantity: stock,
          lowStockThreshold: threshold,
          isActive: true,
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        );

        AppDatabase.instance.upsertProduct(productToSave);
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product saved successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving product: $e')),
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
                  Text(
                    widget.product == null ? 'Add Product' : 'Edit Product',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Product Name *'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _skuController,
                              decoration: const InputDecoration(labelText: 'SKU *'),
                              validator: (val) => val == null || val.trim().isEmpty ? 'SKU is required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(labelText: 'Barcode (Optional)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(labelText: 'Category'),
                              items: _categories.map((c) {
                                return DropdownMenuItem(value: c, child: Text(c));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedUom,
                              decoration: const InputDecoration(labelText: 'Unit of Measure'),
                              items: _uomOptions.map((u) {
                                return DropdownMenuItem(value: u, child: Text(u));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedUom = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Base Price (₹) *'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Price is required';
                          final d = Decimal.tryParse(val);
                          if (d == null || d <= Decimal.zero) return 'Enter a valid price > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedTaxGroupId,
                        decoration: const InputDecoration(labelText: 'GST Tax Group'),
                        items: _taxGroups.map((tg) {
                          return DropdownMenuItem(
                            value: tg.id,
                            child: Text('${tg.name} (${tg.totalRateDecimal}%)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTaxGroupId = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              decoration: const InputDecoration(labelText: 'Stock Quantity'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _thresholdController,
                              decoration: const InputDecoration(labelText: 'Low Stock Threshold'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _hsnController,
                        decoration: const InputDecoration(labelText: 'HSN Code (Optional)'),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FaarPosTheme.kPrimary,
                          foregroundColor: FaarPosTheme.kTextPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('SAVE PRODUCT', style: TextStyle(fontWeight: FontWeight.bold)),
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
