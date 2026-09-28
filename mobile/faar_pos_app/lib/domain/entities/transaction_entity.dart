import 'package:decimal/decimal.dart';

class TransactionItemEntity {
  final int id;
  final int productId;
  final String productNameSnapshot;
  final String skuSnapshot;
  final int quantity;
  final Decimal unitPrice;
  final Decimal discountAmount;
  final List<Map<String, dynamic>> taxBreakdown;
  final Decimal taxTotal;
  final Decimal lineTotal;

  const TransactionItemEntity({
    required this.id,
    required this.productId,
    required this.productNameSnapshot,
    required this.skuSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.taxBreakdown,
    required this.taxTotal,
    required this.lineTotal,
  });
}

class TransactionEntity {
  final int id;
  final String receiptNo;
  final String transactionType;
  final String? customerName;
  final String? customerPhone;
  final Decimal totalBaseAmount;
  final Decimal totalTaxAmount;
  final Decimal totalDiscountAmount;
  final Decimal grandTotal;
  final String paymentMethod;
  final String? paymentReference;
  final String status;
  final DateTime createdAt;
  final List<TransactionItemEntity> items;

  const TransactionEntity({
    required this.id,
    required this.receiptNo,
    required this.transactionType,
    this.customerName,
    this.customerPhone,
    required this.totalBaseAmount,
    required this.totalTaxAmount,
    required this.totalDiscountAmount,
    required this.grandTotal,
    required this.paymentMethod,
    this.paymentReference,
    required this.status,
    required this.createdAt,
    required this.items,
  });
}
