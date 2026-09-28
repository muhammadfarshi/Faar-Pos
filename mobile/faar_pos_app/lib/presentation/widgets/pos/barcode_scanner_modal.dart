import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../providers/cart_provider.dart';

class BarcodeScannerModal extends ConsumerStatefulWidget {
  const BarcodeScannerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BarcodeScannerModal(),
    );
  }

  @override
  ConsumerState<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends ConsumerState<BarcodeScannerModal> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    final code = rawValue.trim();
    if (code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    HapticFeedback.mediumImpact();

    final product = AppDatabase.instance.getProductByBarcodeOrSku(code);

    if (product != null) {
      ref.read(cartProvider.notifier).addItem(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: FaarPosTheme.kSuccess),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Added "${product.name}" to cart (${product.formattedPrice})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: FaarPosTheme.kSurfaceElevated,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: FaarPosTheme.kWarning),
                SizedBox(width: 8),
                Text('Product Not Found'),
              ],
            ),
            content: Text(
              'No product in catalog matches barcode/SKU: "$code".',
              style: const TextStyle(color: FaarPosTheme.kTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _isProcessing = false;
                    _lastScannedCode = null;
                  });
                },
                child: const Text('Scan Again'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.75,
      decoration: const BoxDecoration(
        color: FaarPosTheme.kBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: FaarPosTheme.kPrimary),
                    SizedBox(width: 8),
                    Text(
                      'Scan Barcode / SKU',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: FaarPosTheme.kTextPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Flash toggle
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: _isTorchOn ? FaarPosTheme.kWarning : FaarPosTheme.kTextSecondary,
                      ),
                      onPressed: () {
                        _controller.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                    ),
                    // Camera flip
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: FaarPosTheme.kTextSecondary),
                      onPressed: () => _controller.switchCamera(),
                    ),
                    // Close
                    IconButton(
                      icon: const Icon(Icons.close, color: FaarPosTheme.kTextPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: FaarPosTheme.kDivider),

          // Camera Viewfinder
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),

                // Viewfinder Reticle Overlay
                Container(
                  width: 260,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isProcessing ? FaarPosTheme.kSuccess : FaarPosTheme.kPrimary,
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                // Helper Text
                Positioned(
                  bottom: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isProcessing ? 'Processing barcode...' : 'Align barcode within frame to add to cart',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
