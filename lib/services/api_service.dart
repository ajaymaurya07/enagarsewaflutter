import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'device_service.dart';
import 'database_service.dart';
import '../constants/app_constants.dart';
import '../login_screen.dart';

class ApiService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  static Future<void> _handleSessionExpired() async {
    await DatabaseService.clearDatabase();
    await StorageService.logout();
    
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
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
            
            if (response.statusCode == 403) {
              await _handleSessionExpired();
            }
          } else {
            await _handleSessionExpired();
          }
        } catch (e) {
          await _handleSessionExpired();
        }
      } else {
        await _handleSessionExpired();
      }
    }
    return response;
  }

  // Save Grievance API (Multipart)
  static Future<SaveGrievanceResponse> saveGrievance({
    required String ulbId,
    required String zoneId,
    required String wardId,
    required String mohallaId,
    required String categoryId,
    required String subCategoryId,
    required String landmark,
    required String description,
    required String name,
    required String fatherName,
    required String mobileNo,
    required String email,
    required String address,
    required String propertyId,
    File? imageFile,
  }) async {
    try {
      final token = await StorageService.getAccessToken();
      final deviceId = await DeviceService.getDeviceId();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}api/house_tax/saveGrievance'),
      );

      // Headers
      request.headers.addAll({
        'Accept': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
        'X-Device-Id': deviceId,
        if (token != null) 'Authorization': 'Bearer $token',
      });

      // Fields
      request.fields['ulbId'] = ulbId;
      request.fields['zoneId'] = zoneId;
      request.fields['wardId'] = wardId;
      request.fields['mohallaId'] = mohallaId;
      request.fields['categoryId'] = categoryId;
      request.fields['subCategoryId'] = subCategoryId;
      request.fields['landmark'] = landmark;
      request.fields['description'] = description;
      request.fields['name'] = name;
      request.fields['fatherName'] = fatherName;
      request.fields['mobileNo'] = mobileNo;
      request.fields['email'] = email;
      request.fields['address'] = address;
      request.fields['propertyId'] = propertyId;

      // File
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ));
      }

      final streamedResponse = await request.send().timeout(Duration(seconds: AppConstants.networkTimeout));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return SaveGrievanceResponse.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 403) {
        await _handleSessionExpired();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to save grievance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Register Grievance Verify OTP API
  static Future<OtpVerificationResponse> registerGrievanceVerifyOtp({
    required String mobileNo,
    required String otp,
    required String grievanceId,
  }) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.post(
        Uri.parse('${AppConstants.baseUrl}api/house_tax/registerGrievanceAfterOtp'),
        headers: headers,
        body: jsonEncode({
          'mobileNo': mobileNo,
          'otp': otp,
          'grievance_id': grievanceId,
        }),
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        return OtpVerificationResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Verification failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Fetch Grievance Categories API
  static Future<List<GrievanceCategory>> getGrievanceCategories() async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.get(
        Uri.parse('${AppConstants.baseUrl}api/House_tax/grievanceCategory'),
        headers: headers,
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return (decodedData['data'] as List)
              .map((item) => GrievanceCategory.fromJson(item))
              .toList();
        }
        throw Exception(decodedData['message'] ?? 'Failed to load categories');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
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

  // Create Transaction API
  static Future<CreateTransactionResponse> initiateTransaction(InitiateTransactionRequest request) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.post(
        Uri.parse('${AppConstants.baseUrl}api/Payment/create_transaction'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        return CreateTransactionResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Transaction initiation failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Fetch Transactions By Email API
  static Future<TransactionsByEmailResponse> getTransactionsByEmail(String emailId) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.post(
        Uri.parse('${AppConstants.baseUrl}api/payment/get_transactions_by_email'),
        headers: headers,
        body: jsonEncode({'email_id': emailId}),
      ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        return TransactionsByEmailResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
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

  // Logout API
  static Future<LogoutResponse> logout() async {
    try {
      final response = await _makeAuthenticatedRequest((headers) => http.post(
            Uri.parse('${AppConstants.baseUrl}api/house_tax/logout'),
            headers: headers,
          ).timeout(Duration(seconds: AppConstants.networkTimeout)));

      if (response.statusCode == 200) {
        return LogoutResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Logout failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
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

class SaveGrievanceResponse {
  final bool success;
  final int responseCode;
  final String message;
  final GrievanceData? data;

  SaveGrievanceResponse({required this.success, required this.responseCode, required this.message, this.data});

  factory SaveGrievanceResponse.fromJson(Map<String, dynamic> json) {
    return SaveGrievanceResponse(
      success: json['success'] ?? false,
      responseCode: json['responseCode'] ?? 0,
      message: json['message'] ?? '',
      data: json['data'] != null ? GrievanceData.fromJson(json['data']) : null,
    );
  }
}

class GrievanceData {
  final String? grievanceId;
  GrievanceData({this.grievanceId});
  factory GrievanceData.fromJson(Map<String, dynamic> json) => GrievanceData(
    grievanceId: json['grievance_id']?.toString(),
  );
}

class GrievanceCategory {
  final int? serviceCode;
  final String? serviceName;
  final List<GrievanceSubCategory>? subCategories;

  GrievanceCategory({this.serviceCode, this.serviceName, this.subCategories});

  factory GrievanceCategory.fromJson(Map<String, dynamic> json) {
    return GrievanceCategory(
      serviceCode: json['serviceCode'],
      serviceName: json['serviceName'],
      subCategories: json['subCategories'] != null
          ? (json['subCategories'] as List)
              .map((i) => GrievanceSubCategory.fromJson(i))
              .toList()
          : null,
    );
  }
}

class GrievanceSubCategory {
  final int? subCatCode;
  final String? subName;

  GrievanceSubCategory({this.subCatCode, this.subName});

  factory GrievanceSubCategory.fromJson(Map<String, dynamic> json) {
    return GrievanceSubCategory(
      subCatCode: json['subCatCode'],
      subName: json['subName'],
    );
  }
}

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
  final String? sewerTaxArrear;
  final String? otherTaxMonthlyInterest;
  final String? houseTaxDiscount;
  final String? waterChargeAdvance;
  final String? houseTaxAdvance;
  final String? finYear;
  final String? othertaxNetAmount;
  final String? sewerTaxDiscount;
  final String? sewerTaxAdvance;
  final String? waterChargeMonthlyInterest;
  final String? houseTaxArrear;
  final String? sewerTaxInterest;
  final String? waterTaxMonthlyInterest;
  final String? waterTaxArrear;
  final String? otherTaxArrear;
  final String? houseCurrentTax;
  final String? waterCurrentTax;
  final String? waterTaxInterest;
  final String? netPayble;
  final String? netDemand;
  final String? otherCurrentTax;
  final String? otherTaxInterest;
  final String? sewerTaxMonthlyInterest;
  final String? billNo;
  final String? waterChargeDiscount;
  final String? waterTaxAdvance;
  final String? otherTaxAdvance;
  final String? waterTaxNetAmount;
  final String? waterTaxDiscount;
  final String? sewerTaxNetAmount;
  final String? billDate;
  final String? waterChargeArrear;
  final String? waterChargeNetAmount;
  final String? houseTaxMonthlyInterest;
  final String? houseTaxInterest;
  final String? sewerCurrentTax;
  final String? houseTaxNetAmount;
  final String? otherTaxDiscount;
  final String? waterChargeInterest;
  final String? waterChargeCurrent;

  BillDetails({
    this.sewerTaxArrear,
    this.otherTaxMonthlyInterest,
    this.houseTaxDiscount,
    this.waterChargeAdvance,
    this.houseTaxAdvance,
    this.finYear,
    this.othertaxNetAmount,
    this.sewerTaxDiscount,
    this.sewerTaxAdvance,
    this.waterChargeMonthlyInterest,
    this.houseTaxArrear,
    this.sewerTaxInterest,
    this.waterTaxMonthlyInterest,
    this.waterTaxArrear,
    this.otherTaxArrear,
    this.houseCurrentTax,
    this.waterCurrentTax,
    this.waterTaxInterest,
    this.netPayble,
    this.netDemand,
    this.otherCurrentTax,
    this.otherTaxInterest,
    this.sewerTaxMonthlyInterest,
    this.billNo,
    this.waterChargeDiscount,
    this.waterTaxAdvance,
    this.otherTaxAdvance,
    this.waterTaxNetAmount,
    this.waterTaxDiscount,
    this.sewerTaxNetAmount,
    this.billDate,
    this.waterChargeArrear,
    this.waterChargeNetAmount,
    this.houseTaxMonthlyInterest,
    this.houseTaxInterest,
    this.sewerCurrentTax,
    this.houseTaxNetAmount,
    this.otherTaxDiscount,
    this.waterChargeInterest,
    this.waterChargeCurrent,
  });

  factory BillDetails.fromJson(Map<String, dynamic> json) {
    return BillDetails(
      sewerTaxArrear: json['sewerTaxArrear']?.toString(),
      otherTaxMonthlyInterest: json['otherTaxMonthlyInterest']?.toString(),
      houseTaxDiscount: json['houseTaxDiscount']?.toString(),
      waterChargeAdvance: json['waterChargeAdvance']?.toString(),
      houseTaxAdvance: json['houseTaxAdvance']?.toString(),
      finYear: json['finYear']?.toString(),
      othertaxNetAmount: json['othertaxNetAmount']?.toString(),
      sewerTaxDiscount: json['sewerTaxDiscount']?.toString(),
      sewerTaxAdvance: json['sewerTaxAdvance']?.toString(),
      waterChargeMonthlyInterest: json['waterChargeMonthlyInterest']?.toString(),
      houseTaxArrear: json['houseTaxArrear']?.toString(),
      sewerTaxInterest: json['sewerTaxInterest']?.toString(),
      waterTaxMonthlyInterest: json['waterTaxMonthlyInterest']?.toString(),
      waterTaxArrear: json['waterTaxArrear']?.toString(),
      otherTaxArrear: json['otherTaxArrear']?.toString(),
      houseCurrentTax: json['houseCurrentTax']?.toString(),
      waterCurrentTax: json['waterCurrentTax']?.toString(),
      waterTaxInterest: json['waterTaxInterest']?.toString(),
      netPayble: json['netPayble']?.toString(),
      netDemand: json['netDemand']?.toString(),
      otherCurrentTax: json['otherCurrentTax']?.toString(),
      otherTaxInterest: json['otherTaxInterest']?.toString(),
      sewerTaxMonthlyInterest: json['sewerTaxMonthlyInterest']?.toString(),
      billNo: json['billNo']?.toString(),
      waterChargeDiscount: json['waterChargeDiscount']?.toString(),
      waterTaxAdvance: json['waterTaxAdvance']?.toString(),
      otherTaxAdvance: json['otherTaxAdvance']?.toString(),
      waterTaxNetAmount: json['waterTaxNetAmount']?.toString(),
      waterTaxDiscount: json['waterTaxDiscount']?.toString(),
      sewerTaxNetAmount: json['sewerTaxNetAmount']?.toString(),
      billDate: json['billDate']?.toString(),
      waterChargeArrear: json['waterChargeArrear']?.toString(),
      waterChargeNetAmount: json['waterChargeNetAmount']?.toString(),
      houseTaxMonthlyInterest: json['houseTaxMonthlyInterest']?.toString(),
      houseTaxInterest: json['houseTaxInterest']?.toString(),
      sewerCurrentTax: json['sewerCurrentTax']?.toString(),
      houseTaxNetAmount: json['houseTaxNetAmount']?.toString(),
      otherTaxDiscount: json['otherTaxDiscount']?.toString(),
      waterChargeInterest: json['waterChargeInterest']?.toString(),
      waterChargeCurrent: json['waterChargeCurrent']?.toString(),
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

class InitiateTransactionRequest {
  final String mobileTransactionId;
  final String mobileTransactionTimestamp;
  final String billNo;
  final String propertyId;
  final String ulbId;
  final String financialYear;
  final String ownerName;
  final String fatherName;
  final String mobileNo;
  final String propertyTax;
  final String waterTax;
  final String sewerTax;
  final String otherTax;
  final String waterCharge;
  final String netDemand;
  final String netPayable;
  final String totalArv;
  final String userId;
  final String emailId;

  InitiateTransactionRequest({
    required this.mobileTransactionId,
    required this.mobileTransactionTimestamp,
    required this.billNo,
    required this.propertyId,
    required this.ulbId,
    required this.financialYear,
    required this.ownerName,
    required this.fatherName,
    required this.mobileNo,
    required this.propertyTax,
    required this.waterTax,
    required this.sewerTax,
    required this.otherTax,
    required this.waterCharge,
    required this.netDemand,
    required this.netPayable,
    required this.totalArv,
    required this.userId,
    required this.emailId,
  });

  Map<String, dynamic> toJson() => {
    'mobile_transaction_id': mobileTransactionId,
    'mobile_transaction_timestamp': mobileTransactionTimestamp,
    'bill_no': billNo,
    'property_id': propertyId,
    'ulb_id': ulbId,
    'financial_year': financialYear,
    'ownerName': ownerName,
    'fatherName': fatherName,
    'mobileNo': mobileNo,
    'property_tax': propertyTax,
    'water_tax': waterTax,
    'sewer_tax': sewerTax,
    'other_tax': otherTax,
    'water_charge': waterCharge,
    'net_demand': netDemand,
    'net_payable': netPayable,
    'totalArv': totalArv,
    'user_id': userId,
    'email_id': emailId,
  };
}

class CreateTransactionResponse {
  final Transaction? data;
  final String? message;
  final bool? status;

  CreateTransactionResponse({this.data, this.message, this.status});

  factory CreateTransactionResponse.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'];

    return CreateTransactionResponse(
      data: dataJson is Map<String, dynamic>
          ? Transaction.fromJson(dataJson)
          : null,
      message: json['message'],
      status: json['status'] ?? json['success'],
    );
  }
}

class Transaction {
  final String? amount;
  final String? firstname;
  final String? phone;
  final String? furl;
  final String? surl;
  final String? productinfo;
  final String? email;
  final String? key;
  final String? txnid;

  Transaction({
    this.amount,
    this.firstname,
    this.phone,
    this.furl,
    this.surl,
    this.productinfo,
    this.email,
    this.key,
    this.txnid,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    amount: json['amount']?.toString(),
    firstname: json['firstname'],
    phone: json['phone']?.toString(),
    furl: json['furl'],
    surl: json['surl'],
    productinfo: json['productinfo'],
    email: json['email'],
    key: json['key'],
    txnid: json['txnid']?.toString(),
  );
}

class TransactionsByEmailResponse {
  final bool? status;
  final String? message;
  final List<TransactionData>? data;

  TransactionsByEmailResponse({this.status, this.message, this.data});

  factory TransactionsByEmailResponse.fromJson(Map<String, dynamic> json) {
    return TransactionsByEmailResponse(
      status: json['status'],
      message: json['message'],
      data: json['data'] != null
          ? (json['data'] as List).map((i) => TransactionData.fromJson(i)).toList()
          : null,
    );
  }
}

class TransactionData {
  final String? paymentAmount;
  final String? billNo;
  final String? propertyId;
  final String? txnId;
  final String? dateTime;
  final String? financialYear;
  final String? paymentMode;
  final String? bankRefNo;
  final String? transactionStatus;

  TransactionData({
    this.paymentAmount,
    this.billNo,
    this.propertyId,
    this.txnId,
    this.dateTime,
    this.financialYear,
    this.paymentMode,
    this.bankRefNo,
    this.transactionStatus,
  });

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      paymentAmount: json['payment_amount']?.toString(),
      billNo: json['bill_no']?.toString(),
      propertyId: json['property_id']?.toString(),
      txnId: json['txnid']?.toString(),
      dateTime: json['date_time'],
      financialYear: json['financial_year'],
      paymentMode: json['payment_mode'],
      bankRefNo: json['bank_ref_no']?.toString(),
      transactionStatus: json['transaction_status'],
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

class LogoutResponse {
  final bool status;
  final String message;
  final int responseCode;

  LogoutResponse({
    required this.status,
    required this.message,
    required this.responseCode,
  });

  factory LogoutResponse.fromJson(Map<String, dynamic> json) {
    return LogoutResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      responseCode: json['responseCode'] ?? 0,
    );
  }
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
