import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'utils/ulb_language_helper.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final String propertyId;
  final List<ReceiptDetailsItem> currReceiptDetails;
  final List<ReceiptDetailsItem> prevReceiptDetails;
  final OwnerDetails? ownerDetails;
  final PropertyInfo? propertyDetails;

  const PaymentHistoryScreen({
    super.key,
    required this.propertyId,
    required this.currReceiptDetails,
    required this.prevReceiptDetails,
    this.ownerDetails,
    this.propertyDetails,
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  String? _ulbName;
  String? _ulbType;
  bool _isLoadingUlb = true;
  String? _ulbError;
  bool _isKrutidev = false;

  @override
  void initState() {
    super.initState();
    _loadUlbInfo();
    _loadUlbLanguagePreference();
  }

  Future<void> _loadUlbLanguagePreference() async {
    final isKrutidev = await UlbLanguageHelper.isKrutidev();
    if (!mounted) return;
    setState(() => _isKrutidev = isKrutidev);
  }

  Future<void> _loadUlbInfo() async {
    setState(() {
      _isLoadingUlb = true;
      _ulbError = null;
    });
    try {
      final property = await DatabaseService.getPropertyById(widget.propertyId);
      final ulbId = property?.ulbId;
      if (ulbId == null || ulbId.isEmpty) {
        setState(() => _ulbError = 'ULB details not found for this property.');
        return;
      }

      final ulbList = await ApiService.getUlbData();
      final match = ulbList.where((u) => u.ulbId == ulbId).firstOrNull;
      if (!mounted) return;
      if (match == null) {
        setState(() => _ulbError = 'ULB details not found for this property.');
        return;
      }

      setState(() {
        _ulbName = match.ulbName;
        _ulbType = match.ulbType;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ulbError = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to load ULB details. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoadingUlb = false);
    }
  }

  static bool _hasValidBillNo(ReceiptDetailsItem receipt) {
    final billNo = receipt.billNo?.trim();
    return billNo != null && billNo.isNotEmpty && billNo != '-';
  }

  Widget _buildUlbErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              _ulbError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUlbInfo,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67514)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertyId = widget.propertyId;
    final currReceiptDetails = widget.currReceiptDetails;
    final prevReceiptDetails = widget.prevReceiptDetails;
    final ownerDetails = widget.ownerDetails;
    final propertyDetails = widget.propertyDetails;
    final filteredCurrReceipts = currReceiptDetails.where(_hasValidBillNo).toList();
    final filteredPrevReceipts = prevReceiptDetails.where(_hasValidBillNo).toList();
    final allReceipts = [...filteredCurrReceipts, ...filteredPrevReceipts];

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
              'Receipt Details',
              style: GoogleFonts.poppins(
                color: const Color(0xFF333333),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'PID: $propertyId',
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
      body: _isLoadingUlb
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE67514)))
          : _ulbError != null
              ? _buildUlbErrorState()
              : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (allReceipts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No current receipt details found',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 15)),
                  ],
                ),
              ),
            )
          else
            ...List.generate(allReceipts.length, (index) {
              final receipt = allReceipts[index];
              final isCurrent = index < filteredCurrReceipts.length;
              return _ReceiptCard(
                receipt: receipt,
                isCurrent: isCurrent,
                propertyId: propertyId,
                ownerDetails: ownerDetails,
                propertyDetails: propertyDetails,
                ulbName: _ulbName,
                ulbType: _ulbType,
                isKrutidev: _isKrutidev,
              );
            }),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final ReceiptDetailsItem receipt;
  final bool isCurrent;
  final String propertyId;
  final OwnerDetails? ownerDetails;
  final PropertyInfo? propertyDetails;
  final String? ulbName;
  final String? ulbType;
  final bool isKrutidev;

  const _ReceiptCard({
    required this.receipt,
    required this.isCurrent,
    required this.propertyId,
    this.ownerDetails,
    this.propertyDetails,
    this.ulbName,
    this.ulbType,
    this.isKrutidev = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_rounded,
                  size: 18,
                  color: isCurrent ? Colors.green.shade700 : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  isCurrent ? 'Current Year' : 'Previous Year',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  receipt.receiptDate ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isCurrent ? Colors.green.shade600 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isCurrent && ownerDetails != null) ...[
                  _buildRow('Owner Name', ownerDetails!.ownerName, isLanguageSensitive: true),
                  _buildRow('Father/Husband Name', ownerDetails!.fatherName, isLanguageSensitive: true),
                ],
                if (isCurrent) ...[
                  _buildRow('ULB Name', ulbName),
                  _buildRow('ULB Type', ulbType),
                ],
                if (isCurrent && propertyDetails != null) ...[
                  _buildRow('Zone', propertyDetails!.zoneName),
                  _buildRow('Ward', propertyDetails!.wardName),
                  _buildRow('Mohalla', propertyDetails!.mohallaName),
                  _buildRow('House Number', propertyDetails!.houseNo),
                  _buildRow('Address', propertyDetails!.address, isLanguageSensitive: true),
                ],
                _buildRow('Bill Number', receipt.billNo),
                _buildRow('Receipt Date', receipt.receiptDate),
                _buildRow('Property Tax Paid', receipt.propertyTaxPaidAmount, isAmount: true),
                _buildRow('Water Tax Paid', receipt.waterTaxPaidAmount, isAmount: true),
                _buildRow('Sewer Tax Paid', receipt.sewerTaxPaidAmount, isAmount: true),
                _buildRow('Other Tax Paid', receipt.otherTaxPaidAmount, isAmount: true),
                _buildRow('Water Charge Paid', receipt.waterChargePaidAmount, isAmount: true),
              ],
            ),
          ),

          // Action Buttons
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _downloadReceipt(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download_rounded, size: 18, color: Color(0xFF0E3B90)),
                          const SizedBox(width: 6),
                          Text('Download',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0E3B90))),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: InkWell(
                    onTap: () => _shareReceipt(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share_rounded, size: 18, color: Color(0xFFE67514)),
                          const SizedBox(width: 6),
                          Text('Share',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFE67514))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String? value, {bool isAmount = false, bool isLanguageSensitive = false}) {
    if (value == null || value.isEmpty || value == 'null') return const SizedBox.shrink();
    final useKrutidev = isLanguageSensitive && isKrutidev;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              isAmount ? '₹ $value' : value,
              textAlign: TextAlign.right,
              style: useKrutidev
                  ? const TextStyle(
                      fontFamily: UlbLanguageHelper.krutidevFontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444),
                    )
                  : GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isAmount ? const Color(0xFF0E3B90) : const Color(0xFF444444),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.Document> _buildPdf() async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document();
    final rows = <List<String>>[];

    void addRow(String label, String? value) {
      if (value != null && value.isNotEmpty && value != 'null' && value != '-') {
        rows.add([label, value]);
      }
    }

    if (isCurrent && ownerDetails != null) {
      addRow('Owner Name', ownerDetails!.ownerName);
      addRow('Father/Husband Name', ownerDetails!.fatherName);
    }
    if (isCurrent) {
      addRow('ULB Name', ulbName);
      addRow('ULB Type', ulbType);
    }
    if (isCurrent && propertyDetails != null) {
      addRow('Zone', propertyDetails!.zoneName);
      addRow('Ward', propertyDetails!.wardName);
      addRow('Mohalla', propertyDetails!.mohallaName);
      addRow('House Number', propertyDetails!.houseNo);
      addRow('Address', propertyDetails!.address);
    }
    addRow('Bill Number', receipt.billNo);
    addRow('Receipt No', receipt.receiptNo);
    addRow('Receipt Date', receipt.receiptDate);
    addRow('Payment Mode', receipt.paymentMode);
    addRow('Property Tax Paid', receipt.propertyTaxPaidAmount != null ? '₹ ${receipt.propertyTaxPaidAmount}' : null);
    addRow('Water Tax Paid', receipt.waterTaxPaidAmount != null ? '₹ ${receipt.waterTaxPaidAmount}' : null);
    addRow('Sewer Tax Paid', receipt.sewerTaxPaidAmount != null ? '₹ ${receipt.sewerTaxPaidAmount}' : null);
    addRow('Other Tax Paid', receipt.otherTaxPaidAmount != null ? '₹ ${receipt.otherTaxPaidAmount}' : null);
    addRow('Water Charge Paid', receipt.waterChargePaidAmount != null ? '₹ ${receipt.waterChargePaidAmount}' : null);

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
                  'Property Tax Property ID. [ $propertyId ]',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  isCurrent
                      ? 'Current Year Receipt for Property ID. [ $propertyId ]'
                      : 'Previous Year Receipt for Property ID. [ $propertyId ]',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.green),
                ),
              ),
              pw.Divider(color: PdfColors.green, height: 1, thickness: 2),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                },
                children: rows
                    .map((row) => pw.TableRow(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              color: PdfColors.grey100,
                              child: pw.Text(row[0], style: const pw.TextStyle(fontSize: 11)),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                row[1],
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ))
                    .toList(),
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
                      'This receipt is printed through EODB, eNagarSewa portal GoUP.',
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

  Future<void> _downloadReceipt(BuildContext context) async {
    try {
      final pdf = await _buildPdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'receipt_${receipt.receiptNo ?? receipt.billNo ?? 'payment'}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.getUserFriendlyErrorMessage(
                e,
                fallbackMessage:
                    'Unable to download receipt right now. Please try again.',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareReceipt(BuildContext context) async {
    try {
      final pdf = await _buildPdf();
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/receipt_${receipt.receiptNo ?? 'payment'}.pdf');
      await file.writeAsBytes(bytes);
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Payment Receipt - Property ID: $propertyId',
        );
      } finally {
        try { await file.delete(); } catch (_) {}
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.getUserFriendlyErrorMessage(
                e,
                fallbackMessage:
                    'Unable to share receipt right now. Please try again.',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
