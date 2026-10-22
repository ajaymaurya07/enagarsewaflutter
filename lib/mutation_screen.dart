import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mutation_application_detail_screen.dart';
import 'new_mutation_screen.dart';
import 'services/api_service.dart';
import 'utils/mutation_ui.dart';

/// Home screen for the Property Mutation service: lets the citizen start a
/// new mutation application, track one by acknowledgement number, or open
/// one of their submitted applications from the list below.
class MutationScreen extends StatefulWidget {
  const MutationScreen({super.key});

  @override
  State<MutationScreen> createState() => _MutationScreenState();
}

class _MutationScreenState extends State<MutationScreen> {
  static const Color _primaryColor = MutationUi.primaryColor;
  static const Color _textColor = MutationUi.textColor;

  final _ackNoController = TextEditingController();
  bool _isTracking = false;

  List<MutationListItem> _applications = const [];
  bool _isLoadingList = true;
  String? _listError;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoadingList = true;
      _listError = null;
    });
    try {
      final response = await ApiService.getMutationList();
      if (!mounted) return;
      setState(() {
        _applications = response.data;
        _listError = response.success ? null : response.message;
        _isLoadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingList = false;
      });
    }
  }

  Future<void> _openApplication(String ackNo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MutationApplicationDetailScreen(ackNo: ackNo),
      ),
    );
  }

  @override
  void dispose() {
    _ackNoController.dispose();
    super.dispose();
  }

  Future<void> _handleNewMutation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewMutationScreen()),
    );
    if (mounted) _loadApplications();
  }

  Future<void> _handleTrack() async {
    final ackNo = _ackNoController.text.trim();
    if (ackNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an Acknowledgement Number')),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isTracking = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MutationApplicationDetailScreen(ackNo: ackNo),
      ),
    );
    if (mounted) setState(() => _isTracking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MutationUi.backgroundColor,
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
          'Mutation',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: RefreshIndicator(
          color: _primaryColor,
          onRefresh: _loadApplications,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildNewMutationButton(),
              const SizedBox(height: 24),
              _buildTrackCard(),
              const SizedBox(height: 24),
              ..._buildApplicationsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewMutationButton() {
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
                  Icons.swap_horiz_rounded,
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
                      'New Mutation Application',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Transfer property ownership in 4 simple steps',
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
              onPressed: _handleNewMutation,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
              label: Text(
                'Apply Now',
                style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard() {
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Track Mutation Application',
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the acknowledgement number you received on submission to '
            'check its status.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ackNoController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
            style: GoogleFonts.poppins(fontSize: 14, color: _textColor),
            onSubmitted: (_) => _handleTrack(),
            decoration: InputDecoration(
              labelText: 'Acknowledgement Number',
              hintText: 'e.g. PM0562627001931',
              labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isTracking ? null : _handleTrack,
              icon: _isTracking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                'Track Application',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildApplicationsSection() {
    final header = Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        'My Mutation Applications',
        style: GoogleFonts.poppins(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
      ),
    );

    if (_isLoadingList) {
      return [
        header,
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: _primaryColor),
          ),
        ),
      ];
    }

    if (_listError != null && _applications.isEmpty) {
      return [
        header,
        _buildListMessage(
          icon: Icons.error_outline_rounded,
          message: _listError!,
          showRetry: true,
        ),
      ];
    }

    if (_applications.isEmpty) {
      return [
        header,
        _buildListMessage(
          icon: Icons.inbox_outlined,
          message: 'No mutation applications found',
        ),
      ];
    }

    return [
      header,
      for (final item in _applications) ...[
        _buildApplicationCard(item),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildListMessage({
    required IconData icon,
    required String message,
    bool showRetry = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (showRetry) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadApplications,
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApplicationCard(MutationListItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.ackNo.isEmpty ? null : () => _openApplication(item.ackNo),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.ackNo,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildCardRow('Property ID', item.propertyId),
                    const SizedBox(height: 2),
                    _buildCardRow('Applied on', item.applicationDate),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardRow(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          TextSpan(
            text: value.isEmpty ? '-' : value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }
}
