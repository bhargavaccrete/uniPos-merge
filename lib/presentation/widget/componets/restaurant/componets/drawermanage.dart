import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/util/color.dart';
import '../../../../screens/restaurant/welcome_Admin.dart';
import '../../../../screens/restaurant/AuthSelectionScreen.dart';
import '../../../../screens/restaurant/need help/needhelp.dart';
import '../../../../screens/retail/reports_screen.dart';

class DrawerManage extends StatelessWidget {
  final bool issync;
  final bool isDelete;
  final bool islogout;

  const DrawerManage({
    super.key,
    required this.issync,
    required this.isDelete,
    required this.islogout,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: isTablet ? 32 : 28,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'UniPOS',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 24 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Restaurant Management',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 12,
                  horizontal: isTablet ? 12 : 8,
                ),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home_rounded,
                    title: 'Home',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigator.pushReplacement(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => AdminWelcome()),
                      //
                      // );
                      
                      Navigator.pushNamed(context, RouteNames.restaurantAdminWelcome);
                    },
                    isTablet: isTablet,
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.bar_chart_rounded,
                    title: 'Reports',
                    onTap: () {

                      Navigator.pop(context);

                      Navigator.pushNamed(context, RouteNames.restaurantReports);


                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => ReportsScreen()),
                      //
                      //
                      // );
                    },
                    isTablet: isTablet,
                  ),
                  if (issync) ...[
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.sync_rounded,
                      title: 'Sync Data',
                      onTap: () {
                        Navigator.pop(context);
                        // Add sync functionality
                      },
                      isTablet: isTablet,
                    ),
                  ],
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    title: 'Need Help?',
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.pushNamed(context, RouteNames.restaurantNeedHelp);

                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => NeedhelpDrawer()),
                      // );
                    },
                    isTablet: isTablet,
                  ),

                  // Divider before danger zone
                  if (isDelete || islogout) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: Colors.grey.shade200,
                        thickness: 1,
                      ),
                    ),
                  ],

                  // Danger zone
                  if (isDelete)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete Account',
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteAccountDialog(context);
                      },
                      isTablet: isTablet,
                      isDanger: true,
                    ),
                  if (islogout)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      onTap: () => _showLogoutDialog(context),
                      isTablet: isTablet,
                      isDanger: true,
                    ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
    bool isDanger = false,
  }) {
    final color = isDanger ? Colors.red : AppColors.primary;
    final bgColor = isDanger
        ? Colors.red.withValues(alpha: 0.1)
        : AppColors.primary.withValues(alpha: 0.1);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 14 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: isTablet ? 22 : 20,
                    color: color,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.w500,
                      color: isDanger ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Account',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Add delete account logic here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Delete",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),

            // Content
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Are you sure you want to logout?',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _clearLoginState();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteNames.restaurantLogin,
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              "Logout",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('restaurant_is_logged_in', false);
  }
}