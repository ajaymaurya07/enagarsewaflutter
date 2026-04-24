import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enagarsewa/services/api_service.dart';
import 'package:enagarsewa/services/storage_service.dart';
import 'property_selection_screen.dart';

class SearchPropertyScreen extends StatefulWidget {
  const SearchPropertyScreen({super.key});

  @override
  State<SearchPropertyScreen> createState() => _SearchPropertyScreenState();
}

class _SearchPropertyScreenState extends State<SearchPropertyScreen> {
  final _ownerController = TextEditingController();
  final _fatherController = TextEditingController();
  final _propertyIdController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _mobileController = TextEditingController();

  String _searchMode = 'By Owner';
  
  List<UlbData> _ulbList = [];
  UlbData? _selectedUlb;
  
  List<ZoneData> _zoneList = [];
  ZoneData? _selectedZone;
  
  List<WardData> _wardList = [];
  WardData? _selectedWard;
  
  List<MohallaData> _mohallaList = [];
  MohallaData? _selectedMohalla;
  
  bool _isLoadingUlbs = true;
  bool _isLoadingZones = false;
  bool _isLoadingWards = false;
  bool _isLoadingMohallas = false;
  bool _isSearching = false;
  String? _errorMessage;

  // Tour guide keys
  final _keySearchTabs = GlobalKey();
  final _keyTabOwner = GlobalKey();
  final _keyTabPropertyId = GlobalKey();
  final _keyTabHouseNo = GlobalKey();
  final _keyTabLocation = GlobalKey();
  final _keyTabMobile = GlobalKey();
  final _keyUlbPicker = GlobalKey();
  final _keyOwnerFields = GlobalKey();
  final _keyPropertyIdFields = GlobalKey();
  final _keyHouseNoFields = GlobalKey();
  final _keyLocationFields = GlobalKey();
  final _keyMobileFields = GlobalKey();
  final _keySearchButton = GlobalKey();

  TutorialCoachMark? _tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    _loadUlbData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStartTourIfFirstVisit());
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_search_property') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_search_property', true);
      _startTour();
    }
  }

  Future<void> _setSearchModeForTour(String mode) async {
    if (!mounted || _searchMode == mode) return;

    setState(() {
      _searchMode = mode;
    });

    await WidgetsBinding.instance.endOfFrame;
  }

  TargetFocus _buildTourTarget({
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

  void _showTourSegment({
    required List<TargetFocus> targets,
    VoidCallback? onFinish,
  }) {
    _tutorialCoachMark = TutorialCoachMark(
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
      onClickTarget: (target) => _tutorialCoachMark?.next(),
      onClickOverlay: (target) => _tutorialCoachMark?.next(),
      onFinish: onFinish,
    )..show(context: context);
  }

  Future<void> _showModeTour({
    required String mode,
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
    VoidCallback? onFinish,
    bool includeSearchButton = false,
  }) async {
    await _setSearchModeForTour(mode);
    if (!mounted) return;

    final targets = [
      _buildTourTarget(
        identify: tabIdentify,
        keyTarget: tabKey,
        align: ContentAlign.bottom,
        icon: tabIcon,
        title: tabTitle,
        body: tabBody,
        radius: 10,
      ),
      _buildTourTarget(
        identify: fieldIdentify,
        keyTarget: fieldKey,
        align: ContentAlign.bottom,
        icon: fieldIcon,
        title: fieldTitle,
        body: fieldBody,
      ),
      if (includeSearchButton)
        _buildTourTarget(
          identify: 'search_button',
          keyTarget: _keySearchButton,
          align: ContentAlign.top,
          icon: Icons.search_rounded,
          title: 'Search Property',
          body: 'Once ULB and required fields are filled, tap Search. Matching properties will open on the next screen where you can select and save one.',
          radius: 14,
        ),
    ];

    _showTourSegment(targets: targets, onFinish: onFinish);
  }

  Future<void> _showOwnerTour() async {
    await _showModeTour(
      mode: 'By Owner',
      tabKey: _keyTabOwner,
      tabIdentify: 'tab_owner',
      tabIcon: Icons.person_search_outlined,
      tabTitle: 'By Owner Name',
      tabBody: 'Search by entering the property owner\'s name and their father\'s name. Useful when you know the owner but not the property ID.',
      fieldKey: _keyOwnerFields,
      fieldIdentify: 'owner_fields',
      fieldIcon: Icons.badge_outlined,
      fieldTitle: 'Owner Search Fields',
      fieldBody: 'Enter Owner Name and Father Name here to search matching properties under that owner profile.',
      onFinish: () {
        _showPropertyIdTour();
      },
    );
  }

  Future<void> _showPropertyIdTour() async {
    await _showModeTour(
      mode: 'By Property ID',
      tabKey: _keyTabPropertyId,
      tabIdentify: 'tab_property_id',
      tabIcon: Icons.tag_rounded,
      tabTitle: 'By Property ID',
      tabBody: 'Enter the unique Property ID directly. This is the fastest way if you already have the property ID on hand.',
      fieldKey: _keyPropertyIdFields,
      fieldIdentify: 'property_id_fields',
      fieldIcon: Icons.confirmation_number_outlined,
      fieldTitle: 'Property ID Field',
      fieldBody: 'Type the exact Property ID here to open the property quickly without searching through multiple results.',
      onFinish: () {
        _showHouseNoTour();
      },
    );
  }

  Future<void> _showHouseNoTour() async {
    await _showModeTour(
      mode: 'By House No',
      tabKey: _keyTabHouseNo,
      tabIdentify: 'tab_house_no',
      tabIcon: Icons.home_outlined,
      tabTitle: 'By House Number',
      tabBody: 'Search using house number. Select Zone and Ward first, then enter the house number to narrow down results.',
      fieldKey: _keyHouseNoFields,
      fieldIdentify: 'house_no_fields',
      fieldIcon: Icons.maps_home_work_outlined,
      fieldTitle: 'House Number Search Fields',
      fieldBody: 'Choose Zone, then Ward, and then enter the house number. This narrows the search inside the selected area.',
      onFinish: () {
        _showLocationTour();
      },
    );
  }

  Future<void> _showLocationTour() async {
    await _showModeTour(
      mode: 'By Location',
      tabKey: _keyTabLocation,
      tabIdentify: 'tab_location',
      tabIcon: Icons.location_on_outlined,
      tabTitle: 'By Location',
      tabBody: 'Search by full address. Select Zone -> Ward -> Mohalla in order, then optionally add a house number to get precise results.',
      fieldKey: _keyLocationFields,
      fieldIdentify: 'location_fields',
      fieldIcon: Icons.location_city_outlined,
      fieldTitle: 'Location Search Fields',
      fieldBody: 'Select Zone, Ward, and Mohalla here. You can also add House Number to make the location search more accurate.',
      onFinish: () {
        _showMobileTour();
      },
    );
  }

  Future<void> _showMobileTour() async {
    await _showModeTour(
      mode: 'By Mobile No',
      tabKey: _keyTabMobile,
      tabIdentify: 'tab_mobile',
      tabIcon: Icons.phone_outlined,
      tabTitle: 'By Mobile Number',
      tabBody: 'Enter the 10-digit mobile number registered with the property. All properties linked to that number will appear.',
      fieldKey: _keyMobileFields,
      fieldIdentify: 'mobile_fields',
      fieldIcon: Icons.phone_android_outlined,
      fieldTitle: 'Mobile Search Field',
      fieldBody: 'Enter the registered mobile number here. This is useful when the owner has more than one linked property.',
      includeSearchButton: true,
    );
  }

  Future<void> _startTour() async {
    await _setSearchModeForTour('By Owner');
    if (!mounted) return;

    _showTourSegment(
      targets: [
        _buildTourTarget(
          identify: 'search_tabs',
          keyTarget: _keySearchTabs,
          align: ContentAlign.bottom,
          icon: Icons.tune_rounded,
          title: '5 Ways to Search',
          body: 'You can search property in 5 different ways. Each tab shows different input fields. Tap any tab to switch the search mode.',
        ),
        _buildTourTarget(
          identify: 'ulb_picker',
          keyTarget: _keyUlbPicker,
          align: ContentAlign.bottom,
          icon: Icons.account_balance_outlined,
          title: 'Select ULB',
          body: 'Select your Urban Local Body first. This is mandatory for all 5 search options and loads the location data.',
        ),
      ],
      onFinish: () {
        _showOwnerTour();
      },
    );
  }

  Widget _tourCard({
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

  Future<void> _loadUlbData() async {
    setState(() {
      _isLoadingUlbs = true;
      _errorMessage = null;
    });
    try {
      final data = await ApiService.getUlbData();
      setState(() {
        _ulbList = data;
        _isLoadingUlbs = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUlbs = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadZoneData(String ulbId) async {
    setState(() {
      _isLoadingZones = true;
      _zoneList = [];
      _selectedZone = null;
      _wardList = [];
      _selectedWard = null;
      _mohallaList = [];
      _selectedMohalla = null;
    });
    try {
      final data = await ApiService.getZoneData(ulbId);
      setState(() {
        _zoneList = data;
        _isLoadingZones = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingZones = false;
        _errorMessage = 'Failed to load zones';
      });
    }
  }

  Future<void> _loadWardData(String ulbId, String zoneId) async {
    setState(() {
      _isLoadingWards = true;
      _wardList = [];
      _selectedWard = null;
      _mohallaList = [];
      _selectedMohalla = null;
    });
    try {
      final data = await ApiService.getWardData(ulbId, zoneId);
      setState(() {
        _wardList = data;
        _isLoadingWards = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWards = false;
        _errorMessage = 'Failed to load wards';
      });
    }
  }

  Future<void> _loadMohallaData(String ulbId, String zoneId, String wardId) async {
    setState(() {
      _isLoadingMohallas = true;
      _mohallaList = [];
      _selectedMohalla = null;
    });
    try {
      final data = await ApiService.getMohallaData(ulbId, zoneId, wardId);
      setState(() {
        _mohallaList = data;
        _isLoadingMohallas = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMohallas = false;
        _errorMessage = 'Failed to load mohallas';
      });
    }
  }

  void _handleSearch() async {
    if (_selectedUlb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select ULB first')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      String searchType = "";
      switch (_searchMode) {
        case 'By Owner': searchType = "OWNER"; break;
        case 'By Property ID': searchType = "PID"; break;
        case 'By House No': searchType = "HOUSE"; break;
        case 'By Location': searchType = "LOCATION"; break;
        case 'By Mobile No': searchType = "MOBILE"; break;
      }

      final properties = await ApiService.searchProperty(
        ulbId: _selectedUlb!.ulbId ?? "",
        searchType: searchType,
        ownerName: _ownerController.text.trim(),
        fatherName: _fatherController.text.trim(),
        propertyId: _propertyIdController.text.trim(),
        houseNo: _houseNoController.text.trim(),
        zoneId: _selectedZone?.zoneId ?? "",
        wardId: _selectedWard?.wardId ?? "",
        mohallaId: _selectedMohalla?.mohallaId ?? "",
        mobileNo: _mobileController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });

      if (properties.isNotEmpty) {
        // 1. Save selected ULB ID
        await StorageService.saveUlbId(_selectedUlb!.ulbId ?? "");
        
        // 2. Save totalArv from the first property
        if (properties.first.totalArv != null) {
          await StorageService.saveTotalArv(properties.first.totalArv.toString());
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PropertySelectionScreen(properties: properties),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No properties found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  void _showUlbSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: 'Select ULB',
        items: _ulbList.map((ulb) => '${ulb.ulbName} (${ulb.ulbType ?? ""})').toList(),
        onSelected: (index) {
          setState(() {
            _selectedUlb = _ulbList[index];
          });
          _loadZoneData(_selectedUlb!.ulbId ?? "");
        },
      ),
    );
  }

  void _showZoneSelection() {
    if (_selectedUlb == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select ULB first')));
      return;
    }
    if (_isLoadingZones) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: 'Select Zone',
        items: _zoneList.map((z) => z.zoneName).toList(),
        onSelected: (index) {
          setState(() {
            _selectedZone = _zoneList[index];
          });
          _loadWardData(_selectedUlb!.ulbId ?? "", _selectedZone!.zoneId);
        },
      ),
    );
  }

  void _showWardSelection() {
    if (_selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Zone first')));
      return;
    }
    if (_isLoadingWards) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: 'Select Ward',
        items: _wardList.map((w) => w.wardName).toList(),
        onSelected: (index) {
          setState(() {
            _selectedWard = _wardList[index];
          });
          _loadMohallaData(_selectedUlb!.ulbId ?? "", _selectedZone!.zoneId, _selectedWard!.wardId);
        },
      ),
    );
  }

  void _showMohallaSelection() {
    if (_selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Ward first')));
      return;
    }
    if (_isLoadingMohallas) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionSheet(
        title: 'Select Mohalla',
        items: _mohallaList.map((m) => m.mohallaName).toList(),
        onSelected: (index) {
          setState(() {
            _selectedMohalla = _mohallaList[index];
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _fatherController.dispose();
    _propertyIdController.dispose();
    _houseNoController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      'Search Property',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded, color: Color(0xFFE67514)),
                      tooltip: 'Tour Guide',
                      onPressed: _startTour,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Search Mode Tabs
                      Padding(
                        key: _keySearchTabs,
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildModeChip('By Owner', key: _keyTabOwner)),
                                const SizedBox(width: 6),
                                Expanded(child: _buildModeChip('By Property ID', key: _keyTabPropertyId)),
                                const SizedBox(width: 6),
                                Expanded(child: _buildModeChip('By House No', key: _keyTabHouseNo)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Expanded(flex: 1, child: SizedBox()),
                                Expanded(flex: 5, child: _buildModeChip('By Location', key: _keyTabLocation)),
                                const SizedBox(width: 6),
                                Expanded(flex: 5, child: _buildModeChip('By Mobile No', key: _keyTabMobile)),
                                const Expanded(flex: 1, child: SizedBox()),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Form Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ULB Picker
                            _fieldLabel('Select ULB'),
                            const SizedBox(height: 8),
                            _buildSelectableField(
                              key: _keyUlbPicker,
                              hint: _isLoadingUlbs
                                  ? 'Loading ULBs...'
                                  : (_selectedUlb?.ulbName ?? 'Choose ULB'),
                              isSelected: _selectedUlb != null,
                              onTap: _isLoadingUlbs ? null : _showUlbSelection,
                            ),

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                    color: Colors.red.shade600, fontSize: 12),
                              ),
                            ],

                            const SizedBox(height: 16),

                            if (_searchMode == 'By Owner') ...[
                              Column(
                                key: _keyOwnerFields,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Owner Name'),
                                  const SizedBox(height: 8),
                                  _buildTextField('Enter owner name', _ownerController),
                                  const SizedBox(height: 16),
                                  _fieldLabel('Father Name'),
                                  const SizedBox(height: 8),
                                  _buildTextField('Enter father name', _fatherController),
                                ],
                              ),
                            ] else if (_searchMode == 'By Property ID') ...[
                              Column(
                                key: _keyPropertyIdFields,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Property ID'),
                                  const SizedBox(height: 8),
                                  _buildTextField('Enter property ID', _propertyIdController),
                                ],
                              ),
                            ] else if (_searchMode == 'By House No') ...[
                              Column(
                                key: _keyHouseNoFields,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Zone'),
                                  const SizedBox(height: 8),
                                  _buildSelectableField(
                                    hint: _isLoadingZones
                                        ? 'Loading Zones...'
                                        : (_selectedZone?.zoneName ?? 'Choose Zone'),
                                    isSelected: _selectedZone != null,
                                    onTap: _showZoneSelection,
                                  ),
                                  const SizedBox(height: 16),
                                  _fieldLabel('Ward'),
                                  const SizedBox(height: 8),
                                  _buildSelectableField(
                                    hint: _isLoadingWards
                                        ? 'Loading Wards...'
                                        : (_selectedWard?.wardName ?? 'Choose Ward'),
                                    isSelected: _selectedWard != null,
                                    onTap: _showWardSelection,
                                  ),
                                  const SizedBox(height: 16),
                                  _fieldLabel('House Number'),
                                  const SizedBox(height: 8),
                                  _buildTextField('Enter house number', _houseNoController),
                                ],
                              ),
                            ] else if (_searchMode == 'By Location') ...[
                              Column(
                                key: _keyLocationFields,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Zone'),
                                  const SizedBox(height: 8),
                                  _buildSelectableField(
                                    hint: _isLoadingZones
                                        ? 'Loading Zones...'
                                        : (_selectedZone?.zoneName ?? 'Choose Zone'),
                                    isSelected: _selectedZone != null,
                                    onTap: _showZoneSelection,
                                  ),
                                  const SizedBox(height: 16),
                                  _fieldLabel('Ward'),
                                  const SizedBox(height: 8),
                                  _buildSelectableField(
                                    hint: _isLoadingWards
                                        ? 'Loading Wards...'
                                        : (_selectedWard?.wardName ?? 'Choose Ward'),
                                    isSelected: _selectedWard != null,
                                    onTap: _showWardSelection,
                                  ),
                                  const SizedBox(height: 16),
                                  _fieldLabel('Mohalla'),
                                  const SizedBox(height: 8),
                                  _buildSelectableField(
                                    hint: _isLoadingMohallas
                                        ? 'Loading Mohallas...'
                                        : (_selectedMohalla?.mohallaName ?? 'Choose Mohalla'),
                                    isSelected: _selectedMohalla != null,
                                    onTap: _showMohallaSelection,
                                  ),
                                  const SizedBox(height: 16),
                                  _fieldLabel('House Number'),
                                  const SizedBox(height: 8),
                                  _buildTextField('Enter house number', _houseNoController),
                                ],
                              ),
                            ] else if (_searchMode == 'By Mobile No') ...[
                              Column(
                                key: _keyMobileFields,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Mobile Number'),
                                  const SizedBox(height: 8),
                                  _buildTextField('Enter mobile number', _mobileController),
                                ],
                              ),
                            ],

                            const SizedBox(height: 28),

                            // Search Button
                            SizedBox(
                              key: _keySearchButton,
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSearching ? null : _handleSearch,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE67514),
                                  disabledBackgroundColor:
                                      const Color(0xFFE67514).withValues(alpha: 0.6),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isSearching
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Search',
                                        style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildModeChip(String title, {Key? key}) {
    final isSelected = _searchMode == title;
    return GestureDetector(
      key: key,
      onTap: () => setState(() {
        _searchMode = title;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE67514) : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableField(
      {Key? key, required String hint, required bool isSelected, VoidCallback? onTap}) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.black87 : Colors.grey.shade400,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType:
          hint.contains('mobile') ? TextInputType.phone : TextInputType.text,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE67514), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class SelectionSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final Function(int) onSelected;

  const SelectionSheet({
    super.key, 
    required this.title,
    required this.items, 
    required this.onSelected
  });

  @override
  State<SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<SelectionSheet> {
  late List<String> filteredList;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredList = widget.items;
  }

  void _filterSearch(String query) {
    setState(() {
      filteredList = widget.items
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSearch,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search,
                    color: const Color(0xFFE67514), size: 20),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFE67514), width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filteredList.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final item = filteredList[index];
                return ListTile(
                  title: Text(item,
                      style: GoogleFonts.poppins(fontSize: 14)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    final originalIndex = widget.items.indexOf(item);
                    widget.onSelected(originalIndex);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
