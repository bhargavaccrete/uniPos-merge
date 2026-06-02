import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

import '../../../widget/componets/common/primary_app_bar.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';

//main screeen of the texes
class taxSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Tax Settings',
        titleFontSize: AppResponsive.headingFontSize(context),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 20.0, tablet: 28.0, desktop: 36.0)),
          child: Column(
            children: [
              // Info Card
              Container(
                padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: AppResponsive.shadowBlurRadius(context),
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calculate_rounded,
                        size: AppResponsive.getValue(context, mobile: 50.0, tablet: 60.0, desktop: 70.0),
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0, desktop: 28.0)),
                    Text(
                      'Tax Configuration',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 22.0, tablet: 24.0, desktop: 26.0),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Configure and manage your tax settings',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppResponsive.getValue(context, mobile: 24.0, tablet: 32.0, desktop: 40.0)),

              // Multiple Tax Card
              _buildOptionCard(
                context: context,
                icon: Icons.add_chart_rounded,
                title: 'Manage Taxes',
                description: 'Create and apply multiple tax rates to your items',
                color: AppColors.primary,
                isTablet: isTablet,
                onTap: () {
                  Navigator.pushNamed(context, RouteNames.restaurantAddMultipleTax);
                },
              ),
            ],
          ),
        ),
      ),
      drawer: DrawerManage(
        issync: true,
        islogout: true,
        isDelete: true,
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isTablet,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(
          color: AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          child: Padding(
            padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: AppResponsive.getValue(context, mobile: 28.0, tablet: 32.0, desktop: 36.0),
                    color: color,
                  ),
                ),
                SizedBox(width: AppResponsive.getValue(context, mobile: 14.0, tablet: 18.0, desktop: 22.0)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: AppResponsive.getValue(context, mobile: 18.0, tablet: 20.0, desktop: 22.0),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
