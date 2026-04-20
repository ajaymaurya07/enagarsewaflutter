import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'property_tax_screen.dart';
import 'search_property_screen.dart';
import 'transaction_history_screen.dart';
import 'account_screen.dart';
import 'track_grievance_screen.dart';
import 'property_tax_assessment_screen.dart';
import 'services/storage_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _userType = "";
  String _displayName = "";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final type = await StorageService.getUserType();
    setState(() {
      _userType = type ?? "";
      _displayName = (_userType.toLowerCase() == "admin") ? "Admin" : _userType;
      if (_displayName.isEmpty) _displayName = "User";
    });
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FB), Color(0xFFF8F9FB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              // Fast Online Payment Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: Color(0xFFE67514), size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fast Online Payment',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFE67514),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Make instant payments using UPI or Debit Card.',
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
              
              // Refined "Search Property" Card - Only for Admin
              if (_userType.toLowerCase() == "admin") ...[
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SearchPropertyScreen()),
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
                            color: const Color(0xFFFFF4E5), // Soft orange background
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_business_outlined, color: Color(0xFFE67514), size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFBBBBBB), size: 16),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PropertyTaxScreen()),
                      );
                    },
                  ),
                  _buildServiceCard(
                    'Track Grievance', 
                    'Manage all property grievances', 
                    Icons.assignment_outlined, 
                    cardWidth,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TrackGrievanceScreen()),
                      );
                    },
                  ),
                  _buildServiceCard('ARV Change History', 'Manage all ARV change history', Icons.history_outlined, cardWidth),
                  _buildServiceCard('Property Tax Assessment', 'Manage all property assessments', Icons.assessment_outlined, cardWidth,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PropertyTaxAssessmentScreen()),
                      );
                    },
                  ),
                  _buildServiceCard('Mutation', 'Manage name transfer and mutation', Icons.swap_horiz_outlined, cardWidth),
                  _buildServiceCard('Water & Sewerage', 'Manage water and sewerage services', Icons.water_drop_outlined, cardWidth),
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
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFFE67514),
          unselectedItemColor: const Color(0xFF999999),
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(String title, String desc, IconData icon, double width, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
