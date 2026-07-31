import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'services/api_service.dart';
import 'utils/water_connection_ui.dart';

/// What the downloaded bytes actually are, decided from their magic number
/// rather than the file name — the backend hands out signed links without an
/// extension, and an "ID Proof" can be either a scan or a photo.
enum _DocumentFormat { pdf, image, unsupported }

/// Full-screen viewer for one uploaded water & sewerage connection document.
///
/// The bytes are pulled through the pinned HTTP client (so the signed link is
/// never handed to a WebView or an external browser) and then rendered in-app:
/// PDFs page by page, images in a zoomable canvas.
class WaterDocumentViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Shown under the title, e.g. the document type ("Aadhar Card").
  final String subtitle;

  /// Signed links live for only a few minutes. When the download fails the
  /// viewer asks for a fresh link through this callback before retrying.
  final Future<String?> Function()? refreshLink;

  const WaterDocumentViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.subtitle = '',
    this.refreshLink,
  });

  @override
  State<WaterDocumentViewerScreen> createState() =>
      _WaterDocumentViewerScreenState();
}

class _WaterDocumentViewerScreenState extends State<WaterDocumentViewerScreen> {
  static const Color _primaryColor = WaterConnectionUi.primaryColor;
  static const Color _textColor = WaterConnectionUi.textColor;

  late String _url = widget.url;

  bool _isLoading = true;
  bool _isSharing = false;
  String? _errorMessage;
  Uint8List? _bytes;
  _DocumentFormat _format = _DocumentFormat.unsupported;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refreshFirst = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (refreshFirst && widget.refreshLink != null) {
        final freshUrl = await widget.refreshLink!();
        if (!mounted) return;
        if (freshUrl != null && freshUrl.isNotEmpty) _url = freshUrl;
      }

      final bytes = await ApiService.downloadWaterConnectionDocument(_url);
      if (!mounted) return;

      final format = _detectFormat(bytes);
      setState(() {
        _bytes = bytes;
        _format = format;
        _isLoading = false;
        _errorMessage = format == _DocumentFormat.unsupported
            ? 'This file type cannot be previewed in the app. Use Share to '
                  'open it in another app.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Could not open this document. Please try again.',
        );
      });
    }
  }

  static _DocumentFormat _detectFormat(Uint8List bytes) {
    bool startsWith(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith([0x25, 0x50, 0x44, 0x46])) return _DocumentFormat.pdf; // %PDF
    if (startsWith([0xFF, 0xD8, 0xFF])) return _DocumentFormat.image; // JPEG
    if (startsWith([0x89, 0x50, 0x4E, 0x47])) return _DocumentFormat.image; // PNG
    if (startsWith([0x47, 0x49, 0x46, 0x38])) return _DocumentFormat.image; // GIF
    if (startsWith([0x42, 0x4D])) return _DocumentFormat.image; // BMP
    // WEBP is a RIFF container tagged at byte 8.
    if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
        startsWith([0x57, 0x45, 0x42, 0x50], 8)) {
      return _DocumentFormat.image;
    }
    return _DocumentFormat.unsupported;
  }

  String get _fileExtension => switch (_format) {
    _DocumentFormat.pdf => 'pdf',
    _DocumentFormat.image => _bytes != null && _bytes!.length > 3 && _bytes![0] == 0x89
        ? 'png'
        : 'jpg',
    _DocumentFormat.unsupported => 'bin',
  };

  String get _fileName {
    final safeTitle = widget.title
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${safeTitle.isEmpty ? 'document' : safeTitle}.$_fileExtension';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Writes the bytes to the cache directory and hands the file to the system
  /// share sheet — the same pattern the receipt screens use.
  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$_fileName');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: widget.title);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Could not share this document. Please try again.');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = widget.subtitle.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: _format == _DocumentFormat.image
          ? const Color(0xFF1A1A1A)
          : WaterConnectionUi.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
            if (hasSubtitle)
              Text(
                widget.subtitle.trim(),
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (_isSharing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _primaryColor,
                  ),
                ),
              ),
            )
          else if (_bytes != null)
            IconButton(
              tooltip: 'Share / Save',
              icon: const Icon(Icons.ios_share_rounded, color: _primaryColor),
              onPressed: _share,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }
    if (_errorMessage != null || _bytes == null) return _buildErrorState();

    return switch (_format) {
      _DocumentFormat.pdf => _buildPdfView(_bytes!),
      _DocumentFormat.image => _buildImageView(_bytes!),
      _DocumentFormat.unsupported => _buildErrorState(),
    };
  }

  Widget _buildPdfView(Uint8List bytes) {
    return PdfPreview(
      build: (_) => bytes,
      pdfFileName: _fileName,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: true,
      allowSharing: true,
      maxPageWidth: 900,
      loadingWidget: const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      ),
      actionBarTheme: const PdfActionBarTheme(
        backgroundColor: _primaryColor,
        iconColor: Colors.white,
      ),
      onError: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'This PDF could not be rendered. Use Share / Save to open it in '
            'another app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageView(Uint8List bytes) {
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'This image could not be displayed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Pinch to zoom · drag to pan',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white70),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final canShare = _bytes != null;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 42,
              color: _primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          canShare ? 'Preview not available' : 'Cannot open this document',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Please try again.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: canShare ? _share : () => _load(refreshFirst: true),
              icon: Icon(
                canShare ? Icons.ios_share_rounded : Icons.refresh_rounded,
                size: 18,
              ),
              label: Text(
                canShare ? 'Share / Save' : 'Retry',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
