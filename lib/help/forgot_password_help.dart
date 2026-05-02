/// Help content constants for the Forgot Password screen fields.
class ForgotPasswordHelp {
  ForgotPasswordHelp._();

  static const String emailTitle = 'Email';
  static const String emailMessage =
      'Enter the email address linked to your account.\n\n'
      'An OTP (One-Time Password) will be sent to this email '
      'to verify your identity and allow you to reset your password.';

  static const String otpTitle = 'OTP';
  static const String otpMessage =
      'Enter the 6-digit One-Time Password (OTP) sent to your email.\n\n'
      'Check your inbox (and spam/junk folder if not found). '
      'The OTP is valid for a limited time only.';

  static const String newPasswordTitle = 'New Password';
  static const String newPasswordMessage =
      'Create a new strong password with at least 6 characters.\n\n'
      'Your password must include:\n'
      '• At least one uppercase letter (A–Z)\n'
      '• At least one lowercase letter (a–z)\n'
      '• At least one number (0–9)\n'
      '• At least one special character (@#\$%^&+=!)';

  static const String confirmPasswordTitle = 'Confirm Password';
  static const String confirmPasswordMessage =
      'Re-enter the new password you entered above.\n\n'
      'Both passwords must match to reset successfully.';
}
