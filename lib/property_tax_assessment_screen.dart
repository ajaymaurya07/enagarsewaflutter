import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'services/property_tax_calculator.dart';
import 'services/database_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'tour_guides/property_tax_assessment_tour.dart';
import 'help/property_tax_assessment_help.dart';

class PropertyTaxAssessmentScreen extends StatefulWidget {
  const PropertyTaxAssessmentScreen({super.key});

  @override
  State<PropertyTaxAssessmentScreen> createState() =>
      _PropertyTaxAssessmentScreenState();
}

class _PropertyTaxAssessmentScreenState
    extends State<PropertyTaxAssessmentScreen> {
  static const Color _primaryColor = Color(0xFFE67514);
  static const Color _primaryDark = Color(0xFFCC5E0F);
  static const Color _surfaceTint = Color(0xFFFFF4E8);
  static const Color _surfaceBorder = Color(0xFFFFE0C5);

  int _currentStep = 1;
  bool _isLoading = true;
  final GlobalKey _keyChooseProperty = GlobalKey();
  final GlobalKey _keyRoadWidthSection = GlobalKey();
  final GlobalKey _keyConstructionTypeSection = GlobalKey();
  final GlobalKey _keyPropertyTypeSection = GlobalKey();
  final GlobalKey _keyAreaDetailsSection = GlobalKey();
  final GlobalKey _keyConstructionDetailsSection = GlobalKey();
  final GlobalKey _keyPrimaryActionButton = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;
  bool _isTourActive = false;
  int? _tourInitialStep;

  // Step 1 fields
  int? _roadWidth;
  String? _constructionType;
  String? _selectedWardNo;
  List<PropertyEntity> _savedProperties = [];
  PropertyEntity? _selectedProperty;
  final _zoneController = TextEditingController();
  final _wardController = TextEditingController();
  final _chkController = TextEditingController();

  // Step 2 fields
  String? _propertyType;
  final _ownerNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _propertyIdController = TextEditingController();
  final _mobileNoController = TextEditingController();

  // Step 3 fields
  final _rentAreaController = TextEditingController();
  final _ownAreaController = TextEditingController();
  final _constructionYearController = TextEditingController();

  // Computed
  double _areaRate = 0.0;
  PropertyTaxCalculation? _calculationResult;
  List<Map<String, String>> _wardList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await RateMasterService.loadRateData();
    final properties = await DatabaseService.getAllProperties();
    setState(() {
      _wardList = RateMasterService.getWardList();
      _savedProperties = properties;
      _isLoading = false;
    });

    await WidgetsBinding.instance.endOfFrame;
    await _autoStartTourIfFirstVisit();
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_property_tax_assessment') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_property_tax_assessment', true);
      await _startTour();
    }
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _fatherNameController.dispose();
    _houseNoController.dispose();
    _propertyIdController.dispose();
    _mobileNoController.dispose();
    _rentAreaController.dispose();
    _ownAreaController.dispose();
    _constructionYearController.dispose();
    _zoneController.dispose();
    _wardController.dispose();
    _chkController.dispose();
    super.dispose();
  }

  int get _ageOfConstruction {
    final year =
        int.tryParse(_constructionYearController.text) ?? DateTime.now().year;
    return DateTime.now().year - year;
  }

  double get _totalArea {
    final rent = double.tryParse(_rentAreaController.text) ?? 0.0;
    final own = double.tryParse(_ownAreaController.text) ?? 0.0;
    return rent + own;
  }

  void _updateAreaRate() {
    if (_selectedWardNo != null &&
        _constructionType != null &&
        _roadWidth != null) {
      _areaRate = RateMasterService.getBaseRate(
        wardNo: _selectedWardNo!,
        constructionType: _constructionType!,
        roadWidth: _roadWidth!,
      );
    }
  }

  bool _isStepValid(int step) {
    switch (step) {
      case 1:
        if (_roadWidth == null || _constructionType == null) {
          _showToast('Road Width & Construction Type are mandatory!');
          return false;
        }
        if (_selectedWardNo == null && _savedProperties.isNotEmpty) {
          _showToast('Please select a property!');
          return false;
        }
        return true;
      case 2:
        if (_propertyType == null) {
          _showToast('Property Type is mandatory!');
          return false;
        }
        return true;
      case 3:
        if (_rentAreaController.text.isEmpty ||
            _ownAreaController.text.isEmpty ||
            _constructionYearController.text.isEmpty) {
          _showToast(
            'Rent Area, Own Area and Construction Year are mandatory!',
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _primaryDark,
      ),
    );
  }

  void _showTourSegment({required TargetFocus target, VoidCallback? onFinish}) {
    _tutorialCoachMark = PropertyTaxAssessmentTourGuide.createCoachMark(
      targets: [target],
      onAdvance: () => _tutorialCoachMark?.next(),
      onFinish: onFinish,
      onSkip: _handleTourSkip,
    )..show(context: context);
  }

  Future<void> _scrollToTourTarget(GlobalKey keyTarget) async {
    final targetContext = keyTarget.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.18,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _showTourStep(
    List<PropertyTaxAssessmentTourStep> steps,
    int index,
  ) async {
    if (!mounted || index >= steps.length) {
      _resetTourState();
      return;
    }

    final step = steps[index];
    if (_currentStep != step.formStep) {
      setState(() {
        _currentStep = step.formStep;
      });
      if (step.formStep == 4) {
        _calculateResult();
      }
      await WidgetsBinding.instance.endOfFrame;
    }

    await _scrollToTourTarget(step.keyTarget);
    if (!mounted) {
      return;
    }

    _showTourSegment(
      target: step.target,
      onFinish: () {
        _showTourStep(steps, index + 1);
      },
    );
  }

  Future<void> _startTour() async {
    if (_isLoading || !mounted || _isTourActive) {
      return;
    }

    final steps = PropertyTaxAssessmentTourGuide.buildSteps(
      choosePropertyKey: _savedProperties.isNotEmpty ? _keyChooseProperty : null,
      roadWidthSectionKey: _keyRoadWidthSection,
      constructionTypeSectionKey: _keyConstructionTypeSection,
      propertyTypeSectionKey: _keyPropertyTypeSection,
      areaDetailsSectionKey: _keyAreaDetailsSection,
      constructionDetailsSectionKey: _keyConstructionDetailsSection,
      actionButtonKey: _keyPrimaryActionButton,
    );

    setState(() {
      _tourInitialStep = _currentStep;
      _isTourActive = true;
    });

    await _showTourStep(steps, 0);
  }

  bool _handleTourSkip() {
    _resetTourState();
    return true;
  }

  void _resetTourState() {
    final initialStep = _tourInitialStep;
    _tutorialCoachMark = null;

    if (!mounted) {
      _isTourActive = false;
      _tourInitialStep = null;
      return;
    }

    setState(() {
      _isTourActive = false;
      _tourInitialStep = null;
      if (initialStep != null) {
        _currentStep = initialStep;
      }
    });

    if (initialStep == 4) {
      _calculateResult();
    }
  }

  void _handleNext() {
    if (_isTourActive) return;
    if (!_isStepValid(_currentStep)) return;

    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
        if (_currentStep == 4) {
          _calculateResult();
        }
      });
    } else {
      // Final step → Generate PDF
      _generatePdf();
    }
  }

  void _handleBack() {
    if (_isTourActive) return;
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _calculateResult() {
    _updateAreaRate();
    final result = PropertyTaxCalculator.calculate(
      areaOwn: double.tryParse(_ownAreaController.text) ?? 0.0,
      areaRent: double.tryParse(_rentAreaController.text) ?? 0.0,
      rate: _areaRate,
      age: _ageOfConstruction,
    );
    setState(() => _calculationResult = result);
  }

  Future<void> _generatePdf() async {
    if (_calculationResult == null) {
      _showToast('Calculation data not available');
      return;
    }

    final data = _calculationResult!;
    final pdf = pw.Document();
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'PROPERTY TAX CALCULATION & COMPARISON REPORT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated On: $now',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Property & Owner Details
              pw.Text(
                'Property & Owner Details',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              _pdfRow('Property ID', _propertyIdController.text),
              _pdfRow('Owner Name', _ownerNameController.text),
              _pdfRow('Mobile Number', _mobileNoController.text),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Area & Structure Details
              pw.Text(
                'Area & Structure Details',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              _pdfRow('Area Rate', _areaRate.toStringAsFixed(2)),
              _pdfRow('Construction Year', _constructionYearController.text),
              _pdfRow('Age Of Structure', '$_ageOfConstruction years'),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Assessment ARV
              pw.Text(
                'Assessment ARV',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              _pdfRow('MRV Owner', data.mrvOwner.toStringAsFixed(2)),
              _pdfRow('MRV Rented', data.mrvRented.toStringAsFixed(2)),
              _pdfRow('ARV Owner', data.arvOwner.toStringAsFixed(2)),
              _pdfRow('ARV Rented', data.arvRented.toStringAsFixed(2)),
              _pdfRow('Depreciation', data.depreciation.toStringAsFixed(2)),
              _pdfRow('Appreciation', data.appreciation.toStringAsFixed(2)),
              _pdfRow(
                'Final ARV (Owner)',
                data.finalArvOwner.toStringAsFixed(2),
              ),
              _pdfRow(
                'Final ARV (Rent)',
                data.finalArvRented.toStringAsFixed(2),
              ),
              _pdfRow(
                'Total Assessment ARV',
                (data.finalArvOwner + data.finalArvRented).toStringAsFixed(2),
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Assessment Tax
              pw.Text(
                'Assessment Tax',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              _pdfRow('Net Owner Tax', '₹ ${data.ownerTax.toStringAsFixed(2)}'),
              _pdfRow(
                'Net Rented Tax',
                '₹ ${data.rentedTax.toStringAsFixed(2)}',
              ),
              _pdfRow('Total Tax', '₹ ${data.totalTax.toStringAsFixed(2)}'),
              pw.Divider(),
              pw.SizedBox(height: 16),

              pw.Center(
                child: pw.Text(
                  'Generated by e-Nagarseva | System generated document',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/Property_Tax_Comparison_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;
    _showToast('PDF Generated Successfully');

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Property_Tax_Comparison.pdf',
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
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
            onPressed: _handleBack,
          ),
          title: Text(
            'Property Tax Assessment (Step $_currentStep of 4)',
            style: GoogleFonts.poppins(
              color: const Color(0xFF333333),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline_rounded, color: _primaryColor),
              tooltip: 'Tour Guide',
              onPressed: _startTour,
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryColor))
            : Column(
                children: [
                  // Step Indicator
                  _buildStepIndicator(),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildCurrentStep(),
                    ),
                  ),
                  // Bottom Buttons
                  _buildBottomButtons(),
                ],
              ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      color: Colors.white,
      child: Row(
        children: List.generate(4, (i) {
          final step = i + 1;
          final isActive = step == _currentStep;
          final isCompleted = step < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? _primaryDark
                        : isActive
                        ? _primaryColor
                        : Colors.grey.shade300,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '$step',
                            style: GoogleFonts.poppins(
                              color: isActive
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                if (i < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? _primaryDark : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      default:
        return _buildStep1();
    }
  }

  void _onPropertySelected(PropertyEntity? property) {
    if (property == null) return;
    setState(() {
      _selectedProperty = property;
      _wardController.text = property.ward;
      _chkController.text = property.mohalla;
      _ownerNameController.text = property.ownerName;
      _propertyIdController.text = property.propertyId;
      _mobileNoController.text = property.phoneNumber;
      if (property.fatherName != null) {
        _fatherNameController.text = property.fatherName!;
      }

      // Match ward by WardName from rate_master
      final wardText = property.ward.trim().toLowerCase();
      _selectedWardNo = null;
      for (final w in _wardList) {
        if ((w['WardName'] ?? '').toLowerCase() == wardText ||
            w['WardNo'] == wardText) {
          _selectedWardNo = w['WardNo'];
          break;
        }
      }
      // If no match found, use default ward "0"
      _selectedWardNo ??= '0';
      _updateAreaRate();
    });
  }

  void _showPropertySelectionSheet() {
    if (_isTourActive) {
      return;
    }

    if (_savedProperties.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PropertySelectionSheet(
        title: 'Select Property',
        items: _savedProperties.map((property) => property.propertyId).toList(),
        onSelected: (index) => _onPropertySelected(_savedProperties[index]),
      ),
    );
  }

  // ─── Step 1: Property Selection, Ward, Road Width, Construction Type ───
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Property Selection from DB
        if (_savedProperties.isNotEmpty) ...[
          _sectionTitle('Select Property'),
          const SizedBox(height: 12),
          Material(
            key: _keyChooseProperty,
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _showPropertySelectionSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _surfaceBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.home_work_outlined,
                      color: _primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Property',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedProperty?.propertyId ??
                                'Choose Property',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _selectedProperty == null
                                  ? Colors.grey.shade500
                                  : const Color(0xFF333333),
                              fontWeight: _selectedProperty == null
                                  ? FontWeight.w400
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Show Zone, Ward, Chk info cards if property selected
          if (_selectedProperty != null) ...[
            _buildInfoCard(
              'Ward',
              _wardController.text.isEmpty ? '-' : _wardController.text,
            ),
            const SizedBox(height: 10),
            _buildInfoCard(
              'Mohalla / Chk',
              _chkController.text.isEmpty ? '-' : _chkController.text,
            ),
            const SizedBox(height: 10),
          ],
          const Divider(height: 32),
        ],
        Container(
          key: _keyRoadWidthSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _sectionTitle('Road Width'),
              const SizedBox(height: 12),
              _buildRadioGroup<int>(
                options: {1: '< 12m', 2: '12-24m', 3: '> 24m'},
                groupValue: _roadWidth,
                onChanged: (val) {
                  setState(() {
                    _roadWidth = val;
                    _updateAreaRate();
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          key: _keyConstructionTypeSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Construction Type'),
              const SizedBox(height: 12),
              _buildRadioGroup<String>(
                options: {'RCC': 'RCC / RBC', 'KACHA': 'Kacha'},
                groupValue: _constructionType,
                onChanged: (val) {
                  setState(() {
                    _constructionType = val;
                    _updateAreaRate();
                  });
                },
              ),
              if (_areaRate > 0) ...[
                const SizedBox(height: 20),
                _buildInfoCard(
                  'Area Rate',
                  '₹ ${_areaRate.toStringAsFixed(2)} / sq.ft',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Property Type & Owner Info ───
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: _keyPropertyTypeSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Property Type'),
              const SizedBox(height: 12),
              _buildRadioGroup<String>(
                options: {
                  'Residency': 'Residential',
                  'Non-Residency': 'Non-Residential',
                },
                groupValue: _propertyType,
                onChanged: (val) => setState(() => _propertyType = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Owner Details'),
        const SizedBox(height: 12),
        _buildTextField(
          'Owner Name',
          _ownerNameController,
          Icons.person_outlined,
          helpTitle: PropertyTaxAssessmentHelp.ownerNameTitle,
          helpMessage: PropertyTaxAssessmentHelp.ownerNameMessage,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          'Father/Husband Name',
          _fatherNameController,
          Icons.person_outline,
          helpTitle: PropertyTaxAssessmentHelp.fatherNameTitle,
          helpMessage: PropertyTaxAssessmentHelp.fatherNameMessage,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          'House No.',
          _houseNoController,
          Icons.home_outlined,
          helpTitle: PropertyTaxAssessmentHelp.houseNoTitle,
          helpMessage: PropertyTaxAssessmentHelp.houseNoMessage,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          'Property ID',
          _propertyIdController,
          Icons.badge_outlined,
          helpTitle: PropertyTaxAssessmentHelp.propertyIdTitle,
          helpMessage: PropertyTaxAssessmentHelp.propertyIdMessage,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          'Mobile No.',
          _mobileNoController,
          Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          helpTitle: PropertyTaxAssessmentHelp.mobileNoTitle,
          helpMessage: PropertyTaxAssessmentHelp.mobileNoMessage,
        ),
      ],
    );
  }

  // ─── Step 3: Area & Construction Details ───
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: _keyAreaDetailsSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Area Details (in Sq.ft)'),
              const SizedBox(height: 12),
              _buildTextField(
                'Rent Area',
                _rentAreaController,
                Icons.square_foot_outlined,
                keyboardType: TextInputType.number,
                helpTitle: PropertyTaxAssessmentHelp.rentAreaTitle,
                helpMessage: PropertyTaxAssessmentHelp.rentAreaMessage,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                'Own Area',
                _ownAreaController,
                Icons.square_foot_outlined,
                keyboardType: TextInputType.number,
                helpTitle: PropertyTaxAssessmentHelp.ownAreaTitle,
                helpMessage: PropertyTaxAssessmentHelp.ownAreaMessage,
              ),
              const SizedBox(height: 14),
              _buildInfoCard(
                'Total Area',
                '${_totalArea.toStringAsFixed(2)} Sq.ft',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          key: _keyConstructionDetailsSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Construction Details'),
              const SizedBox(height: 12),
              _buildTextField(
                'Construction Year',
                _constructionYearController,
                Icons.calendar_today_outlined,
                keyboardType: TextInputType.number,
                helpTitle: PropertyTaxAssessmentHelp.constructionYearTitle,
                helpMessage: PropertyTaxAssessmentHelp.constructionYearMessage,
              ),
              const SizedBox(height: 14),
              _buildInfoCard('Age of Structure', '$_ageOfConstruction years'),
              const SizedBox(height: 14),
              _buildInfoCard('Area Rate', '₹ ${_areaRate.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 4: Calculation Result ───
  Widget _buildStep4() {
    if (_calculationResult == null) {
      return const Center(child: Text('No calculation data available'));
    }
    final data = _calculationResult!;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      // Row 1: MRV Owner | MRV Rented
        Row(
          children: [
            Expanded(
              child: _readOnlyField(
                'MRV Owner',
                data.mrvOwner.toStringAsFixed(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _readOnlyField(
                'MRV Rented',
                data.mrvRented.toStringAsFixed(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Row 2: ARV Owner | ARV Rented
        Row(
          children: [
            Expanded(
              child: _readOnlyField(
                'ARV Owner',
                data.arvOwner.toStringAsFixed(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _readOnlyField(
                'ARV Rented',
                data.arvRented.toStringAsFixed(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Row 3: Depreciation | Appreciation
        Row(
          children: [
            Expanded(
              child: _readOnlyField(
                'Depreciation',
                data.depreciation.toStringAsFixed(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _readOnlyField(
                'Appreciation',
                data.appreciation.toStringAsFixed(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Row 4: Final ARV(Own) | Final ARV(Rent)
        Row(
          children: [
            Expanded(
              child: _readOnlyField(
                'Final ARV(Own)',
                data.finalArvOwner.toStringAsFixed(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _readOnlyField(
                'Final ARV(Rent)',
                data.finalArvRented.toStringAsFixed(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Row 5: Net Owner Tax | Net Rented Tax
        Row(
          children: [
            Expanded(
              child: _readOnlyField(
                'Net Owner Tax',
                data.ownerTax.toStringAsFixed(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _readOnlyField(
                'Net Rented Tax',
                data.rentedTax.toStringAsFixed(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Full width: Total Assessment ARV(Own+Rent)
        _readOnlyField(
          'Total Assessment ARV(Own+Rent)',
          (data.finalArvOwner + data.finalArvRented).toStringAsFixed(2),
        ),
        const SizedBox(height: 14),
        // Full width: Total Assessment Tax(Own+Rent)
        _readOnlyField(
          'Total Assessment Tax(Own+Rent)',
          data.totalTax.toStringAsFixed(2),
        ),
        const SizedBox(height: 14),
        // Full width: Current ARV (empty for now)
        _readOnlyField('Current ARV', ''),
        const SizedBox(height: 14),
        // Full width: Current Tax (empty for now)
        _readOnlyField('Current Tax', ''),
      ],
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reusable Widgets ───

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

  Widget _buildRadioGroup<T>({
    required Map<T, String> options,
    required T? groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: options.entries.map((e) {
        final isSelected = groupValue == e.key;
        return GestureDetector(
          onTap: () {
            if (_isTourActive) {
              return;
            }
            onChanged(e.key);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? _primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _primaryColor : Colors.grey.shade300,
              ),
            ),
            child: Text(
              e.value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF555555),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? helpTitle,
    String? helpMessage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        readOnly: _isTourActive,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
          prefixIcon: Icon(icon, color: _primaryColor, size: 20),
          suffixIcon: helpMessage != null
              ? Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFE67514),
                      size: 18,
                    ),
                    onPressed: () => showDialog(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: Color(0xFFE67514), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              helpTitle ?? label,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
                        ),
                        content: Text(
                          helpMessage,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.6),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('OK',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFFE67514),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF555555),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 1)
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _handleBack,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 1) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep > 1 ? 2 : 1,
            child: SizedBox(
              key: _keyPrimaryActionButton,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentStep == 4 ? 'Download Tax Comparison PDF' : 'Next',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertySelectionSheet extends StatefulWidget {
  const _PropertySelectionSheet({
    required this.title,
    required this.items,
    required this.onSelected,
  });

  final String title;
  final List<String> items;
  final Function(int) onSelected;

  @override
  State<_PropertySelectionSheet> createState() => _PropertySelectionSheetState();
}

class _PropertySelectionSheetState extends State<_PropertySelectionSheet> {
  late List<String> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (widget.items.length > 5)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterItems,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search property...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return ListTile(
                  title: Text(item, style: GoogleFonts.poppins(fontSize: 15)),
                  onTap: () {
                    final originalIndex = widget.items.indexOf(item);
                    widget.onSelected(originalIndex);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
