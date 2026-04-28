import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/sim_service.dart';
import 'services/email_service.dart';
import 'services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _selectedPhone;
  String? _selectedEmail;
  List<String> _phoneNumbers = [];
  List<String> _availableEmails = [];
  bool _loadingPhoneNumbers = false;
  bool _loadingEmails = false;

  // Tracks if we opened settings and are waiting for user to return
  bool _waitingForPhonePermission = false;
  bool _waitingForEmailPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Called when app returns to foreground (e.g. from Settings)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_waitingForPhonePermission || _waitingForEmailPermission) {
        final needPhone = _waitingForPhonePermission;
        final needEmail = _waitingForEmailPermission;
        _waitingForPhonePermission = false;
        _waitingForEmailPermission = false;
        _recheckAfterSettings(needPhone: needPhone, needEmail: needEmail);
      }
    }
  }

  // ─── COMBINED PERMISSION INIT ─────────────────────────────────────────────

  Future<void> _initAllPermissions() async {
    if (!mounted) return;
    setState(() {
      _loadingPhoneNumbers = true;
      _loadingEmails = true;
    });

    // Try Gmail first — no permission needed
    List<String> gmailEmails = [];
    try {
      gmailEmails = await EmailService.getAllGmailEmails();
    } catch (_) {}
    final emailViaGmail = gmailEmails.isNotEmpty;

    // ── IMPORTANT: Request permissions SEQUENTIALLY ───────────────────────
    // Android can only show ONE OS permission dialog at a time.
    // Running both in Future.wait causes the second one to hang indefinitely.
    final phoneStatus = await _forceRequestPermission(
      permission: Permission.phone,
      rationaleTitle: 'Phone Permission Required',
      rationaleReason:
          'This app needs Phone permission to automatically read your SIM number. Please grant it to continue.',
      settingsTitle: 'Phone Permission Blocked',
      settingsMessage:
          'Phone permission is permanently blocked.\n\nPlease open App Settings → Permissions → Phone → Allow, then come back.',
      onWaiting: () => _waitingForPhonePermission = true,
    );

    // Only request contacts if Gmail didn't already give us emails
    final contactsStatus = emailViaGmail
        ? PermissionStatus.granted
        : await _forceRequestPermission(
            permission: Permission.contacts,
            rationaleTitle: 'Contacts Permission Required',
            rationaleReason:
                'This app needs Contacts permission to automatically read your email address. Please grant it to continue.',
            settingsTitle: 'Contacts Permission Blocked',
            settingsMessage:
                'Contacts permission is permanently blocked.\n\nPlease open App Settings → Permissions → Contacts → Allow, then come back.',
            onWaiting: () => _waitingForEmailPermission = true,
          );

    // ── Fetch data in parallel (no dialogs here, safe to parallelize) ─────
    await Future.wait([
      _applyPhoneResult(phoneStatus),
      _applyEmailResult(
        gmailEmails: gmailEmails,
        emailViaGmail: emailViaGmail,
        contactsStatus: contactsStatus,
      ),
    ]);
  }

  // ─── FORCE-REQUEST HELPER ─────────────────────────────────────────────────
  // Loops until permission is granted OR permanently denied (then opens settings).
  // For permanently denied: sets waiting flag, opens settings, returns immediately.
  // The lifecycle observer picks it up on app resume.

  Future<PermissionStatus> _forceRequestPermission({
    required Permission permission,
    required String rationaleTitle,
    required String rationaleReason,
    required String settingsTitle,
    required String settingsMessage,
    required VoidCallback onWaiting,
  }) async {
    while (mounted) {
      var status = await permission.status;

      // Already granted — done
      if (status.isGranted || status.isLimited) return status;

      // Permanently denied — send to settings (lifecycle handles resume)
      if (status.isPermanentlyDenied) {
        onWaiting();
        await _showSettingsDialog(title: settingsTitle, message: settingsMessage);
        return status; // resume handled by didChangeAppLifecycleState
      }

      // isDenied — show OS dialog
      status = await permission.request();

      if (status.isGranted || status.isLimited) return status;

      if (status.isPermanentlyDenied) {
        onWaiting();
        await _showSettingsDialog(title: settingsTitle, message: settingsMessage);
        return status;
      }

      // User tapped "Deny" in OS dialog (can still ask again) —
      // show rationale explaining WHY, then loop back and ask again
      if (!mounted) return status;
      await _showRationaleDialog(
        title: rationaleTitle,
        reason: rationaleReason,
      );
      // Loop: will call permission.request() again
    }
    return PermissionStatus.denied;
  }

  // ─── RE-CHECK AFTER RETURNING FROM SETTINGS ───────────────────────────────

  Future<void> _recheckAfterSettings({
    required bool needPhone,
    required bool needEmail,
  }) async {
    if (!mounted) return;
    if (needPhone) setState(() => _loadingPhoneNumbers = true);
    if (needEmail) setState(() => _loadingEmails = true);

    List<String> gmailEmails = [];
    if (needEmail) {
      try {
        gmailEmails = await EmailService.getAllGmailEmails();
      } catch (_) {}
    }
    final emailViaGmail = gmailEmails.isNotEmpty;

    // Sequential permission re-check (same reason: Android one dialog at a time)
    final phoneStatus = needPhone
        ? await _forceRequestPermission(
            permission: Permission.phone,
            rationaleTitle: 'Phone Permission Required',
            rationaleReason:
                'Phone permission is still needed to auto-detect your SIM number.',
            settingsTitle: 'Phone Permission Still Blocked',
            settingsMessage:
                'Phone permission is still blocked.\n\nPlease go to App Settings → Permissions → Phone → Allow, then come back.',
            onWaiting: () => _waitingForPhonePermission = true,
          )
        : PermissionStatus.denied;

    final contactsStatus = (needEmail && !emailViaGmail)
        ? await _forceRequestPermission(
            permission: Permission.contacts,
            rationaleTitle: 'Contacts Permission Required',
            rationaleReason:
                'Contacts permission is still needed to auto-detect your email address.',
            settingsTitle: 'Contacts Permission Still Blocked',
            settingsMessage:
                'Contacts permission is still blocked.\n\nPlease go to App Settings → Permissions → Contacts → Allow, then come back.',
            onWaiting: () => _waitingForEmailPermission = true,
          )
        : PermissionStatus.denied;

    // Fetch in parallel (no dialogs here)
    await Future.wait([
      if (needPhone) _applyPhoneResult(phoneStatus),
      if (needEmail)
        _applyEmailResult(
          gmailEmails: gmailEmails,
          emailViaGmail: emailViaGmail,
          contactsStatus: contactsStatus,
        ),
    ]);
  }

  // ─── PHONE: fetch with granted status ────────────────────────────────────

  Future<void> _applyPhoneResult(PermissionStatus status) async {
    if (!mounted) return;

    if (status.isGranted || status.isLimited) {
      try {
        final phones = await SimService.getAvailablePhoneNumbers();
        if (!mounted) return;
        setState(() {
          _phoneNumbers = phones;
          // Auto-fill only if exactly 1 number detected
          if (phones.length == 1) {
            _selectedPhone = phones.first;
            _phoneController.text = phones.first;
          }
          _loadingPhoneNumbers = false;
        });
        // If permission granted but device returned no numbers → manual entry
        // _phoneNumbers will be empty so the selection dialog shows text field
        return;
      } catch (_) {}
    }

    // Permission not granted (permanently denied / waiting for settings)
    // Spinner stops — selector tile remains tappable for manual entry
    if (mounted) setState(() => _loadingPhoneNumbers = false);
  }

  // ─── EMAIL: fetch with granted status ────────────────────────────────────

  Future<void> _applyEmailResult({
    required List<String> gmailEmails,
    required bool emailViaGmail,
    required PermissionStatus contactsStatus,
  }) async {
    if (!mounted) return;

    // Priority 1: Always try a FRESH Gmail fetch here.
    // All permission dialogs have completed by this point, so Android's
    // AccountManager is fully initialised and returns correct accounts.
    // On first launch the early fetch (before dialogs) returns empty or wrong
    // results because AccountManager hasn't warmed up yet — which causes
    // emailViaGmail=false and falls through to Contacts (wrong email).
    // Re-fetching now fixes that.
    List<String> freshGmailEmails = [];
    try {
      freshGmailEmails = await EmailService.getAllGmailEmails();
    } catch (_) {}

    if (freshGmailEmails.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _availableEmails = freshGmailEmails;
        if (freshGmailEmails.length == 1) {
          _selectedEmail = freshGmailEmails.first;
          _emailController.text = freshGmailEmails.first;
        }
        _loadingEmails = false;
      });
      return;
    }

    // Priority 2: Contacts granted — fetch
    if (contactsStatus.isGranted || contactsStatus.isLimited) {
      try {
        final emails = await EmailService.getAvailableEmails();
        if (!mounted) return;
        setState(() {
          _availableEmails = emails;
          if (emails.length == 1) {
            _selectedEmail = emails.first;
            _emailController.text = emails.first;
          }
          _loadingEmails = false;
        });
        return;
      } catch (_) {}
    }

    // Not granted — spinner stops, selector tile tappable for manual entry
    if (mounted) setState(() => _loadingEmails = false);
  }

  // ─── DIALOGS ─────────────────────────────────────────────────────────────

  /// Rationale dialog: explains WHY permission is needed.
  /// Has only "Grant Permission" button — no skip, no dismiss.
  Future<void> _showRationaleDialog({
    required String title,
    required String reason,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // back button disabled
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.info_rounded, color: Color(0xFFE67514), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          content: Text(reason,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('Grant Permission',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67514),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Settings dialog: for permanently denied permissions.
  /// Has only "Open Settings" button — no skip, no dismiss.
  Future<void> _showSettingsDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // back button disabled
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.security_rounded,
                  color: Color(0xFFE67514), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          content: Text(message,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text('Open Settings',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67514),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhoneSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final customPhoneController = TextEditingController();
        
        return AlertDialog(
          title: _phoneNumbers.isNotEmpty 
              ? const Text('Select Phone Number')
              : const Text('Enter Phone Number'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // CASE 1: Phone numbers detected - Show only list
                if (_phoneNumbers.isNotEmpty) ...[
                  const Text(
                    'Available Phone Numbers:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._phoneNumbers.map((phone) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPhone = phone;
                            _phoneController.text = phone;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedPhone == phone
                                  ? const Color(0xFFE67514)
                                  : Colors.grey.shade300,
                              width: _selectedPhone == phone ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedPhone == phone
                                ? const Color(0xFFFFF3E0)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                            Icon(
                              Icons.phone,
                              color: _selectedPhone == phone
                                  ? const Color(0xFFE67514)
                                  : Colors.grey,
                            ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  phone,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: _selectedPhone == phone
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: _selectedPhone == phone
                                        ? const Color(0xFFE67514)
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (_selectedPhone == phone)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFE67514),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ]
                // CASE 2: No phone numbers detected - Show input field only
                else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No phone numbers detected on this device',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: customPhoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter 10 digit number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            ),
            // Show action button only for manual entry case
            if (_phoneNumbers.isEmpty)
              TextButton(
                onPressed: () {
                  final customNumber = customPhoneController.text.trim();
                  if (customNumber.isEmpty) {
                    _showError('Please enter a phone number');
                    return;
                  }
                  if (customNumber.length != 10) {
                    _showError('Phone number must be 10 digits');
                    return;
                  }
                  setState(() {
                    _selectedPhone = customNumber;
                    _phoneController.text = customNumber;
                  });
                  Navigator.pop(context);
                },
                child: Text(
                  'Use This',
                  style: GoogleFonts.poppins(color: const Color(0xFFE67514), fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showEmailSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final customEmailController = TextEditingController();
        
        return AlertDialog(
          title: _availableEmails.isNotEmpty 
              ? const Text('Select Email Address')
              : const Text('Enter Email Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // CASE 1: Emails detected - Show only list
                if (_availableEmails.isNotEmpty) ...[
                  const Text(
                    'Available Email Addresses:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._availableEmails.map((email) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedEmail = email;
                            _emailController.text = email;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedEmail == email
                                  ? const Color(0xFFE67514)
                                  : Colors.grey.shade300,
                              width: _selectedEmail == email ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedEmail == email
                                ? const Color(0xFFFFF3E0)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email,
                                color: _selectedEmail == email
                                    ? const Color(0xFFE67514)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  email,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: _selectedEmail == email
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: _selectedEmail == email
                                        ? const Color(0xFFE67514)
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedEmail == email)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFE67514),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ]
                // CASE 2: No emails detected - Show input field only
                else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No email addresses detected on this device',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: customEmailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter your email address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            ),
            // Show action button only for manual entry case
            if (_availableEmails.isEmpty)
              TextButton(
                onPressed: () {
                  final customEmail = customEmailController.text.trim();
                  if (customEmail.isEmpty) {
                    _showError('Please enter an email address');
                    return;
                  }
                  if (!customEmail.contains('@')) {
                    _showError('Please enter a valid email address');
                    return;
                  }
                  setState(() {
                    _selectedEmail = customEmail;
                    _emailController.text = customEmail;
                  });
                  Navigator.pop(context);
                },
                child: Text(
                  'Use This',
                  style: GoogleFonts.poppins(color: const Color(0xFFE67514), fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
      },
    );
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
      _showError('Please select a phone number');
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
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 28),
              const SizedBox(width: 10),
              Text(
                'Success',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            verifyResult.message ?? 'Account created successfully!',
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67514),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
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
      isDismissible: false,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                              'Join e-Nagarseva',
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
                            _fieldLabel('Full Name'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                hint: 'Enter your full name',
                                icon: Icons.person_outline,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Phone Number
                            _fieldLabel('Phone Number'),
                            const SizedBox(height: 8),
                            _SelectorTile(
                              label: 'Select Phone Number',
                              value: _phoneController.text.isNotEmpty
                                  ? _phoneController.text
                                  : null,
                              icon: Icons.phone_outlined,
                              isLoading: _loadingPhoneNumbers,
                              onTap: _loadingPhoneNumbers
                                  ? null
                                  : _showPhoneSelectionDialog,
                            ),
                            const SizedBox(height: 20),

                            // Email
                            _fieldLabel('Email ID'),
                            const SizedBox(height: 8),
                            _SelectorTile(
                              label: 'Select Email Address',
                              value: _emailController.text.isNotEmpty
                                  ? _emailController.text
                                  : null,
                              icon: Icons.email_outlined,
                              isLoading: _loadingEmails,
                              onTap: _loadingEmails
                                  ? null
                                  : _showEmailSelectionDialog,
                            ),
                            const SizedBox(height: 20),

                            // Password
                            _fieldLabel('Password'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
                                icon: Icons.lock_outlined,
                              ).copyWith(
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
                            _fieldLabel('Confirm Password'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: _inputDecoration(
                                hint: 'Re-enter your password',
                                icon: Icons.lock_outlined,
                              ).copyWith(
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

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
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

class _SelectorTile extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onTap;

  const _SelectorTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE67514), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? 'Tap to select',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: value != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                      color: value != null
                          ? Colors.black87
                          : Colors.grey.shade400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE67514))),
              )
            else
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400, size: 14),
          ],
        ),
      ),
    );
  }
}
