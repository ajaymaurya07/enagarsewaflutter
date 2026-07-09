import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';

class FloorUsageAssessmentScreen extends StatefulWidget {
  final RebateType selectedRebate;

  const FloorUsageAssessmentScreen({super.key, required this.selectedRebate});

  @override
  State<FloorUsageAssessmentScreen> createState() =>
      _FloorUsageAssessmentScreenState();
}

class _FloorUsageAssessmentScreenState
    extends State<FloorUsageAssessmentScreen> {
  static const Color _primaryColor = Color(0xFFE67514);

  static const Map<String, String> _floorUsageOptions = {
    'RS': 'Residential Self',
    'RR': 'Residential Rental',
    'MIS': 'Miscellaneous',
    'COM': 'Commercial',
  };

  String? _selectedFloorUsageId;
  bool _isLoadingFloorTypes = false;
  String? _floorTypeError;
  List<FloorType> _floorTypeList = [];
  FloorType? _selectedFloorType;

  bool _isLoadingMultiplier = false;
  String? _multiplierError;
  double? _propertyTypeMultiplier;

  Future<void> _fetchFloorTypes(String floorUsageId) async {
    setState(() {
      _selectedFloorUsageId = floorUsageId;
      _isLoadingFloorTypes = true;
      _floorTypeError = null;
      _floorTypeList = [];
      _selectedFloorType = null;
    });

    debugPrint(
      '[FloorUsageAssessment] Fetching floor types for floorUsageId=$floorUsageId...',
    );
    try {
      final floorTypes = await ApiService.getFloorTypeList(floorUsageId);
      debugPrint(
        '[FloorUsageAssessment] getFloorTypeList($floorUsageId) -> ${floorTypes.length} item(s): '
        '${floorTypes.map((f) => '${f.id}:${f.name}').join(', ')}',
      );
      if (!mounted) return;
      setState(() {
        _floorTypeList = floorTypes;
        _isLoadingFloorTypes = false;
      });
    } catch (e) {
      debugPrint(
        '[FloorUsageAssessment] getFloorTypeList($floorUsageId) error: $e',
      );
      if (!mounted) return;
      setState(() {
        _floorTypeError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingFloorTypes = false;
      });
    }
  }

  Future<void> _fetchPropertyTypeMultiplier(int floorTypeId) async {
    setState(() {
      _isLoadingMultiplier = true;
      _multiplierError = null;
      _propertyTypeMultiplier = null;
    });

    debugPrint(
      '[FloorUsageAssessment] Fetching property type multiplier for floorType=$floorTypeId...',
    );
    try {
      final multiplier =
          await ApiService.getPropertyTypeMultiplier(floorTypeId);
      debugPrint(
        '[FloorUsageAssessment] getPropertyTypeMultiplier($floorTypeId) -> $multiplier',
      );
      if (!mounted) return;
      setState(() {
        _propertyTypeMultiplier = multiplier;
        _isLoadingMultiplier = false;
      });
    } catch (e) {
      debugPrint(
        '[FloorUsageAssessment] getPropertyTypeMultiplier($floorTypeId) error: $e',
      );
      if (!mounted) return;
      setState(() {
        _multiplierError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingMultiplier = false;
      });
    }
  }

  void _handleConfirm() {
    Navigator.pop(context, {
      'rebate': widget.selectedRebate,
      'floorType': _selectedFloorType,
      'propertyTypeMultiplier': _propertyTypeMultiplier,
    });
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
            _sectionTitle('Floor Usage'),
            const SizedBox(height: 12),
            _buildFloorUsageChips(),
            const SizedBox(height: 24),
            if (_selectedFloorUsageId != null) ...[
              _sectionTitle('Floor Type'),
              const SizedBox(height: 12),
              _buildFloorTypeSection(),
            ],
            if (_selectedFloorType != null) ...[
              const SizedBox(height: 24),
              _sectionTitle('Property Type Multiplier'),
              const SizedBox(height: 12),
              _buildMultiplierCard(),
            ],
          ],
        ),
      ),
      bottomNavigationBar:
          _propertyTypeMultiplier == null ? null : _buildBottomBar(),
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

  Widget _buildFloorUsageChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: _floorUsageOptions.entries.map((e) {
        final isSelected = _selectedFloorUsageId == e.key;
        return GestureDetector(
          onTap: () => _fetchFloorTypes(e.key),
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

  Widget _buildFloorTypeSection() {
    if (_isLoadingFloorTypes) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    if (_floorTypeError != null) {
      return _buildErrorCard(
        _floorTypeError!,
        onRetry: () => _fetchFloorTypes(_selectedFloorUsageId!),
      );
    }

    if (_floorTypeList.isEmpty) {
      return Text(
        'No floor types available for this usage',
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
      );
    }

    return Column(
      children: [
        for (final floorType in _floorTypeList) ...[
          _buildOptionCard(
            label: floorType.name ?? '-',
            isSelected: _selectedFloorType?.id == floorType.id,
            onTap: () {
              setState(() => _selectedFloorType = floorType);
              if (floorType.id != null) {
                _fetchPropertyTypeMultiplier(floorType.id!);
              }
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildMultiplierCard() {
    if (_isLoadingMultiplier) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    if (_multiplierError != null) {
      return _buildErrorCard(
        _multiplierError!,
        onRetry: () => _fetchPropertyTypeMultiplier(_selectedFloorType!.id!),
      );
    }

    if (_propertyTypeMultiplier == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(
            'Property Type Multiplier',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
          const Spacer(),
          Text(
            _propertyTypeMultiplier!.toStringAsFixed(
              _propertyTypeMultiplier! % 1 == 0 ? 0 : 2,
            ),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ],
      ),
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
            onPressed: _handleConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Confirm',
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
