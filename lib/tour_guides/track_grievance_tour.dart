import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TrackGrievanceTourGuide {
  static List<TargetFocus> buildTargets({
    required GlobalKey applyNowKey,
    required GlobalKey trackStatusKey,
  }) {
    return [
      _buildTarget(
        identify: 'track_grievance_apply_now',
        keyTarget: applyNowKey,
        align: ContentAlign.bottom,
        icon: Icons.add_task_rounded,
        title: 'Apply Now',
        body: 'Use this option to raise a new grievance request.',
        radius: 18,
      ),
      _buildTarget(
        identify: 'track_grievance_track_status',
        keyTarget: trackStatusKey,
        align: ContentAlign.top,
        icon: Icons.track_changes_rounded,
        title: 'Track Status',
        body: 'Use this option to check grievance details and track your request.',
        radius: 18,
      ),
    ];
  }

  static TutorialCoachMark createCoachMark({
    required List<TargetFocus> targets,
    required VoidCallback onAdvance,
    VoidCallback? onFinish,
    bool Function()? onSkip,
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
      onSkip: onSkip,
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
          builder: (context, controller) =>
              _tourCard(icon: icon, title: title, body: body),
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
