import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/util/color.dart';
import '../../../core/routes/routes_name.dart';
import '../../../domain/services/common/notification_service.dart';
import '../../../domain/services/common/start_of_day_backup_prompt.dart';
import '../../../domain/services/restaurant/day_management_service.dart';
import '../../../domain/services/retail/store_settings_service.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../../../core/di/service_locator.dart';
import '../../widget/componets/restaurant/componets/drawermanage.dart';
import '../../widget/restaurant/opening_balance_dialog.dart';

class AdminWelcome extends StatefulWidget {
  const AdminWelcome({super.key});

  @override
  State<AdminWelcome> createState() => _AdminWelcomeState();
}

class _AdminWelcomeState extends State<AdminWelcome> {
  DateTime? _lastBackPress;
  String _storeName = '';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkDayStarted();
      await _startShiftIfNeeded();
      // Always check backup prompt — has its own date guard so it's idempotent.
      // Previously only ran inside _checkDayStarted → missed returning users.
      if (mounted) await StartOfDayBackupPrompt.show(context);
    });
  }

  Future<void> _loadStoreName() async {
    final name = await StoreSettingsService().getStoreName();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _storeName = name);
    }
  }

  Future<void> _checkDayStarted() async {
    // Check if there's a pending EOD from yesterday (midnight crossed without completing EOD)
    final pendingEOD = await DayManagementService.hasPendingEOD();
    if (pendingEOD && mounted) {
      NotificationService.instance.showError(
        'Previous day was not closed! Redirecting to End of Day...',
      );
      // Auto-navigate to End Day screen so user can complete it
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await Navigator.pushNamed(context, RouteNames.restaurantEndDay);
        // After returning from End Day, re-check day status
        if (mounted) _checkDayStarted();
      }
      return;
    }

    final isDayStarted = await DayManagementService.isDayStarted();
    if (!isDayStarted && mounted) {
      final balance = await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const OpeningBalanceDialog(),
      );

      if (balance != null) {
        // Check if admin changed the pre-filled closing balance — record ADJUSTMENT
        final lastClosing = await DayManagementService.getLastClosingBalance();
        final diff = balance - lastClosing;
        if (lastClosing > 0 && diff.abs() > 0.01) {
          final byName = RestaurantSession.staffName ??
              (RestaurantSession.isAdmin ? 'Admin' : 'Staff');
          await cashMovementStore.addAdjustment(
            signedAmount: diff, // negative if admin entered less than closing
            reason: 'Opening balance modified',
            note: 'Previous closing: Rs.${lastClosing.toStringAsFixed(2)}, '
                'Opened at: Rs.${balance.toStringAsFixed(2)}',
            staffName: byName,
          );
        }

        // Save the opening balance to mark the day as started
        await DayManagementService.setOpeningBalance(balance);

        if (mounted) {
          NotificationService.instance.showSuccess(
            'Day started with opening balance: Rs. ${balance.toStringAsFixed(2)}',
            // style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          );



        }
      }
    }
  }

  Future<void> _startShiftIfNeeded() async {
    final staffId = RestaurantSession.isAdmin
        ? 'admin'
        : (RestaurantSession.staffName ?? 'staff');
    final staffName = RestaurantSession.staffName ??
        (RestaurantSession.isAdmin ? 'Admin' : 'Staff');

    // Restore from Hive in case of hot-restart
    await shiftStore.loadActiveShiftForStaff(staffId);
    if (shiftStore.hasOpenShift) {
      // Re-persist the shift ID into session so currentShiftId is always set
      await RestaurantSession.saveShiftSession(shiftStore.activeShift!.id);
      return;
    }

    final ok = await shiftStore.startShift(
      staffId: staffId,
      staffName: staffName,
    );
    if (ok && shiftStore.activeShift != null && mounted) {
      await RestaurantSession.saveShiftSession(shiftStore.activeShift!.id);
      NotificationService.instance.showSuccess('Shift started');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1200;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Press back again to exit',textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: Scaffold(
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
                          _storeName.isNotEmpty ? _storeName : 'Restaurant',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: RestaurantSession.loginTypeNotifier,
                    builder: (_, __, ___) {
                      final role = RestaurantSession.effectiveRole;
                      // final name = RestaurantSession.staffName;
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: isTablet ? 18 : 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  role,
                                  style: GoogleFonts.poppins(
                                    fontSize: isTablet ? 13 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                // if (name != null && name.isNotEmpty)
                                //   Text(
                                //     name,
                                //     style: GoogleFonts.poppins(
                                //       fontSize: isTablet ? 11 : 10,
                                //       color: AppColors.primary.withOpacity(0.7),
                                //     ),
                                //   ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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

                      final cards = _getVisibleCards(context);
                      return GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: columns,
                        crossAxisSpacing: isTablet ? 16 : 12,
                        mainAxisSpacing: isTablet ? 16 : 12,
                        childAspectRatio: isTablet ? 1.3 : 1.2,
                        children: cards.map((card) => _buildMenuCard(
                          context: context,
                          icon: card.icon,
                          title: card.title,
                          color: card.color,
                          onTap: card.onTap,
                          isTablet: isTablet,
                        )).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ), // PopScope closing
    );
  }

  // Builds the list of dashboard cards visible to the current user.
  // Permissions are defined in RestaurantSession.canAccess() in restaurant_session.dart.
  // Admin and Manager see all cards. Other roles see only what canAccess() permits.
  List<_MenuCardData> _getVisibleCards(BuildContext context) {
    final all = [
      _MenuCardData('Start Order',   Icons.shopping_cart_rounded,       Colors.blue,           'startOrder',   () => Navigator.pushNamed(context, RouteNames.restaurantStartOrder)),
      _MenuCardData('Manage Menu',   Icons.restaurant_menu_rounded,     Colors.purple,         'manageMenu',   () => Navigator.pushNamed(context, RouteNames.restaurantManageMenu)),
      _MenuCardData('Manage Staff',  Icons.people_rounded,              Colors.teal,           'manageStaff',  () => Navigator.pushNamed(context, RouteNames.restaurantStaff)),
      _MenuCardData('Customers',     Icons.person_outline_rounded,      Colors.indigo,         'customers',    () => Navigator.pushNamed(context, RouteNames.restaurantCustomers)),
      _MenuCardData('Reports',       Icons.bar_chart_rounded,           Colors.orange,         'reports',      () => Navigator.pushNamed(context, RouteNames.restaurantReports)),
      _MenuCardData('Tax Settings',  Icons.receipt_long_rounded,        Colors.green,          'taxSettings',  () => Navigator.pushNamed(context, RouteNames.restaurantTaxSettings)),
      _MenuCardData('Expenses',      Icons.account_balance_wallet_rounded, Colors.red,         'expenses',     () => Navigator.pushNamed(context, RouteNames.restaurantExpenses)),
      _MenuCardData('Inventory',     Icons.inventory_2_rounded,         Colors.amber,          'inventory',    () => Navigator.pushNamed(context, RouteNames.restaurantInventory)),
      _MenuCardData('Settings',      Icons.settings_rounded,            Colors.blueGrey,       'settings',     () => Navigator.pushNamed(context, RouteNames.restaurantSettings)),
      _MenuCardData('Cash Drawer',   Icons.point_of_sale_rounded,       const Color(0xFF00897B), 'cashDrawer', () => Navigator.pushNamed(context, RouteNames.restaurantCashDrawer)),
      _MenuCardData('Logout',        Icons.logout_rounded,              Colors.red.shade700,   'logout',       () => _showLogoutDialog(context)),
    ];
    return all.where((c) => c.permission == 'logout' || RestaurantSession.canAccess(c.permission)).toList();
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
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Gradient Header ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade700,
                      Colors.red.shade400,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'End your current session',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Are you sure you want to logout? You will need to sign in again to continue.',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
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
                              backgroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Logout',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('restaurant_is_logged_in', false);
    await RestaurantSession.clearSession();
  }
}

/// Simple data holder for a dashboard menu card.
class _MenuCardData {
  final String title;
  final IconData icon;
  final Color color;
  final String permission;
  final VoidCallback onTap;

  const _MenuCardData(this.title, this.icon, this.color, this.permission, this.onTap);
}