import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String? message;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: FaarPosTheme.kBackground.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: FaarPosTheme.kPrimary),
                    const SizedBox(height: 16),
                    Text(
                      message ?? 'Loading...',
                      style: const TextStyle(color: FaarPosTheme.kTextSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
