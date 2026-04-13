import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'property_tax_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.of(context).size.width - 32 - 14) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF555555),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Admin',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2D4BA0),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fast Online Payment Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDDE8FF), width: 1),
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
                              color: const Color(0xFF1A3B8E),
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
                  _buildServiceCard('Track Grievance', 'Manage all property grievances', Icons.assignment_outlined, cardWidth),
                  _buildServiceCard('ARV Change History', 'Manage all ARV change history', Icons.history_outlined, cardWidth),
                  _buildServiceCard('Property Tax Assessment', 'Manage all property assessments', Icons.assessment_outlined, cardWidth),
                  _buildServiceCard('Mutation', 'Manage name transfer and mutation', Icons.swap_horiz_outlined, cardWidth),
                  _buildServiceCard('Water & Sewerage', 'Manage water and sewerage services', Icons.water_drop_outlined, cardWidth),
                ],
              ),
              const SizedBox(height: 24),
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
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFF0E3B90),
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
              color: Colors.black.withValues(alpha: 0.03),
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
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0E3B90), size: 26),
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
