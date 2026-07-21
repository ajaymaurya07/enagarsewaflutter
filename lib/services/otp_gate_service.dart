import 'package:flutter/material.dart';
import 'api_service.dart';
import 'database_service.dart';
import '../widgets/otp_verification_sheet.dart';

/// Handles the "responseCode: 12" (expired/incorrect session token) recovery
/// flow shared by all Property Tax Assessment / Reassessment APIs: send an
/// OTP to the property's registered mobile number, verify it, and let the
/// caller retry the original request once verification succeeds.
class OtpGateService {
  /// Runs [call] and, if the response's responseCode is 12 (expired/incorrect
  /// session token), sends+verifies an OTP for [propertyId]/[mobileNo] and
  /// retries [call] once on success. Otherwise returns the original response.
  static Future<T> guard<T>({
    required Future<T> Function() call,
    required int? Function(T response) responseCode,
    required String propertyId,
    required String mobileNo,
  }) async {
    final response = await call();
    if (responseCode(response) != 12) return response;

    // debugPrint('[OtpGate] responseCode=12 -> starting OTP verify flow (propertyId=$propertyId).');
    final verified = await verify(propertyId: propertyId, mobileNo: mobileNo);
    // debugPrint('[OtpGate] verify() -> $verified');
    if (!verified) return response;

    // debugPrint('[OtpGate] Retrying original call after successful OTP verify.');
    return await call();
  }

  static Future<bool> verify({
    required String propertyId,
    required String mobileNo,
  }) async {
    final context = ApiService.navigatorKey.currentContext;
    if (context == null) return false;

    // If the caller doesn't have a clean propertyId/mobileNo pair in
    // context (e.g. a brand-new assessment before any property exists, or
    // a list-fetch call with no single property), fall back to the first
    // property stored locally and use its propertyId + mobile number
    // together so the OTP flow can still proceed.
    var resolvedPropertyId = propertyId;
    var resolvedMobileNo = mobileNo;
    if (resolvedPropertyId.isEmpty || resolvedMobileNo.isEmpty) {
      final properties = await DatabaseService.getAllProperties();
      if (properties.isNotEmpty) {
        final fallback = properties.first;
        resolvedPropertyId = fallback.propertyId;
        resolvedMobileNo = fallback.phoneNumber;
      }
    }
    if (resolvedPropertyId.isEmpty || resolvedMobileNo.isEmpty) return false;

    try {
      final sendRes = await ApiService.sendOtp(resolvedMobileNo, resolvedPropertyId);
      if (sendRes.success != true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sendRes.message ?? 'Failed to send OTP')),
          );
        }
        return false;
      }

      if (!context.mounted) return false;
      // debugPrint('[OtpGate] Showing OTP verification sheet.');
      final result = await showOtpVerificationSheet(
        context: context,
        propertyId: resolvedPropertyId,
        mobileNo: resolvedMobileNo,
        maskedMobile: sendRes.maskedMobile ?? resolvedMobileNo,
      );
      // debugPrint('[OtpGate] OTP verification sheet closed -> $result');
      return result;
    } catch (e) {
      // debugPrint('[OtpGate] verify() error -> $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.getUserFriendlyErrorMessage(
                e,
                fallbackMessage: 'Unable to send OTP right now. Please try again.',
              ),
            ),
          ),
        );
      }
      return false;
    }
  }
}
