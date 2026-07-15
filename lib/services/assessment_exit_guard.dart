import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows a confirmation dialog asking whether the user wants to abandon the
/// in-progress assessment/reassessment flow. Returns true if they confirm.
Future<bool> confirmExitAssessment(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE67514), size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Close Assessment?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to close this assessment? Your progress will be lost.',
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE67514),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'Close',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Pops the whole assessment/reassessment flow off the stack, landing back
/// on the dashboard (the app's root route).
void exitAssessmentToDashboard(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Runs the confirm-then-exit sequence used by both the AppBar back button
/// and the hardware/system back gesture on assessment/reassessment screens.
Future<void> handleAssessmentBack(BuildContext context) async {
  final shouldClose = await confirmExitAssessment(context);
  if (shouldClose && context.mounted) {
    exitAssessmentToDashboard(context);
  }
}
