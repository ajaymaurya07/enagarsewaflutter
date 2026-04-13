import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final String propertyId;

  const PaymentDetailsScreen({super.key, required this.propertyId});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  bool _isLoading = true;
  PropertyDetailsData? _details;
  String? _errorMessage;

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
      final response = await ApiService.getPropertyDetails(widget.propertyId);
      if (response.success == true && response.data != null) {
        setState(() {
          _details = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? "Failed to load details";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: GoogleFonts.poppins(
                color: const Color(0xFF333333),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'PID: ${widget.propertyId}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE67514)))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67514)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final bill = _details?.billDetails;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE67514), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Tax Summary',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryRow('Bill Date', bill?.billDate),
                  _buildSummaryRow('Bill Number', bill?.billNo),
                  _buildSummaryRow('Financial Year', bill?.finYear),
                  _buildSummaryRow('Total Arv', '10.0'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, thickness: 0.8),
                  ),
                  _buildSummaryRow('House Tax Net Amount', '201.00'),
                  _buildSummaryRow('Water Tax Net Amount', '201.00'),
                  _buildSummaryRow('Sewer Tax Net Amount', '201.00'),
                  _buildSummaryRow('Other Tax Net Amount', '201.00'),
                  _buildSummaryRow('Water Charge Net Amount', '201.00'),
                  _buildSummaryRow('Net Demand', 'null'),
                  _buildSummaryRow('Total Advance Tax Pay', '10.0'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Net Payable',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        Text(
                          '₹ ${bill?.netPayble ?? "0.0"}',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE67514),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Action Buttons at bottom
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildPrimaryButton('Pay Your Tax Online', () {}),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSecondaryButton('Print Property', Icons.print_outlined, () {})),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSecondaryButton('Add Grievance', Icons.add_comment_outlined, () {})),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSecondaryButton('ARV History', Icons.history_rounded, () {})),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSecondaryButton('Payment History', Icons.payment_rounded, () {})),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value ?? "N/A",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF444444),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE67514),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: const Color(0xFFE67514).withValues(alpha: 0.4),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE67514), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFE67514)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE67514),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
