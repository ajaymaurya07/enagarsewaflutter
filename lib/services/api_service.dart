import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'device_service.dart';
import 'database_service.dart';
import 'integrity_service.dart';
import 'pinned_http_client.dart';
import '../constants/app_constants.dart';
import '../login_screen.dart';

class ApiService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static const String _genericErrorMessage =
      'Something went wrong. Please try again.';
  static const String _networkErrorMessage =
      'Unable to connect right now. Please check your internet connection and try again.';

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

  static bool _isHandlingSessionExpiry = false;

  /// True while a 403/expired-session teardown is replacing the entire
  /// navigator stack with LoginScreen. Other code that also performs a
  /// full-stack navigation (e.g. exiting an assessment/reassessment flow)
  /// should skip its own navigation while this is true, to avoid two
  /// concurrent Navigator stack mutations racing each other.
  static bool get isHandlingSessionExpiry => _isHandlingSessionExpiry;

  static Future<void> _handleSessionExpired() async {
    if (_isHandlingSessionExpiry) {
      // debugPrint('[SessionExpired] Already handling session expiry, skipping duplicate call.');
      return;
    }
    // debugPrint('[SessionExpired] Triggered — tearing down session and navigating to LoginScreen.');
    _isHandlingSessionExpiry = true;
    try {
      await DatabaseService.clearDatabase();
      await StorageService.logout();

      if (navigatorKey.currentState != null) {
        // debugPrint('[SessionExpired] Calling pushAndRemoveUntil(LoginScreen).');
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        // debugPrint('[SessionExpired] navigatorKey.currentState is null — could not navigate.');
      }
    } finally {
      _isHandlingSessionExpiry = false;
      // debugPrint('[SessionExpired] Teardown complete.');
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
          if (refreshResponse.status == true &&
              refreshResponse.data?.accessToken != null) {
            await StorageService.updateAccessToken(
              refreshResponse.data!.accessToken!,
            );
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

  static Future<http.Response> _makeAuthenticatedMultipartRequest(
    Future<http.MultipartRequest> Function(Map<String, String> headers)
        requestFn,
  ) async {
    Future<http.Response> execute(Map<String, String> headers) async {
      final request = await requestFn(headers);
      request.headers.addAll(headers);
      final pinnedClient = await PinnedHttpClient.getInstance();
      final streamedResponse = await pinnedClient
          .send(request)
          .timeout(Duration(seconds: AppConstants.networkTimeout));
      return http.Response.fromStream(streamedResponse);
    }

    var headers = await _getHeaders();
    var response = await execute(headers);

    if (response.statusCode == 403) {
      final refreshTokenStr = await StorageService.getRefreshToken();
      if (refreshTokenStr != null) {
        try {
          final refreshResponse = await refreshToken(refreshTokenStr);
          if (refreshResponse.status == true &&
              refreshResponse.data?.accessToken != null) {
            await StorageService.updateAccessToken(
              refreshResponse.data!.accessToken!,
            );
            headers = await _getHeaders();
            response = await execute(headers);

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

  // Pinned HTTP helpers — all outbound calls go through the certificate-pinned client.
  static Future<http.Response> _get(
    Uri url, {
    Map<String, String>? headers,
  }) =>
      PinnedHttpClient.getInstance()
          .then((c) => c.get(url, headers: headers));

  static Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      PinnedHttpClient.getInstance()
          .then((c) => c.post(url, headers: headers, body: body, encoding: encoding));

  // http.Client's get() doesn't allow a request body, but some backend
  // endpoints here are declared as GET while still expecting a JSON body
  // (e.g. getAssessmentDetails). Build the request manually to support that.
  static Future<http.Response> _getWithBody(
    Uri url, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final client = await PinnedHttpClient.getInstance();
    final request = http.Request('GET', url);
    if (headers != null) request.headers.addAll(headers);
    if (body != null) request.body = body;
    final streamedResponse = await client.send(request);
    return http.Response.fromStream(streamedResponse);
  }

  // ─── Integrity-protected request helper ────────────────────────────────────────────

  /// Executes [requestFn] with an X-Integrity-Token header.
  /// On a 412 response (integrity token expired / invalid) it automatically
  /// refreshes the token via IntegrityService and retries the request once.
  static Future<http.Response> _makeIntegrityProtectedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    String? integrityToken = await IntegrityService.getValidToken();

    // Integrity check failed — do NOT proceed with the payment request.
    if (integrityToken == null) {
      throw Exception(
        'Device integrity check failed. Payment cannot be processed on this device.',
      );
    }

    Future<http.Response> execute(String token) {
      return _makeAuthenticatedRequest((headers) {
        headers['X-Integrity-Token'] = token;
        return requestFn(headers);
      });
    }

    var response = await execute(integrityToken);

    if (_isIntegrityTokenExpired(response)) {
      integrityToken = await IntegrityService.refreshIntegrityToken();

      if (integrityToken == null) {
        throw Exception(
          'Device integrity check failed. Payment cannot be processed on this device.',
        );
      }

      response = await execute(integrityToken);
    }

    return response;
  }

  /// Returns true if the response signals an expired / invalid integrity token
  /// (HTTP 412, or HTTP 200 body with status_code 412).
  static bool _isIntegrityTokenExpired(http.Response response) {
    if (response.statusCode == 412) return true;
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['status_code']?.toString() == '412';
    } catch (_) {
      return false;
    }
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
        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );
      }

      final pinnedClient = await PinnedHttpClient.getInstance();
      final streamedResponse = await pinnedClient.send(request).timeout(
        Duration(seconds: AppConstants.networkTimeout),
      );
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
      throw _userSafeException(e);
    }
  }

  // Fetch Grievance Categories API
  static Future<List<GrievanceCategory>> getGrievanceCategories() async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _get(
              Uri.parse(
                '${AppConstants.baseUrl}api/House_tax/grievanceCategory',
              ),
              headers: headers,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

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
      throw _userSafeException(e);
    }
  }

  // Fetch Property Rebate Types
  static Future<RebateTypeListResponse> getRebateTypeList() async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _get(
              Uri.parse(
                '${AppConstants.baseUrl}api/house_tax/getRebateTypeList',
              ),
              headers: headers,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return RebateTypeListResponse(
            responseCode: decodedData['responseCode'],
            data: (decodedData['data'] as List)
                .map((item) => RebateType.fromJson(item))
                .toList(),
          );
        }
        return RebateTypeListResponse(
          responseCode: decodedData['responseCode'],
          data: const [],
          message: decodedData['message'],
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Fetch Floor Type List for a given floor usage category (RS, RR, MIS, COM)
  static Future<FloorTypeListResponse> getFloorTypeList(String floorUsageId) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse(
                '${AppConstants.baseUrl}api/house_tax/getFloorTypeList',
              ),
              headers: headers,
              body: json.encode({'floorUsageId': floorUsageId}),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return FloorTypeListResponse(
            responseCode: decodedData['responseCode'],
            data: (decodedData['data'] as List)
                .map((item) => FloorType.fromJson(item))
                .toList(),
          );
        }
        return FloorTypeListResponse(
          responseCode: decodedData['responseCode'],
          data: const [],
          message: decodedData['message'],
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Fetch Property Type Multiplier for a given floor type id
  static Future<double> getPropertyTypeMultiplier(int floorType) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse(
                '${AppConstants.baseUrl}api/house_tax/getPropertyTypeMultiplier',
              ),
              headers: headers,
              body: json.encode({'floorType': floorType}),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return double.tryParse(decodedData['data'].toString()) ?? 0.0;
        }
        throw Exception(
          decodedData['message'] ?? 'Failed to load property type multiplier',
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Submit Property Tax Assessment - Step 1 (property/location/owner details)
  static Future<AssessmentStep1Response> submitAssessmentStep1({
    required int zoneId,
    required int wardId,
    required int mohallaId,
    required String oldPropertyId,
    required int totalArea,
    required String ownerName,
    required String fatherHusbandName,
    required String email,
    required String mobile,
    required String houseNo,
    required String address,
    required String landmark,
    required String popularPropertyName,
  }) async {
    final requestBody = {
      'zoneId': zoneId,
      'wardId': wardId,
      'mohallaId': mohallaId,
      'oldPropertyId': oldPropertyId,
      'totalArea': totalArea,
      'ownerName': ownerName,
      'fatherHusbandName': fatherHusbandName,
      'email': email,
      'mobile': mobile,
      'houseNo': houseNo,
      'address': address,
      'landmark': landmark,
      'popularPropertyName': popularPropertyName,
    };
    // debugPrint('[AssessmentStep1] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[AssessmentStep1] Authorization -> ${headers['Authorization']}');
          // debugPrint('[AssessmentStep1] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse(
                  '${AppConstants.baseUrl}api/house_tax/assessmentSubmitS1',
                ),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[AssessmentStep1] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return AssessmentStep1Response.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[AssessmentStep1] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Submit Property Tax Assessment - Step 2 (road location / property type / property uses)
  static Future<AssessmentStep2Response> submitAssessmentStep2({
    required String ackNo,
    required String fileNo,
    required int roadLocationId,
    required int propertyTypeId,
    required int propertyUseasId,
  }) async {
    final requestBody = {
      'ackNo': ackNo,
      'fileNo': fileNo,
      'roadLocationId': roadLocationId,
      'propertyTypeId': propertyTypeId,
      'propertyUseasId': propertyUseasId,
    };
    // debugPrint('[AssessmentStep2] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[AssessmentStep2] Authorization -> ${headers['Authorization']}');
          // debugPrint('[AssessmentStep2] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse(
                  '${AppConstants.baseUrl}api/house_tax/assessmentSubmitS2',
                ),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[AssessmentStep2] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return AssessmentStep2Response.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[AssessmentStep2] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Step 3A: Save Floor Details
  static Future<SaveFloorResponse> saveFloorDetails({
    required String ackNo,
    required int floorNumber,
    required String floorUsageCode,
    required int floorTypeId,
    required int constructionTypeId,
    required String constructionDate,
    required int carpetArea,
    required int roomsPorchArea,
    required int kitchenBalconyArea,
    required int garageArea,
    required String areaEnterMode,
  }) async {
    final requestBody = {
      'ackNo': ackNo,
      'floorNumber': floorNumber,
      'floorUsageCode': floorUsageCode,
      'floorTypeId': floorTypeId,
      'constructionTypeId': constructionTypeId,
      'constructionDate': constructionDate,
      'carpetArea': carpetArea,
      'roomsPorchArea': roomsPorchArea,
      'kitchenBalconyArea': kitchenBalconyArea,
      'garageArea': garageArea,
      'areaEnterMode': areaEnterMode,
    };
    // debugPrint('[SaveFloorDetails] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[SaveFloorDetails] Authorization -> ${headers['Authorization']}');
          // debugPrint('[SaveFloorDetails] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse(
                  '${AppConstants.baseUrl}api/house_tax/assessmentSaveFloor',
                ),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[SaveFloorDetails] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return SaveFloorResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[SaveFloorDetails] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Step 3B: Delete Floor Details
  static Future<DeleteFloorResponse> deleteFloorDetails({
    required String ackNo,
    required int floorNumber,
  }) async {
    final requestBody = {
      'ackNo': ackNo,
      'floorNumber': floorNumber,
    };
    // debugPrint('[DeleteFloorDetails] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[DeleteFloorDetails] Authorization -> ${headers['Authorization']}');
          // debugPrint('[DeleteFloorDetails] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse(
                  '${AppConstants.baseUrl}api/house_tax/assessmentDeleteFloor',
                ),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[DeleteFloorDetails] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return DeleteFloorResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[DeleteFloorDetails] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Step 3C: Finalize Floor Details and Rebate Information
  static Future<AssessmentStep3Response> submitAssessmentStep3({
    required String ackNo,
    required String rebateFinyear,
    required String isRebateClaimed,
    required int? rebateTypeId,
  }) async {
    final requestBody = {
      'ackNo': ackNo,
      'rebateFinyear': rebateFinyear,
      'isRebateClaimed': isRebateClaimed,
      'rebateTypeId': rebateTypeId,
    };
    // debugPrint('[AssessmentStep3] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[AssessmentStep3] Authorization -> ${headers['Authorization']}');
          // debugPrint('[AssessmentStep3] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse(
                  '${AppConstants.baseUrl}api/house_tax/assessmentSubmitS3',
                ),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[AssessmentStep3] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return AssessmentStep3Response.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[AssessmentStep3] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - New Assessment - Step 4: Finalize Assessment (document upload)
  static Future<DeleteFloorResponse> finalizeAssessment({
    required String ackNo,
    required File applicationFile,
  }) async {
    // debugPrint('[AssessmentStep4] Request -> ackNo=$ackNo, file=${applicationFile.path}');

    try {
      final response = await _makeAuthenticatedMultipartRequest((headers) async {
        // debugPrint('[AssessmentStep4] Authorization -> ${headers['Authorization']}');
        // debugPrint('[AssessmentStep4] Device Id -> ${headers['X-Device-Id']}');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConstants.baseUrl}api/house_tax/assessmentSubmitS4'),
        );
        request.fields['ackNo'] = ackNo;
        request.files.add(
          await http.MultipartFile.fromPath('applicationFile', applicationFile.path),
        );
        return request;
      });

      // debugPrint(
        // '[AssessmentStep4] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return DeleteFloorResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[AssessmentStep4] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - Pre-check: Fetch Existing Assessment Details
  static Future<ReassessmentGetS1Response> getReassessmentDetails({
    required String propertyId,
  }) async {
    final requestBody = {'propertyId': propertyId};
    // debugPrint('[ReassessmentGetS1] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[ReassessmentGetS1] Authorization -> ${headers['Authorization']}');
          // debugPrint('[ReassessmentGetS1] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse('${AppConstants.baseUrl}api/house_tax/reassessmentGetS1'),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[ReassessmentGetS1] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return ReassessmentGetS1Response.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentGetS1] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - List: Fetch all reassessments for the user
  static Future<ReassessmentListResponse> getReassessmentList() async {
    // debugPrint('[ReassessmentList] Request -> getReassessmentList');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[ReassessmentList] Authorization -> ${headers['Authorization']}');
          // debugPrint('[ReassessmentList] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse('${AppConstants.baseUrl}api/house_tax/getReassessmentList'),
                headers: headers,
                body: json.encode({}),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[ReassessmentList] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return ReassessmentListResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentList] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - Full Details: Fetch complete
  // details (floors + tax breakdown) for a completed reassessment by Ack No.
  static Future<ReassessmentFullDetailsResponse> getReassessmentFullDetails({
    required String ackNo,
  }) async {
    final requestBody = {'ackNo': ackNo};
    // debugPrint('[ReassessmentFullDetails] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse('${AppConstants.baseUrl}api/house_tax/getReassessmentDetails'),
              headers: headers,
              body: json.encode(requestBody),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      // debugPrint(
        // '[ReassessmentFullDetails] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return ReassessmentFullDetailsResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentFullDetails] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment (fresh, not reassessment) - List: Fetch all
  // assessments for the user. Response shape is identical to
  // getReassessmentList, so the same model classes are reused.
  static Future<ReassessmentListResponse> getAssessmentList() async {
    // debugPrint('[AssessmentList] Request -> getAssessmentList');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[AssessmentList] Authorization -> ${headers['Authorization']}');
          // debugPrint('[AssessmentList] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse('${AppConstants.baseUrl}api/House_tax/getAssessmentList'),
                headers: headers,
                body: json.encode({}),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[AssessmentList] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return ReassessmentListResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[AssessmentList] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment (fresh, not reassessment) - Full Details: Fetch
  // complete details (floors + tax breakdown) for an assessment by Ack No.
  // Declared as GET by the backend but still expects a JSON body.
  static Future<ReassessmentFullDetailsResponse> getAssessmentFullDetails({
    required String ackNo,
  }) async {
    final requestBody = {'ackNo': ackNo};
    // debugPrint('[AssessmentFullDetails] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _getWithBody(
              Uri.parse('${AppConstants.baseUrl}api/House_tax/getAssessmentDetails'),
              headers: headers,
              body: json.encode(requestBody),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      // debugPrint(
        // '[AssessmentFullDetails] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return ReassessmentFullDetailsResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[AssessmentFullDetails] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - Step 1: Initialize Reassessment
  static Future<ReassessmentStep1Response> initializeReassessment({
    required String propertyId,
    required String ackNo,
  }) async {
    final requestBody = {'propertyId': propertyId, 'ackNo': ackNo};
    // debugPrint('[ReassessmentStep1] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[ReassessmentStep1] Authorization -> ${headers['Authorization']}');
          // debugPrint('[ReassessmentStep1] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse('${AppConstants.baseUrl}api/house_tax/reassessmentSubmitS1'),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[ReassessmentStep1] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return ReassessmentStep1Response.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentStep1] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - Step 2: Fetch Floor Configuration Details
  static Future<AssessmentStep2Response> fetchReassessmentFloorConfig({
    required String propertyId,
    required String ackNo,
    required String fileNo,
  }) async {
    final requestBody = {
      'propertyId': propertyId,
      'ackNo': ackNo,
      'fileNo': fileNo,
    };
    // debugPrint('[ReassessmentStep2] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[ReassessmentStep2] Authorization -> ${headers['Authorization']}');
          // debugPrint('[ReassessmentStep2] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse('${AppConstants.baseUrl}api/house_tax/reassessmentFetchFloorConfig'),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[ReassessmentStep2] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return AssessmentStep2Response.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentStep2] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - Step 3A: Save Floor Details
  static Future<SaveFloorResponse> saveReassessmentFloor({
    required String ackNo,
    required int floorNumber,
    required String floorUsageCode,
    required int floorTypeId,
    required int constructionTypeId,
    required String constructionDate,
    required int carpetArea,
    required int roomsPorchArea,
    required int kitchenBalconyArea,
    required int garageArea,
    required String areaEnterMode,
  }) async {
    final requestBody = {
      'ackNo': ackNo,
      'floorNumber': floorNumber,
      'floorUsageCode': floorUsageCode,
      'floorTypeId': floorTypeId,
      'constructionTypeId': constructionTypeId,
      'constructionDate': constructionDate,
      'carpetArea': carpetArea,
      'roomsPorchArea': roomsPorchArea,
      'kitchenBalconyArea': kitchenBalconyArea,
      'garageArea': garageArea,
      'areaEnterMode': areaEnterMode,
    };
    // debugPrint('[ReassessmentSaveFloor] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[ReassessmentSaveFloor] Authorization -> ${headers['Authorization']}');
          // debugPrint('[ReassessmentSaveFloor] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse('${AppConstants.baseUrl}api/house_tax/reassessmentSaveFloor'),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[ReassessmentSaveFloor] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return SaveFloorResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentSaveFloor] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - Step 3B: Delete Floor Details
  static Future<DeleteFloorResponse> deleteReassessmentFloor({
    required String ackNo,
    required int floorNumber,
  }) async {
    final requestBody = {'ackNo': ackNo, 'floorNumber': floorNumber};
    // debugPrint('[ReassessmentDeleteFloor] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[ReassessmentDeleteFloor] Authorization -> ${headers['Authorization']}');
          // debugPrint('[ReassessmentDeleteFloor] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse('${AppConstants.baseUrl}api/house_tax/reassessmentDeleteFloor'),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[ReassessmentDeleteFloor] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return DeleteFloorResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentDeleteFloor] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - Step 3C: Finalize All Floor details and rebate details
  static Future<AssessmentStep3Response> submitReassessmentStep3({
    required String ackNo,
    required String propertyId,
    required String rebateFinyear,
    required String isRebateClaimed,
    required int? rebateTypeId,
  }) async {
    final requestBody = {
      'ackNo': ackNo,
      'propertyId': propertyId,
      'rebateFinyear': rebateFinyear,
      'isRebateClaimed': isRebateClaimed,
      'rebateTypeId': rebateTypeId,
    };
    // debugPrint('[ReassessmentStep3] Request -> ${json.encode(requestBody)}');

    try {
      final response = await _makeAuthenticatedRequest(
        (headers) {
          // debugPrint('[ReassessmentStep3] Authorization -> ${headers['Authorization']}');
          // debugPrint('[ReassessmentStep3] Device Id -> ${headers['X-Device-Id']}');
          return _post(
                Uri.parse('${AppConstants.baseUrl}api/house_tax/reassessmentSubmitS3'),
                headers: headers,
                body: json.encode(requestBody),
              )
              .timeout(Duration(seconds: AppConstants.networkTimeout));
        },
      );

      // debugPrint(
        // '[ReassessmentStep3] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return AssessmentStep3Response.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentStep3] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Property Assessment - Reassessment - Step 4: Finalize Reassessment (document upload)
  static Future<DeleteFloorResponse> finalizeReassessment({
    required String ackNo,
    required File applicationFile,
  }) async {
    // debugPrint('[ReassessmentStep4] Request -> ackNo=$ackNo, file=${applicationFile.path}');

    try {
      final response = await _makeAuthenticatedMultipartRequest((headers) async {
        // debugPrint('[ReassessmentStep4] Authorization -> ${headers['Authorization']}');
        // debugPrint('[ReassessmentStep4] Device Id -> ${headers['X-Device-Id']}');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConstants.baseUrl}api/house_tax/reassessmentSubmitS4'),
        );
        request.fields['ackNo'] = ackNo;
        request.files.add(
          await http.MultipartFile.fromPath('applicationFile', applicationFile.path),
        );
        return request;
      });

      // debugPrint(
        // '[ReassessmentStep4] Response (${response.statusCode}) -> ${response.body}',
      // );

      if (response.statusCode == 200) {
        return DeleteFloorResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[ReassessmentStep4] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Fetch ULB Data
  static Future<List<UlbData>> getUlbData() async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _get(
              Uri.parse('${AppConstants.baseUrl}api/House_tax/ulbdata'),
              headers: headers,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

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
      throw _userSafeException(e);
    }
  }

  // Fetch Zone Data
  static Future<List<ZoneData>> getZoneData(String ulbId) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _get(
              Uri.parse('${AppConstants.baseUrl}api/House_tax/zonedata/$ulbId'),
              headers: headers,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

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
      throw _userSafeException(e);
    }
  }

  // Fetch ULB Language (English / Krutidev) configured for the logged-in
  // citizen's ULB. The ULB ID is resolved server-side from the auth token
  // and echoed back inside the `message` string, e.g.
  // "ULB Language fetched successfully for ULB ID :- 997".
  static Future<UlbLanguageResponse> getUlbLanguage() async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _get(
              Uri.parse('${AppConstants.baseUrl}api/House_tax/getUlbLanguage'),
              headers: headers,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        return UlbLanguageResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load ULB language: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Fetch Ward Data
  static Future<List<WardData>> getWardData(String ulbId, String zoneId) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _get(
              Uri.parse(
                '${AppConstants.baseUrl}api/House_tax/warddata/$ulbId/$zoneId',
              ),
              headers: headers,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

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
      throw _userSafeException(e);
    }
  }

  // Fetch Mohalla Data
  static Future<List<MohallaData>> getMohallaData(
    String ulbId,
    String zoneId,
    String wardId,
  ) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _get(
              Uri.parse(
                '${AppConstants.baseUrl}api/House_tax/mohalladata/$ulbId/$zoneId/$wardId',
              ),
              headers: headers,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

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
      throw _userSafeException(e);
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
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
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
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

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
      throw _userSafeException(e);
    }
  }

  // Fetch Property Details API
  static Future<PropertyDetailsResponse> getPropertyDetails(
    String propertyId,
  ) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse('${AppConstants.baseUrl}api/House_tax/propertydetails'),
              headers: headers,
              body: jsonEncode({'propertyId': propertyId}),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        return PropertyDetailsResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
          'Failed to load property details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Forgot Password - Send OTP
  static Future<ForgotPasswordResponse> forgotPasswordSendOtp(
    String username,
  ) async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final response = await _post(
            Uri.parse(
              '${AppConstants.baseUrl}api/house_tax/forgot_password_request',
            ),
            headers: headers,
            body: jsonEncode({'username': username}),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return ForgotPasswordResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to send OTP: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw _userSafeException(e);
    }
  }

  // Forgot Password - Verify OTP & Reset Password
  static Future<VerifyForgotPasswordOtpResponse> resetPassword({
    required String username,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final hashedPassword = sha512
          .convert(utf8.encode(newPassword))
          .toString();

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final response = await _post(
            Uri.parse(
              '${AppConstants.baseUrl}api/house_tax/verify_forgot_password_otp',
            ),
            headers: headers,
            body: jsonEncode({
              'username': username,
              'otp': otp,
              'new_password': hashedPassword,
              'confirm_password': hashedPassword,
            }),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return VerifyForgotPasswordOtpResponse.fromJson(
          jsonDecode(response.body),
        );
      } else {
        throw Exception('Password reset failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw _userSafeException(e);
    }
  }

  // Send OTP API
  static Future<SendOtpResponse> sendOtp(
    String mobileNo,
    String propertyId,
  ) async {
    // debugPrint('[SendOtp] Request -> mobileNo=$mobileNo, propertyId=$propertyId');
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse('${AppConstants.baseUrl}api/house_tax/sendOtp'),
              headers: headers,
              body: jsonEncode({
                'mobileNo': mobileNo,
                'propertyId': propertyId,
              }),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      // debugPrint('[SendOtp] Response (${response.statusCode}) -> ${response.body}');

      if (response.statusCode == 200) {
        return SendOtpResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to send OTP: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[SendOtp] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Verify OTP API
  static Future<VerifyOtpResponse> verifyOtp(
    String mobileNo,
    String otp,
  ) async {
    // debugPrint('[VerifyOtp] Request -> mobileNo=$mobileNo');
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse('${AppConstants.baseUrl}api/house_tax/verifyOtp'),
              headers: headers,
              body: jsonEncode({'mobileNo': mobileNo, 'otp': otp}),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      // debugPrint('[VerifyOtp] Response (${response.statusCode}) -> ${response.body}');

      if (response.statusCode == 200) {
        return VerifyOtpResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('OTP verification failed: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('[VerifyOtp] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Get ARV Change History API
  static Future<ArvChangeHistoryResponse> getArvChangeHistory(
    String propertyId,
  ) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse(
                '${AppConstants.baseUrl}api/house_tax/getArvChangeHistory',
              ),
              headers: headers,
              body: jsonEncode({'propertyId': propertyId}),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        return ArvChangeHistoryResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch ARV history: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Create Transaction API
  static Future<CreateTransactionResponse> initiateTransaction(
    InitiateTransactionRequest request,
  ) async {
    // debugPrint('[InitiateTransaction] Request -> ${jsonEncode(request.toJson())}');
    try {
      final response = await _makeIntegrityProtectedRequest(
        (headers) => _post(
              Uri.parse(
                '${AppConstants.baseUrl}api/Payment/create_transaction',
              ),
              headers: headers,
              body: jsonEncode(request.toJson()),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      // debugPrint('[InitiateTransaction] Response (${response.statusCode}) -> ${response.body}');

      if (response.statusCode == 200) {
        return CreateTransactionResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
          'Transaction initiation failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      // debugPrint('[InitiateTransaction] Error -> $e');
      throw _userSafeException(e);
    }
  }

  // Create SBI Transaction API
  static Future<CreateSbiTransactionResponse> createSbiTransaction(
    InitiateTransactionRequest request,
  ) async {
    try {
      final response = await _makeIntegrityProtectedRequest(
        (headers) => _post(
              Uri.parse(
                '${AppConstants.baseUrl}api/Payment/create_sbi_transaction',
              ),
              headers: headers,
              body: jsonEncode(request.toJson()),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        return CreateSbiTransactionResponse.fromJson(
          jsonDecode(response.body),
        );
      } else {
        throw Exception(
          'SBI transaction creation failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Get PayU Transaction Details API (cross-verify after SDK callback)
  static Future<PayUTransactionDetailsResponse> getTransactionDetails(
    String mobileTransactionId,
  ) async {
    try {
      final authHeaders = await _getHeaders();
      final deviceId = await DeviceService.getDeviceId();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}api/payment/getTransactionDetails'),
      )
        ..fields['mobile_transaction_id'] = mobileTransactionId
        ..headers.addAll({
          'Authorization': authHeaders['Authorization'] ?? '',
          'X-App-Version': authHeaders['X-App-Version'] ?? '',
          'X-Device-Id': deviceId,
        });

      final client = await PinnedHttpClient.getInstance();
      final streamed = await client
          .send(request)
          .timeout(Duration(seconds: AppConstants.networkTimeout));
      final response = await http.Response.fromStream(streamed);


      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          throw Exception('Empty response from server');
        }
        return PayUTransactionDetailsResponse.fromJson(jsonDecode(body));
      } else {
        throw Exception(
          'Failed to fetch transaction details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Get SBI Transaction Details API
  static Future<SbiTransactionDetailsResponse> getSbiTransactionDetails(
    String mobileTransactionId,
  ) async {
    try {
      final authHeaders = await _getHeaders();
      final deviceId = await DeviceService.getDeviceId();
      // Server expects multipart/form-data (as confirmed via Postman)
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}api/Payment/getSbiTransactionDetails'),
      )
        ..fields['mobile_transaction_id'] = mobileTransactionId
        ..headers.addAll({
          'Authorization': authHeaders['Authorization'] ?? '',
          'X-App-Version': authHeaders['X-App-Version'] ?? '',
          'X-Device-Id': deviceId,
        });

      final client = await PinnedHttpClient.getInstance();
      final streamed = await client
          .send(request)
          .timeout(Duration(seconds: AppConstants.networkTimeout));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return SbiTransactionDetailsResponse.fromJson(
          jsonDecode(response.body),
        );
      } else {
        throw Exception(
          'Failed to fetch SBI transaction details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Generate hash for PayU (form-urlencoded)
  static Future<HashResponse> generateHash(
    String hashName,
    String hashString,
  ) async {
    try {
      final response = await _makeAuthenticatedRequest((headers) {
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
        final body =
            'hashName=${Uri.encodeComponent(hashName)}&hashString=${Uri.encodeComponent(hashString)}';
        return _post(
              Uri.parse('${AppConstants.baseUrl}api/Payment/generate_hash'),
              headers: headers,
              body: body,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout));
      });

      if (response.statusCode == 200) {
        return HashResponse.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 403) {
        await _handleSessionExpired();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to generate hash: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Fetch Transactions By Email API
  static Future<TransactionsByEmailResponse> getTransactionsByEmail(
    String emailId,
  ) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse(
                '${AppConstants.baseUrl}api/payment/get_transactions_by_email',
              ),
              headers: headers,
              body: jsonEncode({'email_id': emailId}),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        return TransactionsByEmailResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Get Grievance Details API
  static Future<GrievanceDetailsResponse> getGrievanceDetails(
    String emailId,
  ) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse(
                '${AppConstants.baseUrl}api/house_tax/getGrievanceDetails',
              ),
              headers: headers,
              body: jsonEncode({'email_id': emailId}),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        return GrievanceDetailsResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
          'Failed to load grievance details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Get Grievance Status API
  static Future<GrievanceStatusResponse> getGrievanceStatus(
    String grievanceNo,
  ) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse(
                '${AppConstants.baseUrl}api/house_tax/getGrievanceStatus',
              ),
              headers: headers,
              body: jsonEncode({'grievanceNo': grievanceNo}),
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        return GrievanceStatusResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
          'Failed to load grievance status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Secure Login Flow
  static Future<LoginResponse> secureLogin(
    String username,
    String password,
    String deviceId,
  ) async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final challengeResponse = await _post(
            Uri.parse('${AppConstants.baseUrl}api/house_tax/get_challenge'),
            headers: headers,
            body: jsonEncode({'username': username, 'device_id': deviceId}),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      // debugPrint(
        // '[Login] get_challenge response (${challengeResponse.statusCode}) -> ${challengeResponse.body}',
      // );

      if (challengeResponse.statusCode != 200) {
        throw Exception(
          'Failed to get challenge: ${challengeResponse.statusCode}',
        );
      }

      final challengeData = jsonDecode(challengeResponse.body);
      if (challengeData['status'] != true) {
        throw Exception(
          challengeData['message'] ?? 'Challenge generation failed',
        );
      }

      final String challengeId = challengeData['data']['challenge_id'];
      final String challenge = challengeData['data']['challenge'];
      final String timestamp = challengeData['data']['timestamp'].toString();

      final hashedPassword = sha512.convert(utf8.encode(password)).toString();
      final String nonce = _generateNonce(16);
      final String inputString = hashedPassword + challenge + timestamp + nonce;
      final String finalHash = sha512
          .convert(utf8.encode(inputString))
          .toString();

      final loginResponse = await _post(
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
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      // debugPrint(
        // '[Login] login response (${loginResponse.statusCode}) -> ${loginResponse.body}',
      // );

      if (loginResponse.statusCode == 200) {
        final loginData = LoginResponse.fromJson(
          jsonDecode(loginResponse.body),
        );
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

  // Fetch Signup Captcha
  static Future<CaptchaResponse> getSignupCaptcha() async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final response = await _get(
            Uri.parse('${AppConstants.baseUrl}api/Signup_citizen/captcha'),
            headers: headers,
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return CaptchaResponse.fromJson(decodedData['data']);
        }
        throw Exception(decodedData['message'] ?? 'Failed to load captcha');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Fetch Signup Cities by ULB Type
  static Future<List<SignupCity>> getSignupCities(String ulbTypeCode) async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final response = await _get(
            Uri.parse(
                '${AppConstants.baseUrl}api/Signup_citizen/cities?type=$ulbTypeCode'),
            headers: headers,
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          return (decodedData['data'] as List)
              .map((item) => SignupCity.fromJson(item))
              .toList();
        }
        throw Exception(decodedData['message'] ?? 'Failed to load cities');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Register Citizen API
  static Future<CitizenRegisterResponse> registerCitizen({
    required String name,
    required String fatherHusbandName,
    required String address1,
    required String address2,
    required String ulbType,
    required int city,
    required String mobileNo,
    required String email,
    required String encryptedPassword,
    required String encryptedConfirmPassword,
    required String captchaId,
    required String captcha,
  }) async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final requestBody = {
        'name': name,
        'fatherHusbandName': fatherHusbandName,
        'address1': address1,
        'address2': address2,
        'ulbType': ulbType,
        'city': city,
        'mobileNo': mobileNo,
        'email': email,
        'encryptedPassword': encryptedPassword,
        'encryptedConfirmPassword': encryptedConfirmPassword,
        'captchaId': captchaId,
        'captcha': captcha,
      };

      final response = await _post(
            Uri.parse('${AppConstants.baseUrl}api/Signup_citizen/register'),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return CitizenRegisterResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Registration failed: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Resend Signup OTP API
  static Future<ResendSignupOtpResponse> resendSignupOtp({
    required String mobileNo,
    required String captchaId,
    required String captcha,
  }) async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final response = await _post(
            Uri.parse('${AppConstants.baseUrl}api/Signup_citizen/resend_otp'),
            headers: headers,
            body: jsonEncode({
              'mobileNo': mobileNo,
              'captchaId': captchaId,
              'captcha': captcha,
            }),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return ResendSignupOtpResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Resend OTP failed: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Verify Citizen OTP (Mobile)
  static Future<CitizenVerifyOtpResponse> verifyCitizenOtp({
    required String mobileNo,
    required String otp,
  }) async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final response = await _post(
            Uri.parse('${AppConstants.baseUrl}api/Signup_citizen/verify_otp'),
            headers: headers,
            body: jsonEncode({'mobileNo': mobileNo, 'otp': otp}),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return CitizenVerifyOtpResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('OTP verification failed: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Sign Up API
  static Future<SignUpResponse> signUp({
    required String name,
    required String mobileNo,
    required String email,
    required String password,
  }) async {
    try {
      final hashedPassword = sha512.convert(utf8.encode(password)).toString();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final response = await _post(
            Uri.parse('${AppConstants.baseUrl}api/house_tax/signup'),
            headers: headers,
            body: jsonEncode({
              'name': name,
              'mobile_no': mobileNo,
              'email': email,
              'password': hashedPassword,
            }),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return SignUpResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Sign up failed: \${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Verify OTP Email API
  static Future<VerifyOtpMailResponse> verifyOtpEmail({
    required String email,
    required String otp,
  }) async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': AppConstants.apiVersion,
      };

      final response = await _post(
            Uri.parse('${AppConstants.baseUrl}api/house_tax/verifyOtpEmail'),
            headers: headers,
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return VerifyOtpMailResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('OTP verification failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw _userSafeException(e);
    }
  }

  // Logout API
  static Future<LogoutResponse> logout() async {
    try {
      final response = await _makeAuthenticatedRequest(
        (headers) => _post(
              Uri.parse('${AppConstants.baseUrl}api/house_tax/logout'),
              headers: headers,
            )
            .timeout(Duration(seconds: AppConstants.networkTimeout)),
      );

      if (response.statusCode == 200) {
        return LogoutResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Logout failed: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  // Refresh Token API
  static Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    try {
      final response = await _post(
            Uri.parse('${AppConstants.baseUrl}api/house_tax/refreshToken'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-App-Version': AppConstants.apiVersion,
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(Duration(seconds: AppConstants.networkTimeout));

      if (response.statusCode == 200) {
        return RefreshTokenResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw _userSafeException(e);
    }
  }

  static String getUserFriendlyErrorMessage(
    Object error, {
    String fallbackMessage = _genericErrorMessage,
  }) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return _networkErrorMessage;
    }

    final message = _extractErrorMessage(error);
    if (message.isEmpty) {
      return fallbackMessage;
    }

    if (_isTechnicalErrorMessage(message)) {
      return fallbackMessage;
    }

    return message;
  }

  static Exception _userSafeException(
    Object error, {
    String fallbackMessage = _genericErrorMessage,
  }) {
    return Exception(
      getUserFriendlyErrorMessage(
        error,
        fallbackMessage: fallbackMessage,
      ),
    );
  }

  static String _extractErrorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  static bool _isTechnicalErrorMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.startsWith('connection error:') ||
        normalized.startsWith('server error:') ||
        normalized.startsWith('login api error:') ||
        normalized.startsWith('failed to get challenge:') ||
        normalized.startsWith('failed to load property details:') ||
        normalized.startsWith('transaction initiation failed:') ||
        normalized.startsWith('failed to generate hash:') ||
        normalized.startsWith('sign up failed:') ||
        normalized.startsWith('otp verification failed:') ||
        normalized.startsWith('password reset failed:') ||
        normalized.contains('socketexception') ||
        normalized.contains('clientexception') ||
        normalized.contains('formatexception') ||
        normalized.contains('xmlhttprequest error') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection closed before full header was received') ||
        (normalized.contains('type ') &&
            normalized.contains(' is not a subtype')) ||
        message.contains(r'${') ||
        RegExp(r':\s*\d{3}\b').hasMatch(message);
  }

  static String _generateNonce(int length) {
    final Random secureRandom = Random.secure();
    const chars = '0123456789abcdef';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(secureRandom.nextInt(chars.length)),
      ),
    );
  }
}

// --- Models ---

class SaveGrievanceResponse {
  final bool success;
  final int responseCode;
  final String message;
  // The grievance ID (e.g. "PG14452552"), or null when the API returns no
  // data (an empty list `[]` on failure cases).
  final String? data;

  SaveGrievanceResponse({
    required this.success,
    required this.responseCode,
    required this.message,
    this.data,
  });

  factory SaveGrievanceResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return SaveGrievanceResponse(
      success: json['success'] ?? false,
      responseCode: json['responseCode'] ?? 0,
      message: json['message'] ?? '',
      data: rawData is String && rawData.isNotEmpty ? rawData : null,
    );
  }
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

class RebateType {
  final int? rebateId;
  final String? rebateName;
  final num? rebatePercentage;

  RebateType({this.rebateId, this.rebateName, this.rebatePercentage});

  factory RebateType.fromJson(Map<String, dynamic> json) {
    return RebateType(
      rebateId: json['rebateId'],
      rebateName: json['rebateName'],
      rebatePercentage: json['rebatePercentage'],
    );
  }
}

class FloorType {
  final int? id;
  final String? name;

  FloorType({this.id, this.name});

  factory FloorType.fromJson(Map<String, dynamic> json) {
    return FloorType(
      id: json['id'],
      name: json['name'],
    );
  }
}

class RebateTypeListResponse {
  final int? responseCode;
  final List<RebateType> data;
  final String? message;

  RebateTypeListResponse({this.responseCode, this.data = const [], this.message});
}

class FloorTypeListResponse {
  final int? responseCode;
  final List<FloorType> data;
  final String? message;

  FloorTypeListResponse({this.responseCode, this.data = const [], this.message});
}

class AssessmentStep1Response {
  final bool? success;
  final String? message;
  final int? responseCode;
  final AssessmentStep1Data? data;

  AssessmentStep1Response({
    this.success,
    this.message,
    this.responseCode,
    this.data,
  });

  factory AssessmentStep1Response.fromJson(Map<String, dynamic> json) {
    return AssessmentStep1Response(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null
          ? AssessmentStep1Data.fromJson(json['data'])
          : null,
    );
  }
}

class AssessmentStep1Data {
  final String? ulbId;
  final String? zoneId;
  final String? wardId;
  final String? mohallaId;
  final String? oldPropertyId;
  final String? totalArea;
  final String? ownerName;
  final String? fatherHusbandName;
  final String? email;
  final String? mobile;
  final String? houseNo;
  final String? address;
  final String? landmark;
  final String? popularPropertyName;
  final String? zoneName;
  final String? wardName;
  final String? mohallaName;
  final String? ackNo;
  final String? assessmentDate;
  final Map<String, String> propertyTypeList;
  final Map<String, String> roadLocationList;
  final Map<String, String> propertyUsesList;

  AssessmentStep1Data({
    this.ulbId,
    this.zoneId,
    this.wardId,
    this.mohallaId,
    this.oldPropertyId,
    this.totalArea,
    this.ownerName,
    this.fatherHusbandName,
    this.email,
    this.mobile,
    this.houseNo,
    this.address,
    this.landmark,
    this.popularPropertyName,
    this.zoneName,
    this.wardName,
    this.mohallaName,
    this.ackNo,
    this.assessmentDate,
    this.propertyTypeList = const {},
    this.roadLocationList = const {},
    this.propertyUsesList = const {},
  });

  static Map<String, String> _toStringMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  factory AssessmentStep1Data.fromJson(Map<String, dynamic> json) {
    return AssessmentStep1Data(
      ulbId: json['ulbId']?.toString(),
      zoneId: json['zoneId']?.toString(),
      wardId: json['wardId']?.toString(),
      mohallaId: json['mohallaId']?.toString(),
      oldPropertyId: json['oldPropertyId']?.toString(),
      totalArea: json['totalArea']?.toString(),
      ownerName: json['ownerName'],
      fatherHusbandName: json['fatherHusbandName'],
      email: json['email'],
      mobile: json['mobile']?.toString(),
      houseNo: json['houseNo']?.toString(),
      address: json['address'],
      landmark: json['landmark'],
      popularPropertyName: json['popularPropertyName'],
      zoneName: json['zoneName'],
      wardName: json['wardName'],
      mohallaName: json['mohallaName'],
      ackNo: json['ackNo'],
      assessmentDate: json['assessmentDate'],
      propertyTypeList: _toStringMap(json['propertyTypeList']),
      roadLocationList: _toStringMap(json['roadLocationList']),
      propertyUsesList: _toStringMap(json['propertyUseasList']),
    );
  }
}

class AssessmentStep2Response {
  final bool? success;
  final String? message;
  final int? responseCode;
  final AssessmentStep2Data? data;

  AssessmentStep2Response({
    this.success,
    this.message,
    this.responseCode,
    this.data,
  });

  factory AssessmentStep2Response.fromJson(Map<String, dynamic> json) {
    return AssessmentStep2Response(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null
          ? AssessmentStep2Data.fromJson(json['data'])
          : null,
    );
  }
}

class AssessmentStep2Data {
  final String? propertyId;
  final String? ackNo;
  final Map<String, String> floorNoList;
  final Map<String, String> floorUsageList;
  final Map<String, String> constructionTypeList;

  AssessmentStep2Data({
    this.propertyId,
    this.ackNo,
    this.floorNoList = const {},
    this.floorUsageList = const {},
    this.constructionTypeList = const {},
  });

  factory AssessmentStep2Data.fromJson(Map<String, dynamic> json) {
    return AssessmentStep2Data(
      propertyId: json['propertyId'],
      ackNo: json['ackNo'],
      floorNoList: AssessmentStep1Data._toStringMap(json['floorNoList']),
      floorUsageList: AssessmentStep1Data._toStringMap(json['floorUsageList']),
      constructionTypeList:
          AssessmentStep1Data._toStringMap(json['constructionTypeList']),
    );
  }
}

class SaveFloorResponse {
  final bool? success;
  final String? message;
  final int? responseCode;
  final SaveFloorData? data;

  SaveFloorResponse({this.success, this.message, this.responseCode, this.data});

  factory SaveFloorResponse.fromJson(Map<String, dynamic> json) {
    return SaveFloorResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null ? SaveFloorData.fromJson(json['data']) : null,
    );
  }
}

class SaveFloorData {
  final String? ackNo;
  final double? totalArv;
  final List<FloorDetailItem> floorList;
  final Map<String, String> rebateFinancialYearList;

  SaveFloorData({
    this.ackNo,
    this.totalArv,
    this.floorList = const [],
    this.rebateFinancialYearList = const {},
  });

  factory SaveFloorData.fromJson(Map<String, dynamic> json) {
    return SaveFloorData(
      ackNo: json['ackNo'],
      totalArv: (json['totalArv'] as num?)?.toDouble(),
      floorList: json['floorList'] is List
          ? (json['floorList'] as List)
              .map((e) => FloorDetailItem.fromJson(e))
              .toList()
          : [],
      rebateFinancialYearList:
          AssessmentStep1Data._toStringMap(json['rebateFinancialYearList']),
    );
  }
}

class FloorDetailItem {
  final int? floorNumber;
  final String? floorName;
  final double? carpetArea;
  final String? floorTypeName;
  final String? constructionTypeName;
  final String? constructionDate;
  final double? mrate;
  final double? multiplier;
  final double? rentalValue;
  final double? arv;
  final double? arvAfterRebate;

  FloorDetailItem({
    this.floorNumber,
    this.floorName,
    this.carpetArea,
    this.floorTypeName,
    this.constructionTypeName,
    this.constructionDate,
    this.mrate,
    this.multiplier,
    this.rentalValue,
    this.arv,
    this.arvAfterRebate,
  });

  factory FloorDetailItem.fromJson(Map<String, dynamic> json) {
    return FloorDetailItem(
      floorNumber: json['floorNumber'],
      floorName: json['floorName'],
      carpetArea: (json['carpetArea'] as num?)?.toDouble(),
      floorTypeName: json['floorTypeName'],
      constructionTypeName: json['constructionTypeName'],
      constructionDate: json['constructionDate'],
      mrate: (json['mrate'] as num?)?.toDouble(),
      multiplier: (json['multiplier'] as num?)?.toDouble(),
      rentalValue: (json['rentalValue'] as num?)?.toDouble(),
      arv: (json['arv'] as num?)?.toDouble(),
      arvAfterRebate: (json['arvAfterRebate'] as num?)?.toDouble(),
    );
  }
}

class DeleteFloorResponse {
  final bool? success;
  final String? message;
  final int? responseCode;

  DeleteFloorResponse({this.success, this.message, this.responseCode});

  factory DeleteFloorResponse.fromJson(Map<String, dynamic> json) {
    return DeleteFloorResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
    );
  }
}

class AssessmentStep3Response {
  final bool? success;
  final String? message;
  final int? responseCode;
  final AssessmentStep3Data? data;

  AssessmentStep3Response({
    this.success,
    this.message,
    this.responseCode,
    this.data,
  });

  factory AssessmentStep3Response.fromJson(Map<String, dynamic> json) {
    return AssessmentStep3Response(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null
          ? AssessmentStep3Data.fromJson(json['data'])
          : null,
    );
  }
}

class ReassessmentGetS1Response {
  final bool? success;
  final String? message;
  final int? responseCode;
  final ReassessmentGetS1Data? data;

  ReassessmentGetS1Response({
    this.success,
    this.message,
    this.responseCode,
    this.data,
  });

  factory ReassessmentGetS1Response.fromJson(Map<String, dynamic> json) {
    return ReassessmentGetS1Response(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null
          ? ReassessmentGetS1Data.fromJson(json['data'])
          : null,
    );
  }
}

class ReassessmentGetS1Data {
  final String? propertyId;
  final String? dateOfLastAssessment;
  final int? noOfFloor;
  final String? ackNo;

  ReassessmentGetS1Data({
    this.propertyId,
    this.dateOfLastAssessment,
    this.noOfFloor,
    this.ackNo,
  });

  factory ReassessmentGetS1Data.fromJson(Map<String, dynamic> json) {
    return ReassessmentGetS1Data(
      propertyId: json['propertyId'],
      dateOfLastAssessment: json['dateOfLastAssessment'],
      noOfFloor: json['noOfFloor'],
      ackNo: json['ackNo']?.toString().trim(),
    );
  }
}

class ReassessmentListResponse {
  final bool? success;
  final String? message;
  final int? responseCode;
  final List<ReassessmentListItem> data;

  ReassessmentListResponse({
    this.success,
    this.message,
    this.responseCode,
    this.data = const [],
  });

  factory ReassessmentListResponse.fromJson(Map<String, dynamic> json) {
    return ReassessmentListResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] is List
          ? (json['data'] as List)
                .map((e) => ReassessmentListItem.fromJson(e))
                .toList()
          : const [],
    );
  }
}

class ReassessmentListItem {
  final String? propertyId;
  final String? ackNo;
  final String? assessType;
  final String? assessDate;
  final String? ownerName;
  final String? fatherName;
  final String? houseNo;
  final String? address;
  final String? totalArv;
  final int? currentStage;
  final String? isCompleted;
  final String? createdAt;
  final String? updatedAt;
  final int? nextStage;

  ReassessmentListItem({
    this.propertyId,
    this.ackNo,
    this.assessType,
    this.assessDate,
    this.ownerName,
    this.fatherName,
    this.houseNo,
    this.address,
    this.totalArv,
    this.currentStage,
    this.isCompleted,
    this.createdAt,
    this.updatedAt,
    this.nextStage,
  });

  bool get isCompletedFlag => (isCompleted ?? '').toUpperCase() == 'YES';

  factory ReassessmentListItem.fromJson(Map<String, dynamic> json) {
    return ReassessmentListItem(
      propertyId: json['property_id']?.toString(),
      ackNo: json['ack_no']?.toString(),
      assessType: json['assess_type']?.toString(),
      assessDate: json['assess_date']?.toString(),
      ownerName: json['owner_name']?.toString(),
      fatherName: json['father_name']?.toString(),
      houseNo: json['house_no']?.toString(),
      address: json['address']?.toString(),
      totalArv: json['total_arv']?.toString(),
      currentStage: json['current_stage'] is int
          ? json['current_stage']
          : int.tryParse('${json['current_stage']}'),
      isCompleted: json['is_completed']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      nextStage: json['next_stage'] is int
          ? json['next_stage']
          : int.tryParse('${json['next_stage']}'),
    );
  }
}

class ReassessmentFullDetailsResponse {
  final bool? success;
  final String? message;
  final int? responseCode;
  final ReassessmentFullDetailsData? data;

  ReassessmentFullDetailsResponse({
    this.success,
    this.message,
    this.responseCode,
    this.data,
  });

  factory ReassessmentFullDetailsResponse.fromJson(Map<String, dynamic> json) {
    return ReassessmentFullDetailsResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null
          ? ReassessmentFullDetailsData.fromJson(json['data'])
          : null,
    );
  }
}

class ReassessmentFullDetailsData {
  final String? userId;
  final String? mobileNo;
  final String? propertyId;
  final String? ackNo;
  final String? assessType;
  final String? assessDate;
  final String? ownerName;
  final String? fatherName;
  final String? houseNo;
  final String? address;
  final String? totalArv;
  final List<ReassessmentFloorDetail> floorDetails;
  final ReassessmentTaxDetails? taxDetails;
  final int? currentStage;
  final String? isCompleted;
  final String? createdAt;
  final String? updatedAt;
  final int? nextStage;

  ReassessmentFullDetailsData({
    this.userId,
    this.mobileNo,
    this.propertyId,
    this.ackNo,
    this.assessType,
    this.assessDate,
    this.ownerName,
    this.fatherName,
    this.houseNo,
    this.address,
    this.totalArv,
    this.floorDetails = const [],
    this.taxDetails,
    this.currentStage,
    this.isCompleted,
    this.createdAt,
    this.updatedAt,
    this.nextStage,
  });

  bool get isCompletedFlag => (isCompleted ?? '').toUpperCase() == 'YES';

  factory ReassessmentFullDetailsData.fromJson(Map<String, dynamic> json) {
    return ReassessmentFullDetailsData(
      userId: json['user_id']?.toString(),
      mobileNo: json['mobile_no']?.toString(),
      propertyId: json['property_id']?.toString(),
      ackNo: json['ack_no']?.toString(),
      assessType: json['assess_type']?.toString(),
      assessDate: json['assess_date']?.toString(),
      ownerName: json['owner_name']?.toString(),
      fatherName: json['father_name']?.toString(),
      houseNo: json['house_no']?.toString(),
      address: json['address']?.toString(),
      totalArv: json['total_arv']?.toString(),
      floorDetails: json['floor_details'] is List
          ? (json['floor_details'] as List)
              .map((e) => ReassessmentFloorDetail.fromJson(e))
              .toList()
          : const [],
      taxDetails: json['tax_details'] != null
          ? ReassessmentTaxDetails.fromJson(json['tax_details'])
          : null,
      currentStage: json['current_stage'] is int
          ? json['current_stage']
          : int.tryParse('${json['current_stage']}'),
      isCompleted: json['is_completed']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      nextStage: json['next_stage'] is int
          ? json['next_stage']
          : int.tryParse('${json['next_stage']}'),
    );
  }
}

class ReassessmentFloorDetail {
  final int? floorNumber;
  final String? floorName;
  final double? carpetArea;
  final String? floorTypeName;
  final String? constructionTypeName;
  final String? constructionDate;
  final double? mrate;
  final double? multiplier;
  final double? rentalValue;
  final double? arv;
  final double? arvAfterRebate;

  ReassessmentFloorDetail({
    this.floorNumber,
    this.floorName,
    this.carpetArea,
    this.floorTypeName,
    this.constructionTypeName,
    this.constructionDate,
    this.mrate,
    this.multiplier,
    this.rentalValue,
    this.arv,
    this.arvAfterRebate,
  });

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory ReassessmentFloorDetail.fromJson(Map<String, dynamic> json) {
    return ReassessmentFloorDetail(
      floorNumber: json['floorNumber'] is int
          ? json['floorNumber']
          : int.tryParse('${json['floorNumber']}'),
      floorName: json['floorName']?.toString(),
      carpetArea: _toDouble(json['carpetArea']),
      floorTypeName: json['floorTypeName']?.toString(),
      constructionTypeName: json['constructionTypeName']?.toString(),
      constructionDate: json['constructionDate']?.toString(),
      mrate: _toDouble(json['mrate']),
      multiplier: _toDouble(json['multiplier']),
      rentalValue: _toDouble(json['rentalValue']),
      arv: _toDouble(json['arv']),
      arvAfterRebate: _toDouble(json['arvAfterRebate']),
    );
  }
}

class ReassessmentTaxDetails {
  final List<ReassessmentPwsItem> pwsList;
  final String? ulbId;
  final String? propertyId;
  final String? acknowledgementId;
  final double? totalArea;
  final String? ownerName;
  final String? fatherName;
  final String? houseNo;
  final String? address;
  final String? zoneId;
  final String? wardId;
  final String? mohallaId;
  final String? mobile;
  final String? assessmentType;
  final String? fileNo;
  final String? propertyUse;
  final String? roadLocation;
  final String? propertyType;
  final String? assessmentDate;
  final String? oldArv;
  final String? existingPropertyId;
  final double? totalArv;
  final String? rebateFinancialYear;
  final String? taxRebateTypeName;

  ReassessmentTaxDetails({
    this.pwsList = const [],
    this.ulbId,
    this.propertyId,
    this.acknowledgementId,
    this.totalArea,
    this.ownerName,
    this.fatherName,
    this.houseNo,
    this.address,
    this.zoneId,
    this.wardId,
    this.mohallaId,
    this.mobile,
    this.assessmentType,
    this.fileNo,
    this.propertyUse,
    this.roadLocation,
    this.propertyType,
    this.assessmentDate,
    this.oldArv,
    this.existingPropertyId,
    this.totalArv,
    this.rebateFinancialYear,
    this.taxRebateTypeName,
  });

  factory ReassessmentTaxDetails.fromJson(Map<String, dynamic> json) {
    return ReassessmentTaxDetails(
      pwsList: json['pwsList'] is List
          ? (json['pwsList'] as List)
              .map((e) => ReassessmentPwsItem.fromJson(e))
              .toList()
          : const [],
      ulbId: json['ulbId']?.toString(),
      propertyId: json['propertyId']?.toString(),
      acknowledgementId: json['acknowledgementId']?.toString(),
      totalArea: ReassessmentFloorDetail._toDouble(json['totalArea']),
      ownerName: json['ownerName']?.toString(),
      fatherName: json['fatherName']?.toString(),
      houseNo: json['houseNo']?.toString(),
      address: json['address']?.toString(),
      zoneId: json['zoneId']?.toString(),
      wardId: json['wardId']?.toString(),
      mohallaId: json['mohallaId']?.toString(),
      mobile: json['mobile']?.toString(),
      assessmentType: json['assessmentType']?.toString(),
      fileNo: json['fileNo']?.toString(),
      propertyUse: json['propertyUse']?.toString(),
      roadLocation: json['roadLocation']?.toString(),
      propertyType: json['propertyType']?.toString(),
      assessmentDate: json['assessmentDate']?.toString(),
      oldArv: json['oldArv']?.toString(),
      existingPropertyId: json['existingPropertyId']?.toString(),
      totalArv: ReassessmentFloorDetail._toDouble(json['totalArv']),
      rebateFinancialYear: json['rebateFinancialYear']?.toString(),
      taxRebateTypeName: json['taxRebateTypeName']?.toString(),
    );
  }
}

class ReassessmentPwsItem {
  final String? finYear;
  final double? propertyTax;
  final double? propertyArrear;
  final double? propertyInterest;
  final double? waterTax;
  final double? waterArrear;
  final double? waterInterest;
  final double? sewerageTax;
  final double? sewerageArrear;
  final double? sewerageInterest;
  final double? otherTax;
  final double? otherArrear;
  final double? otherInterest;
  final double? waterCharge;
  final double? waterChargeArrear;
  final double? waterChargeInterest;
  final double? totalTax;
  final double? totalInterest;
  final double? grandTotal;

  ReassessmentPwsItem({
    this.finYear,
    this.propertyTax,
    this.propertyArrear,
    this.propertyInterest,
    this.waterTax,
    this.waterArrear,
    this.waterInterest,
    this.sewerageTax,
    this.sewerageArrear,
    this.sewerageInterest,
    this.otherTax,
    this.otherArrear,
    this.otherInterest,
    this.waterCharge,
    this.waterChargeArrear,
    this.waterChargeInterest,
    this.totalTax,
    this.totalInterest,
    this.grandTotal,
  });

  factory ReassessmentPwsItem.fromJson(Map<String, dynamic> json) {
    return ReassessmentPwsItem(
      finYear: json['finYear']?.toString(),
      propertyTax: ReassessmentFloorDetail._toDouble(json['propertyTax']),
      propertyArrear: ReassessmentFloorDetail._toDouble(json['propertyArrear']),
      propertyInterest: ReassessmentFloorDetail._toDouble(json['propertyInterest']),
      waterTax: ReassessmentFloorDetail._toDouble(json['waterTax']),
      waterArrear: ReassessmentFloorDetail._toDouble(json['waterArrear']),
      waterInterest: ReassessmentFloorDetail._toDouble(json['waterInterest']),
      sewerageTax: ReassessmentFloorDetail._toDouble(json['sewerageTax']),
      sewerageArrear: ReassessmentFloorDetail._toDouble(json['sewerageArrear']),
      sewerageInterest: ReassessmentFloorDetail._toDouble(json['sewerageInterest']),
      otherTax: ReassessmentFloorDetail._toDouble(json['otherTax']),
      otherArrear: ReassessmentFloorDetail._toDouble(json['otherArrear']),
      otherInterest: ReassessmentFloorDetail._toDouble(json['otherInterest']),
      waterCharge: ReassessmentFloorDetail._toDouble(json['waterCharge']),
      waterChargeArrear: ReassessmentFloorDetail._toDouble(json['waterChargeArrear']),
      waterChargeInterest: ReassessmentFloorDetail._toDouble(json['waterChargeInterest']),
      totalTax: ReassessmentFloorDetail._toDouble(json['totalTax']),
      totalInterest: ReassessmentFloorDetail._toDouble(json['totalInterest']),
      grandTotal: ReassessmentFloorDetail._toDouble(json['grandTotal']),
    );
  }
}

class ReassessmentStep1Response {
  final bool? success;
  final String? message;
  final int? responseCode;
  final ReassessmentStep1Data? data;

  ReassessmentStep1Response({
    this.success,
    this.message,
    this.responseCode,
    this.data,
  });

  factory ReassessmentStep1Response.fromJson(Map<String, dynamic> json) {
    return ReassessmentStep1Response(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null
          ? ReassessmentStep1Data.fromJson(json['data'])
          : null,
    );
  }
}

class ReassessmentStep1Data {
  final String? assessType;
  final int? zoneId;
  final int? wardId;
  final int? mohallaId;
  final String? zoneName;
  final String? wardName;
  final String? mohallaName;
  final String? roadLocationName;
  final String? propertyTypeName;
  final String? fileNo;
  final double? totalArea;
  final String? ownerName;
  final String? fatherName;
  final String? houseNo;
  final String? address;
  final String? assessmentDate;
  final String? propertyId;
  final String? ackNo;
  final String? roadLocationId;
  final String? oldArv;

  ReassessmentStep1Data({
    this.assessType,
    this.zoneId,
    this.wardId,
    this.mohallaId,
    this.zoneName,
    this.wardName,
    this.mohallaName,
    this.roadLocationName,
    this.propertyTypeName,
    this.fileNo,
    this.totalArea,
    this.ownerName,
    this.fatherName,
    this.houseNo,
    this.address,
    this.assessmentDate,
    this.propertyId,
    this.ackNo,
    this.roadLocationId,
    this.oldArv,
  });

  factory ReassessmentStep1Data.fromJson(Map<String, dynamic> json) {
    return ReassessmentStep1Data(
      assessType: json['assessType'],
      zoneId: json['zoneId'],
      wardId: json['wardId'],
      mohallaId: json['mohallaId'],
      zoneName: json['zoneName'],
      wardName: json['wardName'],
      mohallaName: json['mohallaName'],
      roadLocationName: json['roadLocationName'],
      propertyTypeName: json['propertyTypeName'],
      fileNo: json['fileNo'],
      totalArea: (json['totalArea'] as num?)?.toDouble(),
      ownerName: json['ownerName'],
      fatherName: json['fatherName'],
      houseNo: json['houseNo'],
      address: json['address'],
      assessmentDate: json['assessmentDate'],
      propertyId: json['propertyId'],
      ackNo: json['ackNo']?.toString().trim(),
      roadLocationId: json['roadLocationId']?.toString(),
      oldArv: json['oldArv']?.toString(),
    );
  }
}

class AssessmentStep3Data {
  final List<PwsItem> pwsList;
  final String? propertyId;
  final int? ulbId;
  final String? acknowledgementId;
  final double? totalArea;
  final String? ownerName;
  final String? fatherName;
  final String? houseNo;
  final String? address;
  final int? zoneId;
  final int? wardId;
  final int? mohallaId;
  final String? mobile;
  final String? assessmentType;
  final String? fileNo;
  final String? propertyUse;
  final String? roadLocation;
  final int? propertyType;
  final String? assessmentDate;
  final String? oldArv;
  final String? existingPropertyId;
  final double? totalArv;
  final String? rebateFinancialYear;
  final String? taxRebateTypeName;

  AssessmentStep3Data({
    this.pwsList = const [],
    this.propertyId,
    this.ulbId,
    this.acknowledgementId,
    this.totalArea,
    this.ownerName,
    this.fatherName,
    this.houseNo,
    this.address,
    this.zoneId,
    this.wardId,
    this.mohallaId,
    this.mobile,
    this.assessmentType,
    this.fileNo,
    this.propertyUse,
    this.roadLocation,
    this.propertyType,
    this.assessmentDate,
    this.oldArv,
    this.existingPropertyId,
    this.totalArv,
    this.rebateFinancialYear,
    this.taxRebateTypeName,
  });

  factory AssessmentStep3Data.fromJson(Map<String, dynamic> json) {
    return AssessmentStep3Data(
      pwsList: json['pwsList'] is List
          ? (json['pwsList'] as List).map((e) => PwsItem.fromJson(e)).toList()
          : [],
      propertyId: json['propertyId'],
      ulbId: json['ulbId'],
      acknowledgementId: json['acknowledgementId'],
      totalArea: (json['totalArea'] as num?)?.toDouble(),
      ownerName: json['ownerName'],
      fatherName: json['fatherName'],
      houseNo: json['houseNo'],
      address: json['address'],
      zoneId: json['zoneId'],
      wardId: json['wardId'],
      mohallaId: json['mohallaId'],
      mobile: json['mobile']?.toString(),
      assessmentType: json['assessmentType'],
      fileNo: json['fileNo'],
      propertyUse: json['propertyUse']?.toString(),
      roadLocation: json['roadLocation']?.toString(),
      propertyType: json['propertyType'],
      assessmentDate: json['assessmentDate'],
      oldArv: json['oldArv']?.toString(),
      existingPropertyId: json['existingPropertyId'],
      totalArv: (json['totalArv'] as num?)?.toDouble(),
      rebateFinancialYear: json['rebateFinancialYear'],
      taxRebateTypeName: json['taxRebateTypeName'],
    );
  }
}

class PwsItem {
  final String? finYear;
  final double? propertyTax;
  final double? propertyArrear;
  final double? propertyInterest;
  final double? waterTax;
  final double? waterArrear;
  final double? waterInterest;
  final double? sewerageTax;
  final double? sewerageArrear;
  final double? sewerageInterest;
  final double? otherTax;
  final double? otherArrear;
  final double? otherInterest;
  final double? waterCharge;
  final double? waterChargeArrear;
  final double? waterChargeInterest;
  final double? totalTax;
  final double? totalInterest;
  final double? grandTotal;

  PwsItem({
    this.finYear,
    this.propertyTax,
    this.propertyArrear,
    this.propertyInterest,
    this.waterTax,
    this.waterArrear,
    this.waterInterest,
    this.sewerageTax,
    this.sewerageArrear,
    this.sewerageInterest,
    this.otherTax,
    this.otherArrear,
    this.otherInterest,
    this.waterCharge,
    this.waterChargeArrear,
    this.waterChargeInterest,
    this.totalTax,
    this.totalInterest,
    this.grandTotal,
  });

  static double? _d(dynamic v) => (v as num?)?.toDouble();

  factory PwsItem.fromJson(Map<String, dynamic> json) {
    return PwsItem(
      finYear: json['finYear'],
      propertyTax: _d(json['propertyTax']),
      propertyArrear: _d(json['propertyArrear']),
      propertyInterest: _d(json['propertyInterest']),
      waterTax: _d(json['waterTax']),
      waterArrear: _d(json['waterArrear']),
      waterInterest: _d(json['waterInterest']),
      sewerageTax: _d(json['sewerageTax']),
      sewerageArrear: _d(json['sewerageArrear']),
      sewerageInterest: _d(json['sewerageInterest']),
      otherTax: _d(json['otherTax']),
      otherArrear: _d(json['otherArrear']),
      otherInterest: _d(json['otherInterest']),
      waterCharge: _d(json['waterCharge']),
      waterChargeArrear: _d(json['waterChargeArrear']),
      waterChargeInterest: _d(json['waterChargeInterest']),
      totalTax: _d(json['totalTax']),
      totalInterest: _d(json['totalInterest']),
      grandTotal: _d(json['grandTotal']),
    );
  }
}

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
    this.districtName,
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
  String toString() => '${ulbName ?? ""} (${ulbType ?? ""})';
}

class UlbLanguageResponse {
  final bool success;
  final String message;
  final int? responseCode;
  final String? language;
  final String? ulbId;

  UlbLanguageResponse({
    required this.success,
    required this.message,
    this.responseCode,
    this.language,
    this.ulbId,
  });

  factory UlbLanguageResponse.fromJson(Map<String, dynamic> json) {
    final message = json['message']?.toString() ?? '';
    final ulbIdMatch = RegExp(r'ULB ID\s*:-\s*(\S+)').firstMatch(message);
    return UlbLanguageResponse(
      success: json['success'] == true,
      message: message,
      responseCode: json['responseCode'] is int ? json['responseCode'] : null,
      language: json['data']?.toString(),
      ulbId: ulbIdMatch?.group(1),
    );
  }
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
      totalArv: (json['totalArv'] is num)
          ? (json['totalArv'] as num).toDouble()
          : null,
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

  PropertyDetailsResponse({
    this.success,
    this.message,
    this.responseCode,
    this.data,
  });

  factory PropertyDetailsResponse.fromJson(Map<String, dynamic> json) {
    return PropertyDetailsResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      data: json['data'] != null
          ? PropertyDetailsData.fromJson(json['data'])
          : null,
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
      billDetails: json['billDetails'] != null
          ? BillDetails.fromJson(json['billDetails'])
          : null,
      ownerDetails: json['ownerDetails'] != null
          ? OwnerDetails.fromJson(json['ownerDetails'])
          : null,
      propertyDetailsInfo: json['propertyDetails'] != null
          ? PropertyInfo.fromJson(json['propertyDetails'])
          : null,
      currReceiptDetails: json['currReceiptDetails'] != null
          ? (json['currReceiptDetails'] as List)
                .map((i) => ReceiptDetailsItem.fromJson(i))
                .toList()
          : null,
      prevReceiptDetails: json['prevReceiptDetails'] != null
          ? (json['prevReceiptDetails'] as List)
                .map((i) => ReceiptDetailsItem.fromJson(i))
                .toList()
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
      waterChargeMonthlyInterest: json['waterChargeMonthlyInterest']
          ?.toString(),
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
  final String? totalArea;
  final String? chukNo;
  final String? propertyUseAs;
  final String? propertyType;
  final String? ulbName;

  PropertyInfo({
    this.address,
    this.houseNo,
    this.wardName,
    this.zoneName,
    this.mohallaName,
    this.totalArea,
    this.chukNo,
    this.propertyUseAs,
    this.propertyType,
    this.ulbName,
  });

  factory PropertyInfo.fromJson(Map<String, dynamic> json) {
    return PropertyInfo(
      address: json['address'],
      houseNo: json['houseNo']?.toString(),
      wardName: json['wardName'],
      zoneName: json['zoneName'],
      mohallaName: json['mohallaName'],
      totalArea: json['totalArea']?.toString(),
      chukNo: json['chukNo']?.toString(),
      propertyUseAs: json['propertyUseAs']?.toString(),
      ulbName: json['ulbName']?.toString(),
      propertyType: json['propertyType']?.toString(),
    );
  }
}

class ReceiptDetailsItem {
  final String? receiptNo;
  final String? billNo;
  final String? receiptDate;
  final String? paymentMode;
  final String? paymentDate;
  final String? challanId;
  final String? chequeNo;
  final String? propertyTaxNetAmount;
  final String? propertyTaxPaidAmount;
  final String? waterTaxPaidAmount;
  final String? sewerTaxPaidAmount;
  final String? otherTaxPaidAmount;
  final String? waterChargePaidAmount;

  ReceiptDetailsItem({
    this.receiptNo,
    this.billNo,
    this.receiptDate,
    this.paymentMode,
    this.paymentDate,
    this.challanId,
    this.chequeNo,
    this.propertyTaxNetAmount,
    this.propertyTaxPaidAmount,
    this.waterTaxPaidAmount,
    this.sewerTaxPaidAmount,
    this.otherTaxPaidAmount,
    this.waterChargePaidAmount,
  });

  factory ReceiptDetailsItem.fromJson(Map<String, dynamic> json) {
    return ReceiptDetailsItem(
      receiptNo: json['receiptNo']?.toString(),
      billNo: json['billNo']?.toString(),
      receiptDate: json['receiptDate']?.toString(),
      paymentMode: json['paymentMode']?.toString(),
      paymentDate: json['paymentDate']?.toString(),
      challanId: json['challanId']?.toString(),
      chequeNo: json['chequeNo']?.toString(),
      propertyTaxNetAmount: json['propertyTaxNetAmount']?.toString(),
      propertyTaxPaidAmount: json['propertyTaxPaidAmount']?.toString(),
      waterTaxPaidAmount: json['waterTaxPaidAmount']?.toString(),
      sewerTaxPaidAmount: json['sewerTaxPaidAmount']?.toString(),
      otherTaxPaidAmount: json['otherTaxPaidAmount']?.toString(),
      waterChargePaidAmount: json['waterChargePaidAmount']?.toString(),
    );
  }
}

class ForgotPasswordResponse {
  final bool status;
  final String message;
  final int? responseCode;

  ForgotPasswordResponse({
    required this.status,
    required this.message,
    this.responseCode,
  });

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      status: json['status'] == true,
      message: json['message']?.toString() ?? '',
      responseCode: json['responseCode'],
    );
  }
}

class VerifyForgotPasswordOtpResponse {
  final bool status;
  final String message;
  final int? responseCode;
  final int? attemptsLeft;

  VerifyForgotPasswordOtpResponse({
    required this.status,
    required this.message,
    this.responseCode,
    this.attemptsLeft,
  });

  factory VerifyForgotPasswordOtpResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return VerifyForgotPasswordOtpResponse(
      status: json['status'] == true,
      message: json['message']?.toString() ?? '',
      responseCode: json['responseCode'],
      attemptsLeft: data?['attempts_left'],
    );
  }
}

class SendOtpResponse {
  final bool? success;
  final String? message;
  final int? responseCode;
  final String? maskedMobile;

  SendOtpResponse({this.success, this.message, this.responseCode, this.maskedMobile});

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return SendOtpResponse(
      success: json['success'],
      message: json['message'],
      responseCode: json['responseCode'],
      maskedMobile: data?['maskedMobile'],
    );
  }
}

class VerifyOtpResponse {
  final bool? success;
  final String? message;
  final int? userId;
  final int? responseCode;

  VerifyOtpResponse({
    this.success,
    this.message,
    this.userId,
    this.responseCode,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      success: json['success'],
      message: json['message'],
      userId: json['userId'],
      responseCode: json['responseCode'],
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
  /// Raw value from API: 'p' = production, 't' = testing
  final String? payuEnv;
  final String? merchantName;
  final String? ulbId;

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
    this.payuEnv,
    this.merchantName,
    this.ulbId,
  });

  /// Returns the PayU SDK environment value: '0' for production, '1' for test.
  String get resolvedPayuEnvironment => payuEnv == 't' ? '1' : '0';

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
    payuEnv: json['payu_env']?.toString(),
    merchantName: json['merchantName']?.toString(),
    ulbId: json['ulbId']?.toString() ?? json['ulb_id']?.toString(),
  );
}

class CreateSbiTransactionResponse {
  final bool? status;
  final String? message;
  final SbiTransactionData? data;

  CreateSbiTransactionResponse({this.status, this.message, this.data});

  factory CreateSbiTransactionResponse.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'];
    return CreateSbiTransactionResponse(
      status: json['status'],
      message: json['message'],
      data: dataJson is Map<String, dynamic>
          ? SbiTransactionData.fromJson(dataJson)
          : null,
    );
  }
}

class SbiTransactionData {
  final String? txnid;
  final String? merchantId;
  final String? encdata;
  final String? sbiPostUrl;
  final String? paymentPageHtml;

  SbiTransactionData({
    this.txnid,
    this.merchantId,
    this.encdata,
    this.sbiPostUrl,
    this.paymentPageHtml,
  });

  factory SbiTransactionData.fromJson(Map<String, dynamic> json) =>
      SbiTransactionData(
        txnid: json['txnid']?.toString(),
        merchantId: json['merchant_id']?.toString(),
        encdata: json['encdata']?.toString(),
        sbiPostUrl: json['sbi_post_url']?.toString(),
        paymentPageHtml: json['payment_page_html']?.toString(),
      );
}

class SbiTransactionDetailsResponse {
  final bool? status;
  final String? message;
  final SbiPaymentDetails? data;

  SbiTransactionDetailsResponse({this.status, this.message, this.data});

  factory SbiTransactionDetailsResponse.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'];
    return SbiTransactionDetailsResponse(
      status: json['status'],
      message: json['message'],
      data: dataJson is Map<String, dynamic>
          ? SbiPaymentDetails.fromJson(dataJson)
          : null,
    );
  }
}

class SbiPaymentDetails {
  final String? paymentStatus;
  final String? txnid;
  final String? paymentMode;
  final String? netPayable;
  final String? ownerName;
  final String? mobileNo;
  final String? billNo;
  final String? propertyId;
  final String? financialYear;
  final String? propertyTaxPaid;
  final String? waterTaxPaid;
  final String? sewerTaxPaid;
  final String? otherTaxPaid;
  final String? waterChargePaid;
  final String? sbiPaymentTime;
  final String? payuPaymentTime;
  final String? mobileTransactionTimestamp;
  final String? transactionCreatedAt;

  SbiPaymentDetails({
    this.paymentStatus,
    this.txnid,
    this.paymentMode,
    this.netPayable,
    this.ownerName,
    this.mobileNo,
    this.billNo,
    this.propertyId,
    this.financialYear,
    this.propertyTaxPaid,
    this.waterTaxPaid,
    this.sewerTaxPaid,
    this.otherTaxPaid,
    this.waterChargePaid,
    this.sbiPaymentTime,
    this.payuPaymentTime,
    this.mobileTransactionTimestamp,
    this.transactionCreatedAt,
  });

  factory SbiPaymentDetails.fromJson(Map<String, dynamic> json) =>
      SbiPaymentDetails(
        paymentStatus: json['payment_status']?.toString(),
        txnid: json['txnid']?.toString(),
        paymentMode: json['payment_mode']?.toString(),
        netPayable: json['net_payable']?.toString(),
        ownerName: json['owner_name']?.toString(),
        mobileNo: json['mobile_no']?.toString(),
        billNo: json['billNo']?.toString(),
        propertyId: json['propertyId']?.toString(),
        financialYear: json['financialYear']?.toString(),
        propertyTaxPaid: json['propertyTaxPaid']?.toString(),
        waterTaxPaid: json['waterTaxPaid']?.toString(),
        sewerTaxPaid: json['sewerTaxPaid']?.toString(),
        otherTaxPaid: json['otherTaxPaid']?.toString(),
        waterChargePaid: json['waterChargePaid']?.toString(),
        sbiPaymentTime: json['sbi_payment_time']?.toString(),
        payuPaymentTime: json['payu_payment_time']?.toString(),
        mobileTransactionTimestamp: json['mobile_transaction_timestamp']?.toString(),
        transactionCreatedAt: json['transaction_created_at']?.toString(),
      );
}

class PayUTransactionDetailsResponse {
  final bool? status;
  final String? message;
  final PayUTransactionDetails? data;

  PayUTransactionDetailsResponse({this.status, this.message, this.data});

  factory PayUTransactionDetailsResponse.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'];
    return PayUTransactionDetailsResponse(
      status: json['status'],
      message: json['message'],
      data: dataJson is Map<String, dynamic>
          ? PayUTransactionDetails.fromJson(dataJson)
          : null,
    );
  }
}

class PayUTransactionDetails {
  final String? paymentStatus;
  final String? txnid;
  final dynamic paymentMode;
  final String? netPayable;
  final String? ownerName;
  final String? mobileNo;
  final String? billNo;
  final String? propertyId;
  final String? financialYear;
  final String? propertyTaxPaid;
  final String? waterTaxPaid;
  final String? sewerTaxPaid;
  final String? otherTaxPaid;
  final String? waterChargePaid;
  final String? mobileTransactionTimestamp;
  final String? payuPaymentTime;
  final String? transactionCreatedAt;

  PayUTransactionDetails({
    this.paymentStatus,
    this.txnid,
    this.paymentMode,
    this.netPayable,
    this.ownerName,
    this.mobileNo,
    this.billNo,
    this.propertyId,
    this.financialYear,
    this.propertyTaxPaid,
    this.waterTaxPaid,
    this.sewerTaxPaid,
    this.otherTaxPaid,
    this.waterChargePaid,
    this.mobileTransactionTimestamp,
    this.payuPaymentTime,
    this.transactionCreatedAt,
  });

  factory PayUTransactionDetails.fromJson(Map<String, dynamic> json) =>
      PayUTransactionDetails(
        paymentStatus: json['payment_status']?.toString(),
        txnid: json['txnid']?.toString(),
        paymentMode: json['payment_mode'],
        netPayable: json['net_payable']?.toString(),
        ownerName: json['owner_name']?.toString(),
        mobileNo: json['mobile_no']?.toString(),
        billNo: json['billNo']?.toString(),
        propertyId: json['propertyId']?.toString(),
        financialYear: json['financialYear']?.toString(),
        propertyTaxPaid: json['propertyTaxPaid']?.toString(),
        waterTaxPaid: json['waterTaxPaid']?.toString(),
        sewerTaxPaid: json['sewerTaxPaid']?.toString(),
        otherTaxPaid: json['otherTaxPaid']?.toString(),
        waterChargePaid: json['waterChargePaid']?.toString(),
        mobileTransactionTimestamp:
            json['mobile_transaction_timestamp']?.toString(),
        payuPaymentTime: json['payu_payment_time']?.toString(),
        transactionCreatedAt: json['transaction_created_at']?.toString(),
      );
}

class HashResponse {
  final String? data;
  final String? message;
  final bool? status;

  HashResponse({this.data, this.message, this.status});

  factory HashResponse.fromJson(Map<String, dynamic> json) {
    return HashResponse(
      data: json['data']?.toString(),
      message: json['message'],
      status: json['status'] ?? json['success'],
    );
  }
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
          ? (json['data'] as List)
                .map((i) => TransactionData.fromJson(i))
                .toList()
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
  final String? ownerName;
  final String? fatherName;
  final String? address;
  final String? mobileNo;
  final String? eNagarSewaRefNo;
  final String? userCode;
  final String? ulbName;
  final String? ulbType;
  final String? receiptNo;
  final String? billDate;

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
    this.ownerName,
    this.fatherName,
    this.address,
    this.mobileNo,
    this.eNagarSewaRefNo,
    this.userCode,
    this.ulbName,
    this.ulbType,
    this.receiptNo,
    this.billDate,
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
      ownerName: json['owner_name']?.toString(),
      fatherName: json['father_name']?.toString(),
      address: json['address']?.toString(),
      mobileNo: json['mobile_no']?.toString(),
      eNagarSewaRefNo: json['e_nagarsewa_ref_no']?.toString(),
      userCode: json['user_code']?.toString(),
      ulbName: json['ulb_name']?.toString(),
      ulbType: json['ulb_type']?.toString(),
      receiptNo: json['receiptNo']?.toString(),
      billDate: json['bill_date']?.toString(),
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
    this.data,
  });
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
  RefreshTokenResponse({
    this.status,
    this.responseCode,
    this.message,
    this.data,
  });
  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) =>
      RefreshTokenResponse(
        status: json['status'],
        responseCode: json['responseCode'],
        message: json['message'],
        data: json['data'] != null
            ? RefreshTokenData.fromJson(json['data'])
            : null,
      );
}

class RefreshTokenData {
  final String? accessToken;
  RefreshTokenData({this.accessToken});
  factory RefreshTokenData.fromJson(Map<String, dynamic> json) =>
      RefreshTokenData(accessToken: json['access_token']);
}

class GrievanceDetailsResponse {
  final bool? success;
  final String? message;
  final List<GrievanceDetails>? data;

  GrievanceDetailsResponse({this.success, this.message, this.data});

  factory GrievanceDetailsResponse.fromJson(Map<String, dynamic> json) {
    return GrievanceDetailsResponse(
      success: json['success'],
      message: json['message'],
      data: json['data'] != null
          ? (json['data'] as List)
                .map((i) => GrievanceDetails.fromJson(i))
                .toList()
          : null,
    );
  }
}

class GrievanceDetails {
  final String? grievanceNo;
  final String? description;
  final String? name;
  final String? fatherName;
  final String? mobileNo;
  final String? email;
  final String? updatedAt;
  final String? categoryName;
  final String? subcategoryName;

  GrievanceDetails({
    this.grievanceNo,
    this.description,
    this.name,
    this.fatherName,
    this.mobileNo,
    this.email,
    this.updatedAt,
    this.categoryName,
    this.subcategoryName,
  });

  factory GrievanceDetails.fromJson(Map<String, dynamic> json) {
    return GrievanceDetails(
      grievanceNo: json['grievance_no']?.toString(),
      description: json['description'],
      name: json['name'],
      fatherName: json['father_name'],
      mobileNo: json['mobile_no']?.toString(),
      email: json['email'],
      updatedAt: json['updated_at'],
      categoryName: json['category_name'],
      subcategoryName: json['subcategory_name'],
    );
  }
}

class GrievanceStatusResponse {
  final bool success;
  final int responseCode;
  final String message;
  final List<GrievanceStatusData>? data;

  GrievanceStatusResponse({
    this.success = false,
    this.responseCode = 0,
    this.message = "",
    this.data,
  });

  factory GrievanceStatusResponse.fromJson(Map<String, dynamic> json) {
    return GrievanceStatusResponse(
      success: json['success'] ?? false,
      responseCode: json['responseCode'] ?? 0,
      message: json['message'] ?? "",
      data: json['data'] != null
          ? (json['data'] as List)
                .map((i) => GrievanceStatusData.fromJson(i))
                .toList()
          : [],
    );
  }
}

class GrievanceStatusData {
  final String? ulbName;
  final String? mohallaName;
  final String? zoneName;
  final String? wardName;
  final String? complaintId;
  final String? complaintDate;
  final String? categoryName;
  final String? subCategoryName;
  final String? landmark;
  final String? complaintDesc;
  final String? name;
  final String? fatherHusbandName;
  final String? mobile;
  final String? email;
  final String? address1;
  final String? address2;
  final String? assignedEmpName;
  final String? assignedEmpMobile;
  final String? assignedEmpPost;
  final String? assignedOffName;
  final String? assignedOffMobile;
  final String? assignedOffPost;
  final String? status;
  final String? closeDate;
  final String? closeRemark;
  final String? complaintTime;
  final String? closeTime;
  final int? reComplain;
  final String? dueDate;

  GrievanceStatusData({
    this.ulbName,
    this.mohallaName,
    this.zoneName,
    this.wardName,
    this.complaintId,
    this.complaintDate,
    this.categoryName,
    this.subCategoryName,
    this.landmark,
    this.complaintDesc,
    this.name,
    this.fatherHusbandName,
    this.mobile,
    this.email,
    this.address1,
    this.address2,
    this.assignedEmpName,
    this.assignedEmpMobile,
    this.assignedEmpPost,
    this.assignedOffName,
    this.assignedOffMobile,
    this.assignedOffPost,
    this.status,
    this.closeDate,
    this.closeRemark,
    this.complaintTime,
    this.closeTime,
    this.reComplain,
    this.dueDate,
  });

  factory GrievanceStatusData.fromJson(Map<String, dynamic> json) {
    return GrievanceStatusData(
      ulbName: json['ulbName'],
      mohallaName: json['mohallaName'],
      zoneName: json['zoneName'],
      wardName: json['wardName'],
      complaintId: json['complaintId']?.toString(),
      complaintDate: json['complaintDate'],
      categoryName: json['categoryName'],
      subCategoryName: json['subCategoryName'],
      landmark: json['landmark'],
      complaintDesc: json['complaintDesc'],
      name: json['name'],
      fatherHusbandName: json['fatherHusbandName'],
      mobile: json['mobile']?.toString(),
      email: json['email'],
      address1: json['address1'],
      address2: json['address2'],
      assignedEmpName: json['assignedEmpName'],
      assignedEmpMobile: json['assignedEmpMobile']?.toString(),
      assignedEmpPost: json['assignedEmpPost'],
      assignedOffName: json['assignedOffName'],
      assignedOffMobile: json['assignedOffMobile']?.toString(),
      assignedOffPost: json['assignedOffPost'],
      status: json['status'],
      closeDate: json['closeDate'],
      closeRemark: json['closeRemark'],
      complaintTime: json['complaintTime'],
      closeTime: json['closeTime'],
      reComplain: json['reComplain'],
      dueDate: json['dueDate'],
    );
  }
}

class SignUpResponse {
  final String? message;
  final bool? status;
  final int? responseCode;

  SignUpResponse({this.message, this.status, this.responseCode});

  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    return SignUpResponse(
      message: json['message'],
      status: json['status'],
      responseCode: json['responseCode'],
    );
  }
}

class VerifyOtpMailResponse {
  final String? message;
  final bool? status;
  final int? responseCode;

  VerifyOtpMailResponse({this.message, this.status, this.responseCode});

  factory VerifyOtpMailResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpMailResponse(
      message: json['message'],
      status: json['status'],
      responseCode: json['responseCode'],
    );
  }
}

class SignupCity {
  final int id;
  final String name;

  SignupCity({required this.id, required this.name});

  factory SignupCity.fromJson(Map<String, dynamic> json) {
    return SignupCity(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class CaptchaResponse {
  final String captchaId;
  final String captchaImage;

  CaptchaResponse({required this.captchaId, required this.captchaImage});

  factory CaptchaResponse.fromJson(Map<String, dynamic> json) {
    return CaptchaResponse(
      captchaId: json['captchaId'] as String,
      captchaImage: json['captchaImage'] as String,
    );
  }
}

class CitizenRegisterResponse {
  final bool? status;
  final int? responseCode;
  final String? message;
  final bool? mobileOtpRequired;
  final bool? emailOtpRequired;
  final bool? emailOtpSent;
  final bool? registrationComplete;
  final bool? alreadyOnEnagarsewa;
  final String? enagarMessage;

  CitizenRegisterResponse({
    this.status,
    this.responseCode,
    this.message,
    this.mobileOtpRequired,
    this.emailOtpRequired,
    this.emailOtpSent,
    this.registrationComplete,
    this.alreadyOnEnagarsewa,
    this.enagarMessage,
  });

  factory CitizenRegisterResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return CitizenRegisterResponse(
      status: json['status'],
      responseCode: json['responseCode'],
      message: json['message'],
      mobileOtpRequired: data?['mobile_otp_required'],
      emailOtpRequired: data?['email_otp_required'],
      emailOtpSent: data?['email_otp_sent'],
      registrationComplete: data?['registration_complete'],
      alreadyOnEnagarsewa: data?['already_on_enagarsewa'],
      enagarMessage: data?['enagar_message'],
    );
  }
}

class ResendSignupOtpResponse {
  final bool? status;
  final int? responseCode;
  final String? message;
  final bool? mobileOtpSent;
  final bool? emailOtpSent;
  final String? emailMasked;
  final bool? mobileOtpRequired;
  final bool? emailOtpRequired;
  final bool? registrationComplete;
  final String? enagarMessage;

  ResendSignupOtpResponse({
    this.status,
    this.responseCode,
    this.message,
    this.mobileOtpSent,
    this.emailOtpSent,
    this.emailMasked,
    this.mobileOtpRequired,
    this.emailOtpRequired,
    this.registrationComplete,
    this.enagarMessage,
  });

  factory ResendSignupOtpResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return ResendSignupOtpResponse(
      status: json['status'],
      responseCode: json['responseCode'],
      message: json['message'],
      mobileOtpSent: data?['mobile_otp_sent'],
      emailOtpSent: data?['email_otp_sent'],
      emailMasked: data?['email_masked'],
      mobileOtpRequired: data?['mobile_otp_required'],
      emailOtpRequired: data?['email_otp_required'],
      registrationComplete: data?['registration_complete'],
      enagarMessage: data?['enagar_message'],
    );
  }
}

class CitizenVerifyOtpResponse {
  final bool? status;
  final int? responseCode;
  final String? message;
  final bool? mobileVerified;
  final bool? emailVerified;
  final bool? mobileOtpRequired;
  final bool? emailOtpRequired;
  final bool? registrationComplete;
  final String? enagarMessage;

  CitizenVerifyOtpResponse({
    this.status,
    this.responseCode,
    this.message,
    this.mobileVerified,
    this.emailVerified,
    this.mobileOtpRequired,
    this.emailOtpRequired,
    this.registrationComplete,
    this.enagarMessage,
  });

  factory CitizenVerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return CitizenVerifyOtpResponse(
      status: json['status'],
      responseCode: json['responseCode'],
      message: json['message'],
      mobileVerified: data?['mobile_verified'],
      emailVerified: data?['email_verified'],
      mobileOtpRequired: data?['mobile_otp_required'],
      emailOtpRequired: data?['email_otp_required'],
      registrationComplete: data?['registration_complete'],
      enagarMessage: data?['enagar_message'],
    );
  }
}

class ArvChangeHistoryResponse {
  final bool? success;
  final int? responseCode;
  final String? message;
  final List<ArvChangeHistoryItem>? data;

  ArvChangeHistoryResponse({
    this.success,
    this.responseCode,
    this.message,
    this.data,
  });

  factory ArvChangeHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ArvChangeHistoryResponse(
      success: json['success'],
      responseCode: json['responseCode'],
      message: json['message'],
      data: json['data'] != null
          ? (json['data'] as List)
                .map((i) => ArvChangeHistoryItem.fromJson(i))
                .toList()
          : null,
    );
  }
}

class ArvChangeHistoryItem {
  final int? ulbId;
  final String? propertyId;
  final String? ownerName;
  final String? fatherHusbandName;
  final String? houseNo;
  final String? oldPropertyId;
  final String? address;
  final num? oldArv;
  final num? currentArv;
  final String? ulbLanguage;
  final String? arvChangeDate;

  ArvChangeHistoryItem({
    this.ulbId,
    this.propertyId,
    this.ownerName,
    this.fatherHusbandName,
    this.houseNo,
    this.oldPropertyId,
    this.address,
    this.oldArv,
    this.currentArv,
    this.ulbLanguage,
    this.arvChangeDate,
  });

  factory ArvChangeHistoryItem.fromJson(Map<String, dynamic> json) {
    return ArvChangeHistoryItem(
      ulbId: json['ulbId'],
      propertyId: json['propertyId']?.toString(),
      ownerName: json['ownerName']?.toString(),
      fatherHusbandName: json['fatherHusbandName']?.toString(),
      houseNo: json['houseNo']?.toString(),
      oldPropertyId: json['oldPropertyId']?.toString(),
      address: json['address']?.toString(),
      oldArv: json['oldArv'],
      currentArv: json['currentArv'],
      ulbLanguage: json['ulbLanguage']?.toString(),
      arvChangeDate: json['arvChangeDate']?.toString(),
    );
  }
}
