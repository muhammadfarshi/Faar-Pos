import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../../data/local/app_database.dart';
import 'talker_service.dart';

class SyncService {
  final AppDatabase _db;
  final Dio _dio;

  SyncService(this._db) : _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<void> drainQueue() async {
    final pendingItems = _db.getPendingSyncItems();
    if (pendingItems.isEmpty) return;

    AppLog.info('Starting sync for ${pendingItems.length} items');

    for (final item in pendingItems) {
      final id = item['id'] as int;
      final payloadJson = item['payload_json'] as String;
      final attemptCount = item['attempt_count'] as int;

      try {
        final payload = jsonDecode(payloadJson);
        
        await _dio.post(
          '/api/v1/sync/transactions',
          data: payload,
        );

        _db.updateSyncItemStatus(id, 'synced', errorMessage: null);
        AppLog.info('Successfully synced item $id');
      } catch (e) {
        String errorMessage = e.toString();
        if (e is DioException) {
          errorMessage = e.message ?? errorMessage;
        }

        final newAttemptCount = attemptCount + 1;
        final newStatus = newAttemptCount >= 5 ? 'failed' : 'pending';
        
        _db.updateSyncItemStatus(id, newStatus, errorMessage: errorMessage);
        AppLog.error('Failed to sync item $id (attempt $newAttemptCount)', e, null);
        
        // Exponential backoff if we're going to retry
        if (newStatus == 'pending') {
          final backoffMs = min(pow(2, newAttemptCount) * 1000, 30000).toInt();
          await Future.delayed(Duration(milliseconds: backoffMs));
        }
      }
    }
    
    AppLog.info('Sync queue drain completed');
  }

  Map<String, int> getSyncQueueStats() {
    return _db.getSyncQueueStats();
  }
}
