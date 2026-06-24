import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'services/api_service.dart';
import 'tour_guides/transaction_details_tour.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final TransactionData transaction;

  const TransactionDetailsScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final GlobalKey _shareButtonKey = GlobalKey();
  final GlobalKey _downloadButtonKey = GlobalKey();

  TutorialCoachMark? _tutorialCoachMark;
  bool _isTourActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _autoStartTourIfFirstVisit(),
    );
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_transaction_details') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_transaction_details', true);
      await _startTour();
    }
  }

  void _showTourSegment({required TargetFocus target, VoidCallback? onFinish}) {
    _tutorialCoachMark = TransactionDetailsTourGuide.createCoachMark(
      targets: [target],
      onAdvance: () => _tutorialCoachMark?.next(),
      onFinish: onFinish,
      onSkip: _handleTourSkip,
    )..show(context: context);
  }

  Future<void> _scrollToTourTarget(GlobalKey keyTarget) async {
    final targetContext = keyTarget.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.18,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _showTourStep(
    List<TransactionDetailsTourStep> steps,
    int index,
  ) async {
    if (!mounted || index >= steps.length) {
      _resetTourState();
      return;
    }

    final step = steps[index];
    await _scrollToTourTarget(step.keyTarget);
    if (!mounted) {
      return;
    }

    _showTourSegment(
      target: step.target,
      onFinish: () {
        _showTourStep(steps, index + 1);
      },
    );
  }

  Future<void> _startTour() async {
    if (!mounted || _isTourActive) {
      return;
    }

    final steps = TransactionDetailsTourGuide.buildSteps(
      shareButtonKey: _shareButtonKey,
      downloadButtonKey: _downloadButtonKey,
    );

    if (steps.any((step) => step.keyTarget.currentContext == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tour will be available once the action buttons are visible.'),
        ),
      );
      return;
    }

    _isTourActive = true;
    await _showTourStep(steps, 0);
  }

  bool _handleTourSkip() {
    _resetTourState();
    return true;
  }

  void _resetTourState() {
    _isTourActive = false;
    _tutorialCoachMark = null;
  }

  Future<void> _shareReceipt() async {
    if (_isTourActive) {
      return;
    }

    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File(
          '${directory.path}/receipt_${widget.transaction.txnId}.png',
        ).create();
        await imagePath.writeAsBytes(image);
        try {
          await Share.shareXFiles([
            XFile(imagePath.path),
          ], text: 'Transaction Receipt: ${widget.transaction.txnId}');
        } finally {
          try { await imagePath.delete(); } catch (_) {}
        }
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage:
                  'Unable to share receipt right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _downloadReceipt() async {
    if (_isTourActive) {
      return;
    }

    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final pdf = pw.Document();
        final imageProvider = pw.MemoryImage(image);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
              );
            },
          ),
        );

        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'receipt_${widget.transaction.txnId}.pdf',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage:
                  'Unable to download receipt right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          'Receipt',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFFE67514),
            ),
            tooltip: 'Tour Guide',
            onPressed: _startTour,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            children: [
              Screenshot(
                controller: _screenshotController,
                child: _buildReceiptCard(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      key: _shareButtonKey,
                      child: _buildActionButton(
                        'Share Receipt',
                        Icons.share_outlined,
                        const Color(0xFF0E3B90),
                        _shareReceipt,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      key: _downloadButtonKey,
                      child: _buildActionButton(
                        'Download',
                        Icons.file_download_outlined,
                        Colors.white,
                        _downloadReceipt,
                        isOutlined: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptCard() {
    final txn = widget.transaction;
    final status = txn.transactionStatus?.toUpperCase() ?? '';
    final bool isSuccess = status == 'SUCCESS';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF4CAF50), width: 2),
              ),
            ),
            child: Text(
              'Property Tax Property ID. [ ${txn.propertyId ?? "N/A"} ]',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF333333),
              ),
            ),
          ),

          // Status Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: const Color(0xFFFAFAFA),
            child: Text(
              isSuccess
                  ? 'Payment for Property Tax Successful for Property ID. [ ${txn.propertyId ?? "N/A"} ]${txn.ulbName != null ? ', ${txn.ulbName}' : ''}'
                  : 'Payment ${status.isNotEmpty ? status : "UNKNOWN"} for Property ID. [ ${txn.propertyId ?? "N/A"} ]${txn.ulbName != null ? ', ${txn.ulbName}' : ''}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSuccess ? const Color(0xFF4CAF50) : Colors.red,
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFF4CAF50)),

          // Receipt Table
          _buildReceiptRow('Transaction Number', txn.txnId ?? 'N/A'),
          _buildReceiptRow('Property ID', txn.propertyId ?? 'N/A'),
          _buildReceiptRow('Transaction Date', txn.dateTime ?? 'N/A'),
          if (txn.eNagarSewaRefNo != null)
            _buildReceiptRow('E-NagarSewa Ref No.', txn.eNagarSewaRefNo!),
          if (txn.userCode != null)
            _buildReceiptRow('User Code', txn.userCode!),
          if (txn.ownerName != null)
            _buildReceiptRow('Owner Name', txn.ownerName!),
          if (txn.fatherName != null)
            _buildReceiptRow('Father/Husband Name', txn.fatherName!),
          if (txn.address != null)
            _buildReceiptRow('Address', txn.address!),
          _buildReceiptRow('Fees(Rs.)', txn.paymentAmount ?? '0.0'),
          if (txn.mobileNo != null)
            _buildReceiptRow('Mobile Number', txn.mobileNo!),
          if (txn.billNo != null)
            _buildReceiptRow('Bill Number', txn.billNo!),
          if (txn.financialYear != null)
            _buildReceiptRow('Financial Year', txn.financialYear!),
          if (txn.paymentMode != null)
            _buildReceiptRow('Payment Mode', txn.paymentMode!),
          if (txn.bankRefNo != null)
            _buildReceiptRow('Bank Ref No', txn.bankRefNo!),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              border: Border(
                top: BorderSide(color: Color(0xFF4CAF50), width: 2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'This is Computer Generated Receipt. It does not require a signature.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This receipt is printed through EODB, e-nagarsewa portal GoUP.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF555555),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Image.asset(
                  'assets/images/e_nagar_seva_logo.png',
                  height: 36,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 150,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                border: Border(
                  right: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF444444),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isOutlined = false,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutlined ? Colors.white : color,
        foregroundColor: isOutlined ? const Color(0xFF0E3B90) : Colors.white,
        elevation: isOutlined ? 0 : 4,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isOutlined
              ? const BorderSide(color: Color(0xFF0E3B90), width: 1.5)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
