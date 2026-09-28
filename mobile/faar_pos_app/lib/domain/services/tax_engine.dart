import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';
import '../entities/tax_entity.dart';
import '../entities/cart_item_entity.dart';

class TaxCalculationResult {
  final Decimal baseAmount;
  final Decimal discountAmount;
  final Decimal taxableAmount;
  final List<TaxLineItem> taxBreakdown;
  final Decimal totalTaxAmount;
  final Decimal grandTotal;

  const TaxCalculationResult({
    required this.baseAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.taxBreakdown,
    required this.totalTaxAmount,
    required this.grandTotal,
  });
}

class TaxEngine {
  static final Decimal _hundred = Decimal.fromInt(100);
  static final Decimal _zero = Decimal.zero;

  /// Rounds a [Decimal] or [Rational] to [scale] decimal places using HALF_UP rounding.
  static Decimal roundHalfUp(dynamic value, {int scale = 2}) {
    final Rational rationalVal;
    if (value is Decimal) {
      rationalVal = value.toRational();
    } else if (value is Rational) {
      rationalVal = value;
    } else if (value is String) {
      rationalVal = Rational.parse(value);
    } else if (value is num) {
      rationalVal = Rational.parse(value.toString());
    } else {
      rationalVal = Rational.zero;
    }

    final factor = Rational.fromInt(_pow10(scale));
    final scaled = rationalVal * factor;

    // Add 0.5 for half-up rounding on positive numbers, subtract for negative
    final half = Rational.parse('0.5');
    final adjusted = scaled >= Rational.zero ? scaled + half : scaled - half;
    final intPart = adjusted.truncate();
    return (Rational(intPart) / factor)
        .toDecimal(scaleOnInfinitePrecision: scale);
  }

  static int _pow10(int exp) {
    var res = 1;
    for (var i = 0; i < exp; i++) {
      res *= 10;
    }
    return res;
  }

  /// Evaluates whether a tax component applies given the regional condition.
  static bool isComponentApplicable(
    TaxComponentEntity component,
    TaxCondition supplyCondition,
  ) {
    switch (component.appliesToCondition) {
      case TaxCondition.always:
        return true;
      case TaxCondition.intraRegion:
        return supplyCondition == TaxCondition.intraRegion ||
            supplyCondition == TaxCondition.always;
      case TaxCondition.interRegion:
        return supplyCondition == TaxCondition.interRegion;
    }
  }

  /// Calculates line item totals for tax-exclusive or tax-inclusive pricing.
  static TaxCalculationResult calculateLineItem({
    required Decimal unitPrice,
    required int quantity,
    Decimal? discountAmount,
    Decimal? discountPercent,
    TaxGroupEntity? taxGroup,
    TaxCondition supplyCondition = TaxCondition.intraRegion,
    bool isTaxInclusive = false,
  }) {
    final qtyDecimal = Decimal.fromInt(quantity);
    final rawBase = unitPrice * qtyDecimal;

    // Calculate line discount
    var effectiveDiscount = _zero;
    if (discountAmount != null && discountAmount > _zero) {
      effectiveDiscount = discountAmount;
    } else if (discountPercent != null && discountPercent > _zero) {
      effectiveDiscount = roundHalfUp((rawBase * discountPercent) / _hundred);
    }
    if (effectiveDiscount > rawBase) {
      effectiveDiscount = rawBase;
    }

    final netAmount = rawBase - effectiveDiscount;

    if (taxGroup == null || taxGroup.components.isEmpty) {
      return TaxCalculationResult(
        baseAmount: rawBase,
        discountAmount: effectiveDiscount,
        taxableAmount: netAmount,
        taxBreakdown: const [],
        totalTaxAmount: _zero,
        grandTotal: netAmount,
      );
    }

    final applicableComponents = taxGroup.components
        .where((c) => isComponentApplicable(c, supplyCondition))
        .toList();

    if (applicableComponents.isEmpty) {
      return TaxCalculationResult(
        baseAmount: rawBase,
        discountAmount: effectiveDiscount,
        taxableAmount: netAmount,
        taxBreakdown: const [],
        totalTaxAmount: _zero,
        grandTotal: netAmount,
      );
    }

    if (isTaxInclusive) {
      // Net amount includes tax.
      var totalRate = _zero;
      for (final comp in applicableComponents) {
        totalRate += comp.rateDecimal;
      }

      // Base = netAmount / (1 + totalRate / 100)
      final rateFactor = Rational.one + (totalRate / _hundred);
      final derivedTaxable = roundHalfUp(netAmount.toRational() / rateFactor);

      final breakdown = <TaxLineItem>[];
      var runningTotalTax = _zero;

      for (var i = 0; i < applicableComponents.length; i++) {
        final comp = applicableComponents[i];
        final compTax = i == applicableComponents.length - 1 && !taxGroup.isCompound
            ? (netAmount - derivedTaxable) - runningTotalTax
            : roundHalfUp((derivedTaxable * comp.rateDecimal) / _hundred);

        runningTotalTax += compTax;
        breakdown.add(TaxLineItem(
          name: comp.name,
          rateDecimal: comp.rateDecimal,
          amountDecimal: compTax,
        ));
      }

      return TaxCalculationResult(
        baseAmount: derivedTaxable + effectiveDiscount,
        discountAmount: effectiveDiscount,
        taxableAmount: derivedTaxable,
        taxBreakdown: breakdown,
        totalTaxAmount: runningTotalTax,
        grandTotal: netAmount,
      );
    } else {
      // Tax-exclusive: tax added on top of netAmount
      final breakdown = <TaxLineItem>[];
      var currentTaxableBase = netAmount;
      var totalTax = _zero;

      for (final comp in applicableComponents) {
        final compTax = roundHalfUp((currentTaxableBase * comp.rateDecimal) / _hundred);
        totalTax += compTax;
        breakdown.add(TaxLineItem(
          name: comp.name,
          rateDecimal: comp.rateDecimal,
          amountDecimal: compTax,
        ));

        if (taxGroup.isCompound) {
          currentTaxableBase += compTax;
        }
      }

      final grandTotal = netAmount + totalTax;

      return TaxCalculationResult(
        baseAmount: rawBase,
        discountAmount: effectiveDiscount,
        taxableAmount: netAmount,
        taxBreakdown: breakdown,
        totalTaxAmount: totalTax,
        grandTotal: grandTotal,
      );
    }
  }

  /// Aggregates all tax breakdown items from multiple lines into unified tax summary.
  static List<TaxLineItem> aggregateTaxBreakdowns(List<List<TaxLineItem>> lineBreakdowns) {
    final map = <String, ({Decimal rate, Decimal amount})>{};

    for (final lines in lineBreakdowns) {
      for (final tax in lines) {
        final existing = map[tax.name];
        if (existing == null) {
          map[tax.name] = (rate: tax.rateDecimal, amount: tax.amountDecimal);
        } else {
          map[tax.name] = (
            rate: tax.rateDecimal,
            amount: existing.amount + tax.amountDecimal,
          );
        }
      }
    }

    return map.entries
        .map((e) => TaxLineItem(
              name: e.key,
              rateDecimal: e.value.rate,
              amountDecimal: e.value.amount,
            ))
        .toList();
  }

  /// Determines regional tax condition between seller state and buyer state.
  static TaxCondition determineSupplyCondition({
    required String sellerStateCode,
    String? buyerStateCode,
  }) {
    if (buyerStateCode == null || buyerStateCode.trim().isEmpty) {
      return TaxCondition.intraRegion;
    }
    return sellerStateCode.trim().toLowerCase() ==
            buyerStateCode.trim().toLowerCase()
        ? TaxCondition.intraRegion
        : TaxCondition.interRegion;
  }
}
