import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'apply_grievance_screen.dart' show SelectionSheet;
import 'assessment_step3_screen.dart';

class ReassessmentScreen extends StatefulWidget {
  const ReassessmentScreen({super.key});

  @override
  State<ReassessmentScreen> createState() => _ReassessmentScreenState();
}

class _ReassessmentScreenState extends State<ReassessmentScreen> {
  static const Color _primaryColor = Color(0xFFE67514);

  bool _isLoadingProperties = true;
  List<PropertyEntity> _savedProperties = [];
  PropertyEntity? _selectedProperty;

  bool _isFetchingPreCheck = false;
  ReassessmentGetS1Data? _preCheckData;

  bool _isInitializing = false;
  ReassessmentStep1Data? _step1Data;

  bool _isFetchingFloorConfig = false;

  @override
  void initState() {
    super.initState();
    _loadSavedProperties();
  }

  Future<void> _loadSavedProperties() async {
    final properties = await DatabaseService.getAllProperties();
    if (!mounted) return;
    setState(() {
      _savedProperties = properties;
      _isLoadingProperties = false;
    });
  }

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

  Future<void> _onPropertySelected(PropertyEntity property) async {
    setState(() {
      _selectedProperty = property;
      _preCheckData = null;
      _step1Data = null;
      _isFetchingPreCheck = true;
    });
    try {
      final response = await ApiService.getReassessmentDetails(
        propertyId: property.propertyId,
      );
      if (!mounted) return;
      setState(() => _isFetchingPreCheck = false);

      if (response.success != true || response.data == null) {
        _showSnackBar(response.message ?? 'Failed to fetch assessment details');
        return;
      }
      setState(() => _preCheckData = response.data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingPreCheck = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to fetch assessment details. Please try again.',
        ),
      );
    }
  }

  Future<void> _handleInitialize() async {
    if (_selectedProperty == null || _preCheckData?.ackNo == null) return;

    setState(() => _isInitializing = true);
    try {
      final response = await ApiService.initializeReassessment(
        propertyId: _selectedProperty!.propertyId,
        ackNo: _preCheckData!.ackNo!,
      );
      if (!mounted) return;
      setState(() => _isInitializing = false);

      if (response.success != true || response.data == null) {
        _showSnackBar(response.message ?? 'Failed to initialize reassessment');
        return;
      }
      setState(() => _step1Data = response.data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isInitializing = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to initialize reassessment. Please try again.',
        ),
      );
    }
  }

  Future<void> _handleContinueToFloors() async {
    if (_selectedProperty == null || _step1Data?.ackNo == null) return;

    setState(() => _isFetchingFloorConfig = true);
    try {
      final response = await ApiService.fetchReassessmentFloorConfig(
        propertyId: _selectedProperty!.propertyId,
        ackNo: _step1Data!.ackNo!,
      );
      if (!mounted) return;
      setState(() => _isFetchingFloorConfig = false);

      if (response.success != true || response.data == null) {
        _showSnackBar(response.message ?? 'Failed to fetch floor configuration');
        return;
      }

      final data = response.data!;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentStep3Screen(
            ackNo: data.ackNo ?? _step1Data!.ackNo!,
            floorNoList: data.floorNoList,
            floorUsageList: data.floorUsageList,
            constructionTypeList: data.constructionTypeList,
            isReassessment: true,
            propertyId: _selectedProperty!.propertyId,
          ),
        ),
      );
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingFloorConfig = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to fetch floor configuration. Please try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Property Reassessment',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF333333),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Select Property'),
            const SizedBox(height: 12),
            _buildPropertySection(),

            if (_isFetchingPreCheck) ...[
              const SizedBox(height: 20),
              Center(child: CircularProgressIndicator(color: _primaryColor)),
            ],

            if (_preCheckData != null) ...[
              const SizedBox(height: 24),
              _sectionTitle('Last Assessment Details'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _InfoRow('Date of Last Assessment', _preCheckData!.dateOfLastAssessment ?? '-'),
                _InfoRow('No. of Floors', '${_preCheckData!.noOfFloor ?? 0}'),
                _InfoRow('Ack No.', _preCheckData!.ackNo ?? '-'),
              ]),
              if (_step1Data == null) ...[
                const SizedBox(height: 20),
                _buildActionButton(
                  label: 'Continue',
                  isLoading: _isInitializing,
                  onPressed: _handleInitialize,
                ),
              ],
            ],

            if (_step1Data != null) ...[
              const SizedBox(height: 24),
              _sectionTitle('Property Details'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _InfoRow('Owner Name', _step1Data!.ownerName ?? '-'),
                _InfoRow('Father/Husband Name', _step1Data!.fatherName ?? '-'),
                _InfoRow('House No.', _step1Data!.houseNo ?? '-'),
                _InfoRow('Address', _step1Data!.address ?? '-'),
                _InfoRow('Zone', _step1Data!.zoneName ?? '-'),
                _InfoRow('Ward', _step1Data!.wardName ?? '-'),
                _InfoRow('Mohalla', _step1Data!.mohallaName ?? '-'),
                _InfoRow('Road Location', _step1Data!.roadLocationName ?? '-'),
                _InfoRow('Property Type', _step1Data!.propertyTypeName ?? '-'),
                _InfoRow(
                  'Total Area',
                  _step1Data!.totalArea != null
                      ? '${_step1Data!.totalArea} sq.ft.'
                      : '-',
                ),
                _InfoRow('Old ARV', _step1Data!.oldArv ?? '-'),
              ]),
              const SizedBox(height: 20),
              _buildActionButton(
                label: 'Continue to Floor Details',
                isLoading: _isFetchingFloorConfig,
                onPressed: _handleContinueToFloors,
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    rows[i].label,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Text(
                    rows[i].value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertySection() {
    if (_isLoadingProperties) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    if (_savedProperties.isEmpty) {
      return _buildSelectableField(hint: 'No saved property found', onTap: null);
    }

    return _buildSelectableField(
      hint: _selectedProperty?.propertyId ?? 'Select Property ID',
      onTap: () => _showSelectionSheet(
        title: 'Select Property',
        items: _savedProperties.map((e) => e.propertyId).toList(),
        onSelected: (index) => _onPropertySelected(_savedProperties[index]),
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
                  color: hint.contains('Select') || hint.contains('No saved')
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
}

class _InfoRow {
  final String label;
  final String value;

  _InfoRow(this.label, this.value);
}
