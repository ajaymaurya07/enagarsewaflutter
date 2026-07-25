import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/api_service.dart';
import 'widgets/signup_otp_flow.dart';

/// Full-screen captcha + mobile verification step shown when the register
/// API responds with responseCode 0. Replaces the sign-up screen so the
/// user can (re)confirm their mobile number and fill the captcha to resend
/// the OTP; the OTP verification flow that follows is identical to the one
/// used from the sign-up screen itself.
class SignUpVerifyScreen extends StatefulWidget {
  final String initialMobile;
  final String email;
  final String? initialMessage;

  const SignUpVerifyScreen({
    super.key,
    required this.initialMobile,
    required this.email,
    this.initialMessage,
  });

  @override
  State<SignUpVerifyScreen> createState() => _SignUpVerifyScreenState();
}

class _SignUpVerifyScreenState extends State<SignUpVerifyScreen>
    with SignupOtpFlowMixin<SignUpVerifyScreen> {
  late final _mobileController =
      TextEditingController(text: widget.initialMobile);
  final _captchaController = TextEditingController();

  String? _captchaId;
  Uint8List? _captchaImageBytes;
  bool _loadingCaptcha = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialMessage;
    _loadCaptcha();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    setState(() {
      _loadingCaptcha = true;
      _captchaController.clear();
    });
    try {
      final captcha = await ApiService.getSignupCaptcha();
      if (!mounted) return;
      setState(() {
        _captchaId = captcha.captchaId;
        _captchaImageBytes = base64Decode(captcha.captchaImage);
        _loadingCaptcha = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _captchaId = null;
        _captchaImageBytes = null;
        _loadingCaptcha = false;
      });
    }
  }

  Future<void> _submit() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty || mobile.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10 digit mobile number');
      return;
    }
    final captcha = _captchaController.text.trim();
    if (captcha.isEmpty) {
      setState(() => _errorMessage = 'Please enter the captcha text');
      return;
    }
    if (_captchaId == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.resendSignupOtp(
        mobileNo: mobile,
        captchaId: _captchaId!,
        captcha: captcha,
      );

debugPrint("status: ${result.status}");
debugPrint("responseCode: ${result.responseCode}");
debugPrint("message: ${result.message}");
debugPrint("mobileOtpSent: ${result.mobileOtpSent}");
debugPrint("emailOtpSent: ${result.emailOtpSent}");
debugPrint("registrationComplete: ${result.registrationComplete}");
      if (result.responseCode == 9) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = result.message ?? 'Invalid captcha. Please try again.';
        });
        _loadCaptcha();
        return;
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result.status != true) {
        _loadCaptcha();
        showMessageDialog(
          title: 'Registration Failed',
          message: result.message ?? 'Registration failed. Please try again.',
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red.shade600,
        );
        return;
      }

      await _handleOtpSequence(
        mobile: mobile,
        mobileOtpSent: result.mobileOtpSent == true,
        emailOtpSent: result.emailOtpSent == true,
        message: result.message,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _loadCaptcha();
      showMessageDialog(
        title: 'Error',
        message: ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to resend OTP right now. Please try again.',
        ),
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red.shade600,
      );
    }
  }

  /// Drives the mobile -> email OTP dialogs based on what the resend_otp
  /// call reported it actually sent. Mirrors the sign-up screen's flow:
  /// - mobile OTP sent -> show the mobile OTP sheet first.
  ///   - if an email OTP was also sent, follow with the email OTP sheet and
  ///     report "Registration Successful" once that's verified.
  ///   - otherwise report the mobile verification's own completion message.
  /// - only an email OTP sent -> show just the email OTP sheet.
  /// - neither sent -> registration was already complete.
  Future<void> _handleOtpSequence({
    required String mobile,
    required bool mobileOtpSent,
    required bool emailOtpSent,
    required String? message,
  }) async {
    if (mobileOtpSent) {
      if (!mounted) return;
      final mobileOtpResult = await showOtpBottomSheet(
        title: 'Verify Mobile OTP',
        subtitle: message ?? 'OTP sent to your mobile number',
        highlightText: mobile,
        mobileNo: mobile,
        onVerify: (otp) => ApiService.verifyCitizenOtp(
          mobileNo: mobile,
          otp: otp,
        ),
      );
      if (mobileOtpResult == null) return;

      if (!emailOtpSent) {
        if (!mounted) return;
        showSuccessAndGoBack(
          mobileOtpResult.message ?? 'Registration complete!',
        );
        return;
      }
    }

    if (emailOtpSent) {
      if (!mounted) return;
      final emailOtpResult = await showOtpBottomSheet(
        title: 'Verify Email OTP',
        subtitle: 'OTP sent to your email',
        highlightText: widget.email,
        mobileNo: mobile,
        onVerify: (otp) => ApiService.verifyOtpEmail(
          email: widget.email,
          otp: otp,
        ),
      );
      if (emailOtpResult == null) return;

      if (!mounted) return;
      showSuccessAndGoBack(
        emailOtpResult.message ?? 'Registration Successful',
        title: 'Registration Successful',
      );
      return;
    }

    if (!mounted) return;
    showSuccessAndGoBack(
      message ?? 'Registration Successful',
      title: 'Registration Successful',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text('Verify Mobile Number',
            style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildCaptchaStep(),
        ),
      ),
    );
  }

  Widget _buildCaptchaStep() {
    return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_rounded,
                  color: Color(0xFFE67514), size: 40),
              const SizedBox(height: 16),
              Text('Confirm your mobile number and fill the captcha below to continue.',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              Text('Mobile No.',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _mobileController,
                enabled: !_isSubmitting,
                maxLength: 10,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: otpFlowInputDecoration(
                  hint: 'Enter 10 digit mobile number',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 16),
              Text('Captcha',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
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
                    child: _loadingCaptcha
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
                        : _captchaImageBytes != null
                            ? Image.memory(_captchaImageBytes!,
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
                    onPressed: _loadingCaptcha ? null : _loadCaptcha,
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFFE67514), size: 24),
                    tooltip: 'Refresh Captcha',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captchaController,
                enabled: !_isSubmitting,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: otpFlowInputDecoration(hint: 'Enter image text')
                    .copyWith(counterText: ''),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!,
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
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67514),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)))
                      : Text('Submit',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
    );
  }
}
