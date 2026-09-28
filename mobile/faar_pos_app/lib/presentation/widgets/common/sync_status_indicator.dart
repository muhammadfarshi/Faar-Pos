import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

enum SyncStatus { idle, syncing, synced, error }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    return _buildDot(status);
  }

  Widget _buildDot(SyncStatus status) {
    Color color;
    String tooltip;
    switch (status) {
      case SyncStatus.synced:
        color = FaarPosTheme.kSuccess;
        tooltip = 'All synced';
        break;
      case SyncStatus.syncing:
        color = FaarPosTheme.kWarning;
        tooltip = 'Syncing...';
        break;
      case SyncStatus.error:
        color = FaarPosTheme.kDanger;
        tooltip = 'Sync error';
        break;
      case SyncStatus.idle:
        color = FaarPosTheme.kTextSecondary;
        tooltip = 'Idle';
        break;
    }
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)],
        ),
      ),
    );
  }
}
