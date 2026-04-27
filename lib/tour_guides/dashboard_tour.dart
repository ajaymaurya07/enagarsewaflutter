import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class DashboardTourStep {
  const DashboardTourStep({
    required this.keyTarget,
    required this.target,
  });

  final GlobalKey keyTarget;
  final TargetFocus target;
}

class DashboardTourGuide {
  static List<DashboardTourStep> buildSteps({
    required GlobalKey propertyTaxKey,
    required GlobalKey grievanceKey,
    required GlobalKey arvChangeHistoryKey,
    required GlobalKey propertyTaxAssessmentKey,
    required GlobalKey mutationKey,
    required GlobalKey waterSewerageKey,
    required GlobalKey bottomNavKey,
    GlobalKey? searchPropertyKey,
  }) {
    return [
      if (searchPropertyKey != null)
        _buildStep(
          identify: 'search_property',
          keyTarget: searchPropertyKey,
          align: ContentAlign.bottom,
          icon: Icons.add_business_outlined,
          title: 'Search New Property',
          body:
              'Admin users can use this option to search and add more properties to their list before proceeding with further services.',
          radius: 16,
        ),
      _buildStep(
        identify: 'property_tax',
        keyTarget: propertyTaxKey,
        align: ContentAlign.bottom,
        icon: Icons.home_work_outlined,
        title: 'Property Tax',
        body:
            'Use this option to view and manage your property tax related services.',
        radius: 16,
      ),
      _buildStep(
        identify: 'track_grievance',
        keyTarget: grievanceKey,
        align: ContentAlign.bottom,
        icon: Icons.assignment_outlined,
        title: 'Track Grievance',
        body:
            'Use this section to review grievance requests and track their current status.',
        radius: 16,
      ),
      _buildStep(
        identify: 'arv_change_history',
        keyTarget: arvChangeHistoryKey,
        align: ContentAlign.bottom,
        icon: Icons.history_outlined,
        title: 'ARV Change History',
        body:
            'Use this option to review previous ARV change history records related to your property services.',
        radius: 16,
      ),
      _buildStep(
        identify: 'property_tax_assessment',
        keyTarget: propertyTaxAssessmentKey,
        align: ContentAlign.bottom,
        icon: Icons.assessment_outlined,
        title: 'Property Tax Assessment',
        body:
            'Use this option to access property tax assessment services and related details.',
        radius: 16,
      ),
      _buildStep(
        identify: 'mutation',
        keyTarget: mutationKey,
        align: ContentAlign.top,
        icon: Icons.swap_horiz_outlined,
        title: 'Mutation',
        body:
            'Use this option for property name transfer and mutation related services when available.',
        radius: 16,
      ),
      _buildStep(
        identify: 'water_sewerage',
        keyTarget: waterSewerageKey,
        align: ContentAlign.top,
        icon: Icons.water_drop_outlined,
        title: 'Water And Sewerage',
        body:
            'Use this section to access water and sewerage related services provided in the application.',
        radius: 16,
      ),
      _buildStep(
        identify: 'bottom_navigation',
        keyTarget: bottomNavKey,
        align: ContentAlign.top,
        icon: Icons.navigation_outlined,
        title: 'Bottom Navigation',
        body:
            'Use the bottom navigation bar to move between Home, Transaction History, and Account sections at any time.',
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

  static DashboardTourStep _buildStep({
    required String identify,
    required GlobalKey keyTarget,
    required ContentAlign align,
    required IconData icon,
    required String title,
    required String body,
    double radius = 12,
  }) {
    return DashboardTourStep(
      keyTarget: keyTarget,
      target: TargetFocus(
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