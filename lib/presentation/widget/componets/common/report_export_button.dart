import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// The full-width "Export Report" button shared by every report screen.
/// Centralised so the colour and sizing can't drift per report.
class ReportExportButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const ReportExportButton({
    super.key,
    required this.onPressed,
    this.label = 'Export Report',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.file_download_outlined, size: AppResponsive.iconSize(context)),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.buttonFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            vertical: AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
