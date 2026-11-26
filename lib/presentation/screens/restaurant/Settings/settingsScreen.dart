import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/presentation/screens/common/backup/backup_restore_dialog.dart';
import 'package:billberrylite/presentation/screens/common/backup/backup_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/common_setting_tiles.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/day_management_settings_group.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/settings_components.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

/// Restaurant Settings.
///
/// Same section order, rows and controls as retail's Settings — both are built
/// from `componets/common/settings/`. Rows that already live elsewhere (Tax,
/// Printer, Personalization, Need Help, End of Day) navigate to their existing
/// routes; nothing is re-implemented here. Each section carries the same
/// `canAccess` key its destination route checks.
class Settingsscreen extends StatefulWidget {
  const Settingsscreen({super.key});
  @override
  State<Settingsscreen> createState() => _SettingsscreenState();
}

class _SettingsscreenState extends State<Settingsscreen> {
  bool _can(String key) => RestaurantSession.canAccess(key);

  void _push(String route) => Navigator.pushNamed(context, route);

  /// Plan-gated push, matching the dashboard tile / drawer entry for [route].
  void _pushGated(String route, String entKey, String featureName) {
    if (!PlanGuard.allowedOr(context, entKey, featureName: featureName)) {
      return;
    }
    _push(route);
  }

  Future<void> _openBackup() async {
    if (!PlanGuard.allowedOr(
      context,
      EntKeys.dataBackup,
      featureName: 'Backup & Restore',
    )) {
      return;
    }
    // BackupScreen lists local files with dart:io — Web gets the dialog.
    if (kIsWeb) {
      showBackupRestoreDialog(context);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BackupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Settings',
        titleFontSize: AppResponsive.headingFontSize(context),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppResponsive.maxContentWidth(context),
            ),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.isMobile(context)
                    ? AppResponsive.largeSpacing(context)
                    : 0,
                vertical: AppResponsive.largeSpacing(context),
              ),
              children: [
                SettingsSection(
                  title: 'Business',
                  icon: Icons.storefront_rounded,
                  children: [
                    if (_can('settings')) ...[
                      SettingsNavTile(
                        title: 'Store Information',
                        subtitle: 'Name, restaurant type, tax, address & logo',
                        icon: Icons.store_rounded,
                        color: Colors.deepPurple,
                        onTap: () => _push(RouteNames.restaurantStoreInfo),
                      ),
                      SettingsNavTile(
                        title: 'License & Subscription',
                        subtitle:
                            'Manage license key, plan, and device registration',
                        icon: Icons.verified_rounded,
                        color: AppColors.primary,
                        onTap: () => _push(RouteNames.restaurantLicensing),
                      ),
                      SettingsNavTile(
                        title: 'Usage & Limits',
                        subtitle: 'How much of each plan limit you have used',
                        icon: Icons.insights_rounded,
                        color: Colors.cyan,
                        onTap: () => _push(RouteNames.restaurantUsageLimit),
                      ),
                    ],
                  ],
                ),

                // End of Day follows 'endDay' everywhere — the route's key.
                if (_can('endDay'))
                  DayManagementSettingsSection(
                    onOpenEndOfDay: (ctx) async {
                      // Visibility follows billing, like the dashboard tile;
                      // the route itself stays open (it is the close path).
                      if (!PlanGuard.allowedOr(
                        ctx,
                        EntKeys.billing,
                        featureName: 'End of Day',
                      )) {
                        return;
                      }
                      await Navigator.pushNamed(ctx, RouteNames.restaurantEndDay);
                    },
                  ),

                SettingsSection(
                  title: 'Printing',
                  icon: Icons.print_outlined,
                  children: [
                    if (_can('settings')) ...[
                      SettingsNavTile(
                        title: 'Connect Printer',
                        subtitle: 'Pair a printer — Bluetooth · WiFi · USB',
                        icon: Icons.print_outlined,
                        color: AppColors.info,
                        onTap: () => _push(RouteNames.restaurantPrinterSettings),
                      ),
                      SettingsNavTile(
                        title: 'Receipt Layout',
                        subtitle: 'Logo, header, footer and print options',
                        icon: Icons.receipt_outlined,
                        color: const Color(0xFF673AB7),
                        onTap: () =>
                            _push(RouteNames.restaurantPrinterCustomization),
                      ),
                    ],
                  ],
                ),

                SettingsSection(
                  title: 'Billing & Payments',
                  icon: Icons.shopping_bag_outlined,
                  children: [
                    if (_can('settings')) ...[
                      SettingsNavTile(
                        title: 'Payment Methods',
                        subtitle: 'Manage accepted payment types',
                        icon: Icons.payment_rounded,
                        color: Colors.teal,
                        onTap: () => _push(RouteNames.restaurantPaymentMethods),
                      ),
                      SettingsNavTile(
                        title: 'Order Settings',
                        subtitle: 'Configure order behaviour & notifications',
                        icon: Icons.receipt_long_rounded,
                        color: Colors.orange,
                        onTap: () => _push(RouteNames.restaurantOrderSettings),
                      ),
                      const RoundOffSettingTile(),
                      const VisualKeyboardSettingTile(),
                      const RefundSettingTile(),
                      const _AutoServeTile(),
                    ],
                  ],
                ),

                SettingsSection(
                  title: 'Tax',
                  icon: Icons.percent_rounded,
                  children: [
                    if (_can('taxSettings') && TaxFeature.enabled)
                      SettingsNavTile(
                        title: 'Tax Settings',
                        subtitle: 'Tax rates, defaults and inclusive pricing',
                        icon: Icons.receipt_long,
                        color: AppColors.success,
                        onTap: () => _pushGated(
                          RouteNames.restaurantTaxSettings,
                          EntKeys.settings,
                          'Tax Settings',
                        ),
                      ),
                  ],
                ),

                SettingsSection(
                  title: 'Inventory',
                  icon: Icons.inventory_2_outlined,
                  children: [
                    if (_can('settings'))
                      ValueListenableBuilder<double>(
                        valueListenable: AppSettings.lowStockThresholdNotifier,
                        builder: (context, threshold, _) =>
                            LowStockThresholdTile(
                              value: threshold,
                              presets: const [3, 5, 10, 15, 20, 25],
                              allowDecimal: true,
                              onSelected: (v) => AppSettings
                                  .updateLowStockThreshold(v.toDouble()),
                              tip:
                                  'Tip: weight-based items (kg/gm) should set '
                                  'their own threshold on the item — this '
                                  'default suits count-based items.',
                            ),
                      ),
                  ],
                ),

                SettingsSection(
                  title: 'Display',
                  icon: Icons.palette_outlined,
                  children: [
                    if (_can('settings')) ...[
                      const CurrencySettingTile(),
                      const DecimalPrecisionSettingTile(),
                      SettingsNavTile(
                        title: 'Personalization',
                        subtitle: 'Menu layout, KOT and order display options',
                        icon: Icons.tune_rounded,
                        color: Colors.pink,
                        onTap: () => _pushGated(
                          RouteNames.restaurantCustomizationDrawer,
                          EntKeys.settings,
                          'Personalization',
                        ),
                      ),
                    ],
                  ],
                ),

                SettingsSection(
                  title: 'Account & Security',
                  icon: Icons.security_rounded,
                  children: [
                    if (_can('settings')) ...[
                      SettingsNavTile(
                        title: 'Change Admin PIN',
                        subtitle: 'Update the PIN used for admin login',
                        icon: Icons.lock_reset_rounded,
                        color: Colors.blue,
                        onTap: () => _push(RouteNames.restaurantChangePassword),
                      ),
                      const AutoLogoutSettingTile(),
                      const StaleShiftSettingTile(),
                    ],
                  ],
                ),

                SettingsSection(
                  title: 'Backup',
                  icon: Icons.backup_rounded,
                  children: [
                    if (_can('dataBackup')) ...[
                      // Password + reminder live inside BackupScreen; Web gets
                      // the dialog instead, so it keeps them here.
                      if (kIsWeb) ...[
                        const BackupPasswordSettingTile(),
                        const DailyBackupReminderTile(),
                      ],
                      SettingsNavTile(
                        title: 'Backup & Restore',
                        subtitle: 'Backups, backup password and daily reminder',
                        icon: Icons.import_export_rounded,
                        color: Colors.orange,
                        onTap: _openBackup,
                      ),
                    ],
                  ],
                ),

                // Ungated: support must stay one tap away for every role.
                SettingsSection(
                  title: 'Help & Support',
                  icon: Icons.support_agent_rounded,
                  children: [
                    SettingsNavTile(
                      title: 'Need Help?',
                      subtitle:
                          'Call or email support, and browse common questions',
                      icon: Icons.support_agent_rounded,
                      color: AppColors.info,
                      onTap: () => _push(RouteNames.restaurantNeedHelp),
                    ),
                  ],
                ),

                const SettingsSection(
                  title: 'About This Device',
                  icon: Icons.info_outline_rounded,
                  children: [DeviceIdTile()],
                ),

                // Developer tools never ship in a release build.
                if (!kReleaseMode && _can('settings'))
                  SettingsSection(
                    title: 'Developer',
                    icon: Icons.code_rounded,
                    children: [
                      SettingsNavTile(
                        title: 'Performance Test Data Generator',
                        subtitle: 'Generate sample data for load testing',
                        icon: Icons.science_rounded,
                        color: Colors.purple,
                        onTap: () =>
                            _push(RouteNames.restaurantDataGenratorScreen),
                      ),
                      SettingsNavTile(
                        title: 'Animated Splash Preview',
                        subtitle: 'Preview the animated logo splash screen',
                        icon: Icons.animation_rounded,
                        color: Colors.deepPurple,
                        onTap: () => _push(RouteNames.restaurantSplashPreview),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Restaurant-only: pay-to-complete for dine-in tables.
class _AutoServeTile extends StatelessWidget {
  const _AutoServeTile();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.settingsNotifier,
      builder: (context, _) {
        final on = AppSettings.autoServeDineInOnPayment;
        return SettingsSwitchTile(
          title: 'Auto-Serve Dine-In on Payment',
          subtitle: on
              ? 'Paying a dine-in table instantly serves & completes it'
              : 'Dine-in stays active after payment until marked Served (default)',
          icon: Icons.room_service_rounded,
          color: AppColors.primary,
          value: on,
          onChanged: (v) =>
              AppSettings.updateSetting('Auto Serve Dine In On Payment', v),
        );
      },
    );
  }
}
