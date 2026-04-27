import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class PropertySelectionTourGuide {
  static List<TargetFocus> buildTargets({
    required GlobalKey headerKey,
    required GlobalKey propertyCardKey,
    required GlobalKey selectButtonKey,
  }) {
    return [
      _buildTarget(
        identify: 'property_selection_header',
        keyTarget: headerKey,
        align: ContentAlign.bottom,
        icon: Icons.home_work_outlined,
        title: 'Select Property',
        body:
            'This screen displays the list of properties matched to your search. Please review the available property cards and select the correct property to proceed.',
        radius: 14,
      ),
      _buildTarget(
        identify: 'property_selection_card',
        keyTarget: propertyCardKey,
        align: ContentAlign.bottom,
        icon: Icons.description_outlined,
        title: 'Check Property Details',
        body:
            'Each property card includes key details such as the PID, owner name, father or husband name, house number, and address to help you identify the correct property.',
        radius: 16,
      ),
      _buildTarget(
        identify: 'property_selection_button',
        keyTarget: selectButtonKey,
        align: ContentAlign.bottom,
        icon: Icons.check_circle_outline,
        title: 'Select And Verify',
        body:
            'Tap Select on the appropriate property card to receive an OTP on the registered mobile number. After successful OTP verification, the selected property will be saved to your account.',
        radius: 12,
      ),
    ];
  }

  static TutorialCoachMark createCoachMark({
    required List<TargetFocus> targets,
    required VoidCallback onAdvance,
  }) {
    return TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF111827),
      opacityShadow: 0.85,
      paddingFocus: 10,
      hideSkip: false,
      textSkip: 'SKIP TOUR',
      textStyleSkip: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      onClickTarget: (target) => onAdvance(),
      onClickOverlay: (target) => onAdvance(),
    );
  }

  static TargetFocus _buildTarget({
    required String identify,
    required GlobalKey keyTarget,
    required ContentAlign align,
    required IconData icon,
    required String title,
    required String body,
    double radius = 12,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: keyTarget,
      shape: ShapeLightFocus.RRect,
      radius: radius,
      contents: [
        TargetContent(
          align: align,
          builder: (context, controller) => _tourCard(
            icon: icon,
            title: title,
            body: body,
          ),
        ),
      ],
    );
  }

  static Widget _tourCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFE67514), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}