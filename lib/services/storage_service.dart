import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class StorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _integrityTokenKey = 'integrity_token';
  // v10+ uses custom AES-256 ciphers automatically; no options needed
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> saveLoginData(SignIn data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data.accessToken != null) {
      await _writeSecureToken(_accessTokenKey, data.accessToken!);
      await prefs.remove(_accessTokenKey);
    }
    if (data.refreshToken != null) {
      await _writeSecureToken(_refreshTokenKey, data.refreshToken!);
      await prefs.remove(_refreshTokenKey);
    }
    if (data.emailId != null) await prefs.setString('email_id', data.emailId!);
    if (data.userType != null) await prefs.setString('user_type', data.userType!);
  }

  static Future<void> updateAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeSecureToken(_accessTokenKey, token);
    await prefs.remove(_accessTokenKey);
  }

  static Future<void> setPropertyVerified(bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_property_verified', verified);
  }

  static Future<bool> isPropertyVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_property_verified') ?? false;
  }

  static Future<void> saveUlbId(String ulbId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_ulb_id', ulbId);
  }

  static Future<String?> getUlbId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_ulb_id');
  }

  static Future<void> saveTotalArv(String totalArv) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_property_total_arv', totalArv);
  }

  static Future<String?> getTotalArv() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_property_total_arv');
  }

  static Future<void> saveEmailId(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email_id', email);
  }

  static Future<String?> getAccessToken() async {
    return _readToken(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return _readToken(_refreshTokenKey);
  }

  static Future<String?> getEmailId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email_id');
  }

  static Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_type');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _deleteSecureToken(_accessTokenKey);
    await _deleteSecureToken(_refreshTokenKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove('email_id');
    await prefs.remove('user_type');
    await prefs.remove('is_property_verified');
    await prefs.remove('selected_ulb_id');
    await prefs.remove('selected_property_total_arv');
    await clearIntegrityToken();
    await clearUlbLanguageCache();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Remember Me credentials ────────────────────────────────────────────────

  static const String _rememberMeEmailKey = 'remember_me_email';
  static const String _rememberMePasswordKey = 'remember_me_password';

  static Future<void> saveRememberMeCredentials(String email, String password) async {
    await _secureStorage.write(key: _rememberMeEmailKey, value: email);
    await _secureStorage.write(key: _rememberMePasswordKey, value: password);
  }

  static Future<Map<String, String>?> getRememberMeCredentials() async {
    final email = await _secureStorage.read(key: _rememberMeEmailKey);
    final password = await _secureStorage.read(key: _rememberMePasswordKey);
    if (email != null && email.isNotEmpty && password != null && password.isNotEmpty) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  static Future<void> clearRememberMeCredentials() async {
    await _secureStorage.delete(key: _rememberMeEmailKey);
    await _secureStorage.delete(key: _rememberMePasswordKey);
  }

  // ── Integrity token (Play Integrity / App Attest) ──────────────────────────

  static Future<void> saveIntegrityToken(String token) async {
    await _secureStorage.write(key: _integrityTokenKey, value: token);
  }

  static Future<String?> getIntegrityToken() async {
    return _secureStorage.read(key: _integrityTokenKey);
  }

  static Future<void> clearIntegrityToken() async {
    await _secureStorage.delete(key: _integrityTokenKey);
  }

  // ── SBI mobile transaction ID ──────────────────────────────────────────────

  static const String _sbiMobileTxnIdKey = 'sbi_mobile_transaction_id';

  static Future<void> saveSbiMobileTransactionId(String id) async {
    await _secureStorage.write(key: _sbiMobileTxnIdKey, value: id);
  }

  static Future<String?> getSbiMobileTransactionId() async {
    return _secureStorage.read(key: _sbiMobileTxnIdKey);
  }

  static Future<void> clearSbiMobileTransactionId() async {
    await _secureStorage.delete(key: _sbiMobileTxnIdKey);
  }

  // ── PayU mobile transaction ID ─────────────────────────────────────────────

  static const String _payuMobileTxnIdKey = 'payu_mobile_transaction_id';

  static Future<void> savePayuMobileTransactionId(String id) async {
    await _secureStorage.write(key: _payuMobileTxnIdKey, value: id);
  }

  static Future<String?> getPayuMobileTransactionId() async {
    return _secureStorage.read(key: _payuMobileTxnIdKey);
  }

  static Future<void> clearPayuMobileTransactionId() async {
    await _secureStorage.delete(key: _payuMobileTxnIdKey);
  }

  // ── ULB Language (English / Krutidev) cache ────────────────────────────────
  // Cached after the dashboard's getUlbLanguage call so it isn't re-fetched
  // on every app open.

  static const String _languageCacheKey = 'ulb_language';
  static const String _ulbIdCacheKey = 'ulb_id_cache';

  static Future<void> saveLanguageCache(String language) async {
    await _secureStorage.write(key: _languageCacheKey, value: language);
  }

  static Future<String?> getLanguageCache() async {
    return _secureStorage.read(key: _languageCacheKey);
  }

  static Future<void> saveUlbCache(String ulbId) async {
    await _secureStorage.write(key: _ulbIdCacheKey, value: ulbId);
  }

  static Future<String?> getUlbCache() async {
    return _secureStorage.read(key: _ulbIdCacheKey);
  }

  static Future<void> clearUlbLanguageCache() async {
    await _secureStorage.delete(key: _languageCacheKey);
    await _secureStorage.delete(key: _ulbIdCacheKey);
  }

  static Future<void> _writeSecureToken(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> _readToken(String key) async {
    final secureValue = await _secureStorage.read(key: key);
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(key);
    if (legacyValue == null || legacyValue.isEmpty) {
      return legacyValue;
    }

    await _writeSecureToken(key, legacyValue);
    await prefs.remove(key);
    return legacyValue;
  }

  static Future<void> _deleteSecureToken(String key) async {
    await _secureStorage.delete(key: key);
  }
}
