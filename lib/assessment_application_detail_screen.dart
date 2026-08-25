import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/otp_gate_service.dart';
import 'utils/ulb_language_helper.dart';

/// Shows the full details (owner/property info, assessment order, tax
/// breakdown) of an assessment or reassessment application, fetched via
/// api/House_tax/assessmentApplicationDetail. Used by the "See Details"
/// action of both the assessment and reassessment cards.
class AssessmentApplicationDetailScreen extends StatefulWidget {
  final String ackNo;
  final String propertyId;
  final String mobileNo;
  final bool isReassessment;

  const AssessmentApplicationDetailScreen({
    super.key,
    required this.ackNo,
    this.propertyId = '',
    this.mobileNo = '',
    this.isReassessment = false,
  });

  @override
  State<AssessmentApplicationDetailScreen> createState() =>
      _AssessmentApplicationDetailScreenState();
}

class _AssessmentApplicationDetailScreenState
    extends State<AssessmentApplicationDetailScreen> {
  static const Color _primaryColor = Color(0xFFE67514);
  static const Color _textColor = Color(0xFF333333);

  bool _isLoading = true;
  String? _errorMessage;
  AssessmentApplicationDetailData? _data;
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
      final response = await OtpGateService.guard(
        call: () => ApiService.getAssessmentApplicationDetail(ackNo: widget.ackNo),
        responseCode: (r) => r.responseCode,
        propertyId: widget.propertyId,
        mobileNo: widget.mobileNo,
      );
      if (!mounted) return;
      if (response.success != true || response.data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message ?? 'Failed to fetch application details';
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
          fallbackMessage: 'Unable to fetch application details. Please try again.',
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
          widget.isReassessment ? 'Reassessment Details' : 'Assessment Details',
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

  Widget _buildContent(AssessmentApplicationDetailData data) {
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
                  'Ack No: ${_text(data.ackId)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: _textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total ARV: ${_money(data.totalArv)}',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                ),
                if (data.status?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(
                    data.status!.trim(),
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Owner Details', Icons.badge_outlined),
          const SizedBox(height: 10),
          _buildInfoCard([
            _InfoRow('Owner Name', _text(data.ownerName), isLanguageSensitive: true),
            _InfoRow('Father/Husband Name', _text(data.fatherName), isLanguageSensitive: true),
            _InfoRow('Mobile Number', _text(data.mobile)),
            _InfoRow('Email', _text(data.email)),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('Property Details', Icons.home_work_outlined),
          const SizedBox(height: 10),
          _buildInfoCard([
            _InfoRow('Property ID', _text(data.propertyId)),
            _InfoRow('House No.', _text(data.houseNo)),
            _InfoRow('Address', _text(data.address), isLanguageSensitive: true),
            _InfoRow('Landmark', _text(data.landmark), isLanguageSensitive: true),
            _InfoRow('Point of Presence', _text(data.popName)),
            _InfoRow('Zone', _text(data.zoneName)),
            _InfoRow('Ward', _text(data.wardName)),
            _InfoRow('Mohalla', _text(data.mohallaName)),
            _InfoRow('Property Type', _text(data.propertyTypeName)),
            _InfoRow('Nature of House', _text(data.natureHouseName)),
            _InfoRow('Road Location', _text(data.roadLocationName)),
            _InfoRow('Usage Detail', _text(data.detail)),
            _InfoRow('File No.', _text(data.fileNo)),
            _InfoRow('Total Area', _area(data.totalAreaOfProperty)),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('Assessment Details', Icons.assignment_outlined),
          const SizedBox(height: 10),
          _buildInfoCard([
            _InfoRow('Assess Type', _text(data.assessType)),
            _InfoRow('Assess Date', _text(data.assessDate)),
            _InfoRow('Total ARV', _text(data.totalArv)),
            _InfoRow('Net ARV', _text(data.netArv)),
            _InfoRow('Old ARV', _text(data.oldArv)),
            _InfoRow('Entered On', _text(data.enteredTs)),
            _InfoRow('Entered By', _text(data.enteredBy)),
            _InfoRow('Assessment Order No.', _text(data.assessOrderNo)),
            _InfoRow('Order Issued By', _text(data.assessOrderIssuedBy)),
            _InfoRow('Order Date', _text(data.assessOrderTs)),
            _InfoRow('Rebate Type', _text(data.rebateType)),
            _InfoRow('Rebate Date', _text(data.rebateDate)),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('Tax Breakdown', Icons.receipt_long_outlined),
          const SizedBox(height: 10),
          _buildTaxCard(data),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Every value is shown exactly as the API sent it: '-' stays '-', 'NA' stays
  // 'NA', 0 stays 0. Only a null/blank value falls back to '-'.
  String _text(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '-' : trimmed;
  }

  // Prefixes ₹ only when the API sent an actual amount; placeholders like
  // '-' / 'NA' are rendered as-is.
  String _money(String? value) {
    final trimmed = _text(value);
    if (AssessmentApplicationDetailData.asNumber(trimmed) == null) return trimmed;
    return '₹$trimmed';
  }

  String _area(String? value) {
    final trimmed = _text(value);
    if (AssessmentApplicationDetailData.asNumber(trimmed) == null) return trimmed;
    return '$trimmed sq.ft.';
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
    final visibleRows = rows;
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

  Widget _buildTaxCard(AssessmentApplicationDetailData data) {
    // Placeholders ('-', 'NA', blank) count as 0 towards the computed total but
    // are still displayed verbatim in their own row.
    double amount(String? raw) => AssessmentApplicationDetailData.asNumber(raw) ?? 0;
    final grandTotal = amount(data.currentTax) +
        amount(data.arrear) +
        amount(data.interest) +
        amount(data.waterTax) +
        amount(data.waterTaxArrear) +
        amount(data.waterTaxInterest) +
        amount(data.sewerageTax) +
        amount(data.sewerageTaxArrear) +
        amount(data.sewerageTaxInterest) +
        amount(data.waterCharge) +
        amount(data.waterChargeArrear) +
        amount(data.waterChargeInterest) +
        amount(data.garbageTax) +
        amount(data.garbageTaxArrear) +
        amount(data.garbageTaxInterest);

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
          _taxRow('Property Tax', data.currentTax),
          _taxRow('Property Tax Arrear', data.arrear),
          _taxRow('Property Tax Interest', data.interest),
          _taxRow('Modified Property Tax', data.modifiedCurrentTax),
          const Divider(height: 18),
          _taxRow('Water Tax', data.waterTax),
          _taxRow('Water Tax Arrear', data.waterTaxArrear),
          _taxRow('Water Tax Interest', data.waterTaxInterest),
          const Divider(height: 18),
          _taxRow('Sewerage Tax', data.sewerageTax),
          _taxRow('Sewerage Tax Arrear', data.sewerageTaxArrear),
          _taxRow('Sewerage Tax Interest', data.sewerageTaxInterest),
          const Divider(height: 18),
          _taxRow('Water Charge', data.waterCharge),
          _taxRow('Water Charge Arrear', data.waterChargeArrear),
          _taxRow('Water Charge Interest', data.waterChargeInterest),
          const Divider(height: 18),
          _taxRow('Garbage Tax', data.garbageTax),
          _taxRow('Garbage Tax Arrear', data.garbageTaxArrear),
          _taxRow('Garbage Tax Interest', data.garbageTaxInterest),
          const Divider(height: 18),
          _taxRow('Grand Total', grandTotal.toStringAsFixed(2), isBold: true),
        ],
      ),
    );
  }

  Widget _taxRow(String label, String? value, {bool isBold = false}) {
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
            _money(value),
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
