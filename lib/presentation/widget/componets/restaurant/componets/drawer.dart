import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/main.dart' as main_app;

import '../../../../../util/images.dart';

class Drawerr extends StatefulWidget {
  // Order-screen-only action; hidden on the Dashboard.
  final bool showClearCart;
  // Items the Dashboard already shows as grid cards (Reports/Expenses/End Day).
  final bool showGridDuplicates;
  // Change PIN is shown on the Dashboard for staff.
  final bool showChangePin;

  const Drawerr({
    super.key,
    this.showClearCart = true,
    this.showGridDuplicates = true,
    this.showChangePin = false,
  });

  @override
  State<Drawerr> createState() => _DrawerrState();
}

class _DrawerrState extends State<Drawerr> {
  bool _printerExpanded = false;

  Future<void> clearCart() async {
    try {
      await cartStore.clearCart();
      if (mounted) {
        NotificationService.instance.showSuccess('Cart cleared successfully');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error clearing cart');
      }
    }
  }

  @override
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
              padding: AppResponsive.padding(context),
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
                      size: AppResponsive.getValue(context, mobile: 28, tablet: 32),
                    ),
                  ),
                  AppResponsive.verticalSpace(context, size: SpacingSize.medium),
                  Text(
                    'Bill Berry Lite',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 22, tablet: 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'POS System',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 13, tablet: 14),
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: Observer(
                builder: (context) => ListView(
                  padding: EdgeInsets.symmetric(
                    vertical: AppResponsive.getValue(context, mobile: 12, tablet: 16),
                    horizontal: AppResponsive.getValue(context, mobile: 8, tablet: 12),
                  ),
                  children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home_rounded,
                    title: 'Home',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantAdminWelcome);
                    },
                    isTablet: isTablet,
                  ),

                  if (widget.showClearCart && cartStore.isNotEmpty)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.cleaning_services_rounded,
                      title: 'Clear Cart',
                      onTap: () async {
                        Navigator.pop(context);
                        final confirmed = await showAppConfirmDialog(
                          context: context,
                          title: 'Clear Cart?',
                          message: 'Are you sure you want to clear the cart?',
                          confirmLabel: 'Clear',
                          cancelLabel: 'Cancel',
                          accent: Colors.orange,
                          icon: Icons.warning_rounded,
                        );
                        if (confirmed) {
                          await clearCart();
                          if (context.mounted) {
                            Navigator.pushNamed(context, RouteNames.restaurantStartOrder);
                          }
                        }
                      },
                      isTablet: isTablet,
                    ),

                  // Printer Settings Expandable (store config — admin/manager only).
                  // Follows billing (printing is required to operate), not settings.
                  if (RestaurantSession.canAccess('settings'))
                  _buildExpandableSection(
                    context: context,
                    icon: Icons.print_rounded,
                    title: 'Printer Settings',
                    isExpanded: _printerExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _printerExpanded = expanded;
                      });
                    },
                    children: [
                      _buildSubItem(
                        context: context,
                        icon: Icons.add_circle_outline,
                        title: 'Add Printer',
                        onTap: () {
                          if (!PlanGuard.allowedOr(context, EntKeys.billing, featureName: 'Printer Settings')) return;
                          Navigator.pop(context);
                          Navigator.pushNamed(context, RouteNames.restaurantPrinterSettings);
                        },
                        isTablet: isTablet,
                      ),

                      _buildSubItem(
                        context: context,
                        icon: Icons.tune_rounded,
                        title: 'Customize Printer',
                        onTap: () {
                          if (!PlanGuard.allowedOr(context, EntKeys.billing, featureName: 'Printer Settings')) return;
                          Navigator.pop(context);
                          Navigator.pushNamed(context, RouteNames.restaurantPrinterCustomization);
                        },
                        isTablet: isTablet,
                      ),
                    ],
                    isTablet: isTablet,
                  ),

                  if (RestaurantSession.canAccess('settings'))
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Customization',
                    onTap: () {
                      if (!PlanGuard.allowedOr(context, EntKeys.settings, featureName: 'Customization')) return;
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantCustomizationDrawer);
                    },
                    isTablet: isTablet,
                  ),

                  if (widget.showGridDuplicates) ...[
                    if (RestaurantSession.canAccess('reports'))
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.bar_chart_rounded,
                      title: 'Reports',
                      onTap: () {
                        if (!PlanGuard.allowedOr(context, EntKeys.reports, featureName: 'Reports')) return;
                        Navigator.pop(context);
                        Navigator.pushNamed(context, RouteNames.restaurantReports);
                      },
                      isTablet: isTablet,
                    ),

                    if (RestaurantSession.canAccess('expenses'))
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Expenses',
                      onTap: () {
                        if (!PlanGuard.allowedOr(context, EntKeys.expenses, featureName: 'Expenses')) return;
                        Navigator.pop(context);
                        Navigator.pushNamed(context, RouteNames.restaurantExpenses);
                      },
                      isTablet: isTablet,
                    ),

                    // End Day is always reachable (day lifecycle close path).
                    if (RestaurantSession.canAccess('cashDrawer'))
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.sunny_snowing,
                      title: 'End Day',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, RouteNames.restaurantEndDay);
                      },
                      isTablet: isTablet,
                    ),
                  ],

                  if (RestaurantSession.canAccess('settings'))
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.data_object_rounded,
                    title: 'Test Data Generator',
                    onTap: () {
                      if (!PlanGuard.allowedOr(context, EntKeys.settings, featureName: 'Settings')) return;
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantTestData);
                    },
                    isTablet: isTablet,
                    color: Colors.orange,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    title: 'Need Help?',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantNeedHelp);
                    },
                    isTablet: isTablet,
                  ),

                  // Change PIN (non-admin staff, excluding Cashier — admin
                  // resets cashier PINs in Manage Staff)
                  if (widget.showChangePin &&
                      !RestaurantSession.isAdmin &&
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

                ],
              ),
            ),
          ),

            // Footer
            Container(
              padding: AppResponsive.padding(context),
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
                    size: AppResponsive.smallIconSize(context),
                    color: AppColors.textSecondary,
                  ),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  Expanded(
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
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
    Color? color,
  }) {
    final itemColor = color ?? AppColors.primary;
    final bgColor = itemColor.withValues(alpha: 0.1);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.getValue(context, mobile: 12, tablet: 16),
              vertical: AppResponsive.getValue(context, mobile: 12, tablet: 14),
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
                    size: AppResponsive.getValue(context, mobile: 20, tablet: 22),
                    color: itemColor,
                  ),
                ),
                AppResponsive.horizontalSpace(context, size: SpacingSize.medium),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 14, tablet: 15),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
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

  Widget _buildExpandableSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isExpanded,
    required Function(bool) onExpansionChanged,
    required List<Widget> children,
    required bool isTablet,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isExpanded ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isExpanded,
            onExpansionChanged: onExpansionChanged,
            tilePadding: EdgeInsets.symmetric(
              horizontal: AppResponsive.getValue(context, mobile: 12, tablet: 16),
              vertical: AppResponsive.getValue(context, mobile: 4, tablet: 6),
            ),
            childrenPadding: EdgeInsets.only(
              left: AppResponsive.getValue(context, mobile: 20, tablet: 24),
            ),
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: AppResponsive.getValue(context, mobile: 20, tablet: 22),
                color: AppColors.primary,
              ),
            ),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue(context, mobile: 14, tablet: 15),
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildSubItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.getValue(context, mobile: 10, tablet: 12),
              vertical: AppResponsive.getValue(context, mobile: 8, tablet: 10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppResponsive.getValue(context, mobile: 16, tablet: 18),
                  color: AppColors.primary,
                ),
                AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 13, tablet: 14),
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
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

  void _showSyncDialog(BuildContext context) {
    Timer(
      Duration(seconds: 5),
      () {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );

    final syncHInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: syncHInset, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Container(
            padding: EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  AppImages.syncanimation,
                  width: AppResponsive.getValue(context, mobile: 180, tablet: 220),
                  height: AppResponsive.getValue(context, mobile: 130, tablet: 160),
                ),
                AppResponsive.verticalSpace(context, size: SpacingSize.large),
                Text(
                  'Sync in Progress...',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: AppResponsive.getValue(context, mobile: 18, tablet: 20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppResponsive.verticalSpace(context, size: SpacingSize.small),
                Text(
                  'Please wait while we update your data...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
