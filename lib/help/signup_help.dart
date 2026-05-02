/// Help content constants for the Sign Up screen fields.
class SignUpHelp {
  SignUpHelp._();

  static const String fullNameTitle = 'Full Name';
  static const String fullNameMessage =
      'Enter your full name as it appears on official documents.\n'
      'Example: Rajesh Kumar Sharma\n\n'
      'This name will be used on your account profile.';

  static const String phoneTitle = 'Phone Number';
  static const String phoneMessage =
      'Enter your 10-digit mobile number.\n'
      'Example: 9876543210\n\n'
      'The app can auto-detect SIM numbers on your device. '
      'You can also type your number manually.';

  static const String emailTitle = 'Email ID';
  static const String emailMessage =
      'Enter a valid email address.\n'
      'Example: name@example.com\n\n'
      'An OTP will be sent to this email to verify your account. '
      'The app can auto-detect email accounts on your device.';

  static const String passwordTitle = 'Password';
  static const String passwordMessage =
      'Create a strong password with at least 6 characters.\n\n'
      'Your password must include:\n'
      '• At least one uppercase letter (A–Z)\n'
      '• At least one lowercase letter (a–z)\n'
      '• At least one number (0–9)\n'
      '• At least one special character (@#\$%^&+=!)';

  static const String confirmPasswordTitle = 'Confirm Password';
  static const String confirmPasswordMessage =
      'Re-enter the same password you entered above.\n\n'
      'Both passwords must match to proceed.';
}
