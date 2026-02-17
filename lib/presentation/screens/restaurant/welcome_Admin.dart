import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/util/color.dart';
import '../../../core/routes/routes_name.dart';
import '../../../domain/services/common/notification_service.dart';
import '../../../domain/services/common/start_of_day_backup_prompt.dart';
import '../../../domain/services/restaurant/day_management_service.dart';
import '../../widget/componets/restaurant/componets/drawermanage.dart';

class AdminWelcome extends StatefulWidget {
  const AdminWelcome({super.key});

  @override
  State<AdminWelcome> createState() => _AdminWelcomeState();
}

class _AdminWelcomeState extends State<AdminWelcome> {
  @override
  void initState() {
    super.initState();
    _checkDayStarted();
  }

  Future<void> _checkDayStarted() async {
    final isDayStarted = await DayManagementService.isDayStarted();
    if (!isDayStarted && mounted) {
      final balance = await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildOpeningBalanceDialog(),
      );

      if (balance != null) {
        // Save the opening balance to mark the day as started
        await DayManagementService.setOpeningBalance(balance);

        // Ask about backup right after day is started
        if (mounted) await StartOfDayBackupPrompt.show(context);

        if (mounted) {
          NotificationService.instance.showSuccess(
            'Day started with opening balance: Rs. ${balance.toStringAsFixed(2)}',
            // style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          );


        //   ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Row(
        //       children: [
        //         Icon(Icons.check_circle, color: Colors.white),
        //         SizedBox(width: 12),
        //         Text(
        //           'Day started with opening balance: Rs. ${balance.toStringAsFixed(2)}',
        //           style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        //         ),
        //       ],
        //     ),
        //     backgroundColor: Colors.green,
        //     behavior: SnackBarBehavior.floating,
        //   ),
        // );
        }
      }
    }
  }

  Widget _buildOpeningBalanceDialog() {
    final controller = TextEditingController();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.play_circle_rounded,
                    size: 28,
                    color: Colors.green,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Start Day',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter opening balance to start the day',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    prefixText: 'Rs. ',
                    prefixStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 0.0),
          child: Text(
            'Skip',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final balance = double.tryParse(controller.text) ?? 0;
            Navigator.pop(context, balance);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Start Day',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1200;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: DrawerManage(islogout: true, isDelete: false, issync: false),
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
                  Builder(
                    builder: (context) {
                      return GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.menu, color: AppColors.white, size: 24),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Orange Restaurant',
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

          SizedBox(height: 8),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
      /*            Container(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 16 : 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.waving_hand_rounded,
                            size: isTablet ? 32 : 28,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome Back!',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 20 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ready to manage your restaurant',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 14 : 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),*/

                  SizedBox(height: isTablet ? 24 : 20),
                  // Menu Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int columns = 2;
                      if (isDesktop) {
                        columns = 4;
                      } else if (isTablet) {
                        columns = 3;
                      }

                      return GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: columns,
                        crossAxisSpacing: isTablet ? 16 : 12,
                        mainAxisSpacing: isTablet ? 16 : 12,
                        childAspectRatio: isTablet ? 1.3 : 1.2,
                        children: [
                          _buildMenuCard(
                            context: context,
                            icon: Icons.shopping_cart_rounded,
                            title: 'Start Order',
                            color: Colors.blue,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantStartOrder),
                            isTablet: isTablet,
                          ),
                          _buildMenuCard(
                            context: context,
                            icon: Icons.restaurant_menu_rounded,
                            title: 'Manage Menu',
                            color: Colors.purple,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantManageMenu),
                            isTablet: isTablet,
                          ),
                          _buildMenuCard(
                            context: context,
                            icon: Icons.people_rounded,
                            title: 'Manage Staff',
                            color: Colors.teal,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantStaff),
                            isTablet: isTablet,
                          ),
                          _buildMenuCard(
                            context: context,
                            icon: Icons.person_outline_rounded,
                            title: 'Customers',
                            color: Colors.indigo,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantCustomers),
                            isTablet: isTablet,
                          ),
                          _buildMenuCard(
                            context: context,
                            icon: Icons.bar_chart_rounded,
                            title: 'Reports',
                            color: Colors.orange,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantReports),
                            isTablet: isTablet,
                          ),
                          _buildMenuCard(
                            context: context,
                            icon: Icons.receipt_long_rounded,
                            title: 'Tax Settings',
                            color: Colors.green,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantTaxSettings),
                            isTablet: isTablet,
                          ),

                          _buildMenuCard(
                            context: context,
                            icon: Icons.account_balance_wallet_rounded,

                            title: 'Expenses',
                            color: Colors.red,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantExpenses),
                            isTablet: isTablet,
                          ),
                          _buildMenuCard(
                            context: context,
                            icon: Icons.inventory_2_rounded,
                            title: 'Inventory',
                            color: Colors.amber,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantInventory),
                            isTablet: isTablet,
                          ),
                          _buildMenuCard(
                            context: context,
                            icon: Icons.settings_rounded,
                            title: 'Settings',
                            color: Colors.blueGrey,
                            onTap: () => Navigator.pushNamed(context, RouteNames.restaurantSettings),
                            isTablet: isTablet,
                          ),
                          _buildMenuCard(
                            context: context,
                            icon: Icons.logout_rounded,
                            title: 'Logout',
                            color: Colors.red.shade700,
                            onTap: () => _showLogoutDialog(context),
                            isTablet: isTablet,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.divider,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: isTablet ? 32 : 28,
                  color: color,
                ),
              ),
              SizedBox(height: isTablet ? 12 : 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
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