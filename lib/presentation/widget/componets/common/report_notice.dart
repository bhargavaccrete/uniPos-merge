import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// A one-line warning above a report's figures — for a condition the reader
/// needs to know about before trusting the numbers.
///
/// Promoted from the private notice in `SalesTotalsReportView`, which tells the
/// reader how many rows were dropped for an unreadable date. A second and third
/// caller (Purchase Summary and the GRN Report, for receipts with no recorded
/// invoice value) made one shared widget better than three copies.
///
/// This is for DATA QUALITY, not errors: the report rendered, the figures are
/// the best available, and the notice says what is missing from them.
class ReportNotice extends StatelessWidget {
  final String message;

  /// Defaults to a warning triangle; pass another when it reads better.
  final IconData icon;

  const ReportNotice({
    super.key,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      child: Row(
        children: [
          Icon(
            icon,
            size: AppResponsive.iconSize(context),
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
