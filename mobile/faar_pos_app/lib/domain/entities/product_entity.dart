import 'package:decimal/decimal.dart';

class ProductEntity {
  final int id;
  final String name;
  final String sku;
  final String categoryName;
  final String unitOfMeasure;
  final Decimal basePriceDecimal;
  final int? taxGroupId;
  final int stockQuantity;
  final int lowStockThreshold;
  final bool isActive;
  final String? barcode;
  final String? imageUrl;

  const ProductEntity({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryName,
    required this.unitOfMeasure,
    required this.basePriceDecimal,
    this.taxGroupId,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.isActive,
    this.barcode,
    this.imageUrl,
  });

  String get formattedPrice => basePriceDecimal.toStringAsFixed(2);

  bool get isInStock => stockQuantity > lowStockThreshold;
  bool get isLowStock => stockQuantity > 0 && stockQuantity <= lowStockThreshold;
  bool get isOutOfStock => stockQuantity <= 0;

  factory ProductEntity.fromJson(Map<String, dynamic> json) {
    return ProductEntity(
      id: json['id'] as int,
      name: json['name'] as String,
      sku: json['sku'] as String,
      categoryName: json['category_name'] as String? ?? '',
      unitOfMeasure: json['unit_of_measure'] as String? ?? 'pcs',
      basePriceDecimal: Decimal.parse((json['base_price'] ?? '0').toString()),
      taxGroupId: json['tax_group_id'] as int?,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      lowStockThreshold: json['low_stock_threshold'] as int? ?? 10,
      isActive: json['is_active'] as bool? ?? true,
      barcode: json['barcode'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
