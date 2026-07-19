import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'assessment_list_screen.dart';
import 'reassessment_screen.dart';

enum _AssessmentType { assessment, reassessment }

class AssessmentTypeSelectionScreen extends StatefulWidget {
  const AssessmentTypeSelectionScreen({super.key});

  @override
  State<AssessmentTypeSelectionScreen> createState() =>
      _AssessmentTypeSelectionScreenState();
}

class _AssessmentTypeSelectionScreenState
    extends State<AssessmentTypeSelectionScreen> {
  static const Color _primaryColor = Color(0xFFE67514);

  _AssessmentType _selectedType = _AssessmentType.assessment;

  void _handleContinue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _selectedType == _AssessmentType.assessment
            ? const AssessmentListScreen()
            : const ReassessmentScreen(),
      ),
    );
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What would you like to do?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTypeTab(
                    label: 'Assessment',
                    description: 'Assess a property for the first time',
                    icon: Icons.assessment_outlined,
                    type: _AssessmentType.assessment,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeTab(
                    label: 'Reassessment',
                    description: 'Reassess an already assessed property',
                    icon: Icons.fact_check_outlined,
                    type: _AssessmentType.reassessment,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
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
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required String description,
    required IconData icon,
    required _AssessmentType type,
  }) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF4E8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: _primaryColor, size: 26),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? _primaryColor : Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF777777),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
