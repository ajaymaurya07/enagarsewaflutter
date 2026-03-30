import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://iamsup.in/ulb_property_tax/';
  static const String ulbDataEndpoint = 'api/House_tax/ulbdata';
  static const String zoneDataEndpoint = 'api/House_tax/zonedata/';
  static const String wardDataEndpoint = 'api/House_tax/warddata/';
  static const String mohallaDataEndpoint = 'api/House_tax/mohalladata/';
  static const String loginEndpoint = 'api/house_tax/login';
  
  // Header Version
  static const String appVersion = '6'; 

  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-App-Version': appVersion,
  };

  // Fetch ULB Data
  static Future<List<UlbData>> getUlbData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$ulbDataEndpoint'),
        headers: _headers,
      ).timeout(const Duration(seconds: 20));

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
      final response = await http.get(
        Uri.parse('$baseUrl$zoneDataEndpoint$ulbId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 20));

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
      final response = await http.get(
        Uri.parse('$baseUrl$wardDataEndpoint$ulbId/$zoneId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 20));

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
      final response = await http.get(
        Uri.parse('$baseUrl$mohallaDataEndpoint$ulbId/$zoneId/$wardId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 20));

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

  // Login API
  static Future<LoginResponse> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$loginEndpoint'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

// --- Models ---

class UlbData {
  final String ulbName;
  final String ulbId;
  final String? ulbType;

  UlbData({required this.ulbName, required this.ulbId, this.ulbType});

  factory UlbData.fromJson(Map<String, dynamic> json) {
    return UlbData(
      ulbName: json['ulbName'] ?? '',
      ulbId: json['ulbId']?.toString() ?? '',
      ulbType: json['ulbType'],
    );
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
  final UserData? data;

  LoginResponse({required this.success, required this.message, this.data});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['status'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? UserData.fromJson(json['data']) : null,
    );
  }
}

class UserData {
  final String accessToken;
  final String emailId;

  UserData({required this.accessToken, required this.emailId});

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      accessToken: json['access_token'] ?? '',
      emailId: json['email_id'] ?? '',
    );
  }
}
