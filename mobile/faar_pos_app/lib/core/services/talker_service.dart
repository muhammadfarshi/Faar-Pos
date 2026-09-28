import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: true,
    useConsoleLogs: kDebugMode,
    maxHistoryItems: 500,
  ),
);

class AppLog {
  static void info(String message) => talker.info(message);
  static void debug(String message) => talker.debug(message);
  static void warning(String message) => talker.warning(message);
  static void error(String message, [Object? exception, StackTrace? stackTrace]) {
    talker.error(message, exception, stackTrace);
  }
}
