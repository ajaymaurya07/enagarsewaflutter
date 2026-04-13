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
      'device_id': deviceId,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    var headers = await _getHeaders();
    var response = await requestFn(headers);

    if (response.statusCode == 403) {
      final refreshTokenStr = await StorageService.getRefreshToken();
      if (refreshTokenStr != null) {
        try {
          final refreshResponse = await refreshToken(refreshTokenStr);
          if (refreshResponse.status == true && refreshResponse.data?.accessToken != null) {
            await StorageService.updateAccessToken(refreshResponse.data!.accessToken!);
            headers = await _getHeaders();
            response = await requestFn(headers);
          } else {
            await StorageService.logout();
          }
        } catch (e) {
          await StorageService.logout();
        }
      } else {
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

  // Search Property API
  static Future<List<PropertyData>> searchProperty({
    required String ulbId,
    required String searchType,
    String propertyId = "",
    String ownerName = "",
    String fatherName = "",
    String mobileNo = "",
    String zoneId = "",
    String wardId = "",
    String mohallaId = "",
    String chukNo = "",
    String houseNo = "",
  }) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.post(
        Uri.parse('${AppConstants.baseUrl}api/House_tax/propertysearch'),
        headers: headers,
        body: jsonEncode({
          'propertyId': propertyId,
          'ownerName': ownerName,
          'fatherName': fatherName,
          'mobileNo': mobileNo,
          'zoneId': zoneId,
          'wardId': wardId,
          'mohallaId': mohallaId,
          'chukNo': chukNo,
          'houseNo': houseNo,
          'ulbId': ulbId,
          'searchType': searchType,
        }),
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return (decodedData['data'] as List)
              .map((item) => PropertyData.fromJson(item))
              .toList();
        }
        return [];
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Fetch Property Details API
  static Future<PropertyDetailsResponse> getPropertyDetails(String propertyId) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.post(
        Uri.parse('${AppConstants.baseUrl}api/House_tax/propertydetails'),
        headers: headers,
        body: jsonEncode({'propertyId': propertyId}),
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        return PropertyDetailsResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load property details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Send OTP API
  static Future<SendOtpResponse> sendOtp(String mobileNo, String propertyId) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.post(
        Uri.parse('${AppConstants.baseUrl}api/house_tax/sendOtp'),
        headers: headers,
        body: jsonEncode({
          'mobileNo': mobileNo,
          'propertyId': propertyId,
        }),
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        return SendOtpResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to send OTP: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Verify OTP API
  static Future<OtpVerificationResponse> verifyOtp(String mobileNo, String otp) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.post(
        Uri.parse('${AppConstants.baseUrl}api/house_tax/verifyOtp'),
        headers: headers,
        body: jsonEncode({
          'mobileNo': mobileNo,
          'otp': otp,
        }),
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        return OtpVerificationResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('OTP verification failed: ${response.statusCode}');
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

      final hashedPassword = sha512.convert(utf8.encode(password)).toString();
      final String nonce = _generateNonce(16);
      final String inputString = hashedPassword + challenge + timestamp + nonce;
      final String finalHash = sha512.convert(utf8.encode(inputString)).toString();

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

  UlbData({this.ulbName, this.ulbId, this.ulbType, this.districtId, this.districtName});

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
  String toString() => '${ulbName ?? ""} (${ulbType ?? ""})';
}

class ZoneData {
  final String zoneName;
  final String zoneId;
  ZoneData({required this.zoneName, required this.zoneId});
  factory ZoneData.fromJson(Map<String, dynamic> json) => ZoneData(
    zoneName: json['zoneName'] ?? '',
    zoneId: json['zoneId']?.toString() ?? '',
  );
}

class WardData {
  final String wardName;
  final String wardId;
  WardData({required this.wardName, required this.wardId});
  factory WardData.fromJson(Map<String, dynamic> json) => WardData(
    wardName: json['wardName'] ?? '',
    wardId: json['wardId']?.toString() ?? '',
  );
}

class MohallaData {
  final String mohallaName;
  final String mohallaId;
  MohallaData({required this.mohallaName, required this.mohallaId});
  factory MohallaData.fromJson(Map<String, dynamic> json) => MohallaData(
    mohallaName: json['mohallaName'] ?? '',
    mohallaId: json['mohallaId']?.toString() ?? '',
  );
}

class PropertyData {
  final String? oldPropertyId;
  final String? address;
  final String? ownerName;
  final double? totalArv;
  final String? propertyType;
  final String? fatherHusbandName;
  final String? finYear;
  final String? houseNo;
  final String? chukNo;
  final String? propertyId;
  final String? billNo;
  final String? totalArea;

  PropertyData({
    this.oldPropertyId,
    this.address,
    this.ownerName,
    this.totalArv,
    this.propertyType,
    this.fatherHusbandName,
    this.finYear,
    this.houseNo,
    this.chukNo,
    this.propertyId,
    this.billNo,
    this.totalArea,
  });

  factory PropertyData.fromJson(Map<String, dynamic> json) {
    return PropertyData(
      oldPropertyId: json['oldPropertyId']?.toString(),
      address: json['address'],
      ownerName: json['ownerName'],
      totalArv: (json['totalArv'] is num) ? (json['totalArv'] as num).toDouble() : null,
      propertyType: json['propertyType'],
      fatherHusbandName: json['fatherHusbandName'],
      finYear: json['finYear'],
      houseNo: json['houseNo'],
      chukNo: json['chukNo'],
      propertyId: json['propertyId']?.toString(),
      billNo: json['billNo'],
      totalArea: json['totalArea']?.toString(),
    );
  }
}

class PropertyDetailsResponse {
  final bool? success;
  final String? message;
  final int? responseCode;
  final PropertyDetailsData? data;

  PropertyDetailsResponse({this.success, this.message, this.responseCode, this.data});

  factory PropertyDetailsResponse.fromJson(Map<String, dynamic> json) {
    return PropertyDetailsResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null ? PropertyDetailsData.fromJson(json['data']) : null,
    );
  }
}

class PropertyDetailsData {
  final BillDetails? billDetails;
  final OwnerDetails? ownerDetails;
  final PropertyInfo? propertyDetailsInfo;
  final List<ReceiptDetailsItem>? currReceiptDetails;
  final List<ReceiptDetailsItem>? prevReceiptDetails;

  PropertyDetailsData({
    this.billDetails,
    this.ownerDetails,
    this.propertyDetailsInfo,
    this.currReceiptDetails,
    this.prevReceiptDetails,
  });

  factory PropertyDetailsData.fromJson(Map<String, dynamic> json) {
    return PropertyDetailsData(
      billDetails: json['billDetails'] != null ? BillDetails.fromJson(json['billDetails']) : null,
      ownerDetails: json['ownerDetails'] != null ? OwnerDetails.fromJson(json['ownerDetails']) : null,
      propertyDetailsInfo: json['propertyDetails'] != null ? PropertyInfo.fromJson(json['propertyDetails']) : null,
      currReceiptDetails: json['currReceiptDetails'] != null
          ? (json['currReceiptDetails'] as List).map((i) => ReceiptDetailsItem.fromJson(i)).toList()
          : null,
      prevReceiptDetails: json['prevReceiptDetails'] != null
          ? (json['prevReceiptDetails'] as List).map((i) => ReceiptDetailsItem.fromJson(i)).toList()
          : null,
    );
  }
}

class BillDetails {
  final String? netPayble;
  final String? billNo;
  final String? billDate;
  final String? finYear;

  BillDetails({this.netPayble, this.billNo, this.billDate, this.finYear});

  factory BillDetails.fromJson(Map<String, dynamic> json) {
    return BillDetails(
      netPayble: json['netPayble']?.toString(),
      billNo: json['billNo']?.toString(),
      billDate: json['billDate']?.toString(),
      finYear: json['finYear']?.toString(),
    );
  }
}

class OwnerDetails {
  final String? ownerName;
  final String? fatherName;
  final String? mobileNo;

  OwnerDetails({this.ownerName, this.fatherName, this.mobileNo});

  factory OwnerDetails.fromJson(Map<String, dynamic> json) {
    return OwnerDetails(
      ownerName: json['ownerName'],
      fatherName: json['fatherName'],
      mobileNo: json['mobileNo']?.toString(),
    );
  }
}

class PropertyInfo {
  final String? address;
  final String? houseNo;
  final String? wardName;
  final String? zoneName;
  final String? mohallaName;

  PropertyInfo({this.address, this.houseNo, this.wardName, this.zoneName, this.mohallaName});

  factory PropertyInfo.fromJson(Map<String, dynamic> json) {
    return PropertyInfo(
      address: json['address'],
      houseNo: json['houseNo']?.toString(),
      wardName: json['wardName'],
      zoneName: json['zoneName'],
      mohallaName: json['mohallaName'],
    );
  }
}

class ReceiptDetailsItem {
  final String? receiptNo;
  final String? receiptDate;
  final String? propertyTaxPaidAmount;

  ReceiptDetailsItem({this.receiptNo, this.receiptDate, this.propertyTaxPaidAmount});

  factory ReceiptDetailsItem.fromJson(Map<String, dynamic> json) {
    return ReceiptDetailsItem(
      receiptNo: json['receiptNo']?.toString(),
      receiptDate: json['receiptDate']?.toString(),
      propertyTaxPaidAmount: json['propertyTaxPaidAmount']?.toString(),
    );
  }
}

class SendOtpResponse {
  final bool? success;
  final String? message;
  final int? responseCode;

  SendOtpResponse({this.success, this.message, this.responseCode});

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    return SendOtpResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
    );
  }
}

class OtpVerificationResponse {
  final bool? success;
  final String? message;
  final int? responseCode;
  final int? userId;

  OtpVerificationResponse({this.success, this.message, this.responseCode, this.userId});

  factory OtpVerificationResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      userId: json['userId'],
    );
  }
}

class LoginResponse {
  final bool success;
  final String message;
  final int? responseCode;
  final SignIn? data;
  LoginResponse({required this.success, required this.message, this.responseCode, this.data});
  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    success: json['status'] ?? false,
    message: json['message'] ?? '',
    responseCode: json['responseCode'],
    data: json['data'] != null ? SignIn.fromJson(json['data']) : null,
  );
}

class SignIn {
  final String? accessToken;
  final String? refreshToken;
  final String? emailId;
  final String? userType;
  SignIn({this.accessToken, this.refreshToken, this.emailId, this.userType});
  factory SignIn.fromJson(Map<String, dynamic> json) => SignIn(
    accessToken: json['access_token']?.toString(),
    refreshToken: json['refresh_token']?.toString(),
    emailId: json['email_id']?.toString(),
    userType: json['user_type']?.toString(),
  );
}

class RefreshTokenResponse {
  final bool? status;
  final int? responseCode;
  final String? message;
  final RefreshTokenData? data;
  RefreshTokenResponse({this.status, this.responseCode, this.message, this.data});
  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) => RefreshTokenResponse(
    status: json['status'],
    responseCode: json['responseCode'],
    message: json['message'],
    data: json['data'] != null ? RefreshTokenData.fromJson(json['data']) : null,
  );
}

class RefreshTokenData {
  final String? accessToken;
  RefreshTokenData({this.accessToken});
  factory RefreshTokenData.fromJson(Map<String, dynamic> json) => RefreshTokenData(
    accessToken: json['access_token'],
  );
}
