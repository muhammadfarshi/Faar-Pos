import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

class DecimalUtils {
  static final _currencyFormatter = NumberFormat.currency(
    customPattern: '#,##0.00',
    decimalDigits: 2,
  );

  static String formatCurrency(Decimal amount, {String symbol = '', String code = ''}) {
    final formatted = _currencyFormatter.format(amount.toDouble());
    if (symbol.isNotEmpty) {
      return '$symbol$formatted';
    } else if (code.isNotEmpty) {
      return '$formatted $code';
    }
    return formatted;
  }

  static Decimal parseDecimal(dynamic value) {
    if (value == null) return Decimal.zero;
    if (value is Decimal) return value;
    if (value is String) {
      try {
        return Decimal.parse(value);
      } catch (e) {
        return Decimal.zero;
      }
    }
    if (value is double || value is int) {
      return Decimal.parse(value.toString());
    }
    return Decimal.zero;
  }

  static Decimal roundHalfUp(Decimal value, {int scale = 2}) {
    return Decimal.parse(value.toDouble().toStringAsFixed(scale));
  }
}
