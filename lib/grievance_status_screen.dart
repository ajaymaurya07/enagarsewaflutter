import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'grievance_status_details_screen.dart';

class GrievanceStatusScreen extends StatefulWidget {
  const GrievanceStatusScreen({super.key});

  @override
  State<GrievanceStatusScreen> createState() => _GrievanceStatusScreenState();
}

class _GrievanceStatusScreenState extends State<GrievanceStatusScreen> {
  late Future<GrievanceDetailsResponse> _grievanceFuture;

  @override
  void initState() {
    super.initState();
    _grievanceFuture = _fetchGrievances();
  }

  Future<GrievanceDetailsResponse> _fetchGrievances() async {
    final email = await StorageService.getEmailId();
    if (email == null || email.isEmpty) {
      throw Exception('Email not found in storage');
    }
    return ApiService.getGrievanceDetails(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Grievance Status',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<GrievanceDetailsResponse>(
        future: _grievanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data?.data == null || snapshot.data!.data!.isEmpty) {
            return const Center(child: Text('No grievances found.'));
          }

          final grievances = snapshot.data!.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grievances.length,
            itemBuilder: (context, index) {
              final grievance = grievances[index];
              return _buildGrievanceCard(context, grievance);
            },
          );
        },
      ),
    );
  }

  Widget _buildGrievanceCard(BuildContext context, GrievanceDetails grievance) {
    return GestureDetector(
      onTap: () {
        if (grievance.grievanceNo != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GrievanceStatusDetailsScreen(grievanceNo: grievance.grievanceNo!),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${grievance.grievanceNo ?? "N/A"}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF0E3B90),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Pending',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Category', grievance.categoryName ?? 'N/A'),
            _buildInfoRow('Sub-category', grievance.subcategoryName ?? 'N/A'),
            _buildInfoRow('Date & Time', grievance.updatedAt ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
