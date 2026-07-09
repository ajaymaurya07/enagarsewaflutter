import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'floor_usage_assessment_screen.dart';

class PropertyTaxAssessmentScreen extends StatefulWidget {
  const PropertyTaxAssessmentScreen({super.key});

  @override
  State<PropertyTaxAssessmentScreen> createState() =>
      _PropertyTaxAssessmentScreenState();
}

class _PropertyTaxAssessmentScreenState
    extends State<PropertyTaxAssessmentScreen> {
  static const Color _primaryColor = Color(0xFFE67514);

  bool _isLoadingRebates = true;
  String? _rebateError;
  List<RebateType> _rebateList = [];
  RebateType? _selectedRebate;

  @override
  void initState() {
    super.initState();
    _fetchRebateTypes();
  }

  Future<void> _fetchRebateTypes() async {
    setState(() {
      _isLoadingRebates = true;
      _rebateError = null;
    });

    debugPrint('[PropertyTaxAssessment] Fetching rebate types...');
    try {
      final rebates = await ApiService.getRebateTypeList();
      debugPrint(
        '[PropertyTaxAssessment] getRebateTypeList -> ${rebates.length} item(s): '
        '${rebates.map((r) => '${r.rebateId}:${r.rebateName}').join(', ')}',
      );
      if (!mounted) return;
      setState(() {
        _rebateList = rebates;
        _isLoadingRebates = false;
      });
    } catch (e) {
      debugPrint('[PropertyTaxAssessment] getRebateTypeList error: $e');
      if (!mounted) return;
      setState(() {
        _rebateError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingRebates = false;
      });
    }
  }

  Future<void> _handleContinue() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FloorUsageAssessmentScreen(selectedRebate: _selectedRebate!),
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Rebate Type'),
            const SizedBox(height: 12),
            _buildRebateSection(),
          ],
        ),
      ),
      bottomNavigationBar:
          _selectedRebate == null ? null : _buildBottomBar(),
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

  Widget _buildRebateSection() {
    if (_isLoadingRebates) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    if (_rebateError != null) {
      return _buildErrorCard(_rebateError!, onRetry: _fetchRebateTypes);
    }

    if (_rebateList.isEmpty) {
      return Text(
        'No rebate types available',
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
      );
    }

    return Column(
      children: [
        for (final rebate in _rebateList) ...[
          _buildOptionCard(
            label: rebate.rebateName ?? '-',
            badge: '${rebate.rebatePercentage ?? 0}%',
            isSelected: _selectedRebate?.rebateId == rebate.rebateId,
            onTap: () => setState(() => _selectedRebate = rebate),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildErrorCard(String message, {required VoidCallback onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                  color: _primaryColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String label,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF4E8) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? _primaryColor : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF333333),
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
          ],
        ),
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
            onPressed: _handleContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
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
