import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'services/api_service.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final TransactionData transaction;

  const TransactionDetailsScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailsScreen> createState() => _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _shareReceipt() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/receipt_${widget.transaction.txnId}.png').create();
        await imagePath.writeAsBytes(image);

        await Share.shareXFiles([XFile(imagePath.path)], text: 'Transaction Receipt: ${widget.transaction.txnId}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing receipt: $e')),
      );
    }
  }

  Future<void> _downloadReceipt() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading receipt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = widget.transaction.transactionStatus?.toLowerCase() == 'success' || 
                         widget.transaction.transactionStatus?.toLowerCase() == 'captured';
    final bool isPending = widget.transaction.transactionStatus?.toLowerCase() == 'pending';

    Color statusColor = Colors.red;
    if (isSuccess) {
      statusColor = Colors.green;
    } else if (isPending) statusColor = const Color(0xFFE6A23C);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('Receipt', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Receipt Container wrapped with Screenshot widget
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // Status Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSuccess ? Icons.check_rounded : (isPending ? Icons.access_time_rounded : Icons.close_rounded),
                          color: statusColor,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSuccess ? 'Payment Successful' : (isPending ? 'Payment Pending' : 'Payment Failed'),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹ ${widget.transaction.paymentAmount ?? "0.0"}',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0E3B90),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                      ),
                      const SizedBox(height: 24),
                      
                      // Details List
                      _buildDetailItem('Transaction ID', widget.transaction.txnId ?? 'N/A'),
                      _buildDetailItem('Date & Time', widget.transaction.dateTime ?? 'N/A'),
                      _buildDetailItem('Property ID', widget.transaction.propertyId ?? 'N/A'),
                      _buildDetailItem('Bill Number', widget.transaction.billNo ?? 'N/A'),
                      _buildDetailItem('Financial Year', widget.transaction.financialYear ?? 'N/A'),
                      _buildDetailItem('Payment Mode', widget.transaction.paymentMode ?? 'N/A'),
                      if (widget.transaction.bankRefNo != null)
                        _buildDetailItem('Bank Ref No', widget.transaction.bankRefNo!),
                      
                      const SizedBox(height: 16),
                      // Dashed Line Simulation
                      Row(
                        children: List.generate(30, (index) => Expanded(
                          child: Container(
                            color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade300,
                            height: 1,
                          ),
                        )),
                      ),
                      const SizedBox(height: 24),
                      
                      // Logo or Footer
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32.0),
                        child: Image.asset(
                          'assets/images/e_nagar_seva_logo.png',
                          height: 40,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Share Receipt',
                      Icons.share_outlined,
                      const Color(0xFF0E3B90),
                      _shareReceipt,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      'Download',
                      Icons.file_download_outlined,
                      Colors.white,
                      _downloadReceipt,
                      isOutlined: true,
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onTap, {bool isOutlined = false}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutlined ? Colors.white : color,
        foregroundColor: isOutlined ? const Color(0xFF0E3B90) : Colors.white,
        elevation: isOutlined ? 0 : 4,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isOutlined ? const BorderSide(color: Color(0xFF0E3B90), width: 1.5) : BorderSide.none,
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
