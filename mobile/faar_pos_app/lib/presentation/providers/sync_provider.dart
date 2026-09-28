import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/app_database.dart';
import '../../core/services/sync_service.dart';

import '../widgets/common/sync_status_indicator.dart';

final _databaseChangeStreamProvider = StreamProvider<String>((ref) {
  return AppDatabase.instance.tableChanges;
});

final syncQueueStatsProvider = Provider<Map<String, int>>((ref) {
  // Watch table changes so this provider updates when db changes
  ref.watch(_databaseChangeStreamProvider);
  return AppDatabase.instance.getSyncQueueStats();
});

final triggerSyncProvider = FutureProvider.family<void, int>((ref, _) async {
  ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
  try {
    final syncService = SyncService(AppDatabase.instance);
    await syncService.drainQueue();
    ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
  } catch (e) {
    ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    rethrow;
  }
});
