import 'dart:io';

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
    if (_isTourActive) return;

    try {
      final pdf = await _buildPdf();
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/receipt_${widget.transaction.txnId ?? 'payment'}.pdf');
      await file.writeAsBytes(bytes);
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Payment Receipt - Property ID: ${widget.transaction.propertyId}',
        );
      } finally {
        try { await file.delete(); } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage: 'Unable to share receipt right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<pw.Document> _buildPdf() async {
    final txn = widget.transaction;
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document();

    final status = txn.transactionStatus?.toUpperCase() ?? '';
    final isSuccess = status == 'SUCCESS';

    final rows = <List<String>>[];

    rows.add(['Transaction Number', txn.txnId ?? 'null']);
    rows.add(['Property ID.', txn.propertyId ?? 'null']);
    rows.add(['Transaction Date', txn.dateTime ?? 'null']);
    rows.add(['User Code', txn.userCode ?? 'null']);
    rows.add(['Owner Name', txn.ownerName ?? 'null']);
    rows.add(['Father/Husband Name', txn.fatherName ?? 'null']);
    rows.add(['Address', txn.address ?? 'null']);
    rows.add(['Fees(Rs.)', txn.paymentAmount ?? 'null']);
    rows.add(['Mobile Number', txn.mobileNo ?? 'null']);
    rows.add(['Receipt No', txn.receiptNo ?? 'null']);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.green, width: 2)),
                ),
                child: pw.Text(
                  'Property Tax Property ID. [ ${txn.propertyId ?? "N/A"} ]',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  isSuccess
                      ? 'Payment for Property Tax Successful for Property ID. [ ${txn.propertyId ?? "N/A"} ]${_ulbLabel(txn)}'
                      : 'Payment ${status.isNotEmpty ? status : "UNKNOWN"} for Property ID. [ ${txn.propertyId ?? "N/A"} ]${_ulbLabel(txn)}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: isSuccess ? PdfColors.green : PdfColors.red,
                  ),
                ),
              ),
              pw.Divider(color: PdfColors.green, height: 1, thickness: 2),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                },
                children: rows.map((row) => pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      color: PdfColors.grey100,
                      child: pw.Text(row[0], style: const pw.TextStyle(fontSize: 11)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(row[1], style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                )).toList(),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.green, width: 2)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'This is Computer Generated Receipt. It does not require a signature.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'This receipt is printed through EODB,e-nagarsewa portal GoUP.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> _downloadReceipt() async {
    if (_isTourActive) return;

    try {
      final pdf = await _buildPdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'receipt_${widget.transaction.txnId}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage: 'Unable to download receipt right now. Please try again.',
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

  String _ulbLabel(TransactionData txn) {
    final parts = <String>[];
    if (txn.ulbName != null) parts.add(txn.ulbName!);
    if (txn.ulbType != null) parts.add(txn.ulbType!);
    return parts.isNotEmpty ? ', ${parts.join(' ')}' : '';
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
                  ? 'Payment for Property Tax Successful for Property ID. [ ${txn.propertyId ?? "N/A"} ]${_ulbLabel(txn)}'
                  : 'Payment ${status.isNotEmpty ? status : "UNKNOWN"} for Property ID. [ ${txn.propertyId ?? "N/A"} ]${_ulbLabel(txn)}',
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
          _buildReceiptRow('Transaction Number', txn.txnId ?? 'null'),
          _buildReceiptRow('Property ID', txn.propertyId ?? 'null'),
          _buildReceiptRow('Transaction Date', txn.dateTime ?? 'null'),
          _buildReceiptRow('User Code', txn.userCode ?? 'null'),
          _buildReceiptRow('Owner Name', txn.ownerName ?? 'null'),
          _buildReceiptRow('Father/Husband Name', txn.fatherName ?? 'null'),
          _buildReceiptRow('Address', txn.address ?? 'null'),
          _buildReceiptRow('Fees(Rs.)', txn.paymentAmount ?? 'null'),
          _buildReceiptRow('Mobile Number', txn.mobileNo ?? 'null'),
          _buildReceiptRow('Receipt No', txn.receiptNo ?? 'null'),

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
                // Image.asset(
                //   'assets/images/e_nagar_seva_logo.png',
                //   height: 36,
                //   errorBuilder: (context, error, stackTrace) =>
                //       const SizedBox.shrink(),
                // ),
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
