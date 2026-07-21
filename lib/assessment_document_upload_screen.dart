import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';
import 'services/otp_gate_service.dart';
import 'services/assessment_exit_guard.dart';
import 'widgets/assessment_progress_bar.dart';

class AssessmentDocumentUploadScreen extends StatefulWidget {
  final String ackNo;
  final bool isReassessment;
  final String propertyId;
  final String mobileNo;

  const AssessmentDocumentUploadScreen({
    super.key,
    required this.ackNo,
    this.isReassessment = false,
    required this.propertyId,
    required this.mobileNo,
  });

  @override
  State<AssessmentDocumentUploadScreen> createState() =>
      _AssessmentDocumentUploadScreenState();
}

class _AssessmentDocumentUploadScreenState
    extends State<AssessmentDocumentUploadScreen> {
  static const Color _primaryColor = Color(0xFFE67514);
  static const Color _softPrimaryColor = Color(0xFFFFF4E8);

  final ImagePicker _picker = ImagePicker();

  File? _selectedFile;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _successMessage;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final fileSizeInBytes = await file.length();
      if (fileSizeInBytes > 200 * 1024) {
        final sizeInKB = (fileSizeInBytes / 1024).toStringAsFixed(1);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'File Too Large',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(
                'Selected file size is ${sizeInKB}KB which exceeds the 200KB limit.\n\nPlease select a smaller file.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }
      setState(() => _selectedFile = file);
    } catch (_) {}
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attach Document',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _softPrimaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primaryColor, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedFile == null) {
      _showSnackBar('Please attach a supporting document');
      return;
    }

    // debugPrint('[DocUpload] _handleSubmit -> ackNo=${widget.ackNo}, isReassessment=${widget.isReassessment}');
    setState(() => _isSubmitting = true);
    try {
      final response = await OtpGateService.guard(
        call: () => widget.isReassessment
            ? ApiService.finalizeReassessment(
                ackNo: widget.ackNo,
                applicationFile: _selectedFile!,
              )
            : ApiService.finalizeAssessment(
                ackNo: widget.ackNo,
                applicationFile: _selectedFile!,
              ),
        responseCode: (r) => r.responseCode,
        propertyId: widget.propertyId,
        mobileNo: widget.mobileNo,
      );

      // debugPrint('[DocUpload] finalize response -> success=${response.success}, mounted=$mounted');
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (response.success != true) {
        _showSnackBar(response.message ?? 'Failed to finalize. Please try again.');
        return;
      }

      // debugPrint('[DocUpload] finalize succeeded -> showing success view.');
      setState(() {
        _isSuccess = true;
        _successMessage = response.message;
      });
    } catch (e) {
      // debugPrint('[DocUpload] _handleSubmit error -> $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar(
        ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to submit document. Please try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = widget.isReassessment ? 3 : 4;
    final currentStep = totalSteps;

    return PopScope(
      canPop: _isSuccess,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await handleAssessmentBack(context);
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: !_isSuccess,
          leading: _isSuccess
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor, size: 20),
                  onPressed: () => handleAssessmentBack(context),
                ),
          title: Text(
            widget.isReassessment ? 'Finalize Reassessment' : 'Finalize Assessment',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
          bottom: _isSuccess
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(38),
                  child: AssessmentProgressBar(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                  ),
                ),
        ),
        body: _isSuccess ? _buildSuccessView() : _buildUploadForm(),
      ),
      ),
    );
  }

  Widget _buildUploadForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _softPrimaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ack No: ${widget.ackNo}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload the supporting document to complete your ${widget.isReassessment ? 'reassessment' : 'assessment'} application.',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Supporting Document',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF333333)),
          ),
          const SizedBox(height: 6),
          Text(
            'Only JPEG images are supported. Maximum file size 200 KB.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _showImageSourceSheet,
            child: _selectedFile == null
                ? DottedUploadBox(primaryColor: _primaryColor)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Image.file(
                          _selectedFile!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedFile = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showImageSourceSheet,
              icon: const Icon(Icons.refresh_rounded, color: _primaryColor, size: 18),
              label: Text(
                'Replace Document',
                style: GoogleFonts.poppins(fontSize: 13, color: _primaryColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      'Submit & Finalize',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _softPrimaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isReassessment ? 'Reassessment Submitted' : 'Assessment Submitted',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF333333)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _successMessage ?? 'Your application has been submitted successfully.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DottedUploadBox extends StatelessWidget {
  final Color primaryColor;

  const DottedUploadBox({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined, color: primaryColor, size: 36),
          const SizedBox(height: 10),
          Text(
            'Tap to attach document',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
