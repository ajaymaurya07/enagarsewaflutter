import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/otp_gate_service.dart';
import 'services/storage_service.dart';
import 'services/assessment_exit_guard.dart';
import 'widgets/assessment_progress_bar.dart';
import 'apply_grievance_screen.dart' show SelectionSheet;
import 'assessment_step2_screen.dart';

class PropertyTaxAssessmentScreen extends StatefulWidget {
  const PropertyTaxAssessmentScreen({super.key});

  @override
  State<PropertyTaxAssessmentScreen> createState() =>
      _PropertyTaxAssessmentScreenState();
}

class _PropertyTaxAssessmentScreenState
    extends State<PropertyTaxAssessmentScreen> {
  static const Color _primaryColor = Color(0xFFE67514);

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  bool _isLoadingUlbId = true;
  String? _ulbId;

  bool _isLoadingZones = false;
  bool _isLoadingWards = false;
  bool _isLoadingMohallas = false;
  List<ZoneData> _zoneList = [];
  List<WardData> _wardList = [];
  List<MohallaData> _mohallaList = [];
  ZoneData? _selectedZone;
  WardData? _selectedWard;
  MohallaData? _selectedMohalla;

  // Personal Details
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _oldPropertyIdController = TextEditingController();

  // Location Details (manual entry)
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _houseNoController = TextEditingController();
  final TextEditingController _totalAreaController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _popularPropertyNameController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUlbId();
  }

  Future<void> _loadUlbId() async {
    final ulbId = await StorageService.getUlbCache();
    if (!mounted) return;
    setState(() {
      _ulbId = ulbId;
      _isLoadingUlbId = false;
    });
    if (ulbId != null && ulbId.isNotEmpty) {
      await _fetchZones(ulbId);
    }
  }

  Future<void> _fetchZones(String ulbId) async {
    setState(() => _isLoadingZones = true);
    final List<ZoneData> zones;
    try {
      zones = await ApiService.getZoneData(ulbId);
    } catch (_) {
      if (mounted) setState(() => _isLoadingZones = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _zoneList = zones;
      _isLoadingZones = false;
    });
  }

  Future<void> _fetchWards(String zoneId) async {
    final ulbId = _ulbId;
    if (ulbId == null) return;

    setState(() => _isLoadingWards = true);
    final List<WardData> wards;
    try {
      wards = await ApiService.getWardData(ulbId, zoneId);
    } catch (_) {
      if (mounted) setState(() => _isLoadingWards = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _wardList = wards;
      _isLoadingWards = false;
    });
  }

  Future<void> _fetchMohallas(String zoneId, String wardId) async {
    final ulbId = _ulbId;
    if (ulbId == null) return;

    setState(() => _isLoadingMohallas = true);
    final List<MohallaData> mohallas;
    try {
      mohallas = await ApiService.getMohallaData(ulbId, zoneId, wardId);
    } catch (_) {
      if (mounted) setState(() => _isLoadingMohallas = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _mohallaList = mohallas;
      _isLoadingMohallas = false;
    });
  }

  void _showSelectionSheet({
    required String title,
    required List<String> items,
    required Function(int) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          SelectionSheet(title: title, items: items, onSelected: onSelected),
    );
  }

  void _showSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedZone == null || _selectedWard == null || _selectedMohalla == null) {
      _showSnackBar('Please select Zone, Ward and Mohalla');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await OtpGateService.guard(
        call: () => ApiService.submitAssessmentStep1(
          zoneId: int.tryParse(_selectedZone!.zoneId) ?? 0,
          wardId: int.tryParse(_selectedWard!.wardId) ?? 0,
          mohallaId: int.tryParse(_selectedMohalla!.mohallaId) ?? 0,
          oldPropertyId: _oldPropertyIdController.text.trim().isEmpty
              ? '0'
              : _oldPropertyIdController.text.trim(),
          totalArea: int.tryParse(_totalAreaController.text.trim()) ??
              (double.tryParse(_totalAreaController.text.trim())?.round() ??
                  0),
          ownerName: _fullNameController.text.trim(),
          fatherHusbandName: _fatherNameController.text.trim(),
          email: _emailController.text.trim(),
          mobile: _mobileController.text.trim(),
          houseNo: _houseNoController.text.trim(),
          address: _addressController.text.trim(),
          landmark: _landmarkController.text.trim(),
          popularPropertyName: _popularPropertyNameController.text.trim(),
        ),
        responseCode: (r) => r.responseCode,
        propertyId: '',
        mobileNo: _mobileController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (response.success != true || response.data == null) {
        _showSnackBar(
          '${response.message ?? 'Failed to submit assessment'}\n'
          '(zone: ${_selectedZone!.zoneName}/${_selectedZone!.zoneId}, '
          'ward: ${_selectedWard!.wardName}/${_selectedWard!.wardId}, '
          'mohalla: ${_selectedMohalla!.mohallaName}/${_selectedMohalla!.mohallaId})',
          duration: const Duration(seconds: 8),
        );
        return;
      }

      final data = response.data!;
      final ackNo = data.ackNo;
      if (ackNo == null) {
        _showSnackBar('Assessment saved but no Ack No. was returned');
        return;
      }
      _showSnackBar(response.message ?? 'Assessment Step 1 saved with Ack No. $ackNo');

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentStep2Screen(
            ackNo: ackNo,
            roadLocationList: data.roadLocationList,
            propertyTypeList: data.propertyTypeList,
            propertyUsesList: data.propertyUsesList,
            propertyId: '',
            mobileNo: _mobileController.text.trim(),
          ),
        ),
      );
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to submit assessment. Please try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await handleAssessmentBack(context);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryColor,
            size: 20,
          ),
          onPressed: () => handleAssessmentBack(context),
        ),
        title: Text(
          'Property Tax Assessment',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF333333),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(38),
          child: AssessmentProgressBar(currentStep: 1, totalSteps: 4),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Personal Details'),
            const SizedBox(height: 12),
            _buildTextField(
              'Full Name',
              _fullNameController,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Father/Husband Name',
              _fatherNameController,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Mobile Number',
              _mobileController,
              keyboardType: TextInputType.phone,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Email ID',
              _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Old Property ID (if any)',
              _oldPropertyIdController,
            ),

            const SizedBox(height: 24),
            _sectionTitle('Location Details'),
            const SizedBox(height: 12),
            _buildSelectableField(
              label: 'Zone',
              hint: _isLoadingUlbId
                  ? 'Loading...'
                  : (_ulbId == null || _ulbId!.isEmpty)
                      ? 'ULB not found. Please open Dashboard first.'
                      : _isLoadingZones
                          ? 'Loading Zones...'
                          : (_selectedZone?.zoneName ?? 'Select Zone'),
              onTap: (_isLoadingUlbId || _ulbId == null || _ulbId!.isEmpty || _isLoadingZones)
                  ? null
                  : () => _showSelectionSheet(
                      title: 'Select Zone',
                      items: _zoneList.map((e) => e.zoneName).toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedZone = _zoneList[index];
                          _selectedWard = null;
                          _selectedMohalla = null;
                          _wardList = [];
                          _mohallaList = [];
                        });
                        _fetchWards(_selectedZone!.zoneId);
                      },
                    ),
            ),
            const SizedBox(height: 16),
            _buildSelectableField(
              label: 'Ward',
              hint: _isLoadingWards
                  ? 'Loading Wards...'
                  : (_selectedWard?.wardName ?? 'Select Ward'),
              onTap: (_selectedZone == null || _isLoadingWards)
                  ? null
                  : () => _showSelectionSheet(
                      title: 'Select Ward',
                      items: _wardList.map((e) => e.wardName).toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedWard = _wardList[index];
                          _selectedMohalla = null;
                          _mohallaList = [];
                        });
                        _fetchMohallas(
                          _selectedZone!.zoneId,
                          _selectedWard!.wardId,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            _buildSelectableField(
              label: 'Mohalla',
              hint: _isLoadingMohallas
                  ? 'Loading Mohallas...'
                  : (_selectedMohalla?.mohallaName ?? 'Select Mohalla'),
              onTap: (_selectedWard == null || _isLoadingMohallas)
                  ? null
                  : () => _showSelectionSheet(
                      title: 'Select Mohalla',
                      items:
                          _mohallaList.map((e) => e.mohallaName).toList(),
                      onSelected: (index) {
                        setState(() {
                          _selectedMohalla = _mohallaList[index];
                        });
                      },
                    ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'House Number',
              _houseNoController,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Total Area (sq. ft.)',
              _totalAreaController,
              keyboardType: TextInputType.number,
              isRequired: true,
              digitsOnly: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Address',
              _addressController,
              maxLines: 2,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField('Landmark', _landmarkController, isRequired: true),
            const SizedBox(height: 12),
            _buildTextField('Popular Property Name', _popularPropertyNameController),
          ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      ),
      ),
    );
  }

  Widget _buildSelectableField({
    String? label,
    required String hint,
    VoidCallback? onTap,
  }) {
    final field = GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: hint.contains('Select') || hint.contains('Loading')
                      ? Colors.grey.shade600
                      : const Color(0xFF333333),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
          ],
        ),
      ),
    );

    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    bool digitsOnly = false,
    bool enabled = true,
  }) {
    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: !enabled,
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: enabled ? const Color(0xFF333333) : Colors.grey.shade700,
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter $label';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );

    if (enabled) return field;

    // Disabled fields must not grab focus themselves; tapping one should
    // instead release focus from whichever field the keyboard is currently
    // showing for, otherwise the cursor appears stuck on the last-focused
    // editable field.
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AbsorbPointer(child: field),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF333333),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
