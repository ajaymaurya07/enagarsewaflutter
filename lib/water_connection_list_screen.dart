import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'new_water_connection_screen.dart';
import 'services/api_service.dart';
import 'utils/water_connection_ui.dart';
import 'water_connection_details_screen.dart';

/// Home screen for the Water & Sewerage service: lists every connection
/// application raised from this account and offers a "New Connection" entry
/// point. Mirrors assessment_list_screen.dart.
class WaterConnectionListScreen extends StatefulWidget {
  const WaterConnectionListScreen({super.key});

  @override
  State<WaterConnectionListScreen> createState() =>
      _WaterConnectionListScreenState();
}

class _WaterConnectionListScreenState extends State<WaterConnectionListScreen> {
  static const Color _primaryColor = WaterConnectionUi.primaryColor;
  static const Color _textColor = WaterConnectionUi.textColor;

  bool _isLoading = true;
  String? _errorMessage;
  List<WaterConnectionListItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  Future<void> _fetchList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.getWaterConnectionList();
      if (!mounted) return;
      if (!response.success) {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Failed to fetch water connection applications';
        });
        return;
      }
      setState(() {
        _items = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage:
              'Unable to fetch water connection applications. Please try again.',
        );
      });
    }
  }

  Future<void> _handleNewConnection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewWaterConnectionScreen()),
    );
    if (result != null && mounted) _fetchList();
  }

  void _openDetails(WaterConnectionListItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaterConnectionDetailsScreen(
          id: item.id,
          ackNo: item.ackNo,
          applicantName: item.applicantName,
        ),
      ),
    );
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
          'Water & Sewerage',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: _fetchList,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildNewConnectionButton(),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'My Applications',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const Spacer(),
                if (!_isLoading && _errorMessage == null && _items.isNotEmpty)
                  Text(
                    '${_items.length} total',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildListContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewConnectionButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFF08B33), _primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Water & Sewerage Connection',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Apply in 4 simple steps',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _handleNewConnection,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
              label: Text(
                'Apply Now',
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_errorMessage != null) {
      return _buildMessageState(
        icon: Icons.wifi_off_rounded,
        title: 'Something went wrong',
        subtitle: _errorMessage!,
        showRetry: true,
      );
    }

    if (_items.isEmpty) {
      return _buildMessageState(
        icon: Icons.water_drop_outlined,
        title: 'No applications yet',
        subtitle:
            'Water & sewerage connection applications you submit will appear '
            'here so you can track their status.',
        showRetry: false,
      );
    }

    return Column(
      children: [
        for (final item in _items) ...[
          _buildCard(item),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: _primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          if (showRetry) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _fetchList,
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
          ],
        ],
      ),
    );
  }

  Widget _buildCard(WaterConnectionListItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(item),
        child: Container(
          decoration: BoxDecoration(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.applicantName.trim().isNotEmpty
                                ? item.applicantName.trim()
                                : 'Unknown Applicant',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ack: ${item.ackNo.isNotEmpty ? item.ackNo : '-'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    WaterConnectionUi.statusChip(item.status),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTag(
                          Icons.category_outlined,
                          item.connectionCategory,
                        ),
                        _buildTag(
                          Icons.schedule_rounded,
                          item.connectionType,
                        ),
                        _buildTag(
                          Icons.water_drop_outlined,
                          item.connectionRequirement,
                        ),
                        _buildTag(
                          Icons.straighten_rounded,
                          '${item.pipeSize} mm',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Property ID', item.propertyId),
                    _buildDetailRow('Mobile No.', item.mobileNo),
                    _buildDetailRow(
                      'Applied On',
                      WaterConnectionUi.formatDateTime(item.createdAt),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF6F0),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View Details',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: _primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            value.trim(),
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isNotEmpty ? value.trim() : '-',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
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
}
