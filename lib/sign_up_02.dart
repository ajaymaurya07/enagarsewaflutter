import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/rsa_service.dart';
import 'widgets/info_label.dart';
import 'help/signup_help.dart';
import 'widgets/signup_otp_flow.dart';
import 'sign_up_verify_screen.dart';

class SignUp02Screen extends StatefulWidget {
  const SignUp02Screen({super.key});

  @override
  State<SignUp02Screen> createState() => _SignUp02ScreenState();
}

class _SignUp02ScreenState extends State<SignUp02Screen>
    with SignupOtpFlowMixin<SignUp02Screen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();

  final _captchaController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _captchaId;
  Uint8List? _captchaImageBytes;
  bool _loadingCaptcha = false;

  String? _selectedUlbType;
  SignupCity? _selectedCity;
  List<SignupCity> _cities = [];
  bool _loadingCities = false;

  final List<String> _ulbTypes = [
    'Nagar Nigam',
    'Nagar Palika Parishad',
    'Nagar Panchayat',
  ];

  final Map<String, String> _ulbTypeCodes = {
    'Nagar Nigam': 'NN',
    'Nagar Palika Parishad': 'NPP',
    'Nagar Panchayat': 'NP',
  };

  Future<void> _fetchCities(String ulbType) async {
    final code = _ulbTypeCodes[ulbType];
    if (code == null) return;

    setState(() {
      _loadingCities = true;
      _cities = [];
      _selectedCity = null;
    });

    try {
      final cities = await ApiService.getSignupCities(code);
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _loadingCities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCities = false);
      _showError(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to load cities. Please try again.',
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCaptcha();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _fetchCaptcha() async {
    // debugPrint('[SignUp] Fetching form captcha...');
    setState(() => _loadingCaptcha = true);
    try {
      final captcha = await ApiService.getSignupCaptcha();
      // debugPrint('[SignUp] Form captcha loaded -> captchaId=${captcha.captchaId}');
      if (!mounted) return;
      setState(() {
        _captchaId = captcha.captchaId;
        _captchaImageBytes = base64Decode(captcha.captchaImage);
        _loadingCaptcha = false;
        _captchaController.clear();
      });
    } catch (e) {
      // debugPrint('[SignUp] Form captcha fetch failed -> $e');
      if (!mounted) return;
      setState(() => _loadingCaptcha = false);
    }
  }

  void _showUlbTypeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Select ULB Type',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(),
            ..._ulbTypes.map((type) => ListTile(
                  title: Text(type, style: GoogleFonts.poppins(fontSize: 14)),
                  trailing: _selectedUlbType == type
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFFE67514))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedUlbType = type;
                      _selectedCity = null;
                      _cities = [];
                    });
                    Navigator.pop(ctx);
                    _fetchCities(type);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showCitySheet() {
    if (_selectedUlbType == null) {
      _showError('Please select ULB Type first');
      return;
    }
    if (_loadingCities) {
      _showError('Loading cities, please wait...');
      return;
    }
    if (_cities.isEmpty) {
      _showError('No cities available for selected ULB Type');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final searchController = TextEditingController();
        var filtered = List<SignupCity>.from(_cities);

        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select City',
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade500),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search city...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFFE67514), size: 20),
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
                        borderSide: const BorderSide(
                            color: Color(0xFFE67514), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (query) {
                      setSheetState(() {
                        if (query.trim().isEmpty) {
                          filtered = List<SignupCity>.from(_cities);
                        } else {
                          final q = query.trim().toLowerCase();
                          filtered = _cities
                              .where((c) =>
                                  c.name.toLowerCase().contains(q))
                              .toList();
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('No cities found',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade400)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          separatorBuilder: (ctx, index) =>
                              Divider(height: 1, color: Colors.grey.shade100),
                          itemBuilder: (ctx, i) => ListTile(
                            title: Text(filtered[i].name,
                                style: GoogleFonts.poppins(fontSize: 14)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            trailing:
                                _selectedCity?.id == filtered[i].id
                                    ? const Icon(Icons.check_circle,
                                        color: Color(0xFFE67514))
                                    : null,
                            onTap: () {
                              setState(
                                  () => _selectedCity = filtered[i]);
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (_selectedUlbType == null) {
      _showError('Please select ULB Type');
      return;
    }
    if (_selectedCity == null) {
      _showError('Please select City');
      return;
    }

    if (!RegExp(
            r'^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=!])(?=\S+$).{6,}$')
        .hasMatch(password)) {
      _showError(
          'Password must be at least 6 characters with uppercase, lowercase, number & special character (@#\$%^&+=!)');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    if (_captchaId == null) {
      _showError('Please wait for captcha to load');
      return;
    }

    final encryptedPassword = RsaService.encrypt(password);
    final encryptedConfirmPassword = RsaService.encrypt(confirmPassword);

    _doSignUp(
      name: name,
      mobile: mobile,
      email: email,
      encryptedPassword: encryptedPassword,
      encryptedConfirmPassword: encryptedConfirmPassword,
    );
  }

  Future<void> _doSignUp({
    required String name,
    required String mobile,
    required String email,
    required String encryptedPassword,
    required String encryptedConfirmPassword,
  }) async {
    // debugPrint('[SignUp] _doSignUp start -> mobile=$mobile, email=$email');
    setState(() => _isLoading = true);

    try {
      final registerResult = await ApiService.registerCitizen(
        name: name,
        fatherHusbandName: _fatherNameController.text.trim(),
        address1: _address1Controller.text.trim(),
        address2: _address2Controller.text.trim(),
        ulbType: _ulbTypeCodes[_selectedUlbType!]!,
        city: _selectedCity!.id,
        mobileNo: mobile,
        email: email,
        encryptedPassword: encryptedPassword,
        encryptedConfirmPassword: encryptedConfirmPassword,
        captchaId: _captchaId!,
        captcha: _captchaController.text.trim(),
      );

      // debugPrint(
        // '[SignUp] register response -> status=${registerResult.status}, '
        // 'responseCode=${registerResult.responseCode}, message=${registerResult.message}, '
        // 'mobileOtpRequired=${registerResult.mobileOtpRequired}, '
        // 'emailOtpRequired=${registerResult.emailOtpRequired}',
      // );

      bool? status = registerResult.status;
      String? message = registerResult.message;
      bool? mobileOtpRequired = registerResult.mobileOtpRequired;
      bool? emailOtpRequired = registerResult.emailOtpRequired;

      // responseCode 0 -> register itself needs a captcha-verified OTP
      // (re)send, so the rest of the flow continues on a dedicated
      // mobile/captcha verification screen instead of an in-place dialog.
      if (registerResult.responseCode == 0) {
        // debugPrint('[SignUp] responseCode=0 -> navigating to verify screen.');
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SignUpVerifyScreen(
              initialMobile: mobile,
              email: email,
              initialMessage: registerResult.message,
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (status != true) {
        // debugPrint('[SignUp] Registration failed -> $message');
        _fetchCaptcha();
        showMessageDialog(
          title: 'Registration Failed',
          message: message ?? 'Registration failed. Please try again.',
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red.shade600,
        );
        return;
      }

      bool needEmailOtp = emailOtpRequired == true;
      String? nextMessage = message;

      // Step 2: Mobile OTP verification
      if (mobileOtpRequired == true) {
        // debugPrint('[SignUp] mobileOtpRequired=true -> showing mobile OTP sheet.');
        if (!mounted) return;
        final mobileOtpResult = await showOtpBottomSheet(
          title: 'Verify Mobile OTP',
          subtitle: message ?? 'OTP sent to your mobile number',
          highlightText: mobile,
          mobileNo: mobile,
          onVerify: (otp) => ApiService.verifyCitizenOtp(
            mobileNo: mobile,
            otp: otp,
          ),
        );
        if (mobileOtpResult == null) {
          // debugPrint('[SignUp] Mobile OTP sheet cancelled by user.');
          return;
        }

        // debugPrint(
          // '[SignUp] Mobile OTP verified -> registrationComplete=${mobileOtpResult.registrationComplete}, '
          // 'emailOtpRequired=${mobileOtpResult.emailOtpRequired}',
        // );

        if (mobileOtpResult.registrationComplete == true) {
          if (!mounted) return;
          showSuccessAndGoBack(
            mobileOtpResult.message ?? 'Registration complete!',
          );
          return;
        }

        needEmailOtp = mobileOtpResult.emailOtpRequired;
        nextMessage = mobileOtpResult.message;
      }

      // Step 3: Email OTP verification
      if (needEmailOtp) {
        // debugPrint('[SignUp] emailOtpRequired=true -> showing email OTP sheet.');
        if (!mounted) return;
        final emailOtpResult = await showOtpBottomSheet(
          title: 'Verify Email OTP',
          subtitle: nextMessage ?? 'OTP sent to your email',
          highlightText: email,
          mobileNo: mobile,
          onVerify: (otp) => ApiService.verifyOtpEmail(
            email: email,
            otp: otp,
          ),
        );
        if (emailOtpResult == null) {
          // debugPrint('[SignUp] Email OTP sheet cancelled by user.');
          return;
        }

        // debugPrint('[SignUp] Email OTP verified -> registration complete.');
        if (!mounted) return;
        showSuccessAndGoBack(
          emailOtpResult.message ?? 'Registration complete!',
        );
        return;
      }
    } catch (e) {
      // debugPrint('[SignUp] _doSignUp error -> $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _fetchCaptcha();
      showMessageDialog(
        title: 'Error',
        message: ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage:
              'Unable to create account right now. Please try again.',
        ),
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red.shade600,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Form(
                    key: _formKey,
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
                                color:
                                    Colors.black.withValues(alpha: 0.06),
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
                              TextFormField(
                                controller: _nameController,
                                maxLength: 100,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r"[a-zA-Z\s\.]")),
                                ],
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Enter your full name',
                                ).copyWith(counterText: ''),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Father/Husband Name
                              const InfoLabel(
                                label: 'Father/Husband Name',
                                helpTitle: 'Father/Husband Name',
                                helpMessage:
                                    'Enter the name of your father or husband as per official records.',
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _fatherNameController,
                                maxLength: 100,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r"[a-zA-Z\s\.]")),
                                ],
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Enter father/husband name',
                                ).copyWith(counterText: ''),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Father/Husband name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Address 1
                              const InfoLabel(
                                label: 'Address 1',
                                helpTitle: 'Address Line 1',
                                helpMessage:
                                    'Enter your primary address (House No., Street, Locality).',
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _address1Controller,
                                maxLength: 100,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                      RegExp(r'[<>"\\]')),
                                ],
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'House No., Street, Locality',
                                ).copyWith(counterText: ''),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Address 1 is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Address 2
                              const InfoLabel(
                                label: 'Address 2',
                                helpTitle: 'Address Line 2',
                                helpMessage:
                                    'Enter additional address details (Area, Landmark, etc.).',
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _address2Controller,
                                maxLength: 100,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                      RegExp(r'[<>"\\]')),
                                ],
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Area, Landmark',
                                ).copyWith(counterText: ''),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Address 2 is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // ULB Type
                              const InfoLabel(
                                label: 'ULB Type',
                                helpTitle: 'ULB Type',
                                helpMessage:
                                    'Select the type of Urban Local Body (Nagar Nigam, Nagar Palika Parishad, or Nagar Panchayat).',
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _showUlbTypeSheet(),
                                child: InputDecorator(
                                  decoration: _dropdownDecoration(),
                                  child: Text(
                                    _selectedUlbType ?? 'Select ULB Type',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: _selectedUlbType != null
                                          ? Colors.black87
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // City
                              const InfoLabel(
                                label: 'City',
                                helpTitle: 'City',
                                helpMessage:
                                    'Select your city. You will only be able to avail services of the selected city.',
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _showCitySheet(),
                                child: InputDecorator(
                                  decoration: _dropdownDecoration(),
                                  child: _loadingCities
                                      ? Row(
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Color(0xFFE67514))),
                                            ),
                                            const SizedBox(width: 12),
                                            Text('Loading cities...',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: Colors
                                                        .grey.shade400)),
                                          ],
                                        )
                                      : Text(
                                    _selectedCity?.name ?? 'Select City',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: _selectedCity != null
                                          ? Colors.black87
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Mobile No
                              const InfoLabel(
                                label: 'Mobile No.',
                                helpTitle: SignUpHelp.phoneTitle,
                                helpMessage: SignUpHelp.phoneMessage,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _mobileController,
                                maxLength: 10,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Enter 10 digit mobile number',
                                ).copyWith(counterText: ''),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Mobile number is required';
                                  }
                                  if (v.trim().length != 10) {
                                    return 'Mobile number must be 10 digits';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Password
                              const InfoLabel(
                                label: 'Password',
                                helpTitle: SignUpHelp.passwordTitle,
                                helpMessage: SignUpHelp.passwordMessage,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                maxLength: 25,
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Enter your password',
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
                                    onPressed: () => setState(() =>
                                        _obscurePassword =
                                            !_obscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Password is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Confirm Password
                              const InfoLabel(
                                label: 'Confirm Password',
                                helpTitle:
                                    SignUpHelp.confirmPasswordTitle,
                                helpMessage:
                                    SignUpHelp.confirmPasswordMessage,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                maxLength: 25,
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Re-enter your password',
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
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Confirm Password is required';
                                  }
                                  if (v != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Email
                              const InfoLabel(
                                label: 'Email ID',
                                helpTitle: SignUpHelp.emailTitle,
                                helpMessage: SignUpHelp.emailMessage,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                maxLength: 50,
                                keyboardType:
                                    TextInputType.emailAddress,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                      RegExp(r'[<>"\\]')),
                                ],
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Enter your email',
                                ).copyWith(counterText: ''),
                              ),
                              const SizedBox(height: 20),

                              // Captcha
                              const InfoLabel(
                                label: 'Captcha',
                                helpTitle: 'Captcha',
                                helpMessage:
                                    'Enter the text shown in the image to verify you are not a robot.',
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                      borderRadius:
                                          BorderRadius.circular(12),
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
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Color(
                                                              0xFFE67514)),
                                                ),
                                              ),
                                            ),
                                          )
                                        : _captchaImageBytes != null
                                            ? Image.memory(
                                                _captchaImageBytes!,
                                                height: 50,
                                                fit: BoxFit.contain,
                                              )
                                            : SizedBox(
                                                width: 120,
                                                child: Center(
                                                  child: Text(
                                                    'Failed',
                                                    style:
                                                        GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .red.shade400,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    onPressed: _loadingCaptcha
                                        ? null
                                        : _fetchCaptcha,
                                    icon: const Icon(
                                        Icons.refresh_rounded,
                                        color: Color(0xFFE67514),
                                        size: 26),
                                    tooltip: 'Refresh Captcha',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _captchaController,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9]')),
                                ],
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Enter image text',
                                ).copyWith(counterText: ''),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter the captcha text';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Create Account Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFE67514),
                                    disabledBackgroundColor:
                                        const Color(0xFFE67514)
                                            .withValues(alpha: 0.6),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                        Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'Create Account',
                                          style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.w700),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SignUpVerifyScreen(
                                        initialMobile:
                                            _mobileController.text.trim(),
                                        email: _emailController.text.trim(),
                                      ),
                                    ),
                                  );
                                },
                                child: Text.rich(
                                  TextSpan(
                                    text:
                                        'Already registered? Verify your mobile number and email ID. ',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Click here.',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFE67514),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
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
                                  color: Colors.grey.shade600,
                                  fontSize: 14),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
