import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/otp_gate_service.dart';
import 'apply_grievance_screen.dart' show SelectionSheet;
import 'assessment_step3_screen.dart';

class AssessmentStep2Screen extends StatefulWidget {
  final String ackNo;
  final Map<String, String> roadLocationList;
  final Map<String, String> propertyTypeList;
  final Map<String, String> propertyUsesList;
  final String propertyId;
  final String mobileNo;

  const AssessmentStep2Screen({
    super.key,
    required this.ackNo,
    required this.roadLocationList,
    required this.propertyTypeList,
    required this.propertyUsesList,
    required this.propertyId,
    required this.mobileNo,
  });

  @override
  State<AssessmentStep2Screen> createState() => _AssessmentStep2ScreenState();
}

class _AssessmentStep2ScreenState extends State<AssessmentStep2Screen> {
  static const Color _primaryColor = Color(0xFFE67514);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fileNoController = TextEditingController();

  bool _isSubmitting = false;

  String? _selectedRoadLocationId;
  String? _selectedPropertyTypeId;
  String? _selectedPropertyUsesId;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedRoadLocationId == null ||
        _selectedPropertyTypeId == null ||
        _selectedPropertyUsesId == null) {
      _showSnackBar('Please select Road Location, Property Type and Property Uses');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await OtpGateService.guard(
        call: () => ApiService.submitAssessmentStep2(
          ackNo: widget.ackNo,
          fileNo: _fileNoController.text.trim(),
          roadLocationId: int.tryParse(_selectedRoadLocationId!) ?? 0,
          propertyTypeId: int.tryParse(_selectedPropertyTypeId!) ?? 0,
          propertyUseasId: int.tryParse(_selectedPropertyUsesId!) ?? 0,
        ),
        responseCode: (r) => r.responseCode,
        propertyId: widget.propertyId,
        mobileNo: widget.mobileNo,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (response.success != true || response.data == null) {
        _showSnackBar(response.message ?? 'Failed to submit assessment');
        return;
      }

      _showSnackBar(response.message ?? 'Assessment Step 2 saved successfully');

      final data = response.data!;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentStep3Screen(
            ackNo: data.ackNo ?? widget.ackNo,
            floorNoList: data.floorNoList,
            floorUsageList: data.floorUsageList,
            constructionTypeList: data.constructionTypeList,
            propertyId: widget.propertyId,
            mobileNo: widget.mobileNo,
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
    final roadLocationEntries = widget.roadLocationList.entries.toList();
    final propertyTypeEntries = widget.propertyTypeList.entries.toList();
    final propertyUsesEntries = widget.propertyUsesList.entries.toList();

    return Scaffold(
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Property Tax Assessment',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF333333),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Ack No.'),
              const SizedBox(height: 12),
              _buildReadOnlyField(widget.ackNo),

              const SizedBox(height: 24),
              _sectionTitle('File No.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fileNoController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF333333)),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter File No.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Enter File No.',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
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
              ),

              const SizedBox(height: 24),
              _sectionTitle('Road Location'),
              const SizedBox(height: 12),
              _buildSelectableField(
                hint: _selectedRoadLocationId == null
                    ? 'Select Road Location'
                    : widget.roadLocationList[_selectedRoadLocationId]!,
                onTap: roadLocationEntries.isEmpty
                    ? null
                    : () => _showSelectionSheet(
                        title: 'Select Road Location',
                        items: roadLocationEntries.map((e) => e.value).toList(),
                        onSelected: (index) {
                          setState(() {
                            _selectedRoadLocationId = roadLocationEntries[index].key;
                          });
                        },
                      ),
              ),

              const SizedBox(height: 24),
              _sectionTitle('Property Type'),
              const SizedBox(height: 12),
              _buildSelectableField(
                hint: _selectedPropertyTypeId == null
                    ? 'Select Property Type'
                    : widget.propertyTypeList[_selectedPropertyTypeId]!,
                onTap: propertyTypeEntries.isEmpty
                    ? null
                    : () => _showSelectionSheet(
                        title: 'Select Property Type',
                        items: propertyTypeEntries.map((e) => e.value).toList(),
                        onSelected: (index) {
                          setState(() {
                            _selectedPropertyTypeId = propertyTypeEntries[index].key;
                          });
                        },
                      ),
              ),

              const SizedBox(height: 24),
              _sectionTitle('Property Uses'),
              const SizedBox(height: 12),
              _buildSelectableField(
                hint: _selectedPropertyUsesId == null
                    ? 'Select Property Uses'
                    : widget.propertyUsesList[_selectedPropertyUsesId]!,
                onTap: propertyUsesEntries.isEmpty
                    ? null
                    : () => _showSelectionSheet(
                        title: 'Select Property Uses',
                        items: propertyUsesEntries.map((e) => e.value).toList(),
                        onSelected: (index) {
                          setState(() {
                            _selectedPropertyUsesId = propertyUsesEntries[index].key;
                          });
                        },
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
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
      ),
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

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        value,
        style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF333333)),
      ),
    );
  }

  Widget _buildSelectableField({
    required String hint,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
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
                  color: hint.startsWith('Select')
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
  }
}
