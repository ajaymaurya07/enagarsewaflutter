import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'apply_grievance_screen.dart' show SelectionSheet;
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/otp_gate_service.dart';
import 'services/storage_service.dart';
import 'utils/mutation_ui.dart';
import 'widgets/assessment_progress_bar.dart';

/// Four-part "Property Mutation" application form.
///
/// Step 1 Property & Mutation Cause   (saved Property ID lookup via the
///                                     Mutation Basic Details API)
/// Step 2 Owner & Occupier Details    (new owner, occupier, communication)
/// Step 3 Registry, Cost & Fees       (Mutation Fetch Fees API)
/// Step 4 Upload Documents            (Mutation Apply API, multipart)
class NewMutationScreen extends StatefulWidget {
  const NewMutationScreen({super.key});

  @override
  State<NewMutationScreen> createState() => _NewMutationScreenState();
}

class _NewMutationScreenState extends State<NewMutationScreen> {
  static const Color _primaryColor = MutationUi.primaryColor;
  static const Color _textColor = MutationUi.textColor;
  static const Color _disabledFillColor = Color(0xFFF3F4F6);
  static const int _totalSteps = 4;
  static const int _maxDocSizeBytes = 200 * 1024;

  static const List<String> _salutationOptions = ['S/o', 'D/o', 'W/o'];
  static const List<String> _occupiedByOptions = ['Self', 'Other'];
  static const List<String> _flagJujOptions = [
    'Normal Mutation',
    'Jujbhag (against existing application)',
  ];

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  int _currentStep = 0;

  // Step 1 - Property lookup
  bool _isLoadingSavedProperties = true;
  List<PropertyEntity> _savedProperties = [];
  PropertyEntity? _selectedProperty;
  bool _isLoadingProperty = false;
  String? _propertyError;
  MutationPropertyData? _propertyData;
  String? _selectedCauseId;
  String? _selectedIdProofId;

  // Step 2 - Owner & occupier details
  String _propertyOccupiedBy = _occupiedByOptions.first;
  final _occupierNameController = TextEditingController();
  final _occupierFatherNameController = TextEditingController();
  final _occupierMobileController = TextEditingController();
  final _occupierTimeController = TextEditingController();
  final _newOwnerNameController = TextEditingController();
  String _fatherHusbandSalutation = _salutationOptions.first;
  final _fatherHusbandNameController = TextEditingController();
  final _mobileNoController = TextEditingController();
  final _alternateMobileNoController = TextEditingController();
  final _emailIdController = TextEditingController();
  final _communicationAddressController = TextEditingController();
  final _pinCodeController = TextEditingController();
  int _flagJuj = 0;

  // Step 3 - Registry, cost & fees
  final _propertyCostController = TextEditingController();
  final _registryDateController = TextEditingController();
  String? _ulbId;
  bool _isLoadingFees = false;
  String? _feesError;
  MutationFees? _fees;

  // Step 4 - Documents
  PlatformFile? _idProofDoc;
  PlatformFile? _affidavitDoc;
  PlatformFile? _occupierPhotoDoc;
  PlatformFile? _registryFirstFront;
  PlatformFile? _registryFirstBack;
  PlatformFile? _registryLastFront;
  PlatformFile? _registryLastBack;
  PlatformFile? _additionalDoc;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUlbId();
    _loadSavedProperties();
  }

  @override
  void dispose() {
    _occupierNameController.dispose();
    _occupierFatherNameController.dispose();
    _occupierMobileController.dispose();
    _occupierTimeController.dispose();
    _newOwnerNameController.dispose();
    _fatherHusbandNameController.dispose();
    _mobileNoController.dispose();
    _alternateMobileNoController.dispose();
    _emailIdController.dispose();
    _communicationAddressController.dispose();
    _pinCodeController.dispose();
    _propertyCostController.dispose();
    _registryDateController.dispose();
    super.dispose();
  }

  Future<void> _loadUlbId() async {
    final ulbId = await StorageService.getUlbCache();
    if (!mounted) return;
    setState(() => _ulbId = ulbId);
  }

  Future<void> _loadSavedProperties() async {
    final properties = await DatabaseService.getAllProperties();
    if (!mounted) return;
    setState(() {
      _savedProperties = properties;
      _isLoadingSavedProperties = false;
    });
  }

  // ------------------------------------------------------------- step 1: lookup

  Future<void> _onPropertySelected(PropertyEntity property) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final propertyId = property.propertyId;
    setState(() {
      _selectedProperty = property;
      _propertyData = null;
      _selectedCauseId = null;
      _selectedIdProofId = null;
      _fees = null;
      _feesError = null;
      _isLoadingProperty = true;
      _propertyError = null;
    });

    try {
      final response = await OtpGateService.guard(
        call: () => ApiService.getMutationPropertyData(propertyId: propertyId),
        responseCode: (r) => r.responseCode,
        propertyId: propertyId,
        mobileNo: property.phoneNumber,
      );
      if (!mounted || _selectedProperty != property) return;
      if (!response.success || response.data == null) {
        setState(() {
          _isLoadingProperty = false;
          _propertyError = response.message.isNotEmpty
              ? response.message
              : 'Property details not found for this Property ID.';
        });
        return;
      }
      setState(() {
        _propertyData = response.data;
        _isLoadingProperty = false;
        _selectedCauseId = null;
        _selectedIdProofId = null;
        _mobileNoController.text = response.data!.mobile == '0'
            ? ''
            : response.data!.mobile;
      });
    } catch (e) {
      if (!mounted || _selectedProperty != property) return;
      setState(() {
        _isLoadingProperty = false;
        _propertyError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ------------------------------------------------------------ step 3: fees

  Future<void> _fetchFees() async {
    if (!(_step3FormKey.currentState?.validate() ?? false)) return;
    final ulbId = _ulbId;
    final cause = _selectedCauseId;
    final property = _propertyData;
    if (ulbId == null || ulbId.isEmpty) {
      _showSnackBar('ULB not found. Please open Dashboard first.');
      return;
    }
    if (cause == null || property == null) {
      _showSnackBar('Please select a Mutation Cause in Step 1');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLoadingFees = true;
      _feesError = null;
      _fees = null;
    });

    try {
      final response = await OtpGateService.guard(
        call: () => ApiService.getMutationFees(
          ulbId: ulbId,
          propertyCost: _propertyCostController.text.trim(),
          mutationCause: cause,
          currentArv: property.arv,
          registryDate: _registryDateController.text.trim(),
        ),
        responseCode: (r) => r.responseCode,
        propertyId: property.propertyId,
        mobileNo: _mobileNoController.text.trim(),
      );
      if (!mounted) return;
      if (!response.success || response.data == null) {
        setState(() {
          _isLoadingFees = false;
          _feesError = response.message.isNotEmpty
              ? response.message
              : 'Unable to calculate mutation fees.';
        });
        return;
      }
      setState(() {
        _fees = response.data;
        _isLoadingFees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFees = false;
        _feesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickRegistryDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final formatted =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      _registryDateController.text = formatted;
      // Any previously fetched fee belongs to the old registry date.
      _fees = null;
      _feesError = null;
    });
  }

  // -------------------------------------------------------- shared helpers

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

  // TODO: set back to false before release - skips per-step validation so
  // every step can be opened for UI testing.
  static const bool _skipStepValidation = true;

  void _handleContinue() {
    FocusManager.instance.primaryFocus?.unfocus();
    final isLastStep = _currentStep == _totalSteps - 1;
    if (!(_skipStepValidation && !isLastStep) && !_validateCurrentStep()) {
      return;
    }
    if (!isLastStep) {
      setState(() => _currentStep++);
      return;
    }
    _submit();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _validateStep1();
      case 1:
        return _validateStep2();
      case 2:
        return _validateStep3();
      default:
        return _validateStep4();
    }
  }

  bool _validateStep1() {
    if (_propertyData == null) {
      _showSnackBar('Please select a Property ID first');
      return false;
    }
    if (_selectedCauseId == null) {
      _showSnackBar('Please select the Mutation Cause');
      return false;
    }
    if (_selectedIdProofId == null) {
      _showSnackBar('Please select an ID Proof Type');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return false;
    if (_propertyOccupiedBy == 'Other') {
      if (_occupierNameController.text.trim().isEmpty ||
          _occupierFatherNameController.text.trim().isEmpty ||
          _occupierMobileController.text.trim().isEmpty) {
        _showSnackBar('Please enter the occupier details');
        return false;
      }
    }
    return true;
  }

  bool _validateStep3() {
    if (!(_step3FormKey.currentState?.validate() ?? false)) return false;
    if (_isLoadingFees) {
      _showSnackBar('Please wait, calculating the applicable fees...');
      return false;
    }
    if (_fees == null) {
      _showSnackBar(
        _feesError ?? 'Please calculate the mutation fees before continuing.',
      );
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    if (_idProofDoc == null) {
      _showSnackBar('Please upload the ID Proof document');
      return false;
    }
    if (_affidavitDoc == null) {
      _showSnackBar('Please upload the Affidavit document');
      return false;
    }
    if (_occupierPhotoDoc == null) {
      _showSnackBar('Please upload the Occupier Photo');
      return false;
    }
    if (_registryFirstFront == null ||
        _registryFirstBack == null ||
        _registryLastFront == null ||
        _registryLastBack == null) {
      _showSnackBar('Please upload all four registry pages');
      return false;
    }
    if ([
      _idProofDoc,
      _affidavitDoc,
      _occupierPhotoDoc,
      _registryFirstFront,
      _registryFirstBack,
      _registryLastFront,
      _registryLastBack,
      _additionalDoc,
    ].any((f) => f != null && f.path == null)) {
      _showSnackBar('Could not read a selected file. Please choose it again.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final property = _propertyData;
    if (property == null) return;

    setState(() => _isSubmitting = true);

    String? ackNo;
    num? totalFees;
    String? errorMessage;
    try {
      final response = await OtpGateService.guard(
        call: () => ApiService.applyMutation(
          propertyId: property.propertyId,
          ulbId: _ulbId ?? '',
          oldOwnerName: property.ownerName,
          oldFatherHusbandName: property.fatherName,
          oldAddress: property.address,
          oldMobileNo: property.mobile,
          zoneName: property.zoneName,
          zoneId: property.zoneId,
          wardName: property.wardName,
          wardId: property.wardId,
          mohallaName: property.mohallaName,
          currentArv: property.arv,
          propertyOccupiedBy: _propertyOccupiedBy,
          occupierName:
              _propertyOccupiedBy == 'Self' ? '' : _occupierNameController.text.trim(),
          occupierFatherName: _propertyOccupiedBy == 'Self'
              ? ''
              : _occupierFatherNameController.text.trim(),
          occupierMobile: _propertyOccupiedBy == 'Self'
              ? ''
              : _occupierMobileController.text.trim(),
          occupierTime:
              _propertyOccupiedBy == 'Self' ? '' : _occupierTimeController.text.trim(),
          propertyCost: _propertyCostController.text.trim(),
          registryDate: _registryDateController.text.trim(),
          mutationCause: _selectedCauseId!,
          idProofType: _selectedIdProofId!,
          newOwnerName: _newOwnerNameController.text.trim(),
          fatherHusbandSalutation: _fatherHusbandSalutation,
          fatherHusbandName: _fatherHusbandNameController.text.trim(),
          mobileNo: _mobileNoController.text.trim(),
          alternateMobileNo: _alternateMobileNoController.text.trim(),
          emailId: _emailIdController.text.trim(),
          communicationAddress: _communicationAddressController.text.trim(),
          pinCode: _pinCodeController.text.trim(),
          flagJuj: _flagJuj,
          idProofDoc: File(_idProofDoc!.path!),
          affidavitDoc: File(_affidavitDoc!.path!),
          occupierPhotoDoc: File(_occupierPhotoDoc!.path!),
          registryFirstFront: File(_registryFirstFront!.path!),
          registryFirstBack: File(_registryFirstBack!.path!),
          registryLastFront: File(_registryLastFront!.path!),
          registryLastBack: File(_registryLastBack!.path!),
          additionalDoc:
              _additionalDoc?.path != null ? File(_additionalDoc!.path!) : null,
        ),
        responseCode: (r) => r.responseCode,
        propertyId: property.propertyId,
        mobileNo: _mobileNoController.text.trim(),
      );
      if (response.success) {
        ackNo = response.ackNo;
        totalFees = response.totalFees;
      } else {
        errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Failed to submit the mutation application. Please try again.';
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
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(
              'Submitted',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Your property mutation application has been submitted.'
          '${ackNo != null ? '\n\nAcknowledgement No: $ackNo' : ''}'
          '${totalFees != null ? '\nTotal Fees: ₹${MutationUi.formatAmount(totalFees.toString())}' : ''}',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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
          backgroundColor: MutationUi.backgroundColor,
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
              'New Mutation Application',
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

  // --------------------------------------------------- step 1: property lookup

  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Property Details'),
          const SizedBox(height: 4),
          _sectionHint('Select Property ID first.'),
          const SizedBox(height: 14),
          _buildPropertySelector(),
          if (_isLoadingProperty) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            ),
          ],
          if (_propertyError != null) ...[
            const SizedBox(height: 10),
            Text(
              _propertyError!,
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.red),
            ),
          ],
          if (_propertyData != null) ...[
            const SizedBox(height: 18),
            _buildPropertySummaryCard(_propertyData!),
            const SizedBox(height: 20),
            _sectionTitle('Mutation Details'),
            const SizedBox(height: 4),
            _sectionHint('Choose the reason for mutation and the ID proof type.'),
            const SizedBox(height: 14),
            _buildSelectableField(
              label: 'Mutation Cause',
              hint: _selectedCauseId != null
                  ? _propertyData!.causeList[_selectedCauseId] ?? ''
                  : 'Select Mutation Cause',
              onTap: () => _showSelectionSheet(
                title: 'Select Mutation Cause',
                items: _propertyData!.causeList.values.toList(),
                onSelected: (index) {
                  final id = _propertyData!.causeList.keys.elementAt(index);
                  setState(() {
                    _selectedCauseId = id;
                    _fees = null;
                    _feesError = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildSelectableField(
              label: 'ID Proof Type',
              hint: _selectedIdProofId != null
                  ? _propertyData!.idList[_selectedIdProofId] ?? ''
                  : 'Select ID Proof Type',
              onTap: () => _showSelectionSheet(
                title: 'Select ID Proof Type',
                items: _propertyData!.idList.values.toList(),
                onSelected: (index) {
                  final id = _propertyData!.idList.keys.elementAt(index);
                  setState(() => _selectedIdProofId = id);
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildSelectableField(
              label: 'Application Type',
              hint: _flagJujOptions[_flagJuj],
              onTap: () => _showSelectionSheet(
                title: 'Select Application Type',
                items: _flagJujOptions,
                onSelected: (index) => setState(() => _flagJuj = index),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertySelector() {
    if (_isLoadingSavedProperties) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    if (_savedProperties.isEmpty) {
      return _buildSelectableField(
        label: 'Property ID',
        hint: 'No saved property found',
      );
    }

    return _buildSelectableField(
      label: 'Property ID',
      hint: _selectedProperty?.propertyId ?? 'Select Property ID',
      onTap: _isLoadingProperty
          ? null
          : () => _showSelectionSheet(
                title: 'Select Property',
                items: _savedProperties.map((e) => e.propertyId).toList(),
                onSelected: (index) => _onPropertySelected(_savedProperties[index]),
              ),
    );
  }

  Widget _buildPropertySummaryCard(MutationPropertyData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                  size: 17,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.ownerName.isNotEmpty ? data.ownerName : 'Current Owner',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _infoRow('Property ID', data.propertyId),
          _infoRow('Address', data.address),
          _infoRow('Zone / Ward / Mohalla',
              '${data.zoneName} / ${data.wardName} / ${data.mohallaName}'),
          _infoRow('Current ARV', '₹${MutationUi.formatAmount(data.arv)}'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isNotEmpty ? value.trim() : '-',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------- step 2: owner & occupier

  Widget _buildStep2() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Occupancy Details'),
          const SizedBox(height: 4),
          _sectionHint('Who currently occupies this property?'),
          const SizedBox(height: 14),
          _buildFieldLabel('Property Occupied By'),
          const SizedBox(height: 8),
          _buildRadioGroup(
            options: _occupiedByOptions,
            groupValue: _propertyOccupiedBy,
            onChanged: (value) =>
                setState(() => _propertyOccupiedBy = value ?? _occupiedByOptions.first),
          ),
          if (_propertyOccupiedBy == 'Other') ...[
            const SizedBox(height: 12),
            _buildTextField(
              'Occupier Name',
              _occupierNameController,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Occupier Father's Name",
              _occupierFatherNameController,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Occupier Mobile',
              _occupierMobileController,
              isRequired: true,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              digitsOnly: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Occupancy Period',
              _occupierTimeController,
              hintText: 'ex: Jan 2022',
            ),
          ],
          const SizedBox(height: 26),
          _sectionTitle('New Owner Details'),
          const SizedBox(height: 4),
          _sectionHint('Details of the applicant/new owner.'),
          const SizedBox(height: 14),
          _buildTextField(
            'New Owner Name',
            _newOwnerNameController,
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
                    value: _fatherHusbandSalutation,
                    style: GoogleFonts.poppins(fontSize: 14, color: _textColor),
                    items: _salutationOptions
                        .map((option) =>
                            DropdownMenuItem(value: option, child: Text(option)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _fatherHusbandSalutation = value);
                      }
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
          const SizedBox(height: 12),
          _buildTextField(
            'Alternate Mobile Number',
            _alternateMobileNoController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            digitsOnly: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Email ID',
            _emailIdController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 26),
          _sectionTitle('Communication Address'),
          const SizedBox(height: 4),
          _sectionHint('Where letters and notices should be delivered.'),
          const SizedBox(height: 14),
          _buildTextField(
            'Communication Address',
            _communicationAddressController,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'PIN Code',
            _pinCodeController,
            isRequired: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            digitsOnly: true,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------- step 3: registry, cost & fees

  Widget _buildStep3() {
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Registry & Cost Details'),
          const SizedBox(height: 4),
          _sectionHint('Used to calculate the applicable mutation fees.'),
          const SizedBox(height: 14),
          _buildTextField(
            'Property Cost (₹)',
            _propertyCostController,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decimalsAllowed: true,
            onChanged: (_) => setState(() {
              _fees = null;
              _feesError = null;
            }),
            validator: (value) {
              final cost = value?.trim() ?? '';
              if (cost.isEmpty) return 'Please enter Property Cost';
              final parsed = double.tryParse(cost);
              if (parsed == null || parsed <= 0) {
                return 'Please enter a valid property cost';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickRegistryDate,
            child: AbsorbPointer(
              child: _buildTextField(
                'Registry Date',
                _registryDateController,
                isRequired: true,
                hintText: 'YYYY-MM-DD',
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isLoadingFees ? null : _fetchFees,
              icon: _isLoadingFees
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryColor,
                      ),
                    )
                  : const Icon(Icons.calculate_outlined, size: 18),
              label: Text(
                _isLoadingFees ? 'Calculating...' : 'Calculate Mutation Fees',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: const BorderSide(color: _primaryColor),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_feesError != null) ...[
            const SizedBox(height: 10),
            Text(
              _feesError!,
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.red),
            ),
          ],
          if (_fees != null) ...[
            const SizedBox(height: 16),
            _buildFeesCard(_fees!),
          ],
        ],
      ),
    );
  }

  Widget _buildFeesCard(MutationFees fees) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 18, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                'Fee Breakdown',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _feeRow('Mutation Fees', fees.mutationFees),
          _feeRow('Late Fees', fees.lateFees),
          _feeRow('Publication Fees', fees.publicationFees),
          _feeRow('Processing Fees', fees.processingFees),
          _feeRow('ULB Processing Fees', fees.ulbProcessingFees),
          if (num.tryParse(fees.discountRate) != null &&
              (num.tryParse(fees.discountRate) ?? 0) > 0)
            _feeRow('Discount Rate', '${fees.discountRate}%'),
          if (num.tryParse(fees.onlineDiscountAmount) != null &&
              (num.tryParse(fees.onlineDiscountAmount) ?? 0) > 0)
            _feeRow('Online Discount', fees.onlineDiscountAmount),
          _feeRow('Evidence', fees.evidence, isAmount: false),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              Text(
                '₹${MutationUi.formatAmount(fees.fees)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, {bool isAmount = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          Text(
            isAmount ? '₹${MutationUi.formatAmount(value)}' : value,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ],
      ),
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
          'Documents must be PDF, up to 200 KB each. Occupier photo must be JPG.',
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('ID Proof Document'),
        const SizedBox(height: 8),
        _buildFileUploadRow(
          file: _idProofDoc,
          onPick: () => _pickDocument((f) => _idProofDoc = f),
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('Affidavit'),
        const SizedBox(height: 8),
        _buildFileUploadRow(
          file: _affidavitDoc,
          onPick: () => _pickDocument((f) => _affidavitDoc = f),
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('Occupier Photo'),
        const SizedBox(height: 8),
        _buildFileUploadRow(
          file: _occupierPhotoDoc,
          hintText: 'No file chosen (JPG, max 200 KB)',
          onPick: () => _pickDocument(
            (f) => _occupierPhotoDoc = f,
            allowedExtensions: const ['jpg', 'jpeg'],
          ),
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('Registry - First Page (Front)'),
        const SizedBox(height: 8),
        _buildFileUploadRow(
          file: _registryFirstFront,
          onPick: () => _pickDocument((f) => _registryFirstFront = f),
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('Registry - First Page (Back)'),
        const SizedBox(height: 8),
        _buildFileUploadRow(
          file: _registryFirstBack,
          onPick: () => _pickDocument((f) => _registryFirstBack = f),
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('Registry - Last Page (Front)'),
        const SizedBox(height: 8),
        _buildFileUploadRow(
          file: _registryLastFront,
          onPick: () => _pickDocument((f) => _registryLastFront = f),
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('Registry - Last Page (Back)'),
        const SizedBox(height: 8),
        _buildFileUploadRow(
          file: _registryLastBack,
          onPick: () => _pickDocument((f) => _registryLastBack = f),
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('Additional Document (optional)'),
        const SizedBox(height: 8),
        _buildFileUploadRow(
          file: _additionalDoc,
          onPick: () => _pickDocument((f) => _additionalDoc = f),
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
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
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
    final isPlaceholder = hint.contains('Select') || hint.isEmpty;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
