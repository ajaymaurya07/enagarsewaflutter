import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/sim_service.dart';
import 'services/email_service.dart';

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
  String? _selectedPhone;
  String? _selectedEmail;
  List<String> _phoneNumbers = [];
  List<String> _availableEmails = [];
  bool _loadingPhoneNumbers = false;
  bool _loadingEmails = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumbers();
    _loadEmails();
  }

  Future<void> _loadPhoneNumbers() async {
    setState(() {
      _loadingPhoneNumbers = true;
    });
    
    try {
      final phones = await SimService.getAvailablePhoneNumbers();
      
      setState(() {
        _phoneNumbers = phones;
        _loadingPhoneNumbers = false;
      });
    } catch (e) {
      setState(() {
        _phoneNumbers = [];
        _loadingPhoneNumbers = false;
      });
    }
  }

  Future<void> _loadEmails() async {
    setState(() {
      _loadingEmails = true;
    });
    
    try {
      // First, try to get all Gmail account emails
      final gmailEmails = await EmailService.getAllGmailEmails();
      
      if (gmailEmails.isNotEmpty) {
        setState(() {
          _availableEmails = gmailEmails;
          _loadingEmails = false;
        });
        return;
      }
      
      // If no Gmail emails, try to get emails from device contacts
      final emails = await EmailService.getAvailableEmails();
      
      setState(() {
        _availableEmails = emails;
        _loadingEmails = false;
      });
    } catch (e) {
      // If anything fails, show empty list so input field appears
      setState(() {
        _availableEmails = [];
        _loadingEmails = false;
      });
    }
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
    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate sign up delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });
      _showSuccess('Account created successfully for $email!');
      // Navigate back to login
      Navigator.pop(context);
    });
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
                              color: Colors.black.withOpacity(0.06),
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
                                      const Color(0xFFE67514).withOpacity(0.6),
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
