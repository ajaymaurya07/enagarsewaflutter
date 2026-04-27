import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class SearchPropertyTourGuide {
  static List<TargetFocus> buildIntroTargets({
    required GlobalKey searchTabsKey,
    required GlobalKey ulbPickerKey,
  }) {
    return [
      _buildTarget(
        identify: 'search_tabs',
        keyTarget: searchTabsKey,
        align: ContentAlign.bottom,
        icon: Icons.tune_rounded,
        title: '5 Ways to Search',
        body:
            'You can search property in 5 different ways. Each tab shows different input fields. Tap any tab to switch the search mode.',
      ),
      _buildTarget(
        identify: 'ulb_picker',
        keyTarget: ulbPickerKey,
        align: ContentAlign.bottom,
        icon: Icons.account_balance_outlined,
        title: 'Select ULB',
        body:
            'Select your Urban Local Body first. This is mandatory for all 5 search options and loads the location data.',
      ),
    ];
  }

  static List<TargetFocus> buildOwnerTargets({
    required GlobalKey tabKey,
    required GlobalKey fieldKey,
  }) {
    return _buildModeTargets(
      tabKey: tabKey,
      tabIdentify: 'tab_owner',
      tabIcon: Icons.person_search_outlined,
      tabTitle: 'By Owner Name',
      tabBody:
          'Search by entering the property owner\'s name and their father\'s name. Useful when you know the owner but not the property ID.',
      fieldKey: fieldKey,
      fieldIdentify: 'owner_fields',
      fieldIcon: Icons.badge_outlined,
      fieldTitle: 'Owner Search Fields',
      fieldBody:
          'Enter Owner Name and Father Name here to search matching properties under that owner profile.',
    );
  }

  static List<TargetFocus> buildPropertyIdTargets({
    required GlobalKey tabKey,
    required GlobalKey fieldKey,
  }) {
    return _buildModeTargets(
      tabKey: tabKey,
      tabIdentify: 'tab_property_id',
      tabIcon: Icons.tag_rounded,
      tabTitle: 'By Property ID',
      tabBody:
          'Enter the unique Property ID directly. This is the fastest way if you already have the property ID on hand.',
      fieldKey: fieldKey,
      fieldIdentify: 'property_id_fields',
      fieldIcon: Icons.confirmation_number_outlined,
      fieldTitle: 'Property ID Field',
      fieldBody:
          'Type the exact Property ID here to open the property quickly without searching through multiple results.',
    );
  }

  static List<TargetFocus> buildHouseNoTargets({
    required GlobalKey tabKey,
    required GlobalKey fieldKey,
  }) {
    return _buildModeTargets(
      tabKey: tabKey,
      tabIdentify: 'tab_house_no',
      tabIcon: Icons.home_outlined,
      tabTitle: 'By House Number',
      tabBody:
          'Search using house number. Select Zone and Ward first, then enter the house number to narrow down results.',
      fieldKey: fieldKey,
      fieldIdentify: 'house_no_fields',
      fieldIcon: Icons.maps_home_work_outlined,
      fieldTitle: 'House Number Search Fields',
      fieldBody:
          'Choose Zone, then Ward, and then enter the house number. This narrows the search inside the selected area.',
    );
  }

  static List<TargetFocus> buildLocationTargets({
    required GlobalKey tabKey,
    required GlobalKey fieldKey,
  }) {
    return _buildModeTargets(
      tabKey: tabKey,
      tabIdentify: 'tab_location',
      tabIcon: Icons.location_on_outlined,
      tabTitle: 'By Location',
      tabBody:
          'Search by full address. Select Zone -> Ward -> Mohalla in order, then optionally add a house number to get precise results.',
      fieldKey: fieldKey,
      fieldIdentify: 'location_fields',
      fieldIcon: Icons.location_city_outlined,
      fieldTitle: 'Location Search Fields',
      fieldBody:
          'Select Zone, Ward, and Mohalla here. You can also add House Number to make the location search more accurate.',
    );
  }

  static List<TargetFocus> buildMobileTargets({
    required GlobalKey tabKey,
    required GlobalKey fieldKey,
    required GlobalKey searchButtonKey,
  }) {
    return _buildModeTargets(
      tabKey: tabKey,
      tabIdentify: 'tab_mobile',
      tabIcon: Icons.phone_outlined,
      tabTitle: 'By Mobile Number',
      tabBody:
          'Enter the 10-digit mobile number registered with the property. All properties linked to that number will appear.',
      fieldKey: fieldKey,
      fieldIdentify: 'mobile_fields',
      fieldIcon: Icons.phone_android_outlined,
      fieldTitle: 'Mobile Search Field',
      fieldBody:
          'Enter the registered mobile number here. This is useful when the owner has more than one linked property.',
      searchButtonKey: searchButtonKey,
    );
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

  static List<TargetFocus> _buildModeTargets({
    required GlobalKey tabKey,
    required String tabIdentify,
    required IconData tabIcon,
    required String tabTitle,
    required String tabBody,
    required GlobalKey fieldKey,
    required String fieldIdentify,
    required IconData fieldIcon,
    required String fieldTitle,
    required String fieldBody,
    GlobalKey? searchButtonKey,
  }) {
    return [
      _buildTarget(
        identify: tabIdentify,
        keyTarget: tabKey,
        align: ContentAlign.bottom,
        icon: tabIcon,
        title: tabTitle,
        body: tabBody,
        radius: 10,
      ),
      _buildTarget(
        identify: fieldIdentify,
        keyTarget: fieldKey,
        align: ContentAlign.bottom,
        icon: fieldIcon,
        title: fieldTitle,
        body: fieldBody,
      ),
      if (searchButtonKey != null)
        _buildTarget(
          identify: 'search_button',
          keyTarget: searchButtonKey,
          align: ContentAlign.top,
          icon: Icons.search_rounded,
          title: 'Search Property',
          body:
              'Once ULB and required fields are filled, tap Search. Matching properties will open on the next screen where you can select and save one.',
          radius: 14,
        ),
    ];
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Tap to continue →',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFFE67514),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}