import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'property_tax_screen.dart';
import 'search_property_screen.dart';
import 'transaction_history_screen.dart';
import 'account_screen.dart';
import 'track_grievance_screen.dart';
import 'assessment_type_selection_screen.dart';
import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'services/notification_helper.dart';
import 'tour_guides/dashboard_tour.dart';
import 'arv_change_history_screen.dart';
import 'water_connection_list_screen.dart';
import 'widgets/urban_development_webview.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _sliderAccentColor = Color(0xFFE67514);
  static const Color _sliderBgColor = Color(0xFFFFF4E5);
  static const Color _sliderBorderColor = Color(0xFFFFE0B2);
  static const Color _sliderBodyTextColor = Color(0xFF666666);

  final _keySearchProperty = GlobalKey();
  final _keyPropertyTax = GlobalKey();
  final _keyTrackGrievance = GlobalKey();
  final _keyArvChangeHistory = GlobalKey();
  final _keyPropertyTaxAssessment = GlobalKey();
  final _keyMutation = GlobalKey();
  final _keyWaterSewerage = GlobalKey();
  final _keyBottomNav = GlobalKey();

  int _selectedIndex = 0;
  String _userType = "";
  String _displayName = "";

  // Add-more-property (Search New Property) card admin aur citizen dono ke
  // liye enable hai.
  bool get _canSearchProperty {
    final normalizedType = _userType.toLowerCase();
    return normalizedType == "admin" || normalizedType == "citizen";
  }

  final PageController _paymentPageController = PageController(
    viewportFraction: 0.95,
  );
  Timer? _paymentAutoScrollTimer;
  int _currentPaymentPage = 0;
  TutorialCoachMark? _tutorialCoachMark;

  // Payment Status — poora data local DB se aata hai (koi API call nahi).
  // Har saved property ka apna card banta hai; jis property ka bill data
  // cache nahi hua uska card slider me aata hi nahi.
  List<_PropertyPaymentStatus> _paymentStatuses = const [];

  // Fast-payment slide hamesha rehta hai, uske baad har property ka card.
  int get _sliderCardCount => 1 + _paymentStatuses.length;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _startPaymentAutoScroll();
    _loadPaymentStatuses();
  }

  @override
  void dispose() {
    _paymentAutoScrollTimer?.cancel();
    _paymentPageController.dispose();
    super.dispose();
  }

  void _startPaymentAutoScroll() {
    _paymentAutoScrollTimer?.cancel();
    _paymentAutoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_paymentPageController.hasClients) {
        return;
      }

      // Sirf ek hi card ho to scroll karne ka koi matlab nahi.
      if (_sliderCardCount < 2) {
        return;
      }

      final nextPage = (_currentPaymentPage + 1) % _sliderCardCount;
      _paymentPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadUserInfo() async {
    final type = await StorageService.getUserType();
    if (!mounted) return;

    setState(() {
      _userType = type ?? "";
      final normalizedType = _userType.toLowerCase();
      if (normalizedType == "admin") {
        _displayName = "Admin";
      } else if (normalizedType == "citizen") {
        _displayName = "Citizen";
      } else {
        _displayName = _userType;
      }
      if (_displayName.isEmpty) _displayName = "User";
    });

    await WidgetsBinding.instance.endOfFrame;
    await _autoStartTourIfFirstVisit();
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_dashboard') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_dashboard', true);
      await _startTour();
    }
  }

  /// Saari saved properties local DB se padhta hai aur unme se sirf unke card
  /// banata hai jinke paas bill data cache hai. Yahan koi network call nahi
  /// hoti — bill date / net payable payment details screen par cache hote hain.
  Future<void> _loadPaymentStatuses() async {
    List<PropertyEntity> properties;
    try {
      properties = await DatabaseService.getAllProperties();
    } catch (_) {
      properties = const [];
    }

    if (!mounted) return;

    final statuses = properties
        .map(_PropertyPaymentStatus.fromEntity)
        .whereType<_PropertyPaymentStatus>()
        .toList();

    // Card kam ho gaye to page index range se bahar na chala jaye.
    final needsReset = _currentPaymentPage >= 1 + statuses.length;

    setState(() {
      _paymentStatuses = statuses;
      if (needsReset) _currentPaymentPage = 0;
    });

    if (needsReset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _paymentPageController.hasClients) {
          _paymentPageController.jumpToPage(0);
        }
      });
    }

    _sendPaymentNotificationsIfNeeded(statuses);
  }

  /// `dd-mm-yyyy` parse karta hai. Galat format par null.
  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    final parts = dateStr.trim().split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  void _showTourSegment({
    required TargetFocus target,
    VoidCallback? onFinish,
  }) {
    _tutorialCoachMark = DashboardTourGuide.createCoachMark(
      targets: [target],
      onAdvance: () => _tutorialCoachMark?.next(),
      onFinish: onFinish,
    )..show(context: context);
  }

  Future<void> _scrollToTourTarget(GlobalKey keyTarget) async {
    if (keyTarget == _keyBottomNav) {
      return;
    }

    final targetContext = keyTarget.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.18,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _showTourStep(
    List<DashboardTourStep> steps,
    int index,
  ) async {
    if (!mounted || index >= steps.length) {
      return;
    }

    final step = steps[index];
    await _scrollToTourTarget(step.keyTarget);
    if (!mounted) {
      return;
    }

    _showTourSegment(
      target: step.target,
      onFinish: () {
        _showTourStep(steps, index + 1);
      },
    );
  }

  Future<void> _startTour() async {
    if (!mounted) return;

    final steps = DashboardTourGuide.buildSteps(
      propertyTaxKey: _keyPropertyTax,
      grievanceKey: _keyTrackGrievance,
      arvChangeHistoryKey: _keyArvChangeHistory,
      propertyTaxAssessmentKey: _keyPropertyTaxAssessment,
      mutationKey: _keyMutation,
      waterSewerageKey: _keyWaterSewerage,
      bottomNavKey: _keyBottomNav,
      searchPropertyKey: _canSearchProperty ? _keySearchProperty : null,
    );

    await _showTourStep(steps, 0);
  }

  void _handleTourTap() {
    _startTour();
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TransactionHistoryScreen(),
        ),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.of(context).size.width - 32 - 14) / 2;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _displayName,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFE67514),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFFE67514),
                      ),
                      tooltip: 'Tour Guide',
                      onPressed: _handleTourTap,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 150,
                        child: PageView.builder(
                          controller: _paymentPageController,
                          itemCount: _sliderCardCount,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPaymentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildFastPaymentSlide();
                            }
                            // Index 1 se aage: har saved property ka apna card.
                            return _buildPaymentStatusSlide(
                              _paymentStatuses[index - 1],
                            );
                          },
                        ),
                      ),
                      if (_sliderCardCount > 1) _buildSliderIndicator(),

                      // Refined "Search Property" Card - Admin + Citizen
                      if (_canSearchProperty) ...[
                        const SizedBox(height: 24),
                        GestureDetector(
                          key: _keySearchProperty,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SearchPropertyScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFFF4E5,
                                    ), // Soft orange background
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.add_business_outlined,
                                    color: Color(0xFFE67514),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Search New Property',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF444444),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Add more properties to your list',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Color(0xFFBBBBBB),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      Text(
                        'Quick Services',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF555555),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Dynamic Height Services Grid
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _buildServiceCard(
                            'OTS',
                            'Visit the department portal',
                            Icons.public_outlined,
                            cardWidth,
                            titleMaxLines: 3,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const UrbanDevelopmentWebView(),
                                ),
                              );
                            },
                          ),
                          _buildServiceCard(
                            'Property Tax',
                            'Manage all property tax',
                            Icons.home_work_outlined,
                            cardWidth,
                            key: _keyPropertyTax,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PropertyTaxScreen(),
                                ),
                              );
                              // Payment details screen wahan se khulti hai aur
                              // bill info DB me cache karti hai — wapas aate hi
                              // status cards refresh kar lo.
                              await _loadPaymentStatuses();
                            },
                          ),
                          _buildServiceCard(
                            'Track Grievance',
                            'Manage all property grievances',
                            Icons.assignment_outlined,
                            cardWidth,
                            key: _keyTrackGrievance,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TrackGrievanceScreen(),
                                ),
                              );
                            },
                          ),
                          _buildServiceCard(
                            'ARV Change History',
                            'Manage all ARV change history',
                            Icons.history_outlined,
                            cardWidth,
                            key: _keyArvChangeHistory,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ArvChangeHistoryScreen(),
                                ),
                              );
                            },
                          ),
                          _buildServiceCard(
                            'Property Tax Assessment',
                            'Manage all property assessments',
                            Icons.assessment_outlined,
                            cardWidth,
                            key: _keyPropertyTaxAssessment,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AssessmentTypeSelectionScreen(),
                                ),
                              );
                            },
                          ),
                          _buildServiceCard(
                            'Water & Sewerage',
                            'Manage water and sewerage services',
                            Icons.water_drop_outlined,
                            cardWidth,
                            key: _keyWaterSewerage,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const WaterConnectionListScreen(),
                                ),
                              );
                            },
                          ),
                          _buildServiceCard(
                            'Mutation',
                            'Manage name transfer and mutation',
                            Icons.swap_horiz_outlined,
                            cardWidth,
                            key: _keyMutation,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        key: _keyBottomNav,
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFFE67514),
          unselectedItemColor: const Color(0xFF999999),
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    String title,
    String desc,
    IconData icon,
    double width, {
    Key? key,
    VoidCallback? onTap,
    int titleMaxLines = 2,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: key,
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFE67514), size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF444444),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF777777),
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }





  Widget _buildFastPaymentSlide() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: _sliderCardDecoration(),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: _sliderAccentColor,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Fast Online Payment',
                    style: GoogleFonts.poppins(
                      color: _sliderAccentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Make instant payments using UPI or Debit Card.',
                    style: GoogleFonts.poppins(
                      color: _sliderBodyTextColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusSlide(_PropertyPaymentStatus status) {
    final statusColor = status.color;
    final isPaid = status.isPaid;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _sliderCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment Status',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _sliderAccentColor,
                    ),
                  ),
                ),
                if (isPaid)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Colors.green.shade600,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              status.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: _sliderBodyTextColor,
                height: 1.35,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    status.status,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        status.billDate != null
                            ? 'Due: ${status.billDate}'
                            : 'Due: N/A',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF444444),
                        ),
                      ),
                      if (!isPaid && status.netPayable != null)
                        Text(
                          'Payable: ₹${status.netPayableText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Slider ke neeche chhote dots — tabhi jab ek se zyada card ho.
  Widget _buildSliderIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_sliderCardCount, (index) {
          final isActive = index == _currentPaymentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 6,
            width: isActive ? 18 : 6,
            decoration: BoxDecoration(
              color: isActive ? _sliderAccentColor : _sliderBorderColor,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  BoxDecoration _sliderCardDecoration() {
    return BoxDecoration(
      color: _sliderBgColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _sliderBorderColor,
        width: 1,
      ),
    );
  }

  // ── Payment due notification (per property, per alert type, once a day) ────

  Future<void> _sendPaymentNotificationsIfNeeded(
    List<_PropertyPaymentStatus> statuses,
  ) async {
    final pending = statuses.where((s) => !s.isPaid && s.dueDate != null);
    if (pending.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final prefs = await SharedPreferences.getInstance();

    for (final status in pending) {
      final daysDiff = status.dueDate!.difference(today).inDays;

      String? notificationMsg;
      if (daysDiff == 7) {
        notificationMsg = 'Your payment is due in 7 days.';
      } else if (daysDiff == 3) {
        notificationMsg = 'Your payment is due in 3 days.';
      } else if (daysDiff == 1) {
        notificationMsg = 'Your payment is due tomorrow.';
      } else if (daysDiff == 0) {
        notificationMsg = 'Your payment is due today.';
      } else if (daysDiff == -3) {
        notificationMsg = 'Your payment is overdue by 3 days.';
      } else if (daysDiff == -7) {
        notificationMsg = 'Your payment is overdue by 7 days.';
      }

      if (notificationMsg == null) continue;

      // Guard: ek property ka ek alert ek calendar din me sirf ek baar.
      final key =
          'payment_notif_${status.propertyId}_${today.year}_${today.month}_${today.day}_$daysDiff';
      if (prefs.getBool(key) == true) continue;

      await prefs.setBool(key, true);
      NotificationHelper.showSimpleNotification(
        'Payment Alert',
        'Property ${status.propertyId}: $notificationMsg',
      );
    }
  }
}

/// Dashboard slider ke ek payment-status card ka data.
///
/// Poori tarah local DB ke cached `billDate` + `netPayable` par bana hota hai.
/// Dono khali hon to [fromEntity] null lautata hai — matlab card dikhana hi
/// nahi hai.
class _PropertyPaymentStatus {
  final String propertyId;

  /// Raw bill date jaisi DB me hai (`dd-mm-yyyy`), khali hone par null.
  final String? billDate;

  /// Parse ho chuki bill date; format galat ho to null.
  final DateTime? dueDate;

  /// Bakaya rakam; khali / `-` / unparseable hone par null.
  final double? netPayable;

  final String status;

  const _PropertyPaymentStatus({
    required this.propertyId,
    required this.billDate,
    required this.dueDate,
    required this.netPayable,
    required this.status,
  });

  static _PropertyPaymentStatus? fromEntity(PropertyEntity property) {
    final billDate = _cleanText(property.billDate);
    final netPayable = _parseAmount(property.netPayable);

    // Bill date aur net payable dono nadarad → is property ka card nahi.
    if (billDate == null && netPayable == null) return null;

    final dueDate = _DashboardScreenState._parseDate(billDate);
    final isPaid = netPayable != null && netPayable <= 0;

    final String status;
    if (isPaid) {
      status = 'Payment Done';
    } else if (dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (dueDate.isBefore(today)) {
        status = 'Overdue';
      } else if (dueDate.isAtSameMomentAs(today)) {
        status = 'Due Today';
      } else {
        status = 'Upcoming';
      }
    } else {
      // Rakam bakaya hai par valid due date nahi mili.
      status = 'Payment Due';
    }

    return _PropertyPaymentStatus(
      propertyId: property.propertyId,
      billDate: billDate,
      dueDate: dueDate,
      netPayable: netPayable,
      status: status,
    );
  }

  bool get isPaid => status == 'Payment Done';

  Color get color {
    switch (status) {
      case 'Payment Done':
        return Colors.green;
      case 'Overdue':
        return Colors.red;
      case 'Due Today':
        return Colors.orange;
      case 'Upcoming':
        return Colors.blue;
      default:
        return Colors.deepOrange;
    }
  }

  /// Card ki dusri line — kis property ka status hai ye clear karne ke liye.
  String get label => 'PID: $propertyId';

  String get message {
    switch (status) {
      case 'Payment Done':
        return 'Payment received successfully. Your account is up to date.';
      case 'Overdue':
        return 'Your payment is overdue. Please clear dues to avoid penalties.';
      case 'Due Today':
        return 'Your payment is due today. Complete payment to stay updated.';
      case 'Upcoming':
        return 'Your payment is upcoming. You can pay early for convenience.';
      default:
        return 'You have an outstanding amount on this property.';
    }
  }

  String get netPayableText {
    final amount = netPayable;
    if (amount == null) return '-';
    return amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toStringAsFixed(2);
  }

  /// Khali string, `-`, `n/a` jaise placeholders ko null maanta hai.
  static String? _cleanText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == '-' ||
        trimmed.toLowerCase() == 'null' ||
        trimmed.toLowerCase() == 'n/a') {
      return null;
    }
    return trimmed;
  }

  static double? _parseAmount(String? value) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;
    return double.tryParse(cleaned.replaceAll(',', '').replaceAll('₹', ''));
  }
}
