import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/domain/services/retail/stock_alert_service.dart';
import 'package:billberrylite/presentation/screens/common/auth/change_admin_pin_screen.dart';
import 'package:billberrylite/presentation/screens/common/backup/backup_restore_dialog.dart';
import 'package:billberrylite/presentation/screens/common/backup/backup_screen.dart';
import 'package:billberrylite/presentation/screens/common/plan/usage_limit_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/Settings/licensing_screen.dart';
import 'package:billberrylite/presentation/screens/retail/attributes_screen.dart';
import 'package:billberrylite/presentation/screens/retail/eod_screen.dart';
import 'package:billberrylite/presentation/screens/retail/need_help_screen.dart';
import 'package:billberrylite/presentation/screens/retail/payment_methods_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings/invoice_numbering_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings/printer_connection_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings/printer_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/simple_product_fields_screen.dart';
import 'package:billberrylite/presentation/screens/retail/store_info_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/tax_settings_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/common_setting_tiles.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/day_management_settings_group.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/settings_components.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// Retail Settings.
///
/// Same section order, rows and controls as restaurant's Settings — both are
/// built from `componets/common/settings/`. The hub itself is NOT gated on
/// 'settings': Day Management, Help and Device ID must stay reachable for a
/// Cashier, so each section carries its own `canAccess` key instead.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _can(String key) => RestaurantSession.canAccess(key);

  /// Plan-gated push. Returns once the pushed screen pops.
  Future<void> _open(
    Widget screen, {
    String? entKey,
    String? featureName,
  }) async {
    if (entKey != null &&
        !PlanGuard.allowedOr(context, entKey, featureName: featureName)) {
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openBackup() async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.dataBackup,
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
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Settings'),
      // MoneyScope: every figure re-renders when currency or precision changes.
      body: MoneyScope(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          child: ListView(
            padding: AppResponsive.padding(context),
            children: [
              SettingsSection(
                title: 'Business',
                icon: Icons.storefront_rounded,
                children: [
                  if (_can('settings')) ...[
                    SettingsNavTile(
                      title: 'Store Information',
                      subtitle: 'Name, store type, tax, address & logo',
                      icon: Icons.store_rounded,
                      color: Colors.deepPurple,
                      onTap: () async {
                        await _open(
                          const StoreInfoSettingsScreen(),
                          entKey: RetailEntKeys.settings,
                          featureName: 'Store Information',
                        );
                        // Tax registration can change there; the Tax section
                        // reads TaxFeature.enabled at build time.
                        if (mounted) setState(() {});
                      },
                    ),
                    SettingsNavTile(
                      title: 'License & Subscription',
                      subtitle:
                          'Manage license key, plan, and device registration',
                      icon: Icons.verified_rounded,
                      color: AppColors.primary,
                      onTap: () => _open(const LicensingScreen()),
                    ),
                    SettingsNavTile(
                      title: 'Usage & Limits',
                      subtitle: 'How much of each plan limit you have used',
                      icon: Icons.insights_rounded,
                      color: Colors.cyan,
                      onTap: () => _open(const UsageLimitScreen()),
                    ),
                  ],
                ],
              ),

              if (_can('endDay'))
                DayManagementSettingsSection(
                  onOpenEndOfDay: (ctx) => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const RetailEODScreen()),
                  ),
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
                      onTap: () => _open(const RetailPrinterConnectionScreen()),
                    ),
                    SettingsNavTile(
                      title: 'Receipt Layout',
                      subtitle: 'Invoice layout, paper size and print options',
                      icon: Icons.receipt_outlined,
                      color: const Color(0xFF673AB7),
                      onTap: () => _open(const PrinterSettingsScreen()),
                    ),
                  ],
                ],
              ),

              SettingsSection(
                title: 'Billing & Payments',
                icon: Icons.shopping_bag_outlined,
                children: [
                  if (_can('settings'))
                    SettingsNavTile(
                      title: 'Payment Methods',
                      subtitle: 'Manage accepted payment types',
                      icon: Icons.payment_rounded,
                      color: Colors.teal,
                      onTap: () => _open(
                        const PaymentMethodsScreen(),
                        entKey: RetailEntKeys.settings,
                        featureName: 'Payment Methods',
                      ),
                    ),
                  // Not tax-gated: an unregistered shop still numbers invoices.
                  if (_can('taxSettings'))
                    SettingsNavTile(
                      title: 'Invoice Numbering',
                      subtitle:
                          'Invoice prefix and the next number in the series',
                      icon: Icons.tag,
                      color: AppColors.info,
                      onTap: () => _open(
                        const InvoiceNumberingScreen(),
                        entKey: RetailEntKeys.settings,
                        featureName: 'Invoice Numbering',
                      ),
                    ),
                  if (_can('settings')) ...[
                    const RoundOffSettingTile(),
                    const VisualKeyboardSettingTile(),
                    const RefundSettingTile(),
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
                      onTap: () => _open(
                        const TaxSettingsScreen(),
                        entKey: RetailEntKeys.settings,
                        featureName: 'Tax Settings',
                      ),
                    ),
                ],
              ),

              SettingsSection(
                title: 'Inventory & Products',
                icon: Icons.inventory_2_outlined,
                children: [
                  if (_can('settings'))
                    Observer(
                      builder: (_) => LowStockThresholdTile(
                        value: stockAlertStore.threshold,
                        presets: StockAlertService.thresholdOptions,
                        allowDecimal: false,
                        onSelected: (v) =>
                            stockAlertStore.setThreshold(v.toInt()),
                        tip:
                            'A variant with its own minimum stock uses that '
                            'instead of this default.',
                      ),
                    ),
                  // Attributes and field config change the catalogue, so they
                  // ride catalogEdit rather than the generic settings key.
                  if (_can('catalogEdit')) ...[
                    SettingsNavTile(
                      title: 'Product Attributes',
                      subtitle: 'Manage global attributes (Color, Size, etc.)',
                      icon: Icons.tune,
                      color: const Color(0xFF9C27B0),
                      onTap: () => _open(
                        const AttributesScreen(),
                        entKey: RetailEntKeys.catalog,
                        featureName: 'Product Attributes',
                      ),
                    ),
                    SettingsNavTile(
                      title: 'Simple Product Fields',
                      subtitle: 'Choose the fields shown on simple products',
                      icon: Icons.checklist_rtl,
                      color: const Color(0xFF3F51B5),
                      onTap: () => _open(
                        const SimpleProductFieldsScreen(),
                        entKey: RetailEntKeys.catalog,
                        featureName: 'Simple Product Fields',
                      ),
                    ),
                  ],
                ],
              ),

              SettingsSection(
                title: 'Display',
                icon: Icons.palette_outlined,
                children: [
                  if (_can('settings')) ...[
                    const CurrencySettingTile(),
                    const DecimalPrecisionSettingTile(),
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
                      onTap: () => _open(const ChangeAdminPinScreen()),
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
                    // Password + reminder live inside BackupScreen; Web gets the
                    // dialog instead, so it keeps them here.
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
                    onTap: () => _open(const RetailNeedHelpScreen()),
                  ),
                ],
              ),

              const SettingsSection(
                title: 'About This Device',
                icon: Icons.info_outline_rounded,
                children: [DeviceIdTile()],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
