import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';

/// Shared empty-state placeholder — use anywhere a list/search/screen has
/// nothing to show, instead of leaving a blank area or hand-rolling a one-off.
///
/// ```dart
/// const AppEmptyState(
///   icon: Icons.search_off_rounded,
///   title: 'No items found',
///   message: 'Try a different search term.',
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  /// Optional call-to-action (e.g. an "Add Item" button) shown below the text.
  final Widget? action;

  /// Compact variant — smaller icon/spacing for inline/embedded use.
  final bool dense;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = dense ? 64.0 : 88.0;
    final iconSize = dense ? 32.0 : 44.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(dense ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: iconSize,
                  color: AppColors.primary.withValues(alpha: 0.7)),
            ),
            SizedBox(height: dense ? 12 : 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: dense ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: dense ? 12 : 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: dense ? 16 : 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
