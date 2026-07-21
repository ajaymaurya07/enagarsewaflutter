import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/otp_gate_service.dart';
import 'services/assessment_exit_guard.dart';
import 'widgets/assessment_progress_bar.dart';
import 'apply_grievance_screen.dart' show SelectionSheet;
import 'assessment_document_upload_screen.dart';

class AssessmentStep3Screen extends StatefulWidget {
  final String ackNo;
  final Map<String, String> floorNoList;
  final Map<String, String> floorUsageList;
  final Map<String, String> constructionTypeList;
  final bool isReassessment;
  final String propertyId;
  final String mobileNo;

  const AssessmentStep3Screen({
    super.key,
    required this.ackNo,
    required this.floorNoList,
    required this.floorUsageList,
    required this.constructionTypeList,
    this.isReassessment = false,
    required this.propertyId,
    required this.mobileNo,
  });

  @override
  State<AssessmentStep3Screen> createState() => _AssessmentStep3ScreenState();
}

class _AssessmentStep3ScreenState extends State<AssessmentStep3Screen> {
  static const Color _primaryColor = Color(0xFFE67514);

  final _floorFormKey = GlobalKey<FormState>();
  final _rebateFormKey = GlobalKey<FormState>();

  final TextEditingController _constructionDateController =
      TextEditingController();
  final TextEditingController _carpetAreaController = TextEditingController();
  final TextEditingController _roomsPorchAreaController =
      TextEditingController();
  final TextEditingController _kitchenBalconyAreaController =
      TextEditingController();
  final TextEditingController _garageAreaController = TextEditingController();

  bool _isSavingFloor = false;
  bool _isFinalizing = false;
  int? _deletingFloorNumber;

  String? _selectedFloorNumberKey;
  String? _selectedFloorUsageCode;
  String? _selectedConstructionTypeId;
  String _areaEnterMode = 'MR';

  bool _isLoadingFloorTypes = false;
  List<FloorType> _floorTypeList = [];
  FloorType? _selectedFloorType;

  List<FloorDetailItem> _floorList = [];
  double? _totalArv;
  Map<String, String> _rebateFinancialYearList = {};

  String? _selectedRebateFinyear;
  final String _isRebateClaimed = 'Y';
  bool _isLoadingRebateTypes = false;
  List<RebateType> _rebateTypeList = [];
  RebateType? _selectedRebateType;

  AssessmentStep3Data? _finalResult;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _onFloorUsageSelected(String code) async {
    setState(() {
      _selectedFloorUsageCode = code;
      _selectedFloorType = null;
      _floorTypeList = [];
      _isLoadingFloorTypes = true;
    });
    try {
      final response = await OtpGateService.guard(
        call: () => ApiService.getFloorTypeList(code),
        responseCode: (r) => r.responseCode,
        propertyId: widget.propertyId,
        mobileNo: widget.mobileNo,
      );
      if (!mounted) return;
      setState(() {
        _floorTypeList = response.data;
        _isLoadingFloorTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFloorTypes = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to load floor types.',
        ),
      );
    }
  }

  Future<void> _pickConstructionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final formatted =
        '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
    setState(() => _constructionDateController.text = formatted);
  }

  Future<void> _handleSaveFloor() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_floorFormKey.currentState?.validate() ?? false)) return;
    if (_selectedFloorNumberKey == null) {
      _showSnackBar('Please select Floor Number');
      return;
    }
    if (_selectedFloorUsageCode == null) {
      _showSnackBar('Please select Floor Usage');
      return;
    }
    if (_selectedFloorType == null) {
      _showSnackBar('Please select Floor Type');
      return;
    }
    if (_selectedConstructionTypeId == null) {
      _showSnackBar('Please select Construction Type');
      return;
    }

    setState(() => _isSavingFloor = true);
    try {
      final response = await OtpGateService.guard(
        call: () => widget.isReassessment
            ? ApiService.saveReassessmentFloor(
                ackNo: widget.ackNo,
                floorNumber: int.tryParse(_selectedFloorNumberKey!) ?? 0,
                floorUsageCode: _selectedFloorUsageCode!,
                floorTypeId: _selectedFloorType!.id ?? 0,
                constructionTypeId:
                    int.tryParse(_selectedConstructionTypeId!) ?? 0,
                constructionDate: _constructionDateController.text.trim(),
                carpetArea:
                    int.tryParse(_carpetAreaController.text.trim()) ?? 0,
                roomsPorchArea:
                    int.tryParse(_roomsPorchAreaController.text.trim()) ?? 0,
                kitchenBalconyArea: int.tryParse(
                        _kitchenBalconyAreaController.text.trim()) ??
                    0,
                garageArea:
                    int.tryParse(_garageAreaController.text.trim()) ?? 0,
                areaEnterMode: _areaEnterMode,
              )
            : ApiService.saveFloorDetails(
                ackNo: widget.ackNo,
                floorNumber: int.tryParse(_selectedFloorNumberKey!) ?? 0,
                floorUsageCode: _selectedFloorUsageCode!,
                floorTypeId: _selectedFloorType!.id ?? 0,
                constructionTypeId:
                    int.tryParse(_selectedConstructionTypeId!) ?? 0,
                constructionDate: _constructionDateController.text.trim(),
                carpetArea:
                    int.tryParse(_carpetAreaController.text.trim()) ?? 0,
                roomsPorchArea:
                    int.tryParse(_roomsPorchAreaController.text.trim()) ?? 0,
                kitchenBalconyArea: int.tryParse(
                        _kitchenBalconyAreaController.text.trim()) ??
                    0,
                garageArea:
                    int.tryParse(_garageAreaController.text.trim()) ?? 0,
                areaEnterMode: _areaEnterMode,
              ),
        responseCode: (r) => r.responseCode,
        propertyId: widget.propertyId,
        mobileNo: widget.mobileNo,
      );

      if (!mounted) return;
      setState(() => _isSavingFloor = false);

      if (response.success != true || response.data == null) {
        _showSnackBar(response.message ?? 'Failed to save floor details');
        return;
      }

      final data = response.data!;
      setState(() {
        _floorList = data.floorList;
        _totalArv = data.totalArv;
        _rebateFinancialYearList = data.rebateFinancialYearList;
        // reset the add-floor form for the next floor
        _selectedFloorNumberKey = null;
        _selectedFloorUsageCode = null;
        _selectedFloorType = null;
        _floorTypeList = [];
        _selectedConstructionTypeId = null;
        _constructionDateController.clear();
        _carpetAreaController.clear();
        _roomsPorchAreaController.clear();
        _kitchenBalconyAreaController.clear();
        _garageAreaController.clear();
      });
      _loadRebateTypes();
      _showSnackBar(response.message ?? 'Floor details saved successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingFloor = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to save floor details. Please try again.',
        ),
      );
    }
  }

  Future<void> _handleDeleteFloor(int floorNumber) async {
    setState(() => _deletingFloorNumber = floorNumber);
    try {
      final response = await OtpGateService.guard(
        call: () => widget.isReassessment
            ? ApiService.deleteReassessmentFloor(
                ackNo: widget.ackNo,
                floorNumber: floorNumber,
              )
            : ApiService.deleteFloorDetails(
                ackNo: widget.ackNo,
                floorNumber: floorNumber,
              ),
        responseCode: (r) => r.responseCode,
        propertyId: widget.propertyId,
        mobileNo: widget.mobileNo,
      );

      if (!mounted) return;
      setState(() => _deletingFloorNumber = null);

      if (response.success != true) {
        _showSnackBar(response.message ?? 'Failed to delete floor');
        return;
      }

      setState(() {
        _floorList =
            _floorList.where((f) => f.floorNumber != floorNumber).toList();
      });
      _showSnackBar(response.message ?? 'Floor deleted successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingFloorNumber = null);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to delete floor. Please try again.',
        ),
      );
    }
  }

  Future<void> _loadRebateTypes() async {
    if (_rebateTypeList.isNotEmpty || _isLoadingRebateTypes) return;
    setState(() => _isLoadingRebateTypes = true);
    try {
      final response = await OtpGateService.guard(
        call: () => ApiService.getRebateTypeList(),
        responseCode: (r) => r.responseCode,
        propertyId: widget.propertyId,
        mobileNo: widget.mobileNo,
      );
      if (!mounted) return;
      setState(() {
        _rebateTypeList = response.data;
        _isLoadingRebateTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingRebateTypes = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to load rebate types.',
        ),
      );
    }
  }

  Future<void> _handleFinalize() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_rebateFormKey.currentState?.validate() ?? false)) return;
    if (_floorList.isEmpty) {
      _showSnackBar('Please add at least one floor before finalizing');
      return;
    }
    if (_selectedRebateFinyear == null) {
      _showSnackBar('Please select a Rebate Financial Year');
      return;
    }
    if (_isRebateClaimed == 'Y' && _selectedRebateType == null) {
      _showSnackBar('Please select a Rebate Type');
      return;
    }

    // debugPrint('[Step3Finalize] _handleFinalize -> ackNo=${widget.ackNo}, isReassessment=${widget.isReassessment}');
    setState(() => _isFinalizing = true);
    try {
      final response = await OtpGateService.guard(
        call: () => widget.isReassessment
            ? ApiService.submitReassessmentStep3(
                ackNo: widget.ackNo,
                propertyId: widget.propertyId,
                rebateFinyear:
                    _rebateFinancialYearList[_selectedRebateFinyear!]!,
                isRebateClaimed: _isRebateClaimed,
                rebateTypeId: _isRebateClaimed == 'Y'
                    ? _selectedRebateType!.rebateId
                    : 0,
              )
            : ApiService.submitAssessmentStep3(
                ackNo: widget.ackNo,
                rebateFinyear:
                    _rebateFinancialYearList[_selectedRebateFinyear!]!,
                isRebateClaimed: _isRebateClaimed,
                rebateTypeId: _isRebateClaimed == 'Y'
                    ? _selectedRebateType!.rebateId
                    : 0,
              ),
        responseCode: (r) => r.responseCode,
        propertyId: widget.propertyId,
        mobileNo: widget.mobileNo,
      );

      // debugPrint(
        // '[Step3Finalize] response -> success=${response.success}, dataIsNull=${response.data == null}, mounted=$mounted',
      // );
      if (!mounted) return;
      setState(() => _isFinalizing = false);

      if (response.success != true || response.data == null) {
        _showSnackBar(response.message ?? 'Failed to finalize assessment');
        return;
      }

      // debugPrint('[Step3Finalize] Success -> rendering final summary.');
      setState(() => _finalResult = response.data);
    } catch (e) {
      // debugPrint('[Step3Finalize] Error -> $e');
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to finalize assessment. Please try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final floorNoEntries = widget.floorNoList.entries.toList();
    final floorUsageEntries = widget.floorUsageList.entries.toList();
    final constructionTypeEntries = widget.constructionTypeList.entries.toList();
    final rebateFinyearEntries = _rebateFinancialYearList.entries.toList();

    final totalSteps = widget.isReassessment ? 3 : 4;
    final currentStep = widget.isReassessment ? 2 : 3;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await handleAssessmentBack(context);
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor, size: 20),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(38),
          child: AssessmentProgressBar(
            currentStep: currentStep,
            totalSteps: totalSteps,
          ),
        ),
      ),
      body: _finalResult != null
          ? _buildFinalSummary(_finalResult!)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_floorList.isNotEmpty) ...[
                    _sectionTitle('Saved Floors', icon: Icons.layers_outlined),
                    const SizedBox(height: 12),
                    ..._floorList.map(_buildFloorCard),
                    if (_totalArv != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Total ARV: ₹${_totalArv!.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  _sectionTitle('Add Floor', icon: Icons.add_home_work_outlined),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _floorFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _subLabel('Floor Information'),
                          const SizedBox(height: 12),
                          _buildSelectableField(
                            label: 'Floor Number',
                            hint: _selectedFloorNumberKey == null
                                ? 'Select Floor Number'
                                : widget.floorNoList[_selectedFloorNumberKey]!,
                            onTap: floorNoEntries.isEmpty
                                ? null
                                : () => _showSelectionSheet(
                                    title: 'Select Floor Number',
                                    items: floorNoEntries.map((e) => e.value).toList(),
                                    onSelected: (index) {
                                      setState(() {
                                        _selectedFloorNumberKey = floorNoEntries[index].key;
                                      });
                                    },
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _buildSelectableField(
                            label: 'Floor Usage',
                            hint: _selectedFloorUsageCode == null
                                ? 'Select Floor Usage'
                                : widget.floorUsageList[_selectedFloorUsageCode]!,
                            onTap: floorUsageEntries.isEmpty
                                ? null
                                : () => _showSelectionSheet(
                                    title: 'Select Floor Usage',
                                    items: floorUsageEntries.map((e) => e.value).toList(),
                                    onSelected: (index) {
                                      _onFloorUsageSelected(floorUsageEntries[index].key);
                                    },
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _buildSelectableField(
                            label: 'Floor Type',
                            hint: _isLoadingFloorTypes
                                ? 'Loading Floor Types...'
                                : (_selectedFloorType?.name ?? 'Select Floor Type'),
                            onTap: (_selectedFloorUsageCode == null ||
                                    _isLoadingFloorTypes ||
                                    _floorTypeList.isEmpty)
                                ? null
                                : () => _showSelectionSheet(
                                    title: 'Select Floor Type',
                                    items: _floorTypeList
                                        .map((e) => e.name ?? '-')
                                        .toList(),
                                    onSelected: (index) {
                                      setState(() {
                                        _selectedFloorType = _floorTypeList[index];
                                      });
                                    },
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _buildSelectableField(
                            label: 'Construction Type',
                            hint: _selectedConstructionTypeId == null
                                ? 'Select Construction Type'
                                : widget.constructionTypeList[_selectedConstructionTypeId]!,
                            onTap: constructionTypeEntries.isEmpty
                                ? null
                                : () => _showSelectionSheet(
                                    title: 'Select Construction Type',
                                    items: constructionTypeEntries
                                        .map((e) => e.value)
                                        .toList(),
                                    onSelected: (index) {
                                      setState(() {
                                        _selectedConstructionTypeId =
                                            constructionTypeEntries[index].key;
                                      });
                                    },
                                  ),
                          ),

                          _formDivider(),

                          _subLabel('Construction Date'),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _pickConstructionDate,
                            child: AbsorbPointer(
                              child: _buildTextField(
                                'Construction Date',
                                _constructionDateController,
                                isRequired: true,
                                hintText: 'DD-MM-YYYY',
                              ),
                            ),
                          ),

                          _formDivider(),

                          _subLabel('Area Details'),
                          const SizedBox(height: 12),
                          _buildSelectableField(
                            label: 'How do you want to enter the area?',
                            hint: _areaEnterModeLabel(_areaEnterMode),
                            onTap: () => _showSelectionSheet(
                              title: 'Select Area Entry Mode',
                              items: const ['Carpet Area', 'Measure by Room'],
                              onSelected: (index) => _onAreaEnterModeSelected(
                                index == 0 ? 'CA' : 'MR',
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _areaEnterMode == 'CA'
                                ? 'Enter the total carpet area of the floor directly.'
                                : 'Enter the area of each part of the floor separately — rooms/porch is required, kitchen/balcony and garage are optional.',
                            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 12),
                          if (_areaEnterMode == 'CA')
                            _buildTextField(
                              'Carpet Area (sq. ft.)',
                              _carpetAreaController,
                              fieldKey: const ValueKey('carpet_area_field'),
                              keyboardType: TextInputType.number,
                              isRequired: true,
                              digitsOnly: true,
                            )
                          else ...[
                            _buildTextField(
                              'Rooms & Porch Area (sq. ft.)',
                              _roomsPorchAreaController,
                              fieldKey: const ValueKey('rooms_porch_area_field'),
                              keyboardType: TextInputType.number,
                              isRequired: true,
                              digitsOnly: true,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              'Kitchen, Balcony, Corridor & Store Area (sq. ft.)',
                              _kitchenBalconyAreaController,
                              fieldKey: const ValueKey('kitchen_balcony_area_field'),
                              keyboardType: TextInputType.number,
                              digitsOnly: true,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              'Garage Area (sq. ft.)',
                              _garageAreaController,
                              fieldKey: const ValueKey('garage_area_field'),
                              keyboardType: TextInputType.number,
                              digitsOnly: true,
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSavingFloor ? null : _handleSaveFloor,
                              icon: _isSavingFloor
                                  ? const SizedBox.shrink()
                                  : const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              label: _isSavingFloor
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Save Floor',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_floorList.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _sectionTitle('Rebate Details', icon: Icons.percent_rounded),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                      key: _rebateFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSelectableField(
                            label: 'Rebate Financial Year',
                            hint: _selectedRebateFinyear == null
                                ? 'Select Financial Year'
                                : _rebateFinancialYearList[_selectedRebateFinyear]!,
                            onTap: rebateFinyearEntries.isEmpty
                                ? null
                                : () => _showSelectionSheet(
                                    title: 'Select Financial Year',
                                    items: rebateFinyearEntries
                                        .map((e) => e.value)
                                        .toList(),
                                    onSelected: (index) {
                                      setState(() {
                                        _selectedRebateFinyear =
                                            rebateFinyearEntries[index].key;
                                      });
                                    },
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _buildSelectableField(
                              label: 'Rebate Type',
                              hint: _isLoadingRebateTypes
                                  ? 'Loading Rebate Types...'
                                  : (_selectedRebateType?.rebateName ?? 'Select Rebate Type'),
                              onTap: (_isLoadingRebateTypes || _rebateTypeList.isEmpty)
                                  ? null
                                  : () => _showSelectionSheet(
                                      title: 'Select Rebate Type',
                                      items: _rebateTypeList
                                          .map((e) => e.rebateName ?? '-')
                                          .toList(),
                                      onSelected: (index) {
                                        setState(() {
                                          _selectedRebateType = _rebateTypeList[index];
                                        });
                                      },
                                    ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isFinalizing ? null : _handleFinalize,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isFinalizing
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Finalize Assessment',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
      ),
      ),
    );
  }

  Widget _buildFinalSummary(AssessmentStep3Data data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ack No: ${data.acknowledgementId ?? '-'}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total ARV: ₹${data.totalArv?.toStringAsFixed(2) ?? '-'}',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                ),
                Text(
                  'Rebate: ${data.taxRebateTypeName ?? '-'} (${data.rebateFinancialYear ?? '-'})',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Tax Breakdown'),
          const SizedBox(height: 12),
          ...data.pwsList.map(
            (pws) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FY ${pws.finYear ?? '-'}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _summaryRow('Property Tax', pws.propertyTax),
                  _summaryRow('Water Tax', pws.waterTax),
                  _summaryRow('Sewerage Tax', pws.sewerageTax),
                  _summaryRow('Other Tax', pws.otherTax),
                  const Divider(height: 20),
                  _summaryRow('Grand Total', pws.grandTotal, isBold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssessmentDocumentUploadScreen(
                      ackNo: data.acknowledgementId ?? widget.ackNo,
                      isReassessment: widget.isReassessment,
                      propertyId: widget.propertyId,
                      mobileNo: widget.mobileNo,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Upload Document & Finish',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double? value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            '₹${(value ?? 0).toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? _primaryColor : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCard(FloorDetailItem floor) {
    final floorNumber = floor.floorNumber;
    final isDeleting = _deletingFloorNumber == floorNumber;
    return Container(
      key: ValueKey('floor_card_$floorNumber'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  floor.floorName ?? 'Floor ${floorNumber ?? ''}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${floor.floorTypeName ?? '-'} • ${floor.constructionTypeName ?? '-'}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  'Area: ${floor.carpetArea ?? '-'} sq.ft. • ARV: ₹${floor.arv?.toStringAsFixed(2) ?? '-'}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryColor),
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: floorNumber == null
                      ? null
                      : () => _handleDeleteFloor(floorNumber),
                ),
        ],
      ),
    );
  }

  String _areaEnterModeLabel(String mode) {
    return mode == 'CA' ? 'Carpet Area' : 'Measure by Room';
  }

  void _onAreaEnterModeSelected(String mode) {
    setState(() {
      _areaEnterMode = mode;
      if (mode == 'CA') {
        _roomsPorchAreaController.clear();
        _kitchenBalconyAreaController.clear();
        _garageAreaController.clear();
      } else {
        _carpetAreaController.clear();
      }
    });
  }

  Widget _sectionTitle(String text, {IconData? icon}) {
    if (icon == null) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF333333),
        ),
      );
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _subLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _formDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Divider(height: 1, color: Colors.grey.shade200),
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
                  color: hint.startsWith('Select') || hint.startsWith('Loading')
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
    Key? fieldKey,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    bool digitsOnly = false,
    String? hintText,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF333333)),
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
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
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
}
