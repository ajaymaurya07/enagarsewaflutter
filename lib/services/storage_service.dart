import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class StorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: _androidOptions,
  );

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
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
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
