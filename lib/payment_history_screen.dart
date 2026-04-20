import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'services/api_service.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final String propertyId;
  final List<ReceiptDetailsItem> currReceiptDetails;
  final List<ReceiptDetailsItem> prevReceiptDetails;

  const PaymentHistoryScreen({
    super.key,
    required this.propertyId,
    required this.currReceiptDetails,
    required this.prevReceiptDetails,
  });

  @override
  Widget build(BuildContext context) {
    final allReceipts = [...currReceiptDetails, ...prevReceiptDetails];

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
              'Payment History',
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
      body: allReceipts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No payment history found',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 15)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allReceipts.length,
              itemBuilder: (context, index) {
                final receipt = allReceipts[index];
                final isCurrent = index < currReceiptDetails.length;
                return _ReceiptCard(
                  receipt: receipt,
                  isCurrent: isCurrent,
                  propertyId: propertyId,
                );
              },
            ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final ReceiptDetailsItem receipt;
  final bool isCurrent;
  final String propertyId;

  const _ReceiptCard({
    required this.receipt,
    required this.isCurrent,
    required this.propertyId,
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
            color: Colors.black.withOpacity(0.04),
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

  Widget _buildRow(String label, String? value, {bool isAmount = false}) {
    if (value == null || value.isEmpty || value == 'null') return const SizedBox.shrink();
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
              style: GoogleFonts.poppins(
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

  pw.Document _buildPdf() {
    final pdf = pw.Document();
    final rows = <List<String>>[];

    void addRow(String label, String? value) {
      if (value != null && value.isNotEmpty && value != 'null') {
        rows.add([label, value]);
      }
    }

    addRow('Bill Number', receipt.billNo);
    addRow('Receipt Date', receipt.receiptDate);
    addRow('Property Tax Paid', receipt.propertyTaxPaidAmount != null ? '₹ ${receipt.propertyTaxPaidAmount}' : null);
    addRow('Water Tax Paid', receipt.waterTaxPaidAmount != null ? '₹ ${receipt.waterTaxPaidAmount}' : null);
    addRow('Sewer Tax Paid', receipt.sewerTaxPaidAmount != null ? '₹ ${receipt.sewerTaxPaidAmount}' : null);
    addRow('Other Tax Paid', receipt.otherTaxPaidAmount != null ? '₹ ${receipt.otherTaxPaidAmount}' : null);
    addRow('Water Charge Paid', receipt.waterChargePaidAmount != null ? '₹ ${receipt.waterChargePaidAmount}' : null);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Payment Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Property ID: $propertyId', style: const pw.TextStyle(fontSize: 14)),
              if (receipt.receiptNo != null)
                pw.Text('Receipt No: ${receipt.receiptNo}', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                cellStyle: const pw.TextStyle(fontSize: 12),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellPadding: const pw.EdgeInsets.all(8),
                headers: ['Description', 'Value'],
                data: rows,
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
      final pdf = _buildPdf();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareReceipt(BuildContext context) async {
    try {
      final pdf = _buildPdf();
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/receipt_${receipt.receiptNo ?? 'payment'}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payment Receipt - Property ID: $propertyId',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
