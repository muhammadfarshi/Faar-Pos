enum AppEnvironment { development, staging, production }

/// App-wide configuration loaded from compile-time --dart-define flags.
///
/// Usage:
///   Development:  flutter run --dart-define=ENV=development
///   Staging:      flutter run --dart-define=ENV=staging
///   Production:   flutter build apk --dart-define=ENV=production --dart-define=API_BASE_URL=https://api.faarpos.com
///
/// Never hardcode production URLs or secrets in this file.
class AppConfig {
  // ── Environment ────────────────────────────────────────────────────────────
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'development');

  static AppEnvironment get environment {
    switch (_env) {
      case 'staging':    return AppEnvironment.staging;
      case 'production': return AppEnvironment.production;
      default:           return AppEnvironment.development;
    }
  }

  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isStaging     => environment == AppEnvironment.staging;
  static bool get isProduction  => environment == AppEnvironment.production;

  // ── API Base URL ───────────────────────────────────────────────────────────
  /// Android emulator: 10.0.2.2 maps to host machine localhost.
  /// iOS simulator: localhost works directly.
  /// Physical device: use your machine's LAN IP or the staging/production URL.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String apiVersion = '/api/v1';

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration demoFallbackTimeout = Duration(seconds: 8);

  // ── Token Lifetimes ────────────────────────────────────────────────────────
  static const Duration accessTokenLifetime  = Duration(minutes: 15);
  static const Duration refreshTokenLifetime = Duration(days: 30);

  // ── Sync ───────────────────────────────────────────────────────────────────
  static const Duration syncInterval          = Duration(minutes: 5);
  static const Duration syncInitialBackoff    = Duration(seconds: 5);
  static const Duration syncMaxBackoff        = Duration(minutes: 10);
  static const int      syncMaxRetries        = 5;

  // ── POS Defaults ───────────────────────────────────────────────────────────
  static const String defaultCurrencyCode   = 'INR';
  static const String defaultCurrencySymbol = '₹';
  static const String defaultCountryCode    = 'IN';
  static const int    defaultDecimalPlaces  = 2;

  // ── Logging ────────────────────────────────────────────────────────────────
  static bool get verboseLogging => !isProduction;

  // ── App Info ───────────────────────────────────────────────────────────────
  static const String appName    = 'FAAR POS';
  static const String appVersion = '1.0.0';
  static const String supportUrl = 'https://support.faarpos.com';

  // ── Feature Flags ──────────────────────────────────────────────────────────
  static const bool enablePinLogin      = bool.fromEnvironment('FEATURE_PIN_LOGIN',      defaultValue: false);
  static const bool enableMultiStore    = bool.fromEnvironment('FEATURE_MULTI_STORE',    defaultValue: false);
  static const bool enableAnalytics     = bool.fromEnvironment('FEATURE_ANALYTICS',      defaultValue: false);
  static const bool enableCrashlytics  = bool.fromEnvironment('FEATURE_CRASHLYTICS',    defaultValue: false);

  // ── Security ───────────────────────────────────────────────────────────────
  /// Set to false in production to block demo credential fallback.
  static const bool allowDemoFallback = String.fromEnvironment('ENV', defaultValue: 'development') != 'production';
}
