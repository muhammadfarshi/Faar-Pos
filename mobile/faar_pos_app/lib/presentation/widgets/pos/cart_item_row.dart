import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/cart_item_entity.dart';
import '../common/currency_text.dart';
import 'package:google_fonts/google_fonts.dart';

class CartItemRow extends StatelessWidget {
  final CartItemEntity item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const CartItemRow({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.sku,
                  style: GoogleFonts.jetBrainsMono(
                    textStyle: const TextStyle(fontSize: 12, color: FaarPosTheme.kTextSecondary),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle),
                color: FaarPosTheme.kDanger,
                iconSize: 20,
                onPressed: onDecrement,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: GoogleFonts.jetBrainsMono(
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: FaarPosTheme.kSuccess,
                iconSize: 20,
                onPressed: onIncrement,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CurrencyText(
                amount: item.lineTotalDecimal,
                style: const TextStyle(fontWeight: FontWeight.bold, color: FaarPosTheme.kPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                color: FaarPosTheme.kTextSecondary,
                iconSize: 20,
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
