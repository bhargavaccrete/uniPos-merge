import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../util/color.dart';

/// Button that shows selected category and opens category selector
class CategorySelectorButton extends StatelessWidget {
  final String? selectedCategoryName;
  final VoidCallback onTap;

  const CategorySelectorButton({
    super.key,
    this.selectedCategoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCategoryName != null;
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
              Icons.category_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedCategoryName ?? 'Select Category',
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