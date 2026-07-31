import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Presentation helpers shared by the water & sewerage connection list and
/// details screens.
class WaterConnectionUi {
  WaterConnectionUi._();

  static const Color primaryColor = Color(0xFFE67514);
  static const Color textColor = Color(0xFF333333);
  static const Color backgroundColor = Color(0xFFF8F9FB);

  static const Color _submitted = Color(0xFF2563EB);
  static const Color _approved = Color(0xFF1E9E5A);
  static const Color _rejected = Color(0xFFD92D20);
  static const Color _pending = primaryColor;
  static const Color _unknown = Color(0xFF667085);

  /// Backend statuses are upper-snake-case (e.g. `SUBMITTED`, `IN_PROGRESS`).
  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUBMITTED':
        return _submitted;
      case 'APPROVED':
      case 'COMPLETED':
      case 'CONNECTED':
        return _approved;
      case 'REJECTED':
      case 'CANCELLED':
        return _rejected;
      case 'PENDING':
      case 'IN_PROGRESS':
      case 'UNDER_REVIEW':
        return _pending;
      default:
        return _unknown;
    }
  }

  static IconData statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'SUBMITTED':
        return Icons.task_alt_rounded;
      case 'APPROVED':
      case 'COMPLETED':
      case 'CONNECTED':
        return Icons.check_circle_rounded;
      case 'REJECTED':
      case 'CANCELLED':
        return Icons.cancel_rounded;
      case 'PENDING':
      case 'IN_PROGRESS':
      case 'UNDER_REVIEW':
        return Icons.hourglass_bottom_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  /// `IN_PROGRESS` -> `In Progress`
  static String statusLabel(String status) {
    if (status.trim().isEmpty) return 'Unknown';
    return status
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  static Widget statusChip(String status, {bool compact = true}) {
    final color = statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Text(
            statusLabel(status),
            style: GoogleFonts.poppins(
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// `2026-07-30 18:38:13` -> `30 Jul 2026, 06:38 PM`. Unparseable values are
  /// returned unchanged so nothing silently disappears from the UI.
  static String formatDateTime(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw.trim().isEmpty ? '-' : raw.trim();
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
  }

  static String formatDate(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw.trim().isEmpty ? '-' : raw.trim();
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  /// Property proof values arrive as backend codes (e.g. `SALE_DEED`).
  static String prettify(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    if (!trimmed.contains('_')) return trimmed;
    return statusLabel(trimmed);
  }
}
