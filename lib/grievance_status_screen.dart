import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'grievance_status_details_screen.dart';
import 'tour_guides/grievance_status_tour.dart';

class GrievanceStatusScreen extends StatefulWidget {
  const GrievanceStatusScreen({super.key});

  @override
  State<GrievanceStatusScreen> createState() => _GrievanceStatusScreenState();
}

class _GrievanceStatusScreenState extends State<GrievanceStatusScreen> {
  late Future<GrievanceDetailsResponse> _grievanceFuture;
  final GlobalKey _firstGrievanceCardKey = GlobalKey();
  final GlobalKey _firstStatusChipKey = GlobalKey();

  TutorialCoachMark? _tutorialCoachMark;
  bool _isTourActive = false;
  bool _hasQueuedAutoTour = false;

  @override
  void initState() {
    super.initState();
    _grievanceFuture = _fetchGrievances();
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_grievance_status') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_grievance_status', true);
      await _startTour(showUnavailableMessage: false);
    }
  }

  void _showTourSegment({required TargetFocus target, VoidCallback? onFinish}) {
    _tutorialCoachMark = GrievanceStatusTourGuide.createCoachMark(
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
      alignment: 0.2,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _showTourStep(
    List<GrievanceStatusTourStep> steps,
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

  Future<void> _startTour({bool showUnavailableMessage = true}) async {
    if (!mounted) {
      return;
    }

    if (_isTourActive) {
      return;
    }

    final steps = GrievanceStatusTourGuide.buildSteps(
      grievanceCardKey: _firstGrievanceCardKey,
      statusChipKey: _firstStatusChipKey,
    );

    if (steps.any((step) => step.keyTarget.currentContext == null)) {
      if (showUnavailableMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tour will be available once grievance records load.',
            ),
          ),
        );
      }
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

  void _openGrievanceDetails(GrievanceDetails grievance) {
    if (_isTourActive) {
      return;
    }

    if (grievance.grievanceNo != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              GrievanceStatusDetailsScreen(grievanceNo: grievance.grievanceNo!),
        ),
      );
    }
  }

  Future<GrievanceDetailsResponse> _fetchGrievances() async {
    final email = await StorageService.getEmailId();
    if (email == null || email.isEmpty) {
      throw Exception('Email not found in storage');
    }
    return ApiService.getGrievanceDetails(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Grievance Status',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
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
      body: FutureBuilder<GrievanceDetailsResponse>(
        future: _grievanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData ||
              snapshot.data?.data == null ||
              snapshot.data!.data!.isEmpty) {
            return const Center(child: Text('No grievances found.'));
          }

          final grievances = snapshot.data!.data!;

          if (!_hasQueuedAutoTour) {
            _hasQueuedAutoTour = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _autoStartTourIfFirstVisit();
              }
            });
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grievances.length,
            itemBuilder: (context, index) {
              final grievance = grievances[index];
              return _buildGrievanceCard(
                context,
                grievance,
                cardKey: index == 0 ? _firstGrievanceCardKey : null,
                statusKey: index == 0 ? _firstStatusChipKey : null,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGrievanceCard(
    BuildContext context,
    GrievanceDetails grievance, {
    Key? cardKey,
    Key? statusKey,
  }) {
    return GestureDetector(
      key: cardKey,
      onTap: () => _openGrievanceDetails(grievance),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${grievance.grievanceNo ?? "N/A"}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF0E3B90),
                  ),
                ),
                Container(
                  key: statusKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Pending',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Category', grievance.categoryName ?? 'N/A'),
            _buildInfoRow('Sub-category', grievance.subcategoryName ?? 'N/A'),
            _buildInfoRow('Date & Time', grievance.updatedAt ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
