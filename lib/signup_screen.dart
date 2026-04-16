import 'package:flutter/material.dart';
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
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              width: _selectedPhone == phone ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedPhone == phone
                                ? Colors.blue.shade50
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                            Icon(
                              Icons.phone,
                              color: _selectedPhone == phone
                                  ? const Color(0xFFffbd18)
                                  : Colors.grey,
                            ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  phone,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _selectedPhone == phone
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _selectedPhone == phone
                                        ? Colors.blue
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              if (_selectedPhone == phone)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFffbd18),
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
              child: const Text('Cancel'),
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
                child: const Text(
                  'Use This',
                  style: TextStyle(color: Colors.blue),
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
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              width: _selectedEmail == email ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedEmail == email
                                ? Colors.blue.shade50
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email,
                                color: _selectedEmail == email
                                    ? const Color(0xFFffbd18)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _selectedEmail == email
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _selectedEmail == email
                                        ? Colors.blue
                                        : Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedEmail == email)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFffbd18),
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
              child: const Text('Cancel'),
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
                child: const Text(
                  'Use This',
                  style: TextStyle(color: Colors.blue),
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
        content: Text(message),
        backgroundColor: const Color(0xFFE67514),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFffbd18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // Back Button and Title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              
                const SizedBox(height: 32),
                // Name Input
                Text(
                  'Full Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 24),
                // Phone Number Input
                Text(
                  'Phone Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _loadingPhoneNumbers ? null : _showPhoneSelectionDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              color: Color(0xFFffbd18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Phone Number',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _phoneController.text.isNotEmpty
                                      ? _phoneController.text
                                      : 'Tap to select',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _phoneController.text.isNotEmpty
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_loadingPhoneNumbers)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey.shade400,
                            size: 16,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Email Input
                Text(
                  'Email ID',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _loadingEmails ? null : _showEmailSelectionDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              color: Color(0xFFffbd18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Email Address',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _emailController.text.isNotEmpty
                                      ? _emailController.text
                                      : 'Tap to select',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _emailController.text.isNotEmpty
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_loadingEmails)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey.shade400,
                            size: 16,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Password Input
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 24),
                // Confirm Password Input
                Text(
                  'Confirm Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 32),
                // Sign Up Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67514),
                    disabledBackgroundColor: const Color(0xFFE67514).withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
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
                      : const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                // Already have account link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Color(0xFFE67514),
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
      ),
    );
  }
}
