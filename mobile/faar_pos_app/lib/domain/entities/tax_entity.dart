import 'package:decimal/decimal.dart';

enum TaxCondition { always, intraRegion, interRegion }

class TaxComponentEntity {
  final int id;
  final String name;
  final Decimal rateDecimal;
  final TaxCondition appliesToCondition;

  TaxComponentEntity({
    required this.id,
    required this.name,
    required this.rateDecimal,
    required this.appliesToCondition,
  });
}

class TaxGroupEntity {
  final int id;
  final String name;
  final Decimal totalRateDecimal;
  final bool isCompound;
  final List<TaxComponentEntity> components;

  TaxGroupEntity({
    required this.id,
    required this.name,
    required this.totalRateDecimal,
    required this.isCompound,
    required this.components,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxGroupEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
