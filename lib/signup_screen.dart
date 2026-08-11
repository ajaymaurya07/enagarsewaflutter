import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'widgets/info_label.dart';
import 'help/signup_help.dart';
import 'otp_login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (name.length < 3) {
      _showError('Name must be at least 3 characters');
      return;
    }
    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    if (_sanitizePhone(phone).length != 10) {
      _showError('Phone number must be 10 digits');
      return;
    }


    if (email.isEmpty) {
      _showError('Please enter email address');
      return;
    }
    if (!email.contains('@')) {
      _showError('Please enter a valid email address');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter password');
      return;
    }
    if (!RegExp(r'^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=!])(?=\S+$).{6,}$').hasMatch(password)) {
      _showError('Password must be at least 6 characters with uppercase, lowercase, number & special character (@#\$%^&+=!)');
      return;
    }
    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    _doSignUp(name: name, phone: _sanitizePhone(phone), email: email, password: password);
  }

  String _sanitizePhone(String phone) {
    // Remove spaces, dashes, brackets
    String cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    // Remove +91 or 91 prefix
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    // Return last 10 digits as fallback
    if (cleaned.length > 10) cleaned = cleaned.substring(cleaned.length - 10);
    return cleaned;
  }

  Future<void> _doSignUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    setState(() => _isLoading = true);

    try {
      final signUpResult = await ApiService.signUp(
        name: name,
        mobileNo: phone,
        email: email,
        password: password,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (signUpResult.status != true) {
        _showError(signUpResult.message ?? 'Sign up failed. Please try again.');
        return;
      }

      // Step 2: Verify OTP inside the bottom sheet
      final verifyResult = await _showOtpDialog(email, serverMessage: signUpResult.message);
      if (verifyResult == null) return;

      if (verifyResult.status != true) {
        _showError(verifyResult.message ?? 'OTP verification failed. Please try again.');
        return;
      }

      // Step 3: Show success dialog and go back
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Success',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: Text(
            verifyResult.message ?? 'Account created successfully!',
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // close dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
                );
              },
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE67514),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      // Dialog handles navigation to OtpLoginScreen on OK tap.
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage:
              'Unable to create account right now. Please try again.',
        ),
      );
    }
  }

  Future<VerifyOtpMailResponse?> _showOtpDialog(String email, {String? serverMessage}) async {
    final otpController = TextEditingController();
    String? sheetError;
    bool isVerifying = false;

    return showModalBottomSheet<VerifyOtpMailResponse>(
      context: context,
      isDismissible: false, // Only close with X button
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  Text(
                    'Verify Email',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  if (serverMessage != null) ...[  
                    Text(
                      serverMessage,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ] else ...[  
                    Text(
                      'An OTP has been sent to',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE67514),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    enabled: !isVerifying,
                    style: GoogleFonts.poppins(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '------',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 20,
                        letterSpacing: 6,
                        color: Colors.grey.shade300,
                      ),
                      counterText: '',
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
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      sheetError!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                                setSheetState(() => sheetError = 'Please enter OTP');
                                return;
                              }

                              setSheetState(() {
                                sheetError = null;
                                isVerifying = true;
                              });

                              try {
                                final verifyResult = await ApiService.verifyOtpEmail(
                                  email: email,
                                  otp: otp,
                                );

                                if (!ctx.mounted) return;

                                if (verifyResult.status == true) {
                                  Navigator.pop(ctx, verifyResult);
                                  return;
                                }

                                setSheetState(() {
                                  isVerifying = false;
                                  sheetError = verifyResult.message ??
                                      'OTP verification failed. Please try again.';
                                });
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setSheetState(() {
                                  isVerifying = false;
                                  sheetError =
                                      ApiService.getUserFriendlyErrorMessage(
                                    e,
                                    fallbackMessage:
                                        'Unable to verify OTP right now. Please try again.',
                                  );
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE67514),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Verify OTP',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: isVerifying ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFFE67514), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Create Account',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
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
                              'Join eNagarSewa',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create your account to get started',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Full Name
                            const InfoLabel(
                              label: 'Full Name',
                              helpTitle: SignUpHelp.fullNameTitle,
                              helpMessage: SignUpHelp.fullNameMessage,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              maxLength: 30,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\.]"))  ,
                              ],
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                hint: 'Enter your full name',
                                icon: Icons.person_outline,
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 20),

                            // Phone Number
                            const InfoLabel(
                              label: 'Phone Number',
                              helpTitle: SignUpHelp.phoneTitle,
                              helpMessage: SignUpHelp.phoneMessage,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                hint: 'Enter 10 digit mobile number',
                                icon: Icons.phone_outlined,
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 20),

                            // Email
                            const InfoLabel(
                              label: 'Email ID',
                              helpTitle: SignUpHelp.emailTitle,
                              helpMessage: SignUpHelp.emailMessage,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              maxLength: 50,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'[<>"\\\s]')),
                              ],
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                hint: 'Enter your email address',
                                icon: Icons.email_outlined,
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 20),

                            // Password
                            const InfoLabel(
                              label: 'Password',
                              helpTitle: SignUpHelp.passwordTitle,
                              helpMessage: SignUpHelp.passwordMessage,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              maxLength: 25,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
                                icon: Icons.lock_outlined,
                              ).copyWith(
                                counterText: '',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey.shade500,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Confirm Password
                            const InfoLabel(
                              label: 'Confirm Password',
                              helpTitle: SignUpHelp.confirmPasswordTitle,
                              helpMessage: SignUpHelp.confirmPasswordMessage,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              maxLength: 25,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                hint: 'Re-enter your password',
                                icon: Icons.lock_outlined,
                              ).copyWith(
                                counterText: '',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey.shade500,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE67514),
                                  disabledBackgroundColor:
                                    const Color(0xFFE67514).withValues(alpha: 0.6),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Create Account',
                                        style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade600, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Login',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE67514),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
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
        borderSide:
            const BorderSide(color: Color(0xFFE67514), width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
