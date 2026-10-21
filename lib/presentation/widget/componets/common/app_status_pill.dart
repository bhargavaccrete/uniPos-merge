import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tinted status pill — one look for every document status across the app.
///
/// Each caller maps its own enum to a label + colour; this only owns the
/// shape, so a Purchase Return, a Supplier Claim and a PO all read the same.
///
/// ```dart
/// AppStatusPill(label: 'Pending', color: AppColors.warning)
/// ```
class AppStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  /// Smaller variant for dense rows (list cards, inline document links).
  final bool dense;

  final IconData? icon;

  const AppStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
