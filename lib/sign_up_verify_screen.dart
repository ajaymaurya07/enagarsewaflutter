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
  final _mobileOtpController = TextEditingController();
  final _emailOtpController = TextEditingController();

  String? _captchaId;
  Uint8List? _captchaImageBytes;
  bool _loadingCaptcha = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Set once the resend_otp call succeeds and OTP entry is shown.
  bool _showOtpStep = false;
  bool _mobileOtpRequired = false;
  bool _emailOtpRequired = false;
  String? _mobile;
  String? _otpInfoMessage;
  bool _isVerifyingOtp = false;
  String? _otpError;

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
    _mobileOtpController.dispose();
    _emailOtpController.dispose();
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

      _startOtpStep(
        mobile: mobile,
        message: result.message,
        mobileOtpRequired: result.mobileOtpRequired == true,
        emailOtpRequired: result.emailOtpRequired == true,
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

  void _startOtpStep({
    required String mobile,
    required String? message,
    required bool mobileOtpRequired,
    required bool emailOtpRequired,
  }) {
    if (!mobileOtpRequired && !emailOtpRequired) {
      showSuccessAndGoBack(
        message ?? 'Registration Successful',
        title: 'Registration Successful',
      );
      return;
    }

    setState(() {
      _showOtpStep = true;
      _mobile = mobile;
      _mobileOtpRequired = mobileOtpRequired;
      _emailOtpRequired = emailOtpRequired;
      _otpInfoMessage = message;
      _otpError = null;
    });
  }

  Future<void> _verifyOtps() async {
    final mobileOtp = _mobileOtpController.text.trim();
    final emailOtp = _emailOtpController.text.trim();

    if (_mobileOtpRequired && mobileOtp.isEmpty) {
      setState(() => _otpError = 'Please enter the mobile OTP');
      return;
    }
    if (_emailOtpRequired && emailOtp.isEmpty) {
      setState(() => _otpError = 'Please enter the email OTP');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _otpError = null;
    });

    try {
      if (_mobileOtpRequired) {
        final mobileResult = await ApiService.verifyCitizenOtp(
          mobileNo: _mobile!,
          otp: mobileOtp,
        );
        if (mobileResult.status != true) {
          if (!mounted) return;
          setState(() {
            _isVerifyingOtp = false;
            _otpError = mobileResult.message ?? 'Mobile OTP verification failed.';
          });
          return;
        }
      }

      if (_emailOtpRequired) {
        final emailResult = await ApiService.verifyOtpEmail(
          email: widget.email,
          otp: emailOtp,
        );
        if (emailResult.status != true) {
          if (!mounted) return;
          setState(() {
            _isVerifyingOtp = false;
            _otpError = emailResult.message ?? 'Email OTP verification failed.';
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      showSuccessAndGoBack(
        'Registration Successful',
        title: 'Registration Successful',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingOtp = false;
        _otpError = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to verify OTP. Please try again.',
        );
      });
    }
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
          child: _showOtpStep ? _buildOtpStep() : _buildCaptchaStep(),
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

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.mark_email_read_rounded,
            color: Color(0xFFE67514), size: 40),
        const SizedBox(height: 16),
        Text(
          _otpInfoMessage ?? 'Enter the OTP(s) below to complete registration.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
        ),
        if (_mobileOtpRequired) ...[
          const SizedBox(height: 24),
          Text('Mobile OTP',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('OTP sent to $_mobile',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextField(
            controller: _mobileOtpController,
            enabled: !_isVerifyingOtp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: GoogleFonts.poppins(
                fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.bold),
            decoration: otpFlowInputDecoration(hint: '------')
                .copyWith(counterText: ''),
          ),
        ],
        if (_emailOtpRequired) ...[
          const SizedBox(height: 24),
          Text('Email OTP',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('OTP sent to ${widget.email}',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextField(
            controller: _emailOtpController,
            enabled: !_isVerifyingOtp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: GoogleFonts.poppins(
                fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.bold),
            decoration: otpFlowInputDecoration(hint: '------')
                .copyWith(counterText: ''),
          ),
        ],
        if (_otpError != null) ...[
          const SizedBox(height: 8),
          Text(_otpError!,
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
            onPressed: _isVerifyingOtp ? null : _verifyOtps,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE67514),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isVerifyingOtp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : Text('Verify OTP',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
