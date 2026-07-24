import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'search_property_screen.dart';
import 'services/api_service.dart';

/// Modern OTP-based login screen.
///
/// Step 1: citizen enters their mobile number and requests an OTP.
/// Step 2: citizen enters the 6-digit OTP. The resend countdown is driven
/// entirely by `expiresInSeconds` returned from the send/resend OTP API —
/// it is never hardcoded, so the timer always matches what the backend
/// actually enforces.
class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

enum _OtpLoginStep { mobileEntry, otpEntry }

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  static const Color _primaryColor = Color(0xFFE67514);

  final _mobileController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final FocusNode _mobileFocusNode = FocusNode();

  _OtpLoginStep _step = _OtpLoginStep.mobileEntry;
  bool _isSendingOtp = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _mobileError;
  String? _otpError;
  String? _maskedMobile;

  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _mobileController.dispose();
    _mobileFocusNode.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = seconds);
    if (seconds <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  String get _formattedCountdown {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _isValidMobile =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(_mobileController.text.trim());

  Future<void> _handleSendOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      setState(() => _mobileError = 'Please enter your mobile number');
      return;
    }
    if (!_isValidMobile) {
      setState(() => _mobileError = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _mobileError = null;
      _isSendingOtp = true;
    });

    try {
      final response = await ApiService.otpLoginSendOtp(mobile);
      if (!mounted) return;

      if (response.status) {
        setState(() {
          _isSendingOtp = false;
          _maskedMobile = response.maskedMobile ?? mobile;
          _step = _OtpLoginStep.otpEntry;
          _otpError = null;
        });
        _startCountdown(response.expiresInSeconds ?? 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNodes.first.requestFocus();
        });
      } else {
        setState(() {
          _isSendingOtp = false;
          _mobileError = response.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _mobileError = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to send OTP. Please try again.',
        );
      });
    }
  }

  Future<void> _handleResendOtp() async {
    if (_secondsRemaining > 0 || _isResending) return;
    final mobile = _mobileController.text.trim();

    setState(() {
      _isResending = true;
      _otpError = null;
    });

    try {
      final response = await ApiService.otpLoginSendOtp(mobile);
      if (!mounted) return;

      if (response.status) {
        for (final c in _otpControllers) {
          c.clear();
        }
        setState(() {
          _isResending = false;
          _maskedMobile = response.maskedMobile ?? _maskedMobile;
        });
        _startCountdown(response.expiresInSeconds ?? 0);
        _otpFocusNodes.first.requestFocus();
        _showSuccess('OTP has been resent');
      } else {
        setState(() {
          _isResending = false;
          _otpError = response.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _otpError = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to resend OTP. Please try again.',
        );
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _otpError = 'Please enter the complete 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
      _otpError = null;
    });

    try {
      final mobile = _mobileController.text.trim();
      final response = await ApiService.otpLoginVerifyOtp(mobile, otp);
      if (!mounted) return;

      if (response.status) {
        _countdownTimer?.cancel();
        _showSuccess(response.message.isNotEmpty ? response.message : 'Login successful');
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (context) => const SearchPropertyScreen()),
        );
      } else {
        setState(() {
          _isVerifying = false;
          _otpError = response.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _otpError = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to verify OTP. Please try again.',
        );
      });
    }
  }

  void _handleChangeNumber() {
    _countdownTimer?.cancel();
    for (final c in _otpControllers) {
      c.clear();
    }
    setState(() {
      _step = _OtpLoginStep.mobileEntry;
      _otpError = null;
      _secondsRemaining = 0;
    });
  }

  void _onOtpDigitChanged(int index, String value) {
    if (_otpError != null) setState(() => _otpError = null);

    if (value.length > 1) {
      // Handle pasted OTP across the boxes starting at `index`.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < digits.length && index + i < 6; i++) {
        _otpControllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _otpFocusNodes[nextIndex].requestFocus();
      if (index + digits.length >= 6) {
        FocusScope.of(context).unfocus();
      }
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isNotEmpty && index == 5) {
      FocusScope.of(context).unfocus();
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/e_nagar_seva_logo.png',
                  width: 130,
                  height: 130,
                ),
                const SizedBox(height: 28),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _step == _OtpLoginStep.mobileEntry
                          ? _buildMobileEntryStep()
                          : _buildOtpEntryStep(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileEntryStep() {
    return Column(
      key: const ValueKey('mobile-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Login with OTP',
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF333333)),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your registered mobile number to receive an OTP',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 28),
        Text(
          'Mobile Number',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF333333)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _mobileController,
          focusNode: _mobileFocusNode,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(fontSize: 15),
          onChanged: (_) {
            if (_mobileError != null) setState(() => _mobileError = null);
          },
          onSubmitted: (_) => _isSendingOtp ? null : _handleSendOtp(),
          decoration: InputDecoration(
            hintText: 'Enter 10-digit mobile number',
            counterText: '',
            errorText: _mobileError,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
            prefixIcon: const Icon(Icons.phone_android_outlined, color: _primaryColor, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isSendingOtp ? null : _handleSendOtp,
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              disabledBackgroundColor: _primaryColor.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSendingOtp
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text('Send OTP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpEntryStep() {
    final canResend = _secondsRemaining <= 0;
    return Column(
      key: const ValueKey('otp-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Verify OTP',
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF333333)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'OTP sent to ${_maskedMobile ?? _mobileController.text}',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
            TextButton(
              onPressed: (_isVerifying || _isResending) ? null : _handleChangeNumber,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              child: Text(
                'Change',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) => _buildOtpDigitBox(index)),
        ),
        if (_otpError != null) ...[
          const SizedBox(height: 10),
          Text(_otpError!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade600)),
        ],
        const SizedBox(height: 18),
        Center(
          child: canResend
              ? TextButton(
                  onPressed: _isResending ? null : _handleResendOtp,
                  child: _isResending
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
                        )
                      : Text(
                          'Resend OTP',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryColor),
                        ),
                )
              : Text.rich(
                  TextSpan(
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                    children: [
                      const TextSpan(text: 'Resend OTP in '),
                      TextSpan(
                        text: _formattedCountdown,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _primaryColor),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isVerifying ? null : _handleVerifyOtp,
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              disabledBackgroundColor: _primaryColor.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isVerifying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text('Verify OTP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpDigitBox(int index) {
    return SizedBox(
      width: 44,
      height: 52,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) => _onOtpDigitChanged(index, value),
        onTap: () {
          _otpControllers[index].selection = TextSelection.fromPosition(
            TextPosition(offset: _otpControllers[index].text.length),
          );
        },
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
