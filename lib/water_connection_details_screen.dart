import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/api_service.dart';
import 'utils/water_connection_ui.dart';
import 'water_document_viewer_screen.dart';

/// Which of the three uploaded documents a row refers to.
enum _DocumentKind { selfPhoto, idProof, propertyProof }

/// Read-only view of a single water & sewerage connection application,
/// including the uploaded documents behind their short-lived signed links.
class WaterConnectionDetailsScreen extends StatefulWidget {
  final String id;
  final String ackNo;

  /// Shown in the header while the details request is still in flight.
  final String applicantName;

  const WaterConnectionDetailsScreen({
    super.key,
    required this.id,
    required this.ackNo,
    this.applicantName = '',
  });

  @override
  State<WaterConnectionDetailsScreen> createState() =>
      _WaterConnectionDetailsScreenState();
}

class _WaterConnectionDetailsScreenState
    extends State<WaterConnectionDetailsScreen> {
  static const Color _primaryColor = WaterConnectionUi.primaryColor;
  static const Color _textColor = WaterConnectionUi.textColor;

  bool _isLoading = true;
  String? _errorMessage;
  WaterConnectionDetails? _details;

  /// Set while a document is being downloaded, so only that row spins.
  _DocumentKind? _openingDocument;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final response = await ApiService.getWaterConnectionDetails(
        id: widget.id,
        ackNo: widget.ackNo,
      );
      if (!mounted) return;
      if (!response.success || response.data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Failed to fetch application details';
        });
        return;
      }
      setState(() {
        _details = response.data;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage:
              'Unable to fetch application details. Please try again.',
        );
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  WaterConnectionDocument? _document(_DocumentKind kind) {
    final details = _details;
    if (details == null) return null;
    return switch (kind) {
      _DocumentKind.selfPhoto => details.selfPhoto,
      _DocumentKind.idProof => details.idProofDocument,
      _DocumentKind.propertyProof => details.propertyProofDocument,
    };
  }

  /// Opens a document in the in-app viewer. Signed links live for only a few
  /// minutes, so an expired one is swapped for a fresh link by re-fetching the
  /// details first — and the viewer can ask for another one if its download
  /// still fails.
  Future<void> _openDocument(
    _DocumentKind kind, {
    required String title,
    required String subtitle,
  }) async {
    if (_openingDocument != null) return;
    setState(() => _openingDocument = kind);

    var document = _document(kind);
    if (document != null && document.isExpired) {
      await _fetchDetails(silent: true);
      if (!mounted) return;
      document = _document(kind);
    }

    if (!mounted) return;
    setState(() => _openingDocument = null);

    if (document == null) {
      _showSnackBar('This document is not available.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaterDocumentViewerScreen(
          url: document!.url,
          title: title,
          subtitle: subtitle,
          refreshLink: () async {
            await _fetchDetails(silent: true);
            return _document(kind)?.url;
          },
        ),
      ),
    );
  }

  void _copyAckNo() {
    Clipboard.setData(ClipboardData(text: widget.ackNo));
    _showSnackBar('Acknowledgement number copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaterConnectionUi.backgroundColor,
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
        title: Text(
          'Application Details',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: _fetchDetails,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (_errorMessage != null || _details == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Application details are not available.',
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
                onPressed: _fetchDetails,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Retry',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
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

    final details = _details!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildHeaderCard(details),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.person_outline_rounded,
          title: 'Applicant Details',
          rows: [
            ('Applicant Name', details.applicantName),
            ('Relation', details.relationType),
            ('Father/Husband Name', details.fatherHusbandName),
            ('Mobile No.', details.mobileNo),
            ('Property ID', details.propertyId),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.water_drop_outlined,
          title: 'Connection Details',
          rows: [
            ('Connection Type', details.connectionType),
            ('Connection Required', details.connectionRequirement),
            ('Connection Category', details.connectionCategory),
            ('Plot Area', _formatPlotArea(details.plotArea)),
            ('Pipe Size', _formatPipeSize(details.pipeSize)),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.home_outlined,
          title: 'Address of New Connection',
          rows: [
            ('Plot/House No.', details.newPlotNo),
            ('Street/Road', details.newStreet),
            ('Landmark', details.newLandmark),
            ('Zone ID', details.newZoneId),
            ('Ward ID', details.newWardId),
            ('Mohalla ID', details.newMohallaId),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.markunread_mailbox_outlined,
          title: 'Correspondence Address',
          rows: [
            ('Plot/House No.', details.corrPlotNo),
            ('Street/Road', details.corrStreet),
            ('Landmark', details.corrLandmark),
            ('Zone ID', details.corrZoneId),
            ('Ward ID', details.corrWardId),
            ('Mohalla ID', details.corrMohallaId),
          ],
        ),
        const SizedBox(height: 16),
        _buildDocumentsCard(details),
      ],
    );
  }

  String _formatPlotArea(String plotArea) {
    final parsed = double.tryParse(plotArea);
    if (parsed == null) return plotArea;
    // The backend stores 2 decimals ("1000.00"); drop them when they add nothing.
    final trimmed = parsed == parsed.roundToDouble()
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(2);
    return '$trimmed sq. m';
  }

  String _formatPipeSize(String pipeSize) =>
      pipeSize.trim().isEmpty ? '-' : '${pipeSize.trim()} mm';

  Widget _buildHeaderCard(WaterConnectionDetails details) {
    final hasResponseMessage = details.responseMessage.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acknowledgement No.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            details.ackNo.isNotEmpty ? details.ackNo : '-',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _copyAckNo,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              WaterConnectionUi.statusChip(details.status, compact: false),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStamp(
                  Icons.event_available_outlined,
                  'Applied On',
                  WaterConnectionUi.formatDateTime(details.createdAt),
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _buildStamp(
                  Icons.update_rounded,
                  'Last Updated',
                  WaterConnectionUi.formatDateTime(details.updatedAt),
                ),
              ),
            ],
          ),
          if (hasResponseMessage) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: WaterConnectionUi.statusColor(
                  details.status,
                ).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: WaterConnectionUi.statusColor(details.status),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      details.responseMessage.trim(),
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: _textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStamp(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<(String, String)> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(icon, title),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                for (final (label, value) in rows) _buildInfoRow(label, value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isNotEmpty ? value.trim() : '-',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard(WaterConnectionDetails details) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.folder_open_rounded, 'Uploaded Documents'),
          const Divider(height: 1),
          _buildDocumentRow(
            kind: _DocumentKind.idProof,
            icon: Icons.badge_outlined,
            iconColor: const Color(0xFFD92D20),
            title: 'ID Proof',
            subtitle: WaterConnectionUi.prettify(details.idProofType),
            onTap: () => _openDocument(
              _DocumentKind.idProof,
              title: 'ID Proof',
              subtitle: WaterConnectionUi.prettify(details.idProofType),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildDocumentRow(
            kind: _DocumentKind.propertyProof,
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF7A5AF8),
            title: 'Property Proof',
            subtitle: WaterConnectionUi.prettify(details.propertyProofType),
            onTap: () => _openDocument(
              _DocumentKind.propertyProof,
              title: 'Property Proof',
              subtitle: WaterConnectionUi.prettify(details.propertyProofType),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildDocumentRow(
            kind: _DocumentKind.selfPhoto,
            icon: Icons.image_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Self Photo',
            subtitle: 'Passport size photograph',
            onTap: () => _openDocument(
              _DocumentKind.selfPhoto,
              title: 'Self Photo',
              subtitle: 'Passport size photograph',
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Document links are valid for a few minutes and are refreshed '
              'automatically when you open one.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow({
    required _DocumentKind kind,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isAvailable = _document(kind) != null;
    final isBusy = _openingDocument == kind;

    return InkWell(
      onTap: isAvailable && _openingDocument == null ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isAvailable ? subtitle : 'Not uploaded',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isBusy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: _primaryColor,
                ),
              )
            else if (isAvailable)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: _primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'View',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
