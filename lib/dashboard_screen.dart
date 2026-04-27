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
import 'property_tax_assessment_screen.dart';
import 'services/storage_service.dart';
import 'tour_guides/dashboard_tour.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
  final PageController _paymentPageController = PageController(
    viewportFraction: 0.95,
  );
  Timer? _paymentAutoScrollTimer;
  int _currentPaymentPage = 0;
  TutorialCoachMark? _tutorialCoachMark;

  final List<Map<String, dynamic>> _paymentCards = const [
    {
      'title': 'Fast Online Payment',
      'subtitle': 'Make instant payments using UPI or Debit Card.',
      'icon': Icons.notifications_active_outlined,
    },
    {
      'title': 'Quick Tax Payment',
      'subtitle': 'Pay property tax safely with net banking and cards.',
      'icon': Icons.account_balance_wallet_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _startPaymentAutoScroll();
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
      if (!mounted ||
          !_paymentPageController.hasClients ||
          _paymentCards.isEmpty) {
        return;
      }

      final nextPage = (_currentPaymentPage + 1) % _paymentCards.length;
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
      _displayName = (_userType.toLowerCase() == "admin") ? "Admin" : _userType;
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
      searchPropertyKey:
          _userType.toLowerCase() == 'admin' ? _keySearchProperty : null,
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
                      // Auto-scrolling payment cards
                      SizedBox(
                        height: 120,
                        child: PageView.builder(
                          controller: _paymentPageController,
                          itemCount: _paymentCards.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPaymentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final card = _paymentCards[index];

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4E5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFFE0B2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      card['icon'] as IconData,
                                      color: const Color(0xFFE67514),
                                      size: 36,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            card['title'] as String,
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFFE67514),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            card['subtitle'] as String,
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF666666),
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
                          },
                        ),
                      ),

                      // Refined "Search Property" Card - Only for Admin
                      if (_userType.toLowerCase() == "admin") ...[
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
                            'Property Tax',
                            'Manage all property tax',
                            Icons.home_work_outlined,
                            cardWidth,
                            key: _keyPropertyTax,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PropertyTaxScreen(),
                                ),
                              );
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
                                      const PropertyTaxAssessmentScreen(),
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
                          _buildServiceCard(
                            'Water & Sewerage',
                            'Manage water and sewerage services',
                            Icons.water_drop_outlined,
                            cardWidth,
                            key: _keyWaterSewerage,
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
              maxLines: 2,
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
}
