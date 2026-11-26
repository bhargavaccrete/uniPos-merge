import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// The stock-adjustment reason picker — tinted chips in the dialog's accent
/// (green to add, red to remove). Shared by Manage Inventory and Low Stock so
/// both stock dialogs look and read the same. Presentational only.
class StockReasonChips extends StatelessWidget {
  final List<String> reasons;
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  const StockReasonChips({
    super.key,
    required this.reasons,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in reasons) _chip(context, r, r == selected),
      ],
    );
  }

  Widget _chip(BuildContext context, String reason, bool isSelected) {
    return InkWell(
      onTap: () => onSelected(reason),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected ? accent : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 15, color: accent),
              const SizedBox(width: 5),
            ],
            Text(
              reason,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? accent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
