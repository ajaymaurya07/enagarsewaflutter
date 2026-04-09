import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'storage_service.dart';
import 'device_service.dart';
import '../constants/app_constants.dart';

class ApiService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getAccessToken();
    final deviceId = await DeviceService.getDeviceId();
    
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-App-Version': AppConstants.apiVersion,
      'X-Device-Id': deviceId,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Generic request wrapper to handle 403 and Refresh Token
  static Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    var headers = await _getHeaders();
    var response = await requestFn(headers);

    if (response.statusCode == 403) {
      // Token might be expired, try to refresh
      final refreshTokenStr = await StorageService.getRefreshToken();
      if (refreshTokenStr != null) {
        try {
          final refreshResponse = await refreshToken(refreshTokenStr);
          if (refreshResponse.status == true && refreshResponse.data?.accessToken != null) {
            // Update token and retry
            await StorageService.updateAccessToken(refreshResponse.data!.accessToken!);
            
            // Get new headers and retry the original request
            headers = await _getHeaders();
            response = await requestFn(headers);
          } else {
            // Refresh failed, logout
            await StorageService.logout();
          }
        } catch (e) {
          // Error in refresh, logout
          await StorageService.logout();
        }
      } else {
        // No refresh token, logout
        await StorageService.logout();
      }
    }
    return response;
  }

  // Fetch ULB Data
  static Future<List<UlbData>> getUlbData() async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.get(
        Uri.parse('${AppConstants.baseUrl}api/House_tax/ulbdata'),
        headers: headers,
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return (decodedData['data'] as List)
              .map((item) => UlbData.fromJson(item))
              .toList();
        }
        throw Exception(decodedData['message'] ?? 'Failed to load ULB data');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Fetch Zone Data
  static Future<List<ZoneData>> getZoneData(String ulbId) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.get(
        Uri.parse('${AppConstants.baseUrl}api/House_tax/zonedata/$ulbId'),
        headers: headers,
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return (decodedData['data'] as List)
              .map((item) => ZoneData.fromJson(item))
              .toList();
        }
        return [];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Fetch Ward Data
  static Future<List<WardData>> getWardData(String ulbId, String zoneId) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.get(
        Uri.parse('${AppConstants.baseUrl}api/House_tax/warddata/$ulbId/$zoneId'),
        headers: headers,
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return (decodedData['data'] as List)
              .map((item) => WardData.fromJson(item))
              .toList();
        }
        return [];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Fetch Mohalla Data
  static Future<List<MohallaData>> getMohallaData(String ulbId, String zoneId, String wardId) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.get(
        Uri.parse('${AppConstants.baseUrl}api/House_tax/mohalladata/$ulbId/$zoneId/$wardId'),
        headers: headers,
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return (decodedData['data'] as List)
              .map((item) => MohallaData.fromJson(item))
              .toList();
        }
        return [];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Secure Login Flow
  static Future<LoginResponse> secureLogin(String username, String password, String deviceId) async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      // Step 1: Get Challenge
      final challengeResponse = await http.post(
        Uri.parse('${AppConstants.baseUrl}api/house_tax/get_challenge'),
        headers: headers,
        body: jsonEncode({
          'username': username,
          'device_id': deviceId,
        }),
      ).timeout(Duration(seconds: AppConstants.networkTimeout));

      if (challengeResponse.statusCode != 200) {
        throw Exception('Failed to get challenge: ${challengeResponse.statusCode}');
      }

      final challengeData = jsonDecode(challengeResponse.body);
      if (challengeData['status'] != true) {
        throw Exception(challengeData['message'] ?? 'Challenge generation failed');
      }

      final String challengeId = challengeData['data']['challenge_id'];
      final String challenge = challengeData['data']['challenge'];
      final String timestamp = challengeData['data']['timestamp'].toString();

      // Step 2: Hashing logic
      final hashedPassword = sha512.convert(utf8.encode(password)).toString();
      final String nonce = _generateNonce(16);
      final String inputString = hashedPassword + challenge + timestamp + nonce;
      final String finalHash = sha512.convert(utf8.encode(inputString)).toString();

      // Step 3: Final Login Call
      final loginResponse = await http.post(
        Uri.parse('${AppConstants.baseUrl}api/house_tax/login'),
        headers: headers,
        body: jsonEncode({
          'username': username,
          'device_id': deviceId,
          'challenge_id': challengeId,
          'timestamp': timestamp,
          'nonce': nonce,
          'hash': finalHash,
        }),
      ).timeout(Duration(seconds: AppConstants.networkTimeout));

      if (loginResponse.statusCode == 200) {
        final loginData = LoginResponse.fromJson(jsonDecode(loginResponse.body));
        if (loginData.success && loginData.data != null) {
          await StorageService.saveLoginData(loginData.data!);
        }
        return loginData;
      } else {
        throw Exception('Login API error: ${loginResponse.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Refresh Token API
  static Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}api/house_tax/refreshToken'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-App-Version': AppConstants.apiVersion,
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
        }),
      ).timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return RefreshTokenResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static String _generateNonce(int length) {
    final Random secureRandom = Random.secure();
    const chars = '0123456789abcdef';
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(secureRandom.nextInt(chars.length))));
  }
}

// --- Models ---

class UlbData {
  final String? ulbName;
  final String? ulbId;
  final String? ulbType;
  final String? districtId;
  final String? districtName;

  UlbData({
    this.ulbName, 
    this.ulbId, 
    this.ulbType, 
    this.districtId, 
    this.districtName
  });

  factory UlbData.fromJson(Map<String, dynamic> json) {
    return UlbData(
      ulbName: json['ulbName'],
      ulbId: json['ulbId']?.toString(),
      ulbType: json['ulbType'],
      districtId: json['districtId']?.toString(),
      districtName: json['districtName'],
    );
  }

  @override
  String toString() {
    return '${ulbName ?? ""} (${ulbType ?? ""})';
  }
}

class ZoneData {
  final String zoneName;
  final String zoneId;

  ZoneData({required this.zoneName, required this.zoneId});

  factory ZoneData.fromJson(Map<String, dynamic> json) {
    return ZoneData(
      zoneName: json['zoneName'] ?? '',
      zoneId: json['zoneId']?.toString() ?? '',
    );
  }
}

class WardData {
  final String wardName;
  final String wardId;

  WardData({required this.wardName, required this.wardId});

  factory WardData.fromJson(Map<String, dynamic> json) {
    return WardData(
      wardName: json['wardName'] ?? '',
      wardId: json['wardId']?.toString() ?? '',
    );
  }
}

class MohallaData {
  final String mohallaName;
  final String mohallaId;

  MohallaData({required this.mohallaName, required this.mohallaId});

  factory MohallaData.fromJson(Map<String, dynamic> json) {
    return MohallaData(
      mohallaName: json['mohallaName'] ?? '',
      mohallaId: json['mohallaId']?.toString() ?? '',
    );
  }
}

class LoginResponse {
  final bool success;
  final String message;
  final int? responseCode;
  final SignIn? data;

  LoginResponse({
    required this.success, 
    required this.message, 
    this.responseCode,
    this.data
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['status'] ?? false,
      message: json['message'] ?? '',
      responseCode: json['responseCode'],
      data: json['data'] != null ? SignIn.fromJson(json['data']) : null,
    );
  }
}

class SignIn {
  final String? accessToken;
  final String? refreshToken;
  final String? emailId;
  final String? userType;

  SignIn({this.accessToken, this.refreshToken, this.emailId, this.userType});

  factory SignIn.fromJson(Map<String, dynamic> json) {
    return SignIn(
      accessToken: json['access_token']?.toString(),
      refreshToken: json['refresh_token']?.toString(),
      emailId: json['email_id']?.toString(),
      userType: json['user_type']?.toString(),
    );
  }
}

class RefreshTokenResponse {
  final bool? status;
  final int? responseCode;
  final String? message;
  final RefreshTokenData? data;

  RefreshTokenResponse({this.status, this.responseCode, this.message, this.data});

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      status: json['status'],
      responseCode: json['responseCode'],
      message: json['message'],
      data: json['data'] != null ? RefreshTokenData.fromJson(json['data']) : null,
    );
  }
}

class RefreshTokenData {
  final String? accessToken;

  RefreshTokenData({this.accessToken});

  factory RefreshTokenData.fromJson(Map<String, dynamic> json) {
    return RefreshTokenData(
      accessToken: json['access_token'],
    );
  }
}
