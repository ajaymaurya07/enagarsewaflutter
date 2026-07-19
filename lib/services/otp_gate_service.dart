import 'package:flutter/material.dart';
import 'api_service.dart';
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

    final verified = await verify(propertyId: propertyId, mobileNo: mobileNo);
    if (!verified) return response;

    return await call();
  }

  static Future<bool> verify({
    required String propertyId,
    required String mobileNo,
  }) async {
    final context = ApiService.navigatorKey.currentContext;
    if (context == null || mobileNo.isEmpty || propertyId.isEmpty) return false;

    try {
      final sendRes = await ApiService.sendOtp(mobileNo, propertyId);
      if (sendRes.success != true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sendRes.message ?? 'Failed to send OTP')),
          );
        }
        return false;
      }

      if (!context.mounted) return false;
      return await showOtpVerificationSheet(
        context: context,
        propertyId: propertyId,
        mobileNo: mobileNo,
        maskedMobile: sendRes.maskedMobile ?? mobileNo,
      );
    } catch (e) {
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
