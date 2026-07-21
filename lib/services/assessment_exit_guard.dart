import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';

/// Shows a confirmation dialog asking whether the user wants to abandon the
/// in-progress assessment/reassessment flow. Returns true if they confirm.
Future<bool> confirmExitAssessment(BuildContext context) async {
  // Guards against a double-tap on Cancel/Close firing Navigator.pop twice
  // on the same dialog route (the second call would operate on an
  // already-popped/deactivated route).
  bool responded = false;

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
          onPressed: () {
            if (responded) return;
            responded = true;
            Navigator.pop(ctx, false);
          },
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (responded) return;
            responded = true;
            Navigator.pop(ctx, true);
          },
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
///
/// Skipped if a session-expiry teardown is already replacing the entire
/// navigator stack (see [ApiService.isHandlingSessionExpiry]) — letting both
/// run would mutate the same Navigator stack concurrently.
void exitAssessmentToDashboard(BuildContext context) {
  if (ApiService.isHandlingSessionExpiry) {
    // debugPrint('[ExitGuard] Skipping exit popUntil — session expiry teardown in progress.');
    return;
  }
  // debugPrint('[ExitGuard] exitAssessmentToDashboard -> popUntil(isFirst).');
  Navigator.of(context).popUntil((route) => route.isFirst);
  // debugPrint('[ExitGuard] popUntil(isFirst) returned.');
}

/// Runs the confirm-then-exit sequence used by both the AppBar back button
/// and the hardware/system back gesture on assessment/reassessment screens.
Future<void> handleAssessmentBack(BuildContext context) async {
  // debugPrint('[ExitGuard] handleAssessmentBack -> showing confirm dialog.');
  final shouldClose = await confirmExitAssessment(context);
  // debugPrint('[ExitGuard] confirmExitAssessment -> $shouldClose (context.mounted=${context.mounted})');
  if (shouldClose && context.mounted) {
    exitAssessmentToDashboard(context);
  }
}
