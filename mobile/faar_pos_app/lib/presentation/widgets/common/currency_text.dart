import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class CurrencyText extends StatelessWidget {
  final Decimal amount;
  final String symbol;
  final TextStyle? style;

  const CurrencyText({
    super.key,
    required this.amount,
    this.symbol = '₹',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = _formatAmount(amount);
    final defaultStyle = GoogleFonts.jetBrainsMono(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: FaarPosTheme.kTextPrimary,
    );
    return Text(
      '$symbol$formatted',
      style: style != null
          ? GoogleFonts.jetBrainsMono().merge(style)
          : defaultStyle,
    );
  }

  static String _formatAmount(Decimal amount) {
    final str = amount.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0 && intPart[i] != '-') {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
      count++;
    }
    return '${buffer.toString().split('').reversed.join()}.$decPart';
  }
}
