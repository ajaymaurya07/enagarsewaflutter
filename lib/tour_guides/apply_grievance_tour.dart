import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class ApplyGrievanceTourGuide {
  static List<ApplyGrievanceTourStep> buildSteps({
    required GlobalKey propertySectionKey,
    required GlobalKey personalSectionKey,
    required GlobalKey locationSectionKey,
    required GlobalKey grievanceSectionKey,
    required GlobalKey photoSectionKey,
    required GlobalKey submitButtonKey,
  }) {
    return [
      _buildStep(
        identify: 'property',
        keyTarget: propertySectionKey,
        align: ContentAlign.bottom,
        icon: Icons.home_work_outlined,
        title: 'Select Property',
        body:
            'Tap here to choose your saved property. Your name, mobile, and address will be auto-filled.',
      ),
      _buildStep(
        identify: 'personal',
        keyTarget: personalSectionKey,
        align: ContentAlign.bottom,
        icon: Icons.person_outline,
        title: 'Personal Information',
        body:
            'These fields are auto-filled from the selected property and cannot be edited.',
      ),
      _buildStep(
        identify: 'location',
        keyTarget: locationSectionKey,
        align: ContentAlign.bottom,
        icon: Icons.location_on_outlined,
        title: 'Location Details',
        body:
            'Select your ULB, Zone, Ward, and Mohalla in order. Then enter a landmark near the issue.',
      ),
      _buildStep(
        identify: 'grievance',
        keyTarget: grievanceSectionKey,
        align: ContentAlign.bottom,
        icon: Icons.report_problem_outlined,
        title: 'Grievance Details',
        body:
            'Choose a category, then a sub-category, and describe your grievance clearly.',
      ),
      _buildStep(
        identify: 'photo',
        keyTarget: photoSectionKey,
        align: ContentAlign.top,
        icon: Icons.camera_alt_outlined,
        title: 'Upload Photo (Optional)',
        body:
            'Attach a photo of the issue from your camera or gallery. Max size: 200 KB.',
      ),
      _buildStep(
        identify: 'submit',
        keyTarget: submitButtonKey,
        align: ContentAlign.top,
        icon: Icons.send_outlined,
        title: 'Submit Grievance',
        body:
            'Once all fields are filled, tap here to submit. You will receive an OTP on your mobile to confirm.',
        radius: 14,
      ),
    ];
  }

  static TutorialCoachMark createCoachMark({
    required List<TargetFocus> targets,
    required VoidCallback onAdvance,
    VoidCallback? onFinish,
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
      onFinish: onFinish,
    );
  }

  static ApplyGrievanceTourStep _buildStep({
    required String identify,
    required GlobalKey keyTarget,
    required ContentAlign align,
    required IconData icon,
    required String title,
    required String body,
    double radius = 12,
  }) {
    return ApplyGrievanceTourStep(
      keyTarget: keyTarget,
      target: TargetFocus(
        identify: identify,
        keyTarget: keyTarget,
        shape: ShapeLightFocus.RRect,
        radius: radius,
        contents: [
          TargetContent(
            align: align,
            builder: (context, controller) =>
                _tourCard(icon: icon, title: title, body: body),
          ),
        ],
      ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class ApplyGrievanceTourStep {
  const ApplyGrievanceTourStep({
    required this.keyTarget,
    required this.target,
  });

  final GlobalKey keyTarget;
  final TargetFocus target;
}
