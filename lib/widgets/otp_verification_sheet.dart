import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

/// Shows a bottom sheet that sends/verifies an OTP for [mobileNo].
/// Returns true once the OTP has been verified successfully, false if the
/// user cancels or verification could not be completed.
Future<bool> showOtpVerificationSheet({
  required BuildContext context,
  required String propertyId,
  required String mobileNo,
  required String maskedMobile,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => _OtpVerificationSheet(
      propertyId: propertyId,
      mobileNo: mobileNo,
      maskedMobile: maskedMobile,
    ),
  );
  return result ?? false;
}

class _OtpVerificationSheet extends StatefulWidget {
  final String propertyId;
  final String mobileNo;
  final String maskedMobile;

  const _OtpVerificationSheet({
    required this.propertyId,
    required this.mobileNo,
    required this.maskedMobile,
  });

  @override
  State<_OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<_OtpVerificationSheet> {
  static const Color _primaryColor = Color(0xFFE67514);

  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _error = 'Please enter OTP');
      return;
    }
    if (otp.length < 4) {
      setState(() => _error = 'Please enter valid OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      final res = await ApiService.verifyOtp(widget.mobileNo, otp);
      if (!mounted) return;
      if (res.success == true) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isVerifying = false;
          _error = res.message ?? 'Invalid OTP';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to verify OTP. Please try again.',
        );
      });
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      final res = await ApiService.sendOtp(widget.mobileNo, widget.propertyId);
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _error = res.success == true ? null : (res.message ?? 'Failed to resend OTP');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _error = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to resend OTP. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
            const SizedBox(height: 16),
            Text(
              'Verify OTP',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'For security, please verify the OTP sent to ${widget.maskedMobile} to continue.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              style: GoogleFonts.poppins(fontSize: 15),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.pin_outlined),
                hintText: 'Enter OTP',
                errorText: _error,
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primaryColor),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isResending ? null : _handleResend,
                child: Text(
                  _isResending ? 'Resending...' : 'Resend OTP',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isVerifying ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _handleVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'Verify',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
