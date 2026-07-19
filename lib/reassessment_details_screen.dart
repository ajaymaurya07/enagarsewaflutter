import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'utils/ulb_language_helper.dart';

/// Shows the full details (owner/property info, floor breakdown, tax
/// breakdown) of a completed reassessment, fetched via
/// api/house_tax/getReassessmentDetails.
class ReassessmentDetailsScreen extends StatefulWidget {
  final String ackNo;

  const ReassessmentDetailsScreen({super.key, required this.ackNo});

  @override
  State<ReassessmentDetailsScreen> createState() => _ReassessmentDetailsScreenState();
}

class _ReassessmentDetailsScreenState extends State<ReassessmentDetailsScreen> {
  static const Color _primaryColor = Color(0xFFE67514);
  static const Color _textColor = Color(0xFF333333);

  bool _isLoading = true;
  String? _errorMessage;
  ReassessmentFullDetailsData? _data;
  bool _isKrutidev = false;

  @override
  void initState() {
    super.initState();
    _loadUlbLanguagePreference();
    _fetchDetails();
  }

  Future<void> _loadUlbLanguagePreference() async {
    final isKrutidev = await UlbLanguageHelper.isKrutidev();
    if (!mounted) return;
    setState(() => _isKrutidev = isKrutidev);
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.getReassessmentFullDetails(ackNo: widget.ackNo);
      if (!mounted) return;
      if (response.success != true || response.data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message ?? 'Failed to fetch reassessment details';
        });
        return;
      }
      setState(() {
        _data = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to fetch reassessment details. Please try again.',
        );
      });
    }
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
          'Reassessment Details',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: _textColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(_data!),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchDetails,
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ReassessmentFullDetailsData data) {
    final tax = data.taxDetails;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ack No: ${data.ackNo ?? '-'}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: _textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total ARV: ₹${data.totalArv ?? '-'}',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Property Details', Icons.badge_outlined),
          const SizedBox(height: 10),
          _buildInfoCard([
            _InfoRow('Owner Name', data.ownerName ?? '-', isLanguageSensitive: true),
            _InfoRow('Father/Husband Name', data.fatherName ?? '-', isLanguageSensitive: true),
            _InfoRow('House No.', data.houseNo ?? '-'),
            _InfoRow('Address', data.address ?? '-', isLanguageSensitive: true),
            _InfoRow('Mobile Number', data.mobileNo ?? '-'),
            _InfoRow('Assess Date', data.assessDate ?? '-'),
            if (tax != null) ...[
              _InfoRow('File No.', tax.fileNo ?? '-'),
              _InfoRow('Total Area', tax.totalArea != null ? '${tax.totalArea} sq.ft.' : '-'),
              _InfoRow('Old ARV', tax.oldArv ?? '-'),
            ],
          ]),
          if (data.floorDetails.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Floor Details', Icons.layers_outlined),
            const SizedBox(height: 10),
            ...data.floorDetails.map(_buildFloorCard),
          ],
          if (tax?.pwsList.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            _sectionTitle('Tax Breakdown', Icons.receipt_long_outlined),
            const SizedBox(height: 10),
            ...tax!.pwsList.map(_buildTaxCard),
          ],
          if (tax != null && ((tax.rebateFinancialYear?.isNotEmpty ?? false) || (tax.taxRebateTypeName?.isNotEmpty ?? false))) ...[
            const SizedBox(height: 20),
            _sectionTitle('Rebate', Icons.percent_rounded),
            const SizedBox(height: 10),
            _buildInfoCard([
              _InfoRow('Rebate Financial Year', tax.rebateFinancialYear ?? '-'),
              _InfoRow('Rebate Type', tax.taxRebateTypeName ?? '-'),
            ]),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _textColor),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    final visibleRows = rows.where((r) => r.value.trim().isNotEmpty && r.value.trim() != '-').toList();
    if (visibleRows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < visibleRows.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    visibleRows[i].label,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Text(
                    visibleRows[i].value,
                    textAlign: TextAlign.right,
                    style: (visibleRows[i].isLanguageSensitive && _isKrutidev)
                        ? const TextStyle(
                            fontFamily: UlbLanguageHelper.krutidevFontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          )
                        : GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _textColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloorCard(ReassessmentFloorDetail floor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            floor.floorName ?? 'Floor ${floor.floorNumber ?? ''}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: _textColor),
          ),
          const SizedBox(height: 4),
          Text(
            '${floor.floorTypeName ?? '-'} • ${floor.constructionTypeName ?? '-'}',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Area: ${floor.carpetArea ?? '-'} sq.ft.',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
              Text(
                'ARV: ₹${floor.arv?.toStringAsFixed(2) ?? '-'}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxCard(ReassessmentPwsItem pws) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FY ${pws.finYear ?? '-'}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: _textColor),
          ),
          const SizedBox(height: 8),
          _taxRow('Property Tax', pws.propertyTax),
          _taxRow('Water Tax', pws.waterTax),
          _taxRow('Sewerage Tax', pws.sewerageTax),
          _taxRow('Other Tax', pws.otherTax),
          _taxRow('Water Charge', pws.waterCharge),
          const Divider(height: 18),
          _taxRow('Grand Total', pws.grandTotal, isBold: true),
        ],
      ),
    );
  }

  Widget _taxRow(String label, double? value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            '₹${(value ?? 0).toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? _primaryColor : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool isLanguageSensitive;

  _InfoRow(this.label, this.value, {this.isLanguageSensitive = false});
}
