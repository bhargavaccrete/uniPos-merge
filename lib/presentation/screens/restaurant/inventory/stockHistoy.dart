import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/images.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';

class StockHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: DrawerManage(
        islogout: true,
        isDelete: true,
        issync: false,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back, color: AppColors.white, size: 24),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock History',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'View all stock transactions',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isTablet ? 10 : 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      size: isTablet ? 22 : 20,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Back to Inventory Button
          Container(
            color: AppColors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.inventory_rounded, size: isTablet ? 20 : 18),
                label: Text(
                  'Back to Manage Inventory',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 8),

          // Empty State
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 24 : 20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMedium,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: isTablet ? 64 : 56,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No Stock History Found',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Stock transactions will appear here',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 16 : 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.blue.shade700,
                          size: isTablet ? 22 : 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Add or remove stock to create history',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
