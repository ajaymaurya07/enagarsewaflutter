import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'apply_grievance_screen.dart' show SelectionSheet;
import 'services/api_service.dart';
import 'services/otp_gate_service.dart';
import 'services/storage_service.dart';
import 'widgets/assessment_progress_bar.dart';

/// Four-part "New Water & Sewerage Connection" application form.
///
/// Step 1 House Basic Details        (manual entry)
/// Step 2 Address + Correspondence   (Zone/Ward/Mohalla from API, rest manual)
/// Step 3 Connection Details         (pipe size from the Fetch Pipe Size API)
/// Step 4 Upload Documents
class NewWaterConnectionScreen extends StatefulWidget {
  const NewWaterConnectionScreen({super.key});

  @override
  State<NewWaterConnectionScreen> createState() =>
      _NewWaterConnectionScreenState();
}

class _NewWaterConnectionScreenState extends State<NewWaterConnectionScreen> {
  static const Color _primaryColor = Color(0xFFE67514);
  static const Color _textColor = Color(0xFF333333);
  static const Color _disabledFillColor = Color(0xFFF3F4F6);
  static const int _totalSteps = 4;
  static const int _maxDocSizeBytes = 200 * 1024;

  static const List<String> _relationOptions = ['S/o', 'D/o', 'W/o'];
  static const List<String> _connectionTypeOptions = ['Permanent', 'Temporary'];
  static const List<String> _connectionRequiredOptions = [
    'Water',
    'Sewerage',
    'Both',
  ];
  static const List<String> _connectionCategoryOptions = [
    'Domestic',
    'Commercial',
  ];
  static const List<String> _idProofOptions = [
    'Aadhaar Card',
    'PAN',
    'Voter ID',
  ];

  /// Labels shown to the applicant mapped to the values the submit API accepts
  /// for `documents.propertyProofType`.
  static const Map<String, String> _propertyDocOptions = {
    'Registry / Sale Deed (First & Last Page)': 'SALE_DEED',
    'Lease Agreement (First & Last Page)': 'Lease Agreement',
  };

  /// The pipe size lookup is re-run as the applicant types the plot area, so
  /// the calls are debounced by this much idle time.
  static const Duration _pipeSizeDebounce = Duration(milliseconds: 600);

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  int _currentStep = 0;

  // Step 1 - House Basic Details
  final _ownerNameController = TextEditingController();
  final _fatherHusbandNameController = TextEditingController();
  final _mobileNoController = TextEditingController();
  String _relation = _relationOptions.first;

  // Step 2 - Address of New Connection
  final _plotHouseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  ZoneData? _selectedZone;
  WardData? _selectedWard;
  MohallaData? _selectedMohalla;

  // Step 2 - Communication / Correspondence Address
  bool _sameAsAbove = false;
  final _plotHouseNoController2 = TextEditingController();
  final _streetController2 = TextEditingController();
  final _landmarkController2 = TextEditingController();
  ZoneData? _selectedZone2;
  WardData? _selectedWard2;
  MohallaData? _selectedMohalla2;

  // Step 3 - Connection Details
  String? _connectionType;
  String? _connectionRequired;
  final _propertyIdController = TextEditingController();
  final _plotAreaController = TextEditingController();
  String? _connectionCategory;
  // Pipe size is not chosen by the applicant — the backend derives it from the
  // connection category and the plot area.
  String? _pipeSize;
  String? _pipeSizeError;
  Timer? _pipeSizeDebounceTimer;
  // Guards against a slow earlier lookup landing after a newer one.
  int _pipeSizeRequestId = 0;

  // Step 4 - Upload Documents
  String? _idProofType;
  PlatformFile? _idProofFile;
  String? _propertyDocType;
  PlatformFile? _propertyDocFile;
  PlatformFile? _selfPhotoFile;

  String? _ulbId;
  List<ZoneData> _zoneList = [];
  List<WardData> _wardList = [];
  List<MohallaData> _mohallaList = [];
  // The correspondence address cascades independently, so it needs its own
  // ward/mohalla lists — sharing them would overwrite the other address's
  // options as soon as either zone changed.
  List<WardData> _wardList2 = [];
  List<MohallaData> _mohallaList2 = [];

  bool _isLoadingUlbId = true;
  bool _isLoadingZones = false;
  bool _isLoadingWards = false;
  bool _isLoadingMohallas = false;
  bool _isLoadingWards2 = false;
  bool _isLoadingMohallas2 = false;
  bool _isLoadingPipeSize = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUlbId();
  }

  @override
  void dispose() {
    _pipeSizeDebounceTimer?.cancel();
    _ownerNameController.dispose();
    _fatherHusbandNameController.dispose();
    _mobileNoController.dispose();
    _propertyIdController.dispose();
    _plotAreaController.dispose();
    _plotHouseNoController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _plotHouseNoController2.dispose();
    _streetController2.dispose();
    _landmarkController2.dispose();
    super.dispose();
  }

  // Effective correspondence address — when "Same as Above" is ticked the
  // primary address is read through directly instead of being copied, so the
  // two can never drift apart.
  String get _corrPlotHouseNo => _sameAsAbove
      ? _plotHouseNoController.text.trim()
      : _plotHouseNoController2.text.trim();
  String get _corrStreet =>
      _sameAsAbove ? _streetController.text.trim() : _streetController2.text.trim();
  String get _corrLandmark => _sameAsAbove
      ? _landmarkController.text.trim()
      : _landmarkController2.text.trim();
  ZoneData? get _corrZone => _sameAsAbove ? _selectedZone : _selectedZone2;
  WardData? get _corrWard => _sameAsAbove ? _selectedWard : _selectedWard2;
  MohallaData? get _corrMohalla =>
      _sameAsAbove ? _selectedMohalla : _selectedMohalla2;

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

  Future<void> _fetchWards(String zoneId, {required bool correspondence}) async {
    final ulbId = _ulbId;
    if (ulbId == null) return;

    setState(() {
      if (correspondence) {
        _isLoadingWards2 = true;
      } else {
        _isLoadingWards = true;
      }
    });
    List<WardData> wards = [];
    try {
      wards = await ApiService.getWardData(ulbId, zoneId);
    } catch (_) {
      // Fall through: the list stays empty and the field stays unselectable.
    }
    if (!mounted) return;
    setState(() {
      if (correspondence) {
        _wardList2 = wards;
        _isLoadingWards2 = false;
      } else {
        _wardList = wards;
        _isLoadingWards = false;
      }
    });
  }

  Future<void> _fetchMohallas(
    String zoneId,
    String wardId, {
    required bool correspondence,
  }) async {
    final ulbId = _ulbId;
    if (ulbId == null) return;

    setState(() {
      if (correspondence) {
        _isLoadingMohallas2 = true;
      } else {
        _isLoadingMohallas = true;
      }
    });
    List<MohallaData> mohallas = [];
    try {
      mohallas = await ApiService.getMohallaData(ulbId, zoneId, wardId);
    } catch (_) {
      // Fall through: the list stays empty and the field stays unselectable.
    }
    if (!mounted) return;
    setState(() {
      if (correspondence) {
        _mohallaList2 = mohallas;
        _isLoadingMohallas2 = false;
      } else {
        _mohallaList = mohallas;
        _isLoadingMohallas = false;
      }
    });
  }

  /// Schedules a pipe size lookup once both inputs it depends on are present.
  /// Called whenever the connection category or the plot area changes.
  void _scheduleFetchPipeSize() {
    _pipeSizeDebounceTimer?.cancel();

    final category = _connectionCategory;
    final plotArea = _plotAreaController.text.trim();
    // Any previously fetched size belongs to the old inputs, so drop it.
    setState(() {
      _pipeSize = null;
      _pipeSizeError = null;
    });

    if (category == null ||
        plotArea.isEmpty ||
        (double.tryParse(plotArea) ?? 0) <= 0) {
      setState(() => _isLoadingPipeSize = false);
      return;
    }

    setState(() => _isLoadingPipeSize = true);
    _pipeSizeDebounceTimer = Timer(
      _pipeSizeDebounce,
      () => _fetchPipeSize(category, plotArea),
    );
  }

  Future<void> _fetchPipeSize(String connectionCategory, String plotArea) async {
    final requestId = ++_pipeSizeRequestId;

    String? pipeSize;
    String? error;
    try {
      // responseCode 12 = expired/incorrect session token: the gate sends and
      // verifies an OTP for the property, then retries this lookup once.
      final response = await OtpGateService.guard(
        call: () => ApiService.getPipeSize(
          categoryConnection: connectionCategory,
          plotArea: plotArea,
        ),
        responseCode: (r) => r.responseCode,
        propertyId: _propertyIdController.text.trim(),
        mobileNo: _mobileNoController.text.trim(),
      );
      if (response.success && response.data != null) {
        pipeSize = response.data;
      } else {
        error = response.message.isNotEmpty
            ? response.message
            : 'Pipe size not available for the entered plot area.';
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }

    // A newer lookup has been started since — let that one own the state.
    if (!mounted || requestId != _pipeSizeRequestId) return;
    setState(() {
      _pipeSize = pipeSize;
      _pipeSizeError = error;
      _isLoadingPipeSize = false;
    });
  }

  void _showSelectionSheet({
    required String title,
    required List<String> items,
    required Function(int) onSelected,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          SelectionSheet(title: title, items: items, onSelected: onSelected),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDocument(
    void Function(PlatformFile) onPicked, {
    List<String> allowedExtensions = const ['pdf'],
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;

      if (file.size > _maxDocSizeBytes) {
        if (!mounted) return;
        final sizeInKb = (file.size / 1024).toStringAsFixed(1);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 10),
                Text(
                  'File Too Large',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Selected file size is ${sizeInKb}KB which exceeds the 200KB '
              'limit.\n\nPlease select a smaller file.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }
      setState(() => onPicked(file));
    } catch (_) {}
  }

  // ---------------------------------------------------------------- navigation

  void _handleBack() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentStep--);
  }

  void _handleContinue() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateCurrentStep()) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      return;
    }
    _submit();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step1FormKey.currentState?.validate() ?? false;
      case 1:
        return _validateStep2();
      case 2:
        return _validateStep3();
      default:
        return _validateStep4();
    }
  }

  bool _validateStep2() {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return false;
    if (_selectedZone == null || _selectedWard == null || _selectedMohalla == null) {
      _showSnackBar('Please select Zone, Ward and Mohalla');
      return false;
    }
    if (!_sameAsAbove &&
        (_selectedZone2 == null ||
            _selectedWard2 == null ||
            _selectedMohalla2 == null)) {
      _showSnackBar(
        'Please select Zone, Ward and Mohalla for the correspondence address',
      );
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (!(_step3FormKey.currentState?.validate() ?? false)) return false;
    if (_connectionType == null) {
      _showSnackBar('Please select Connection Type');
      return false;
    }
    if (_connectionRequired == null) {
      _showSnackBar('Please select Connection Required');
      return false;
    }
    if (_connectionCategory == null) {
      _showSnackBar('Please select Connection Category');
      return false;
    }
    if (_isLoadingPipeSize) {
      _showSnackBar('Please wait, fetching the applicable pipe size...');
      return false;
    }
    if (_pipeSize == null) {
      _showSnackBar(
        _pipeSizeError ??
            'Pipe size could not be determined. Please check the Plot Area '
                'and Connection Category.',
      );
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    if (_idProofType == null) {
      _showSnackBar('Please select an ID Proof Type');
      return false;
    }
    if (_idProofFile == null) {
      _showSnackBar('Please upload the ID Proof document');
      return false;
    }
    if (_propertyDocType == null) {
      _showSnackBar('Please select a Document Related to Property');
      return false;
    }
    if (_propertyDocFile == null) {
      _showSnackBar('Please upload the Document Related to Property');
      return false;
    }
    if (_selfPhotoFile == null) {
      _showSnackBar('Please upload your Self Photo');
      return false;
    }
    if (_idProofFile!.path == null ||
        _propertyDocFile!.path == null ||
        _selfPhotoFile!.path == null) {
      _showSnackBar('Could not read a selected file. Please choose it again.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    String? ackNo;
    String? errorMessage;
    try {
      // responseCode 12 = expired/incorrect session token: the gate sends and
      // verifies an OTP for the property, then retries the submit once.
      final response = await OtpGateService.guard(
        call: () => ApiService.submitConnection(
          applicantName: _ownerNameController.text.trim(),
          relationType: _relation,
          fatherHusbandName: _fatherHusbandNameController.text.trim(),
          mobileNo: _mobileNoController.text.trim(),
          newZoneId: _selectedZone!.zoneId,
          newWardId: _selectedWard!.wardId,
          newMohallaId: _selectedMohalla!.mohallaId,
          newPlotNo: _plotHouseNoController.text.trim(),
          newStreet: _streetController.text.trim(),
          newLandmark: _landmarkController.text.trim(),
          corrZoneId: _corrZone!.zoneId,
          corrWardId: _corrWard!.wardId,
          corrMohallaId: _corrMohalla!.mohallaId,
          corrPlotNo: _corrPlotHouseNo,
          corrStreet: _corrStreet,
          corrLandmark: _corrLandmark,
          connectionType: _connectionType!,
          connectionRequirement: _connectionRequired!,
          propertyId: _propertyIdController.text.trim(),
          plotArea: _plotAreaController.text.trim(),
          connectionCategory: _connectionCategory!,
          pipeSize: _pipeSize!,
          idProofType: _idProofType!,
          propertyProofType: _propertyDocOptions[_propertyDocType]!,
          selfPhoto: File(_selfPhotoFile!.path!),
          idProofDocument: File(_idProofFile!.path!),
          propertyProofDocument: File(_propertyDocFile!.path!),
        ),
        responseCode: (r) => r.responseCode,
        propertyId: _propertyIdController.text.trim(),
        mobileNo: _mobileNoController.text.trim(),
      );
      if (response.success) {
        ackNo = response.ackNo;
      } else {
        errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Failed to submit the application. Please try again.';
      }
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (errorMessage != null) {
      _showSnackBar(errorMessage);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              'Submitted',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Your new water & sewerage connection application has been '
          'submitted.'
          '${ackNo != null ? '\n\nAcknowledgement No: $ackNo' : ''}',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // The ack no is handed back so the list screen can refresh.
              Navigator.pop(context, ackNo ?? true);
            },
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0 && !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isSubmitting) return;
        _handleBack();
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _primaryColor,
                size: 20,
              ),
              onPressed: _isSubmitting ? null : _handleBack,
            ),
            title: Text(
              'New Water & Sewerage Connection',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(38),
              child: AssessmentProgressBar(
                currentStep: _currentStep + 1,
                totalSteps: _totalSteps,
              ),
            ),
          ),
          body: SingleChildScrollView(
            key: ValueKey(_currentStep),
            padding: const EdgeInsets.all(16),
            child: switch (_currentStep) {
              0 => _buildStep1(),
              1 => _buildStep2(),
              2 => _buildStep3(),
              _ => _buildStep4(),
            },
          ),
          bottomNavigationBar: _buildBottomBar(),
        ),
      ),
    );
  }

  // ------------------------------------------------- step 1: basic house details

  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('House Basic Details'),
          const SizedBox(height: 4),
          _sectionHint('Enter the details of the house owner.'),
          const SizedBox(height: 14),
          _buildTextField(
            'House Owner Name',
            _ownerNameController,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _relation,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _textColor,
                    ),
                    items: _relationOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _relation = value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  'Father/Husband Name',
                  _fatherHusbandNameController,
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Mobile Number',
            _mobileNoController,
            isRequired: true,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            digitsOnly: true,
            validator: (value) {
              final mobileNo = value?.trim() ?? '';
              if (mobileNo.isEmpty) return 'Please enter Mobile Number';
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobileNo)) {
                return 'Please enter a valid 10-digit mobile number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- step 2: addresses

  Widget _buildStep2() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Address of New Connection'),
          const SizedBox(height: 4),
          _sectionHint('Where the new connection has to be installed.'),
          const SizedBox(height: 14),
          _buildZoneField(correspondence: false),
          const SizedBox(height: 16),
          _buildWardField(correspondence: false),
          const SizedBox(height: 16),
          _buildMohallaField(correspondence: false),
          const SizedBox(height: 16),
          _buildTextField(
            'Plot/House No.',
            _plotHouseNoController,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Street/Road',
            _streetController,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Landmark',
            _landmarkController,
            isRequired: true,
            hintText: 'ex: near school, near PCO',
          ),

          const SizedBox(height: 28),
          _sectionTitle('Communication/Correspondence Address'),
          const SizedBox(height: 4),
          _sectionHint('Where letters and notices should be delivered.'),
          CheckboxListTile(
            value: _sameAsAbove,
            onChanged: (value) =>
                setState(() => _sameAsAbove = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: _primaryColor,
            dense: true,
            title: Text(
              'Same as above address',
              style: GoogleFonts.poppins(fontSize: 14, color: _textColor),
            ),
          ),
          const SizedBox(height: 4),
          if (_sameAsAbove) ...[
            _buildReadOnlyField('Zone', _corrZone?.zoneName),
            const SizedBox(height: 12),
            _buildReadOnlyField('Ward', _corrWard?.wardName),
            const SizedBox(height: 12),
            _buildReadOnlyField('Mohalla', _corrMohalla?.mohallaName),
            const SizedBox(height: 12),
            _buildReadOnlyField('Plot/House No.', _corrPlotHouseNo),
            const SizedBox(height: 12),
            _buildReadOnlyField('Street/Road', _corrStreet),
            const SizedBox(height: 12),
            _buildReadOnlyField('Landmark', _corrLandmark),
          ] else ...[
            _buildZoneField(correspondence: true),
            const SizedBox(height: 16),
            _buildWardField(correspondence: true),
            const SizedBox(height: 16),
            _buildMohallaField(correspondence: true),
            const SizedBox(height: 16),
            _buildTextField(
              'Plot/House No.',
              _plotHouseNoController2,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Street/Road',
              _streetController2,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Landmark',
              _landmarkController2,
              isRequired: true,
              hintText: 'ex: near school, near PCO',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoneField({required bool correspondence}) {
    final selected = correspondence ? _selectedZone2 : _selectedZone;
    return _buildSelectableField(
      label: 'Zone',
      hint: _isLoadingUlbId
          ? 'Loading...'
          : (_ulbId == null || _ulbId!.isEmpty)
              ? 'ULB not found. Please open Dashboard first.'
              : _isLoadingZones
                  ? 'Loading Zones...'
                  : (selected?.zoneName ?? 'Select Zone'),
      onTap: (_isLoadingUlbId ||
              _ulbId == null ||
              _ulbId!.isEmpty ||
              _isLoadingZones)
          ? null
          : () => _showSelectionSheet(
                title: 'Select Zone',
                items: _zoneList.map((e) => e.zoneName).toList(),
                onSelected: (index) {
                  final zone = _zoneList[index];
                  setState(() {
                    if (correspondence) {
                      _selectedZone2 = zone;
                      _selectedWard2 = null;
                      _selectedMohalla2 = null;
                      _wardList2 = [];
                      _mohallaList2 = [];
                    } else {
                      _selectedZone = zone;
                      _selectedWard = null;
                      _selectedMohalla = null;
                      _wardList = [];
                      _mohallaList = [];
                    }
                  });
                  _fetchWards(zone.zoneId, correspondence: correspondence);
                },
              ),
    );
  }

  Widget _buildWardField({required bool correspondence}) {
    final zone = correspondence ? _selectedZone2 : _selectedZone;
    final selected = correspondence ? _selectedWard2 : _selectedWard;
    final isLoading = correspondence ? _isLoadingWards2 : _isLoadingWards;
    final wards = correspondence ? _wardList2 : _wardList;
    return _buildSelectableField(
      label: 'Ward',
      hint: isLoading
          ? 'Loading Wards...'
          : (selected?.wardName ?? 'Select Ward'),
      onTap: (zone == null || isLoading)
          ? null
          : () => _showSelectionSheet(
                title: 'Select Ward',
                items: wards.map((e) => e.wardName).toList(),
                onSelected: (index) {
                  final ward = wards[index];
                  setState(() {
                    if (correspondence) {
                      _selectedWard2 = ward;
                      _selectedMohalla2 = null;
                      _mohallaList2 = [];
                    } else {
                      _selectedWard = ward;
                      _selectedMohalla = null;
                      _mohallaList = [];
                    }
                  });
                  _fetchMohallas(
                    zone.zoneId,
                    ward.wardId,
                    correspondence: correspondence,
                  );
                },
              ),
    );
  }

  Widget _buildMohallaField({required bool correspondence}) {
    final ward = correspondence ? _selectedWard2 : _selectedWard;
    final selected = correspondence ? _selectedMohalla2 : _selectedMohalla;
    final isLoading = correspondence ? _isLoadingMohallas2 : _isLoadingMohallas;
    final mohallas = correspondence ? _mohallaList2 : _mohallaList;
    return _buildSelectableField(
      label: 'Mohalla',
      hint: isLoading
          ? 'Loading Mohallas...'
          : (selected?.mohallaName ?? 'Select Mohalla'),
      onTap: (ward == null || isLoading)
          ? null
          : () => _showSelectionSheet(
                title: 'Select Mohalla',
                items: mohallas.map((e) => e.mohallaName).toList(),
                onSelected: (index) {
                  final mohalla = mohallas[index];
                  setState(() {
                    if (correspondence) {
                      _selectedMohalla2 = mohalla;
                    } else {
                      _selectedMohalla = mohalla;
                    }
                  });
                },
              ),
    );
  }

  // ------------------------------------------------- step 3: connection details

  Widget _buildStep3() {
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Connection Details'),
          const SizedBox(height: 4),
          _sectionHint('Tell us what kind of connection you need.'),
          const SizedBox(height: 14),
          _buildSelectableField(
            label: 'Connection Type',
            hint: _connectionType ?? 'Select Connection Type',
            onTap: () => _showSelectionSheet(
              title: 'Select Connection Type',
              items: _connectionTypeOptions,
              onSelected: (index) => setState(
                () => _connectionType = _connectionTypeOptions[index],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSelectableField(
            label: 'Connection Required',
            hint: _connectionRequired ?? 'Select Connection Required',
            onTap: () => _showSelectionSheet(
              title: 'Select Connection Required',
              items: _connectionRequiredOptions,
              onSelected: (index) => setState(
                () => _connectionRequired = _connectionRequiredOptions[index],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Property ID',
            _propertyIdController,
            isRequired: true,
            hintText: 'Property ID alloted to property by ULB',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Plot Area (in sq. m)',
            _plotAreaController,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decimalsAllowed: true,
            onChanged: (_) => _scheduleFetchPipeSize(),
            validator: (value) {
              final plotArea = value?.trim() ?? '';
              if (plotArea.isEmpty) return 'Please enter Plot Area';
              final parsed = double.tryParse(plotArea);
              if (parsed == null || parsed <= 0) {
                return 'Please enter a valid plot area';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildSelectableField(
            label: 'Connection Category',
            hint: _connectionCategory ?? 'Select Connection Category',
            onTap: () => _showSelectionSheet(
              title: 'Select Connection Category',
              items: _connectionCategoryOptions,
              onSelected: (index) {
                setState(
                  () => _connectionCategory = _connectionCategoryOptions[index],
                );
                _scheduleFetchPipeSize();
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildPipeSizeField(),
        ],
      ),
    );
  }

  /// Pipe size comes from the Fetch Pipe Size API, so it is displayed rather
  /// than picked. It refreshes whenever the category or plot area changes.
  Widget _buildPipeSizeField() {
    final String value;
    if (_isLoadingPipeSize) {
      value = 'Fetching Pipe Size...';
    } else if (_pipeSize != null) {
      value = '$_pipeSize mm';
    } else if (_connectionCategory == null || _plotAreaController.text.trim().isEmpty) {
      value = 'Enter Plot Area & select Connection Category';
    } else {
      value = 'Not available';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReadOnlyField('Pipe Size (in mm)', value),
        if (_pipeSizeError != null) ...[
          const SizedBox(height: 6),
          Text(
            _pipeSizeError!,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------- step 4: upload documents

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Upload Documents'),
        const SizedBox(height: 4),
        _sectionHint(
          'Documents must be PDF and the photo JPG, each up to 200 KB.',
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('ID Proof Type (select any one)'),
        _buildRadioGroup(
          options: _idProofOptions,
          groupValue: _idProofType,
          onChanged: (value) => setState(() => _idProofType = value),
        ),
        const SizedBox(height: 10),
        _buildFileUploadRow(
          file: _idProofFile,
          onPick: () => _pickDocument((f) => _idProofFile = f),
        ),
        const SizedBox(height: 24),
        _buildFieldLabel('Document Related to Property (select any one)'),
        _buildRadioGroup(
          options: _propertyDocOptions.keys.toList(),
          groupValue: _propertyDocType,
          onChanged: (value) => setState(() => _propertyDocType = value),
        ),
        const SizedBox(height: 10),
        _buildFileUploadRow(
          file: _propertyDocFile,
          onPick: () => _pickDocument((f) => _propertyDocFile = f),
        ),
        const SizedBox(height: 24),
        _buildFieldLabel('Self Photo (scanned passport size)'),
        const SizedBox(height: 4),
        _buildFileUploadRow(
          file: _selfPhotoFile,
          hintText: 'No file chosen (JPG, max 200 KB)',
          onPick: () => _pickDocument(
            (f) => _selfPhotoFile = f,
            allowedExtensions: const ['jpg', 'jpeg'],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------ shared field widgets

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _textColor,
      ),
    );
  }

  Widget _sectionHint(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _textColor,
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
    int? maxLength,
    bool digitsOnly = false,
    bool decimalsAllowed = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      onChanged: onChanged,
      inputFormatters: [
        if (digitsOnly)
          FilteringTextInputFormatter.digitsOnly
        else if (decimalsAllowed)
          FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
        else
          FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
      ],
      style: GoogleFonts.poppins(fontSize: 14, color: _textColor),
      validator: validator ??
          (isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter $label';
                  }
                  return null;
                }
              : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        counterText: '',
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.poppins(
          color: Colors.grey.shade500,
          fontSize: 12,
        ),
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: _primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildSelectableField({
    String? label,
    required String hint,
    VoidCallback? onTap,
  }) {
    final isPlaceholder = hint.contains('Select') ||
        hint.contains('Loading') ||
        hint.contains('not found');
    final field = GestureDetector(
      onTap: onTap ?? () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null ? _disabledFillColor : Colors.white,
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
                  color: isPlaceholder ? Colors.grey.shade600 : _textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade600,
            ),
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

  /// Mirrors a value picked elsewhere in the form. Rendered as plain text (not
  /// a disabled field) so it never steals focus from the keyboard.
  Widget _buildReadOnlyField(String label, String? value) {
    final hasValue = value != null && value.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _disabledFillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            hasValue ? value : 'Not filled yet',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: hasValue ? _textColor : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioGroup({
    required List<String> options,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return RadioGroup<String>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options.map((option) {
          return InkWell(
            onTap: () => onChanged(option),
            child: Row(
              children: [
                Radio<String>(
                  value: option,
                  activeColor: _primaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    option,
                    style: GoogleFonts.poppins(fontSize: 13, color: _textColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFileUploadRow({
    required PlatformFile? file,
    required VoidCallback onPick,
    String hintText = 'No file chosen (PDF, max 200 KB)',
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: onPick,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              side: const BorderSide(color: _primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              file == null ? 'Choose File' : 'Replace',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              file?.name ?? hintText,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: file == null ? Colors.grey.shade600 : _textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (file != null)
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == _totalSteps - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _handleBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: const BorderSide(color: _primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child: SizedBox(
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
                          isLastStep ? 'Submit' : 'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
