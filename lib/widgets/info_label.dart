import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A field label row with a tappable ⓘ icon that shows a help dialog.
class InfoLabel extends StatelessWidget {
  final String label;
  final String helpTitle;
  final String helpMessage;

  const InfoLabel({
    super.key,
    required this.label,
    required this.helpTitle,
    required this.helpMessage,
  });

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFE67514), size: 20),
            const SizedBox(width: 8),
            Text(
              helpTitle,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          helpMessage,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: const Color(0xFFE67514),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _showHelp(context),
          child: const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFFE67514),
          ),
        ),
      ],
    );
  }
}
