import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'dashboard_screen.dart';
import 'tour_guides/property_selection_tour.dart';
import 'utils/ulb_language_helper.dart';

class PropertySelectionScreen extends StatefulWidget {
  final List<PropertyData> properties;

  const PropertySelectionScreen({super.key, required this.properties});

  @override
  State<PropertySelectionScreen> createState() => _PropertySelectionScreenState();
}

class _PropertySelectionScreenState extends State<PropertySelectionScreen> {
  final _keyHeader = GlobalKey();
  final _keyFirstPropertyCard = GlobalKey();
  final _keyFirstSelectButton = GlobalKey();

  bool _isLoading = false;
  PropertyDetailsData? _currentPropertyDetails;
  PropertyData? _selectedProperty;
  TutorialCoachMark? _tutorialCoachMark;
  bool _isKrutidev = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _autoStartTourIfFirstVisit(),
    );
    _loadUlbLanguagePreference();
  }

  Future<void> _loadUlbLanguagePreference() async {
    final isKrutidev = await UlbLanguageHelper.isKrutidev();
    if (!mounted) return;
    setState(() => _isKrutidev = isKrutidev);
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    if (widget.properties.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_property_selection') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_property_selection', true);
      _startTour();
    }
  }

  void _startTour() {
    if (widget.properties.isEmpty || !mounted) return;

    final targets = PropertySelectionTourGuide.buildTargets(
      headerKey: _keyHeader,
      propertyCardKey: _keyFirstPropertyCard,
      selectButtonKey: _keyFirstSelectButton,
    );

    _tutorialCoachMark = PropertySelectionTourGuide.createCoachMark(
      targets: targets,
      onAdvance: () => _tutorialCoachMark?.next(),
    )..show(context: context);
  }

  void _handleTourTap() {
    if (widget.properties.isEmpty) {
      _showSnackBar(
        'Tour will be available once the property cards are loaded.',
        isError: false,
      );
      return;
    }

    _startTour();
  }

  void _handlePropertySelection(PropertyData property) async {
    final propertyId = property.propertyId;
    if (propertyId == null) return;

    setState(() {
      _isLoading = true;
      _selectedProperty = property;
    });

    try {
      // 1. Get Property Details
      final res = await ApiService.getPropertyDetails(propertyId);
      _currentPropertyDetails = res.data;

      final mobileNo = _currentPropertyDetails?.ownerDetails?.mobileNo;

      if (mobileNo == null || mobileNo.isEmpty) {
        throw Exception('Mobile number not found for this property');
      }

      // 2. Login wala number (verify_otp se secure storage me aaya) aur
      // property ka owner mobile match hone chahiye. Mismatch par user se
      // confirm karao — Cancel karne par isi screen par rukna hai.
      final loginMobile = await StorageService.getLoginMobile();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (loginMobile != null &&
          loginMobile.isNotEmpty &&
          !_isSameMobile(loginMobile, mobileNo)) {
        final shouldContinue = await _showMobileMismatchDialog(
          loginMobile: loginMobile,
          propertyMobile: mobileNo,
        );
        if (!shouldContinue) {
          if (!mounted) return;
          setState(() => _selectedProperty = null);
          return;
        }
        if (!mounted) return;
      }

      // 3. Koi OTP nahi: property details milte hi selection finalize kar do
      await _finalizePropertySelection(mobileNo, propertyId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to select this property right now. Please try again.',
        ),
      );
    }
  }

  /// Numbers ko digits-only karke aakhri 10 digits par compare karta hai,
  /// taki `+91`/`0` prefix ya spaces ki wajah se false mismatch na aaye.
  bool _isSameMobile(String a, String b) {
    String normalize(String value) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    }

    final left = normalize(a);
    final right = normalize(b);
    if (left.isEmpty || right.isEmpty) return true;
    return left == right;
  }

  /// Mismatch dialog. `true` = Continue, `false` = Cancel / dismiss.
  Future<bool> _showMobileMismatchDialog({
    required String loginMobile,
    required String propertyMobile,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE67514), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Number Mismatch',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your login mobile number does not match the mobile number '
              'registered with this property.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildMismatchRow('Login Number', loginMobile),
            const SizedBox(height: 8),
            _buildMismatchRow('Property Number', propertyMobile),
            const SizedBox(height: 16),
            Text(
              'Do you still want to continue with this property?',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF333333),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE67514),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildMismatchRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _finalizePropertySelection(
    String mobileNo,
    String propertyId,
  ) async {
    final ulbId = await StorageService.getUlbId();
    final totalArv = _selectedProperty?.totalArv?.toString() ?? "0.0";
    // user_id login (verify_otp) response se aata hai, property API se nahi.
    final userId = await StorageService.getUserId() ?? "0";

    await StorageService.saveTotalArv(totalArv);

    final email = await StorageService.getEmailId();
    final userType = await StorageService.getUserType();

    await DatabaseService.insertProperty(
      PropertyEntity(
        propertyId: propertyId,
        ownerName: _currentPropertyDetails?.ownerDetails?.ownerName ?? "N/A",
        ward: _currentPropertyDetails?.propertyDetailsInfo?.wardName ?? "N/A",
        mohalla: _currentPropertyDetails?.propertyDetailsInfo?.mohallaName ?? "N/A",
        zone: _currentPropertyDetails?.propertyDetailsInfo?.zoneName,
        phoneNumber: mobileNo,
        email: email,
        userType: userType,
        ulbId: ulbId,
        arvValue: totalArv,
        userId: userId,
        fatherName: _selectedProperty?.fatherHusbandName ?? "N/A",
        address: _selectedProperty?.address ?? "N/A",
        houseNo: _currentPropertyDetails?.propertyDetailsInfo?.houseNo,
        totalArea: _currentPropertyDetails?.propertyDetailsInfo?.totalArea,
      ),
    );

    await StorageService.setPropertyVerified(true);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white,
            child: SafeArea(
              child: Column(
                children: [
                  // AppBar
                  Padding(
                    key: _keyHeader,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFFE67514), size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'Select Property',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Show tour',
                          onPressed: _handleTourTap,
                          icon: const Icon(
                            Icons.help_outline_rounded,
                            color: Color(0xFFE67514),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: widget.properties.isEmpty
                        ? Center(
                            child: Text(
                              'No properties found.',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.grey.shade500),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: widget.properties.length,
                            itemBuilder: (context, index) {
                              final property = widget.properties[index];
                              return _buildPropertyCard(
                                context,
                                property,
                                isPrimaryTourCard: index == 0,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE67514))),
          ),
      ],
    );
  }

  Widget _buildPropertyCard(
    BuildContext context,
    PropertyData property, {
    bool isPrimaryTourCard = false,
  }) {
    return Container(
      key: isPrimaryTourCard ? _keyFirstPropertyCard : null,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'PID: ${property.propertyId ?? "N/A"}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ),
                SizedBox(
                  key: isPrimaryTourCard ? _keyFirstSelectButton : null,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _handlePropertySelection(property),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67514),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text('Select',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Owner Name', property.ownerName, isLanguageSensitive: true),
                const SizedBox(height: 8),
                _buildDetailRow('Father/Husband', property.fatherHusbandName, isLanguageSensitive: true),
                const SizedBox(height: 8),
                _buildDetailRow('House No', property.houseNo),
                const SizedBox(height: 8),
                _buildDetailRow('Address', property.address, isLanguageSensitive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isLanguageSensitive = false}) {
    final useKrutidev = isLanguageSensitive && _isKrutidev;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: useKrutidev
                ? const TextStyle(
                    fontFamily: UlbLanguageHelper.krutidevFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  )
                : GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF333333),
                  ),
          ),
        ),
      ],
    );
  }
}
