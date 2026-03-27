import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://iamsup.in/ulb_property_tax/';
  static const String loginEndpoint = 'api/house_tax/login';
  static const String appVersion = '1.0.0'; // Update this as needed

  static Future<LoginResponse> login(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl$loginEndpoint');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-App-Version': appVersion,
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return LoginResponse.fromJson(jsonResponse);
      } else if (response.statusCode == 401) {
        throw Exception('Invalid username or password');
      } else if (response.statusCode == 400) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? 'Invalid request');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on http.ClientException {
      throw Exception('Network error. Please check your internet connection.');
    } catch (e) {
      rethrow;
    }
  }
}

class LoginResponse {
  final bool success;
  final String message;
  final String? token;
  final UserData? data;

  LoginResponse({
    required this.success,
    required this.message,
    this.token,
    this.data,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['status'] ?? false,
      message: json['message'] ?? '',
      token: json['token'] as String?,
      data: json['data'] != null ? UserData.fromJson(json['data']) : null,
    );
  }
}

class UserData {
  final String accessToken;
  final String refreshToken;
  final String emailId;
  final String userType;

  UserData({
    required this.accessToken,
    required this.refreshToken,
    required this.emailId,
    required this.userType,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      emailId: json['email_id'] ?? '',
      userType: json['user_type'] ?? '',
    );
  }
}
