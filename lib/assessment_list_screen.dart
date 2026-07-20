import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/otp_gate_service.dart';
import 'utils/ulb_language_helper.dart';
import 'assessment_details_screen.dart';
import 'assessment_document_upload_screen.dart';
import 'property_tax_assessment_screen.dart';

/// Home screen for the fresh (non-reassessment) property tax assessment
/// flow: shows all in-progress/completed assessments via getAssessmentList,
/// and a "+ New Assessment" entry point. Mirrors reassessment_screen.dart.
class AssessmentListScreen extends StatefulWidget {
  const AssessmentListScreen({super.key});

  @override
  State<AssessmentListScreen> createState() => _AssessmentListScreenState();
}

class _AssessmentListScreenState extends State<AssessmentListScreen> {
  static const Color _primaryColor = Color(0xFFE67514);
  static const Color _textColor = Color(0xFF333333);

  bool _isLoading = true;
  String? _errorMessage;
  List<ReassessmentListItem> _items = [];
  bool _isKrutidev = false;

  @override
  void initState() {
    super.initState();
    _loadUlbLanguagePreference();
    _fetchList();
  }

  Future<void> _loadUlbLanguagePreference() async {
    final isKrutidev = await UlbLanguageHelper.isKrutidev();
    if (!mounted) return;
    setState(() => _isKrutidev = isKrutidev);
  }

  Future<void> _fetchList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await OtpGateService.guard(
        call: () => ApiService.getAssessmentList(),
        responseCode: (r) => r.responseCode,
        propertyId: '',
        mobileNo: '',
      );
      if (!mounted) return;
      if (response.success != true) {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message ?? 'Failed to fetch assessment list';
        });
        return;
      }
      setState(() {
        _items = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to fetch assessment list. Please try again.',
        );
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleNewAssessment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PropertyTaxAssessmentScreen()),
    );
    if (result != null && mounted) _fetchList();
  }

  // Completed -> getAssessmentDetails (See Details).
  // next_stage 4 -> document upload screen (only needs ackNo, no
  // dependency on earlier-step dropdown data).
  // next_stage 1/2/3 -> no dedicated resume-fetch API exists for the
  // Road Location/Property Type/Floor Config dropdown data needed by
  // those steps, so restart the full Step 1-4 form instead of trying to
  // resume mid-flow.
  Future<void> _handleCardTap(ReassessmentListItem item) async {
    final propertyId = item.propertyId;
    final ackNo = item.ackNo;
    if (ackNo == null) return;

    if (item.isCompletedFlag) {
      final property = propertyId != null ? await DatabaseService.getPropertyById(propertyId) : null;
      final mobileNo = property?.phoneNumber ?? '';
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentDetailsScreen(
            ackNo: ackNo,
            propertyId: propertyId ?? '',
            mobileNo: mobileNo,
          ),
        ),
      );
      return;
    }

    final nextStage = item.nextStage;
    if (nextStage == null) {
      _showSnackBar('No further action is available for this assessment right now.');
      return;
    }

    if (nextStage >= 4) {
      final property = propertyId != null ? await DatabaseService.getPropertyById(propertyId) : null;
      final mobileNo = property?.phoneNumber ?? '';
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentDocumentUploadScreen(
            ackNo: ackNo,
            isReassessment: false,
            propertyId: propertyId ?? '',
            mobileNo: mobileNo,
          ),
        ),
      );
      if (result != null && mounted) _fetchList();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PropertyTaxAssessmentScreen()),
    );
    if (result != null && mounted) _fetchList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Property Tax Assessment',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: _textColor),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: _fetchList,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildNewAssessmentButton(),
        const SizedBox(height: 24),
        Text(
          'Assessment Summary',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor),
        ),
        const SizedBox(height: 12),
        _buildListContent(),
      ],
    );
  }

  Widget _buildNewAssessmentButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _handleNewAssessment,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
        label: Text(
          'New Assessment',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_errorMessage != null) {
      return _buildMessageState(
        icon: Icons.wifi_off_rounded,
        title: 'Something went wrong',
        subtitle: _errorMessage!,
        showRetry: true,
      );
    }

    if (_items.isEmpty) {
      return _buildMessageState(
        icon: Icons.description_outlined,
        title: 'No assessments yet',
        subtitle: 'Assessments you start will appear here so you can track their progress.',
        showRetry: false,
      );
    }

    return Column(
      children: [
        for (final item in _items) ...[
          _buildCard(item),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: _primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
          ),
          if (showRetry) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _fetchList,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Retry',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(ReassessmentListItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleCardTap(item),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.ownerName?.trim().isNotEmpty == true
                                ? item.ownerName!.trim()
                                : 'Unknown Owner',
                            style: _isKrutidev
                                ? const TextStyle(
                                    fontFamily: UlbLanguageHelper.krutidevFontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _textColor,
                                  )
                                : GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ack: ${item.ackNo ?? '-'}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(item),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    _buildDetailRow('House No.',
                        (item.houseNo?.trim().isNotEmpty == true) ? item.houseNo!.trim() : '-'),
                    _buildDetailRow('Address',
                        (item.address?.trim().isNotEmpty == true) ? item.address!.trim() : '-'),
                    _buildDetailRow('Assess Date', item.assessDate ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ReassessmentListItem item) {
    final completed = item.isCompletedFlag;
    final color = completed ? const Color(0xFF1E9E5A) : _primaryColor;
    final label = completed ? 'Completed' : 'In Progress';
    final icon = completed ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
