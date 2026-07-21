import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

/// Result of a verified OTP step, shared between the sign-up screen and the
/// captcha/mobile verification screen.
class OtpResult {
  final String? message;
  final bool registrationComplete;
  final bool emailOtpRequired;

  OtpResult({
    this.message,
    required this.registrationComplete,
    required this.emailOtpRequired,
  });
}

/// Shared OTP / captcha-challenge UI used by the sign-up flow: the mobile &
/// email OTP bottom sheets, generic message dialogs, the "registration
/// complete" dialog, and the captcha-challenge dialog used to resend OTPs.
mixin SignupOtpFlowMixin<T extends StatefulWidget> on State<T> {
  InputDecoration otpFlowInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE67514), width: 1.5),
      ),
    );
  }

  /// Shows a dialog that fetches a fresh captcha and lets the user fill it
  /// in, returning the (captchaId, captcha) pair on submit or null if the
  /// user cancels. Used for the "captcha required" (responseCode 9) resend
  /// flow triggered from within the OTP bottom sheet.
  Future<({String captchaId, String captcha})?> showCaptchaChallengeDialog({
    String? errorMessage,
  }) async {
    String? dialogCaptchaId;
    Uint8List? dialogImageBytes;
    bool dialogLoading = false;
    bool started = false;
    String? dialogError = errorMessage;
    final controller = TextEditingController();

    return showDialog<({String captchaId, String captcha})?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> loadCaptcha() async {
            setDialogState(() {
              dialogLoading = true;
              dialogError = null;
            });
            try {
              final captcha = await ApiService.getSignupCaptcha();
              if (!ctx.mounted) return;
              setDialogState(() {
                dialogCaptchaId = captcha.captchaId;
                dialogImageBytes = base64Decode(captcha.captchaImage);
                dialogLoading = false;
              });
            } catch (e) {
              if (!ctx.mounted) return;
              setDialogState(() {
                dialogCaptchaId = null;
                dialogImageBytes = null;
                dialogLoading = false;
              });
            }
          }

          if (!started) {
            started = true;
            Future.microtask(loadCaptcha);
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.security_rounded,
                    color: Color(0xFFE67514), size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Captcha Required',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Please fill the captcha shown below to continue.',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF8F9FB),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: dialogLoading
                          ? const SizedBox(
                              width: 120,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFE67514)),
                                  ),
                                ),
                              ),
                            )
                          : dialogImageBytes != null
                              ? Image.memory(dialogImageBytes!,
                                  height: 50, fit: BoxFit.contain)
                              : SizedBox(
                                  width: 120,
                                  child: Center(
                                    child: Text('Failed',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.red.shade400)),
                                  ),
                                ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: dialogLoading ? null : loadCaptcha,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Color(0xFFE67514), size: 24),
                      tooltip: 'Refresh Captcha',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: otpFlowInputDecoration(hint: 'Enter image text')
                      .copyWith(counterText: ''),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 4),
                  Text(dialogError!,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: dialogLoading || dialogCaptchaId == null
                    ? null
                    : () {
                        final text = controller.text.trim();
                        if (text.isEmpty) {
                          setDialogState(
                              () => dialogError = 'Please enter the captcha text');
                          return;
                        }
                        Navigator.pop(
                            ctx, (captchaId: dialogCaptchaId!, captcha: text));
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67514),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Submit',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Repeatedly prompts for a captcha (via [showCaptchaChallengeDialog]) and
  /// invokes [call] with the entered captcha, looping again if the API still
  /// reports responseCode 9 (invalid/expired captcha). Returns null if the
  /// user cancels the dialog at any point.
  Future<R?> promptCaptchaLoop<R>({
    required Future<R> Function(String captchaId, String captcha) call,
    required int? Function(R) responseCode,
    required String? Function(R) message,
    String? initialError,
  }) async {
    String? error = initialError;
    while (true) {
      final entry = await showCaptchaChallengeDialog(errorMessage: error);
      if (entry == null) return null;
      final result = await call(entry.captchaId, entry.captcha);
      if (responseCode(result) == 9) {
        error = message(result) ?? 'Invalid captcha. Please try again.';
        continue;
      }
      return result;
    }
  }

  Future<OtpResult?> showOtpBottomSheet({
    required String title,
    required String subtitle,
    required String highlightText,
    required String mobileNo,
    required Future<dynamic> Function(String otp) onVerify,
  }) {
    final otpController = TextEditingController();
    String? sheetError;
    bool isVerifying = false;
    bool isResending = false;

    return showModalBottomSheet<OtpResult>(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(highlightText,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE67514))),
                  const SizedBox(height: 24),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    enabled: !isVerifying,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '------',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 20,
                          letterSpacing: 6,
                          color: Colors.grey.shade300),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF8F9FB),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE67514), width: 1.5)),
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isVerifying
                          ? null
                          : () async {
                              final otp = otpController.text.trim();
                              if (otp.isEmpty) {
                                setSheetState(
                                    () => sheetError = 'Please enter OTP');
                                return;
                              }
                              setSheetState(() {
                                sheetError = null;
                                isVerifying = true;
                              });
                              try {
                                final result = await onVerify(otp);
                                if (!ctx.mounted) return;

                                bool? status;
                                String? message;
                                bool? regComplete;
                                bool? emailReq;

                                if (result is CitizenVerifyOtpResponse) {
                                  status = result.status;
                                  message = result.message;
                                  regComplete = result.registrationComplete;
                                  emailReq = result.emailOtpRequired;
                                } else if (result is VerifyOtpMailResponse) {
                                  status = result.status;
                                  message = result.message;
                                  regComplete = true;
                                  emailReq = false;
                                }

                                if (status == true) {
                                  Navigator.pop(
                                    ctx,
                                    OtpResult(
                                      message: message,
                                      registrationComplete:
                                          regComplete ?? false,
                                      emailOtpRequired: emailReq ?? false,
                                    ),
                                  );
                                  return;
                                }

                                setSheetState(() {
                                  isVerifying = false;
                                  sheetError = message ??
                                      'OTP verification failed.';
                                });
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setSheetState(() {
                                  isVerifying = false;
                                  sheetError =
                                      ApiService.getUserFriendlyErrorMessage(
                                          e,
                                          fallbackMessage:
                                              'Unable to verify OTP.');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE67514),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          Colors.white)))
                          : Text('Verify OTP',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed:
                          isVerifying ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: isVerifying || isResending
                          ? null
                          : () async {
                              setSheetState(() {
                                isResending = true;
                                sheetError = null;
                              });
                              final resendResult =
                                  await promptCaptchaLoop<
                                      ResendSignupOtpResponse>(
                                call: (captchaId, captcha) =>
                                    ApiService.resendSignupOtp(
                                  mobileNo: mobileNo,
                                  captchaId: captchaId,
                                  captcha: captcha,
                                ),
                                responseCode: (r) => r.responseCode,
                                message: (r) => r.message,
                              );
                              if (!ctx.mounted) return;
                              setSheetState(() => isResending = false);
                              if (resendResult == null) return;

                              if (resendResult.status != true) {
                                setSheetState(() {
                                  sheetError = resendResult.message ??
                                      'Unable to resend OTP. Please try again.';
                                });
                                return;
                              }

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(resendResult.message ??
                                      'OTP resent successfully'),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                            },
                      child: isResending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey.shade500),
                              ),
                            )
                          : Text("Didn't receive OTP? Resend",
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFFE67514),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showMessageDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK',
                style: GoogleFonts.poppins(
                    color: const Color(0xFFE67514),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Shows the "registration complete" dialog, then pops the dialog and the
  /// hosting screen (returning to whatever screen launched the sign-up flow).
  void showSuccessAndGoBack(String message, {String title = 'Registration Complete'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4CAF50), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('OK',
                style: GoogleFonts.poppins(
                    color: const Color(0xFFE67514),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
