import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class PropertyTaxAssessmentTourStep {
  const PropertyTaxAssessmentTourStep({
    required this.formStep,
    required this.keyTarget,
    required this.target,
  });

  final int formStep;
  final GlobalKey keyTarget;
  final TargetFocus target;
}

class PropertyTaxAssessmentTourGuide {
  static List<PropertyTaxAssessmentTourStep> buildSteps({
    GlobalKey? choosePropertyKey,
    required GlobalKey roadWidthSectionKey,
    required GlobalKey constructionTypeSectionKey,
    required GlobalKey propertyTypeSectionKey,
    required GlobalKey areaDetailsSectionKey,
    required GlobalKey constructionDetailsSectionKey,
    required GlobalKey actionButtonKey,
  }) {
    return [
      if (choosePropertyKey != null)
        _buildStep(
          formStep: 1,
          identify: 'assessment_choose_property',
          keyTarget: choosePropertyKey,
          align: ContentAlign.bottom,
          icon: Icons.home_work_outlined,
          title: 'Select Property',
          body:
              'Use this field to select one of your saved properties. Ward and owner details will be filled automatically.',
          radius: 16,
        ),
      _buildStep(
        formStep: 1,
        identify: 'assessment_road_width',
        keyTarget: roadWidthSectionKey,
        align: ContentAlign.bottom,
        icon: Icons.route_outlined,
        title: 'Road Width',
        body:
            'Select the road width of the property so the correct rate can be used for the assessment.',
        radius: 16,
      ),
      _buildStep(
        formStep: 1,
        identify: 'assessment_construction_type',
        keyTarget: constructionTypeSectionKey,
        align: ContentAlign.top,
        icon: Icons.apartment_outlined,
        title: 'Construction Type',
        body:
            'Choose the construction type here. This also affects the area rate used in the calculation.',
        radius: 16,
      ),
      _buildStep(
        formStep: 2,
        identify: 'assessment_property_type',
        keyTarget: propertyTypeSectionKey,
        align: ContentAlign.bottom,
        icon: Icons.domain_outlined,
        title: 'Property Type',
        body:
            'Choose whether the property is residential or non-residential before moving ahead.',
        radius: 16,
      ),
      _buildStep(
        formStep: 3,
        identify: 'assessment_area_details',
        keyTarget: areaDetailsSectionKey,
        align: ContentAlign.bottom,
        icon: Icons.square_foot_outlined,
        title: 'Area Details',
        body:
            'Enter the rent area and own area here so the total area can be prepared for calculation.',
        radius: 16,
      ),
      _buildStep(
        formStep: 3,
        identify: 'assessment_construction_details',
        keyTarget: constructionDetailsSectionKey,
        align: ContentAlign.bottom,
        icon: Icons.calendar_today_outlined,
        title: 'Construction Details',
        body:
            'Enter the construction year here to calculate structure age and continue to the comparison step.',
        radius: 16,
      ),
      _buildStep(
        formStep: 4,
        identify: 'assessment_download_pdf',
        keyTarget: actionButtonKey,
        align: ContentAlign.top,
        icon: Icons.picture_as_pdf_outlined,
        title: 'Download Tax Comparison PDF',
        body:
            'Use this button to generate and share the property tax comparison PDF for the current assessment.',
        radius: 16,
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

  static PropertyTaxAssessmentTourStep _buildStep({
    required int formStep,
    required String identify,
    required GlobalKey keyTarget,
    required ContentAlign align,
    required IconData icon,
    required String title,
    required String body,
    double radius = 12,
  }) {
    return PropertyTaxAssessmentTourStep(
      formStep: formStep,
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