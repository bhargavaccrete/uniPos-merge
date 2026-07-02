import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

class DrawerManage extends StatelessWidget {
  final bool islogout;

  const DrawerManage({
    super.key,
    required this.islogout,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Drawer(
      backgroundColor: AppColors.white,
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
                    'Bill Berry Lite',
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
                  if (RestaurantSession.canAccess('reports'))
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

                  // Change PIN (non-admin staff, excluding Cashier — admin
                  // resets cashier PINs in Manage Staff)
                  if (!RestaurantSession.isAdmin &&
                      RestaurantSession.staffRole != 'Cashier')
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.lock_reset_rounded,
                      title: 'Change PIN',
                      onTap: () {
                        Navigator.pop(context);
                        _showChangePinDialog(context);
                      },
                      isTablet: isTablet,
                    ),

                  // Divider before logout
                  if (islogout) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: AppColors.divider, thickness: 1),
                    ),
                  ],

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
                    color: AppColors.divider,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
                      color: isDanger ? Colors.red : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AppDialogShell(
          title: 'Change PIN',
          accent: Colors.teal,
          icon: Icons.lock_reset_rounded,
          body: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMsg != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(errorMsg!,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.red.shade700)),
                  ),
                AppTextField(
                  controller: currentPinCtrl,
                  label: 'Current PIN',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter current PIN' : null,
                ),
                SizedBox(height: 12),
                AppTextField(
                  controller: newPinCtrl,
                  label: 'New PIN (4–6 digits)',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter new PIN';
                    if (!RegExp(r'^\d{4,6}$').hasMatch(v)) return 'PIN must be 4–6 digits';
                    return null;
                  },
                ),
                SizedBox(height: 12),
                AppTextField(
                  controller: confirmPinCtrl,
                  label: 'Confirm New PIN',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your new PIN';
                    if (v != newPinCtrl.text) return 'PINs do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Update PIN',
              color: Colors.teal,
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await staffStore.loadStaff();
                final staff = staffStore.staff.where(
                  (s) => s.isActive && RestaurantAuthHelper.verifyPassword(currentPinCtrl.text.trim(), s.pinNo.trim()),
                ).firstOrNull;
                if (staff == null) {
                  setState(() => errorMsg = 'Current PIN is incorrect');
                  return;
                }
                final updated = staff.copyWith(pinNo: RestaurantAuthHelper.hashPassword(newPinCtrl.text.trim()));
                await staffStore.updateStaff(updated);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PIN changed successfully',
                          style: GoogleFonts.poppins()),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) async {
    // Capture navigator before the await — context may unmount after.
    final navigator = Navigator.of(context);
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      accent: Colors.red,
      icon: Icons.logout_rounded,
      barrierDismissible: false,
    );
    if (!ok) return;
    await _clearLoginState();
    navigator.pushNamedAndRemoveUntil(
      RouteNames.restaurantLogin,
      (route) => false,
    );
  }

  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('restaurant_is_logged_in', false);
    await RestaurantSession.clearSession();
  }
}