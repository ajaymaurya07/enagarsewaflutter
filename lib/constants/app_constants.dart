class AppConstants {
  // API Constants
  static const String _baseUrlFromEnv = String.fromEnvironment('BASE_URL');
  static final String baseUrl = _resolveBaseUrl();
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
}
