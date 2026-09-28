import 'package:decimal/decimal.dart';
import '../entities/tax_entity.dart';
import '../entities/cart_item_entity.dart';
import '../../core/utils/decimal_utils.dart';

class TaxCalculationService {
  List<TaxLineItem> calculateBreakdown({
    required Decimal unitPrice,
    required int quantity,
    required Decimal discount,
    required TaxGroupEntity taxGroup,
    required TaxCondition supplyCondition,
  }) {
    List<TaxLineItem> breakdown = [];
    Decimal base = (unitPrice * Decimal.parse(quantity.toString())) - discount;
    if (base < Decimal.zero) base = Decimal.zero;

    Decimal currentBase = base;

    for (var component in taxGroup.components) {
      if (component.appliesToCondition != TaxCondition.always && 
          component.appliesToCondition != supplyCondition) {
        continue;
      }

      Decimal amount = DecimalUtils.roundHalfUp(currentBase * component.rateDecimal);
      breakdown.add(TaxLineItem(
        name: component.name,
        rateDecimal: component.rateDecimal,
        amountDecimal: amount,
      ));

      if (taxGroup.isCompound) {
        currentBase = currentBase + amount;
      }
    }

    return breakdown;
  }

  Decimal totalTax(List<TaxLineItem> breakdown) {
    Decimal total = Decimal.zero;
    for (var item in breakdown) {
      total += item.amountDecimal;
    }
    return total;
  }

  Decimal lineTotal(Decimal base, List<TaxLineItem> breakdown, Decimal discount) {
    return base - discount + totalTax(breakdown);
  }
}
