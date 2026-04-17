import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum PaymentStatus { success, failure, pending }

class PaymentResultScreen extends StatelessWidget {
  final PaymentStatus status;
  final String? txnId;
  final String? amount;
  final String? message;
  final Map<String, String> details;

  const PaymentResultScreen({
    super.key,
    required this.status,
    this.txnId,
    this.amount,
    this.message,
    this.details = const {},
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      _buildStatusIcon(),
                      const SizedBox(height: 28),
                      _buildStatusTitle(),
                      const SizedBox(height: 8),
                      _buildStatusMessage(),
                      if (amount != null && amount!.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildAmountCard(),
                      ],
                      const SizedBox(height: 28),
                      _buildDetailsCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              _buildBottomButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    final config = _statusConfig;
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: config.bgColor,
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.color,
          ),
          child: Icon(config.icon, color: Colors.white, size: 44),
        ),
      ),
    );
  }

  Widget _buildStatusTitle() {
    final config = _statusConfig;
    return Text(
      config.title,
      style: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: config.color,
      ),
    );
  }

  Widget _buildStatusMessage() {
    final msg = message ?? _statusConfig.defaultMessage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey.shade600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    final config = _statusConfig;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            status == PaymentStatus.success ? 'Amount Paid' : 'Amount',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹ $amount',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final allDetails = <String, String>{};
    if (txnId != null && txnId!.isNotEmpty) {
      allDetails['Transaction ID'] = txnId!;
    }
    allDetails.addAll(details);

    if (allDetails.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Details',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          ...allDetails.entries.map((e) => _buildDetailRow(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF333333),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    final config = _statusConfig;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: () {
            // Pop back to payment details (or dashboard)
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: config.buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Text(
            config.buttonText,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  _StatusConfig get _statusConfig {
    switch (status) {
      case PaymentStatus.success:
        return _StatusConfig(
          icon: Icons.check_rounded,
          color: const Color(0xFF2ECC71),
          bgColor: const Color(0xFFE8F8F0),
          title: 'Payment Successful!',
          defaultMessage: 'Your property tax payment has been processed successfully.',
          buttonText: 'Done',
          buttonColor: const Color(0xFF2ECC71),
        );
      case PaymentStatus.failure:
        return _StatusConfig(
          icon: Icons.close_rounded,
          color: const Color(0xFFE74C3C),
          bgColor: const Color(0xFFFDE8E8),
          title: 'Payment Failed',
          defaultMessage: 'Your payment could not be processed. Please try again.',
          buttonText: 'Go Back',
          buttonColor: const Color(0xFFE74C3C),
        );
      case PaymentStatus.pending:
        return _StatusConfig(
          icon: Icons.schedule_rounded,
          color: const Color(0xFFF39C12),
          bgColor: const Color(0xFFFFF5E6),
          title: 'Payment Pending',
          defaultMessage: 'Your payment is being processed. Please check back later.',
          buttonText: 'Go Back',
          buttonColor: const Color(0xFFF39C12),
        );
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String title;
  final String defaultMessage;
  final String buttonText;
  final Color buttonColor;

  _StatusConfig({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.title,
    required this.defaultMessage,
    required this.buttonText,
    required this.buttonColor,
  });
}
