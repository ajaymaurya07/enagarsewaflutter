import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'apply_grievance_screen.dart';
import 'grievance_status_screen.dart';
import 'tour_guides/track_grievance_tour.dart';

class TrackGrievanceScreen extends StatefulWidget {
  const TrackGrievanceScreen({super.key});

  @override
  State<TrackGrievanceScreen> createState() => _TrackGrievanceScreenState();
}

class _TrackGrievanceScreenState extends State<TrackGrievanceScreen> {
  final GlobalKey _applyNowCardKey = GlobalKey();
  final GlobalKey _trackStatusCardKey = GlobalKey();

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
    final seen = prefs.getBool('tour_track_grievance') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_track_grievance', true);
      await _startTour();
    }
  }

  void _showTourSegment({required TargetFocus target, VoidCallback? onFinish}) {
    _tutorialCoachMark = TrackGrievanceTourGuide.createCoachMark(
      targets: [target],
      onAdvance: () => _tutorialCoachMark?.next(),
      onFinish: onFinish,
      onSkip: _handleTourSkip,
    )..show(context: context);
  }

  Future<void> _showTourStep(List<TargetFocus> targets, int index) async {
    if (!mounted || index >= targets.length) {
      _resetTourState();
      return;
    }

    _showTourSegment(
      target: targets[index],
      onFinish: () {
        _showTourStep(targets, index + 1);
      },
    );
  }

  Future<void> _startTour() async {
    if (!mounted || _isTourActive) return;

    _isTourActive = true;

    final targets = TrackGrievanceTourGuide.buildTargets(
      applyNowKey: _applyNowCardKey,
      trackStatusKey: _trackStatusCardKey,
    );

    await _showTourStep(targets, 0);
  }

  bool _handleTourSkip() {
    _resetTourState();
    return true;
  }

  void _resetTourState() {
    _isTourActive = false;
    _tutorialCoachMark = null;
  }

  void _handleOptionTap(VoidCallback onTap) {
    if (_isTourActive) {
      return;
    }

    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Track Grievance',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: colorScheme.primary),
            tooltip: 'Tour Guide',
            onPressed: _startTour,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            _buildOptionCard(
              context,
              cardKey: _applyNowCardKey,
              title: 'Apply Now',
              subtext: 'Start a new request',
              icon: Icons.add_task_rounded,
              color: colorScheme.primary,
              onTap: () {
                _handleOptionTap(() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApplyGrievanceScreen(),
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 14),
            _buildOptionCard(
              context,
              cardKey: _trackStatusCardKey,
              title: 'Track Status',
              subtext: 'Know your request status',
              icon: Icons.track_changes_rounded,
              color: colorScheme.secondary,
              onTap: () {
                _handleOptionTap(() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GrievanceStatusScreen(),
                    ),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    Key? cardKey,
    required String title,
    required String subtext,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      key: cardKey,
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtext,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
