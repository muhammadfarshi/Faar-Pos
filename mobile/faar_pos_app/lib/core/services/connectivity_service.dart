import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'talker_service.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) async* {
  final connectivity = Connectivity();
  
  // Initial check
  final initialStatus = await connectivity.checkConnectivity();
  final initialResult = initialStatus.isNotEmpty ? initialStatus.first : ConnectivityResult.none;
  AppLog.info('Initial connectivity status: $initialResult');
  yield initialResult;
  
  // Listen to changes
  await for (final statusList in connectivity.onConnectivityChanged) {
    final status = statusList.isNotEmpty ? statusList.first : ConnectivityResult.none;
    AppLog.info('Connectivity changed: $status');
    yield status;
  }
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivityStatus = ref.watch(connectivityProvider);
  return connectivityStatus.when(
    data: (status) => status != ConnectivityResult.none,
    loading: () => true, // default to true while loading
    error: (_, __) => false,
  );
});
