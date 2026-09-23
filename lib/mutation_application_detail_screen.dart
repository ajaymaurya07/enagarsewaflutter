import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/api_service.dart';
import 'utils/mutation_ui.dart';

/// Read-only view of a single mutation application, looked up by
/// acknowledgement number (Mutation Application Detail API).
class MutationApplicationDetailScreen extends StatefulWidget {
  final String ackNo;

  const MutationApplicationDetailScreen({super.key, required this.ackNo});

  @override
  State<MutationApplicationDetailScreen> createState() =>
      _MutationApplicationDetailScreenState();
}

class _MutationApplicationDetailScreenState
    extends State<MutationApplicationDetailScreen> {
  static const Color _primaryColor = MutationUi.primaryColor;
  static const Color _textColor = MutationUi.textColor;

  bool _isLoading = true;
  String? _errorMessage;
  MutationApplicationDetail? _details;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.getMutationApplicationDetail(
        ackNo: widget.ackNo,
      );
      if (!mounted) return;
      if (!response.success || response.data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'No mutation application found for this acknowledgement number.';
        });
        return;
      }
      setState(() {
        _details = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to fetch application details. Please try again.',
        );
      });
    }
  }

  void _copyAckNo() {
    Clipboard.setData(ClipboardData(text: widget.ackNo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Acknowledgement number copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MutationUi.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mutation Application',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: _fetchDetails,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (_errorMessage != null || _details == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, size: 44, color: _primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Application details are not available.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _fetchDetails,
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
          ),
        ],
      );
    }

    final details = _details!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildHeaderCard(details),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.home_work_outlined,
          title: 'Property & Previous Owner',
          rows: [
            ('Property ID', details.propertyId),
            ('Previous Owner', details.oldOwnerName),
            ("Father/Husband Name", details.oldFatherHusbandName),
            ('Mobile No.', details.oldMobileNo),
            ('Address', details.oldAddress),
            ('Zone / Ward / Mohalla',
                '${details.zoneName} / ${details.wardName} / ${details.mohallaName}'),
            ('Mutation Cause', MutationUi.prettify(details.mutationCauseString)),
            ('Property Occupied By', details.propertyOccupiedBy),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.person_outline_rounded,
          title: 'New Owner / Applicant',
          rows: [
            ('Occupier Name', details.occupierName),
            ("Father/Husband Name", details.fatherHusbandName),
            ('Mobile No.', details.mobileNo),
            ('Alternate Mobile', details.alternateMobileNo),
            ('Email', details.emailId),
            ('Communication Address', details.communicationAddress),
            ('PIN Code', details.occPinCode),
          ],
        ),
        const SizedBox(height: 16),
        _buildFeesSection(details),
      ],
    );
  }

  Widget _buildHeaderCard(MutationApplicationDetail details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acknowledgement No.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            details.ackNo.isNotEmpty ? details.ackNo : widget.ackNo,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _copyAckNo,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.copy_rounded, size: 16, color: _primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Applied ${MutationUi.formatDate(details.ackDate)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeesSection(MutationApplicationDetail details) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
          _buildSectionHeader(Icons.receipt_long_rounded, 'Fees & Registry'),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Column(
              children: [
                _buildInfoRow('Property Cost', '₹${MutationUi.formatAmount(details.propertyCost)}'),
                _buildInfoRow('Registry Date', MutationUi.formatDate(details.registryDate)),
                _buildInfoRow('Current ARV', '₹${MutationUi.formatAmount(details.currentArv)}'),
                _buildInfoRow('Mutation Fees', '₹${MutationUi.formatAmount(details.mutationFees)}'),
                _buildInfoRow('Late Fees', '₹${MutationUi.formatAmount(details.lateFees)}'),
                _buildInfoRow('Publication Fees', '₹${MutationUi.formatAmount(details.publicationFees)}'),
                _buildInfoRow('Processing Fees', '₹${MutationUi.formatAmount(details.processingFees)}'),
                _buildInfoRow('ULB Processing Fees', '₹${MutationUi.formatAmount(details.ulbProcessingFees)}'),
                _buildInfoRow('Residual Fees', '₹${MutationUi.formatAmount(details.residualFees)}'),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Fees',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                Text(
                  '₹${MutationUi.formatAmount(details.totalFees)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<(String, String)> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
          _buildSectionHeader(icon, title),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [for (final (label, value) in rows) _buildInfoRow(label, value)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isNotEmpty ? value.trim() : '-',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
