import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:faar_pos_app/domain/entities/tax_entity.dart';
import 'package:faar_pos_app/domain/services/tax_engine.dart';

void main() {
  group('TaxEngine - Deterministic Rounding', () {
    test('rounds half up correctly to 2 decimal places', () {
      expect(TaxEngine.roundHalfUp(Decimal.parse('10.255')), Decimal.parse('10.26'));
      expect(TaxEngine.roundHalfUp(Decimal.parse('10.254')), Decimal.parse('10.25'));
      expect(TaxEngine.roundHalfUp(Decimal.parse('10.2550001')), Decimal.parse('10.26'));
      expect(TaxEngine.roundHalfUp(Decimal.parse('0.005')), Decimal.parse('0.01'));
      expect(TaxEngine.roundHalfUp(Decimal.parse('0.004')), Decimal.parse('0.00'));
    });
  });

  group('TaxEngine - GST Intra-State (CGST + SGST)', () {
    final gst18Group = TaxGroupEntity(
      id: 1,
      name: 'GST 18%',
      totalRateDecimal: Decimal.parse('18.00'),
      isCompound: false,
      components: [
        TaxComponentEntity(
          id: 1,
          name: 'CGST 9%',
          rateDecimal: Decimal.parse('9.00'),
          appliesToCondition: TaxCondition.intraRegion,
        ),
        TaxComponentEntity(
          id: 2,
          name: 'SGST 9%',
          rateDecimal: Decimal.parse('9.00'),
          appliesToCondition: TaxCondition.intraRegion,
        ),
        TaxComponentEntity(
          id: 3,
          name: 'IGST 18%',
          rateDecimal: Decimal.parse('18.00'),
          appliesToCondition: TaxCondition.interRegion,
        ),
      ],
    );

    test('Tax-exclusive: 1000.00 base with 18% intra-state split into 9% CGST + 9% SGST', () {
      final result = TaxEngine.calculateLineItem(
        unitPrice: Decimal.parse('1000.00'),
        quantity: 1,
        taxGroup: gst18Group,
        supplyCondition: TaxCondition.intraRegion,
        isTaxInclusive: false,
      );

      expect(result.baseAmount, Decimal.parse('1000.00'));
      expect(result.taxableAmount, Decimal.parse('1000.00'));
      expect(result.totalTaxAmount, Decimal.parse('180.00'));
      expect(result.grandTotal, Decimal.parse('1180.00'));
      expect(result.taxBreakdown.length, 2);
      expect(result.taxBreakdown[0].name, 'CGST 9%');
      expect(result.taxBreakdown[0].amountDecimal, Decimal.parse('90.00'));
      expect(result.taxBreakdown[1].name, 'SGST 9%');
      expect(result.taxBreakdown[1].amountDecimal, Decimal.parse('90.00'));
    });

    test('Tax-exclusive: 1000.00 base with 18% inter-state uses only IGST 18%', () {
      final result = TaxEngine.calculateLineItem(
        unitPrice: Decimal.parse('1000.00'),
        quantity: 1,
        taxGroup: gst18Group,
        supplyCondition: TaxCondition.interRegion,
        isTaxInclusive: false,
      );

      expect(result.baseAmount, Decimal.parse('1000.00'));
      expect(result.taxableAmount, Decimal.parse('1000.00'));
      expect(result.totalTaxAmount, Decimal.parse('180.00'));
      expect(result.grandTotal, Decimal.parse('1180.00'));
      expect(result.taxBreakdown.length, 1);
      expect(result.taxBreakdown[0].name, 'IGST 18%');
      expect(result.taxBreakdown[0].amountDecimal, Decimal.parse('180.00'));
    });

    test('Tax-inclusive: 1180.00 gross with 18% intra-state extracts 1000.00 taxable and 90.00 CGST + 90.00 SGST', () {
      final result = TaxEngine.calculateLineItem(
        unitPrice: Decimal.parse('1180.00'),
        quantity: 1,
        taxGroup: gst18Group,
        supplyCondition: TaxCondition.intraRegion,
        isTaxInclusive: true,
      );

      expect(result.taxableAmount, Decimal.parse('1000.00'));
      expect(result.totalTaxAmount, Decimal.parse('180.00'));
      expect(result.grandTotal, Decimal.parse('1180.00'));
      expect(result.taxBreakdown.length, 2);
      expect(result.taxBreakdown[0].amountDecimal, Decimal.parse('90.00'));
      expect(result.taxBreakdown[1].amountDecimal, Decimal.parse('90.00'));
    });

    test('Discount application before tax computation', () {
      final result = TaxEngine.calculateLineItem(
        unitPrice: Decimal.parse('1000.00'),
        quantity: 2, // 2000.00 raw
        discountAmount: Decimal.parse('200.00'), // net 1800.00
        taxGroup: gst18Group,
        supplyCondition: TaxCondition.intraRegion,
        isTaxInclusive: false,
      );

      expect(result.baseAmount, Decimal.parse('2000.00'));
      expect(result.discountAmount, Decimal.parse('200.00'));
      expect(result.taxableAmount, Decimal.parse('1800.00'));
      // 9% of 1800 = 162.00 each
      expect(result.totalTaxAmount, Decimal.parse('324.00'));
      expect(result.grandTotal, Decimal.parse('2124.00'));
    });
  });

  group('TaxEngine - Regional State Determination', () {
    test('Same state code is intra-region', () {
      expect(
        TaxEngine.determineSupplyCondition(sellerStateCode: '32', buyerStateCode: '32'),
        TaxCondition.intraRegion,
      );
      expect(
        TaxEngine.determineSupplyCondition(sellerStateCode: 'KL', buyerStateCode: 'kl'),
        TaxCondition.intraRegion,
      );
    });

    test('Different state code is inter-region', () {
      expect(
        TaxEngine.determineSupplyCondition(sellerStateCode: '32', buyerStateCode: '29'),
        TaxCondition.interRegion,
      );
    });

    test('Null buyer state defaults to intra-region (B2C local sale)', () {
      expect(
        TaxEngine.determineSupplyCondition(sellerStateCode: '32', buyerStateCode: null),
        TaxCondition.intraRegion,
      );
    });
  });
}
