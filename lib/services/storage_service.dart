import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class StorageService {
  static Future<void> saveLoginData(SignIn data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data.accessToken != null) await prefs.setString('access_token', data.accessToken!);
    if (data.refreshToken != null) await prefs.setString('refresh_token', data.refreshToken!);
    if (data.emailId != null) await prefs.setString('email_id', data.emailId!);
    if (data.userType != null) await prefs.setString('user_type', data.userType!);
  }

  static Future<void> updateAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<String?> getEmailId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email_id');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('email_id');
    await prefs.remove('user_type');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
