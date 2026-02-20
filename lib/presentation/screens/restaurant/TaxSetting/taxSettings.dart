import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/presentation/screens/restaurant/TaxSetting/addMultipleTax.dart';
import 'package:unipos/util/color.dart';

import '../../../widget/componets/restaurant/componets/drawermanage.dart';

//main screeen of the texes
class taxSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Tax Settings',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: isTablet ? 22 : 20,
                    color: AppColors.primary,
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 28 : 20),
          child: Column(
            children: [
              // Info Card
              Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calculate_rounded,
                        size: isTablet ? 60 : 50,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: isTablet ? 24 : 20),
                    Text(
                      'Tax Configuration',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 24 : 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Configure and manage your tax settings',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 15 : 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isTablet ? 32 : 24),

             /* // Tax Registration Card
              _buildOptionCard(
                context: context,
                icon: Icons.receipt_long_rounded,
                title: 'Tax Registration',
                description: 'Add your business tax name and registration number',
                color: Colors.blue,
                isTablet: isTablet,
                onTap: () {
                  Navigator.pushNamed(context, RouteNames.restaurantTaxRegistration);
                },
              ),*/

              SizedBox(height: isTablet ? 16 : 12),

              // Multiple Tax Card
              _buildOptionCard(
                context: context,
                icon: Icons.add_chart_rounded,
                title: 'Manage Taxes',
                description: 'Create and apply multiple tax rates to your items',
                color: Colors.green,
                isTablet: isTablet,
                onTap: () {
                  // Navigator.of(context).push(
                  //   MaterialPageRoute(builder: (context) => Addtax()),
                  // );
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 14 : 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: isTablet ? 32 : 28,
                    color: color,
                  ),
                ),
                SizedBox(width: isTablet ? 18 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 17 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 13 : 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: isTablet ? 20 : 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
