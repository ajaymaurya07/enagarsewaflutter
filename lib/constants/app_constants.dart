import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  // API Constants
  static const String _baseUrlFromEnv = String.fromEnvironment('BASE_URL');
  static const String _payuEnvironmentFromEnv = String.fromEnvironment(
    'PAYU_ENV',
  );
  static final String baseUrl = _resolveBaseUrl();
  static final String payuEnvironment = _resolvePayuEnvironment();
  static const int networkTimeout = 30; // Seconds

  // App Info
  static const String appName = 'e-Nagarseva';

  // Populated once at startup via AppConstants.init().
  // Accessing these before init() throws a LateInitializationError — by design.
  static late String apiVersion;        // versionCode  from pubspec (e.g. "7")
  static late String appDisplayVersion; // versionName  from pubspec (e.g. "1.0.3")

  /// Call this once in main() before runApp().
  /// Reads version info from pubspec.yaml automatically.
  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    appDisplayVersion = info.version;       
    apiVersion = info.buildNumber;        
  }

  static String _resolveBaseUrl() {
    if (_baseUrlFromEnv.isEmpty) {
      throw StateError(
        'BASE_URL dart-define is required. Run the app with --dart-define=BASE_URL=https://your-api-host/',
      );
    }

    return _baseUrlFromEnv.endsWith('/')
        ? _baseUrlFromEnv
        : '$_baseUrlFromEnv/';
  }

  static String _resolvePayuEnvironment() {
    if (_payuEnvironmentFromEnv.isEmpty) {
      throw StateError(
        'PAYU_ENV dart-define is required. Use PAYU_ENV=0 for production or PAYU_ENV=1 for test/sandbox.',
      );
    }

    if (_payuEnvironmentFromEnv != '0' && _payuEnvironmentFromEnv != '1') {
      throw StateError(
        'Invalid PAYU_ENV value. Use 0 for production or 1 for test/sandbox.',
      );
    }

    return _payuEnvironmentFromEnv;
  }
}
