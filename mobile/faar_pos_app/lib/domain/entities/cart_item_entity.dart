import 'package:decimal/decimal.dart';


class TaxLineItem {
  final String name;
  final Decimal rateDecimal;
  final Decimal amountDecimal;

  const TaxLineItem({
    required this.name,
    required this.rateDecimal,
    required this.amountDecimal,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'rate': rateDecimal.toString(),
    'amount': amountDecimal.toString(),
  };

  factory TaxLineItem.fromJson(Map<String, dynamic> json) => TaxLineItem(
    name: json['name'] as String,
    rateDecimal: Decimal.parse(json['rate'].toString()),
    amountDecimal: Decimal.parse(json['amount'].toString()),
  );
}

class CartItemEntity {
  final int id;
  final int productId;
  final String productName;
  final String sku;
  final int? taxGroupId;
  final int quantity;
  final Decimal unitPriceDecimal;
  final Decimal discountDecimal;
  final List<TaxLineItem> taxBreakdown;
  final Decimal lineTaxDecimal;
  final Decimal lineTotalDecimal;

  const CartItemEntity({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    this.taxGroupId,
    required this.quantity,
    required this.unitPriceDecimal,
    required this.discountDecimal,
    required this.taxBreakdown,
    required this.lineTaxDecimal,
    required this.lineTotalDecimal,
  });

  CartItemEntity copyWith({
    int? id,
    int? productId,
    String? productName,
    String? sku,
    int? taxGroupId,
    int? quantity,
    Decimal? unitPriceDecimal,
    Decimal? discountDecimal,
    List<TaxLineItem>? taxBreakdown,
    Decimal? lineTaxDecimal,
    Decimal? lineTotalDecimal,
  }) {
    return CartItemEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      taxGroupId: taxGroupId ?? this.taxGroupId,
      quantity: quantity ?? this.quantity,
      unitPriceDecimal: unitPriceDecimal ?? this.unitPriceDecimal,
      discountDecimal: discountDecimal ?? this.discountDecimal,
      taxBreakdown: taxBreakdown ?? this.taxBreakdown,
      lineTaxDecimal: lineTaxDecimal ?? this.lineTaxDecimal,
      lineTotalDecimal: lineTotalDecimal ?? this.lineTotalDecimal,
    );
  }
}
