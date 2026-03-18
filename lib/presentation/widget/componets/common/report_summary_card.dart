import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

/// A compact, responsive summary card used across report screens.
/// Handles small screens by scaling down text and tightening padding.
class ReportSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const ReportSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AppResponsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 10.0, tablet: 16.0, desktop: 20.0)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 4.0 : 8.0),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1 * color.a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isMobile ? 14.0 : AppResponsive.smallIconSize(context),
                ),
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue(context, mobile: 10.0, tablet: 12.0, desktop: 13.0),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 18.0, desktop: 20.0),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue(context, mobile: 10.0, tablet: 11.0, desktop: 12.0),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}