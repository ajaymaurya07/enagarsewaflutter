class AppConstants {
  // API Constants
  static const String _baseUrlFromEnv = String.fromEnvironment('BASE_URL');
  static const String _payuEnvironmentFromEnv = String.fromEnvironment(
    'PAYU_ENV',
  );
  static final String baseUrl = _resolveBaseUrl();
  static final String payuEnvironment = _resolvePayuEnvironment();
  static const String apiVersion = '6'; // Used in X-App-Version header
  static const int networkTimeout = 30; // Seconds
  
  // App Info
  static const String appDisplayVersion = '1.0.0';
  static const String appName = 'e-Nagarseva';

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
