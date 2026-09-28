import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/product_entity.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductCard extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FaarPosTheme.kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: FaarPosTheme.kCardBorder),
      ),
      child: InkWell(
        onTap: () {
          // HapticFeedback.lightImpact(); // Add if services/haptic is imported
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: Container(
                decoration: const BoxDecoration(
                  color: FaarPosTheme.kSurfaceElevated,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Icon(Icons.inventory_2, size: 48, color: FaarPosTheme.kTextSecondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: FaarPosTheme.kTextPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.sku,
                    style: GoogleFonts.jetBrainsMono(
                      textStyle: const TextStyle(fontSize: 12, color: FaarPosTheme.kTextSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Simple stock badge placeholder
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.stockQuantity > product.lowStockThreshold ? FaarPosTheme.kSuccess : FaarPosTheme.kWarning,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.stockQuantity > 0 ? 'In Stock' : 'Out',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '\$${product.basePriceDecimal.toString()}',
                        style: GoogleFonts.jetBrainsMono(
                          textStyle: const TextStyle(
                            color: FaarPosTheme.kPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
