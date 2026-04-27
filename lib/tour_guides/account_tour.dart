import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class AccountTourStep {
  const AccountTourStep({required this.keyTarget, required this.target});

  final GlobalKey keyTarget;
  final TargetFocus target;
}

class AccountTourGuide {
  static List<AccountTourStep> buildSteps({
    required GlobalKey profileHeaderKey,
    required GlobalKey userIdCardKey,
    required GlobalKey userTypeCardKey,
    required GlobalKey logoutButtonKey,
  }) {
    return [
      _buildStep(
        identify: 'account_profile_header',
        keyTarget: profileHeaderKey,
        align: ContentAlign.bottom,
        icon: Icons.person_outline_rounded,
        title: 'Profile Overview',
        body:
            'This section shows your account profile and the role currently signed in to the app.',
        radius: 18,
      ),
      _buildStep(
        identify: 'account_user_id_card',
        keyTarget: userIdCardKey,
        align: ContentAlign.bottom,
        icon: Icons.email_outlined,
        title: 'User Id',
        body:
            'This card displays the email or user ID currently linked with your account.',
        radius: 16,
      ),
      _buildStep(
        identify: 'account_user_type_card',
        keyTarget: userTypeCardKey,
        align: ContentAlign.top,
        icon: Icons.admin_panel_settings_outlined,
        title: 'User Type',
        body:
            'This card shows the account type or access role you are using in the app.',
        radius: 16,
      ),
      _buildStep(
        identify: 'account_logout_button',
        keyTarget: logoutButtonKey,
        align: ContentAlign.top,
        icon: Icons.logout_rounded,
        title: 'Logout',
        body:
            'Use this button to safely log out from the app and return to the login screen.',
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

  static AccountTourStep _buildStep({
    required String identify,
    required GlobalKey keyTarget,
    required ContentAlign align,
    required IconData icon,
    required String title,
    required String body,
    double radius = 12,
  }) {
    return AccountTourStep(
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
