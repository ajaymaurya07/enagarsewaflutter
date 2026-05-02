import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'widgets/info_label.dart';
import 'help/forgot_password_help.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameController = TextEditingController();
  final RegExp _passwordPattern = RegExp(
    r'^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=!])(?=\S+$).{6,}$',
  );
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      _showError('Please enter your email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.forgotPasswordSendOtp(username);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.status) {
        _showResetBottomSheet(username);
      } else {
        _showError(
          response.message.isNotEmpty ? response.message : 'Failed to send OTP',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to send OTP right now. Please try again.',
        ),
      );
    }
  }

  void _showResetBottomSheet(String username) {
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isResetting = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
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
                      const SizedBox(height: 20),

                      Text(
                        'Reset Password',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OTP sent to $username',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Error message inline
                      if (sheetError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sheetError!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // OTP Field
                      InfoLabel(
                        label: 'Enter OTP',
                        helpTitle: ForgotPasswordHelp.otpTitle,
                        helpMessage: ForgotPasswordHelp.otpMessage,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          letterSpacing: 4,
                        ),
                        decoration: _sheetInputDecoration(
                          hint: '------',
                          icon: Icons.pin_outlined,
                        ).copyWith(counterText: ''),
                      ),
                      const SizedBox(height: 20),

                      // New Password
                      InfoLabel(
                        label: 'New Password',
                        helpTitle: ForgotPasswordHelp.newPasswordTitle,
                        helpMessage: ForgotPasswordHelp.newPasswordMessage,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration:
                            _sheetInputDecoration(
                              hint: 'Enter new password',
                              icon: Icons.lock_outlined,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureNew
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                                onPressed: () => setSheetState(
                                  () => obscureNew = !obscureNew,
                                ),
                              ),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Min 6 chars \u2022 Uppercase \u2022 Lowercase \u2022 Number \u2022 Special (@#\$%^&+=!)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      InfoLabel(
                        label: 'Confirm Password',
                        helpTitle: ForgotPasswordHelp.confirmPasswordTitle,
                        helpMessage: ForgotPasswordHelp.confirmPasswordMessage,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration:
                            _sheetInputDecoration(
                              hint: 'Re-enter new password',
                              icon: Icons.lock_outlined,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                                onPressed: () => setSheetState(
                                  () => obscureConfirm = !obscureConfirm,
                                ),
                              ),
                            ),
                      ),
                      const SizedBox(height: 28),

                      // Reset Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isResetting
                              ? null
                              : () async {
                                  final sheetNavigator = Navigator.of(context);
                                  final otp = otpController.text.trim();
                                  final newPass = newPasswordController.text;
                                  final confirmPass =
                                      confirmPasswordController.text;

                                  if (otp.isEmpty) {
                                    setSheetState(
                                      () => sheetError = 'Please enter OTP',
                                    );
                                    return;
                                  }
                                  if (otp.length < 4) {
                                    setSheetState(
                                      () =>
                                          sheetError = 'Please enter valid OTP',
                                    );
                                    return;
                                  }
                                  if (newPass.isEmpty) {
                                    setSheetState(
                                      () => sheetError =
                                          'Please enter new password',
                                    );
                                    return;
                                  }
                                  if (!_passwordPattern.hasMatch(newPass)) {
                                    setSheetState(
                                      () => sheetError =
                                          'Password must be at least 6 characters with uppercase, lowercase, number & special character (@#\$%^&+=!)',
                                    );
                                    return;
                                  }
                                  if (newPass != confirmPass) {
                                    setSheetState(
                                      () =>
                                          sheetError = 'Passwords do not match',
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isResetting = true;
                                    sheetError = null;
                                  });

                                  try {
                                    final response =
                                        await ApiService.resetPassword(
                                          username: username,
                                          otp: otp,
                                          newPassword: newPass,
                                          confirmPassword: confirmPass,
                                        );

                                    if (!mounted) return;
                                    setSheetState(() => isResetting = false);

                                    if (response.status) {
                                      sheetNavigator.pop();
                                      _showSuccessAndGoBack(
                                        response.message.isNotEmpty
                                            ? response.message
                                            : 'Password reset successfully!',
                                      );
                                    } else {
                                      final attemptsMsg =
                                          response.attemptsLeft != null
                                          ? ' (${response.attemptsLeft} attempts left)'
                                          : '';
                                      setSheetState(
                                        () => sheetError =
                                            (response.message.isNotEmpty
                                                ? response.message
                                                : 'Failed to reset password') +
                                            attemptsMsg,
                                      );
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    setSheetState(() {
                                      isResetting = false;
                                      sheetError =
                                          ApiService.getUserFriendlyErrorMessage(
                                        e,
                                        fallbackMessage:
                                            'Unable to reset password right now. Please try again.',
                                      );
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE67514),
                            disabledBackgroundColor: const Color(
                              0xFFE67514,
                            ).withValues(alpha: 0.6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isResetting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Verify & Reset Password',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Cancel
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: isResetting
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessAndGoBack(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text('Success', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back
            },
            child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFE67514))),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  InputDecoration _sheetInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: const Color(0xFFE67514), size: 20),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFFE67514),
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Forgot Password',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE67514).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 40,
                            color: Color(0xFFE67514),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset your password',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter your registered email to receive an OTP',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Email Field
                              const InfoLabel(
                                label: 'Email',
                                helpTitle: ForgotPasswordHelp.emailTitle,
                                helpMessage: ForgotPasswordHelp.emailMessage,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _usernameController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Enter your email',
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: Color(0xFFE67514),
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE67514),
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Send OTP Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSendOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE67514),
                                    disabledBackgroundColor: const Color(
                                      0xFFE67514,
                                    ).withValues(alpha: 0.6),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          'Send OTP',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        // Back to login
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Back to Login',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFE67514),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
