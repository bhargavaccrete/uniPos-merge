import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../util/common/app_responsive.dart';
import '../../componets/Button.dart';

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
    return Container(
      height: AppResponsive.height(context, 0.06),
      decoration: BoxDecoration(
        border: Border.all(width: 0.5, color: Colors.black38),
      ),
      child: CommonButton(
        height: AppResponsive.height(context, 0.05),
        bgcolor: Colors.transparent,
        bordercolor: Colors.black12,
        bordercircular: 0,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedCategoryName ?? 'Select Category',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
                ),
              ),
              const Icon(Icons.arrow_forward_ios)
            ],
          ),
        ),
      ),
    );
  }
}
