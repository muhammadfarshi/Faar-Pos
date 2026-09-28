import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/talker_service.dart';
import 'data/local/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize orientation lock & system UI overlay
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize SQLite local database
  try {
    await AppDatabase.instance.initialize();
  } catch (e, st) {
    AppLog.error('Critical database initialization error', e, st);
  }

  runApp(const ProviderScope(child: FaarPosApp()));
}

class FaarPosApp extends ConsumerWidget {
  const FaarPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'FAAR POS',
      debugShowCheckedModeBanner: false,
      theme: FaarPosTheme.darkTheme,
      routerConfig: router,
    );
  }
}
