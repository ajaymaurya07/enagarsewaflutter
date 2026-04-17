import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';

class GrievanceStatusDetailsScreen extends StatefulWidget {
  final String grievanceNo;

  const GrievanceStatusDetailsScreen({super.key, required this.grievanceNo});

  @override
  State<GrievanceStatusDetailsScreen> createState() => _GrievanceStatusDetailsScreenState();
}

class _GrievanceStatusDetailsScreenState extends State<GrievanceStatusDetailsScreen> {
  late Future<GrievanceStatusResponse> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = ApiService.getGrievanceStatus(widget.grievanceNo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Grievance Details',
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
      body: FutureBuilder<GrievanceStatusResponse>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data?.data == null || snapshot.data!.data!.isEmpty) {
            return const Center(child: Text('No details found.'));
          }

          final data = snapshot.data!.data!.first;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(data),
                const SizedBox(height: 16),
                _buildSectionTitle('Basic Information'),
                _buildInfoCard([
                  _buildDetailRow('Name', data.name ?? 'N/A'),
                  _buildDetailRow('Father Name', data.fatherHusbandName ?? 'N/A'),
                  _buildDetailRow('Mobile', data.mobile ?? 'N/A'),
                  _buildDetailRow('Email', data.email ?? 'N/A'),
                ]),
                const SizedBox(height: 16),
                _buildSectionTitle('Location Details'),
                _buildInfoCard([
                  _buildDetailRow('ULB', data.ulbName ?? 'N/A'),
                  _buildDetailRow('Zone', data.zoneName ?? 'N/A'),
                  _buildDetailRow('Ward', data.wardName ?? 'N/A'),
                  _buildDetailRow('Mohalla', data.mohallaName ?? 'N/A'),
                  _buildDetailRow('Landmark', data.landmark ?? 'N/A'),
                  _buildDetailRow('Address', '${data.address1 ?? ""} ${data.address2 ?? ""}'.trim() == "" ? "N/A" : '${data.address1 ?? ""} ${data.address2 ?? ""}'.trim()),
                ]),
                const SizedBox(height: 16),
                _buildSectionTitle('Complaint Details'),
                _buildInfoCard([
                  _buildDetailRow('Category', data.categoryName ?? 'N/A'),
                  _buildDetailRow('Sub-category', data.subCategoryName ?? 'N/A'),
                  _buildDetailRow('Description', data.complaintDesc ?? 'N/A'),
                  _buildDetailRow('Date', data.complaintDate ?? 'N/A'),
                  _buildDetailRow('Time', data.complaintTime ?? 'N/A'),
                ]),
                const SizedBox(height: 16),
                _buildSectionTitle('Assignment & Resolution'),
                _buildInfoCard([
                  _buildDetailRow('Assigned Official', data.assignedOffName ?? 'N/A'),
                  _buildDetailRow('Official Mobile', data.assignedOffMobile ?? 'N/A'),
                  _buildDetailRow('Employee Name', data.assignedEmpName ?? 'N/A'),
                  _buildDetailRow('Close Remark', data.closeRemark ?? 'N/A'),
                  _buildDetailRow('Resolution Date', data.closeDate ?? 'N/A'),
                ]),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(GrievanceStatusData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE3F2FD), // light blue
            Color(0xFFBBDEFB), // softer blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ID: ${data.complaintId ?? "N/A"}',
                  style: GoogleFonts.poppins(
                    color: Colors.black87, // dark text
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.status ?? 'Pending',
                  style: GoogleFonts.poppins(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.categoryName ?? 'Complaint',
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: const Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF444444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
