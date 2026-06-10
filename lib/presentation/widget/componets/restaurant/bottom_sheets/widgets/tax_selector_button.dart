import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../util/color.dart';

/// Button that shows the selected tax and opens the tax selector.
/// Mirrors [CategorySelectorButton] so the add-item form stays consistent.
class TaxSelectorButton extends StatelessWidget {
  /// Tax rate as a decimal (e.g. 0.18 for 18%), or null for no tax.
  final double? taxRate;
  final VoidCallback onTap;

  const TaxSelectorButton({
    super.key,
    this.taxRate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = taxRate != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(
              Icons.percent_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasSelection
                    ? 'Tax: ${(taxRate! * 100).toStringAsFixed(2)}%'
                    : 'Select Tax (optional)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: hasSelection
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
