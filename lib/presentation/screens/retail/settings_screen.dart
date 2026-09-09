import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/domain/services/retail/stock_alert_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:billberrylite/presentation/screens/retail/backup_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings/invoice_numbering_screen.dart';
import 'package:billberrylite/presentation/screens/retail/tax_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/attributes_screen.dart';
import 'package:billberrylite/presentation/screens/retail/simple_product_fields_screen.dart';
import 'package:billberrylite/presentation/screens/retail/store_info_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/need_help_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings/printer_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings/printer_connection_screen.dart';
import 'package:billberrylite/presentation/widget/restaurant/opening_balance_dialog.dart';
import 'package:billberrylite/presentation/screens/retail/eod_screen.dart';
import 'package:billberrylite/presentation/screens/retail/payment_methods_screen.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/presentation/screens/retail/change_password_screen.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/presentation/screens/restaurant/Settings/licensing_screen.dart';

/// Display name and version shown in the About dialog.
///
/// Kept together so the two can't drift apart the way the name did — this
/// screen still said 'rPOS' after the rename. Version tracks `pubspec.yaml`.

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Key to rebuild the FutureBuilder when returning from Start Day or End Day screens
  int _refreshKey = 0;

  void _refreshDayStatus() {
    setState(() {
      _refreshKey++;
    });
  }

  /// Read-only summary of the open session.
  ///
  /// Day state for the Day Management cards, read in one pass so the two cards
  /// can never disagree about whether the open session is overdue.
  Future<({bool started, bool eodPending})> _dayState() async => (
    started: await DayManagementService.isDayStarted(),
    eodPending:
        await DayManagementService.isEodStrictlyPending() ||
        await DayManagementService.hasPendingEOD(),
  );

  /// Replaces re-opening the start-day dialog. Tapping "Start Day" while a
  /// session was live routed to `startSession`, which minted a second session,
  /// moved the day-start timestamp forward — dropping the day's earlier sales
  /// out of the EOD — and reset bill numbers. Nothing here mutates state; the
  /// day is closed from End of Day.
  Future<void> _showDayInfo(BuildContext context) async {
    final startedAt = await DayManagementService.getDayStartTimestamp();
    final openingBalance = await DayManagementService.getOpeningBalance();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Day In Progress',
        subtitle: 'Close the day from End of Day to start a new one.',
        icon: Icons.wb_sunny_rounded,
        accent: AppColors.success,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dayInfoRow(
              dialogContext,
              'Started at',
              startedAt == null
                  ? '—'
                  : DateFormat('dd MMM yyyy, h:mm a').format(startedAt),
            ),
            _dayInfoRow(
              dialogContext,
              'Opening balance',
              '${CurrencyHelper.currentSymbol}${openingBalance.toStringAsFixed(2)}',
            ),
          ],
        ),
        actions: [appDialogCancelButton(dialogContext, label: 'Close')],
      ),
    );
  }

  Widget _dayInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Settings'),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        child: ListView(
          padding: AppResponsive.padding(context),
          children: [
            // Store Information Section
            if (RestaurantSession.canAccess('settings')) ...[
              _sectionHeader(context, 'BUSINESS INFORMATION'),
              _buildSettingsCard(
                context,
                icon: Icons.store,
                title: 'Store Information',
                subtitle: 'Configure store name, address, and contact details',
                iconColor: AppColors.success,
                onTap: () {
                  if (!PlanGuard.allowedOr(
                    context,
                    RetailEntKeys.settings,
                    featureName: 'Store Information',
                  )) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoreInfoSettingsScreen(),
                    ),
                  );
                },
              ),
              _buildSettingsCard(
                context,
                icon: Icons.verified_rounded,
                title: 'License & Subscription',
                subtitle: 'Manage license key, plan, and device registration',
                iconColor: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LicensingScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Data Management Section
            // Restoring a backup can overwrite the whole database.
            if (RestaurantSession.canAccess('dataBackup')) ...[
              _sectionHeader(context, 'DATA MANAGEMENT'),
              _buildSettingsCard(
                context,
                icon: Icons.backup,
                title: 'Backup & Restore',
                subtitle: 'Manage your data backups',
                iconColor: Colors.blue,
                onTap: () {
                  if (!PlanGuard.allowedOr(
                    context,
                    RetailEntKeys.dataBackup,
                    featureName: 'Backup & Restore',
                  )) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BackupScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Day Management Section
            _sectionHeader(context, 'DAY MANAGEMENT'),
            FutureBuilder<({bool started, bool eodPending})>(
              key: ValueKey(_refreshKey), // Rebuild when _refreshKey changes
              future: _dayState(),
              builder: (context, snapshot) {
                final isDayStarted = snapshot.data?.started ?? false;
                // A session left open from an earlier day reads as "in
                // progress" too, which said nothing about the fact that it is
                // OVERDUE and now blocks billing.
                final eodPending = snapshot.data?.eodPending ?? false;

                return Column(
                  children: [
                    _buildSettingsCard(
                      context,
                      icon: isDayStarted
                          ? Icons.wb_sunny_outlined
                          : Icons.wb_sunny,
                      title: !isDayStarted
                          ? 'Start Day'
                          : eodPending
                          ? 'Previous Day Still Open'
                          : 'Day In Progress',
                      subtitle: !isDayStarted
                          ? 'Set opening balance to begin operations'
                          : eodPending
                          ? 'Complete End of Day below to settle it'
                          : 'View session start time and opening balance',
                      iconColor: eodPending
                          ? AppColors.warning
                          : AppColors.success,
                      onTap: () async {
                        if (isDayStarted) {
                          // Read-only. Re-running the start flow here used to
                          // begin a SECOND session and lose the day's takings
                          // from the EOD.
                          await _showDayInfo(context);
                          return;
                        }
                        // Same opening-balance dialog restaurant uses — one
                        // amount, no denomination counting.
                        await promptStartDay(context);
                        // Refresh the day status after returning
                        _refreshDayStatus();
                      },
                    ),
                    if (isDayStarted)
                      _buildSettingsCard(
                        context,
                        icon: Icons.nights_stay,
                        title: eodPending
                            ? 'End of Day — Pending'
                            : 'End of Day',
                        subtitle: eodPending
                            ? 'Settle the previous day to resume billing'
                            : 'Close day and reconcile cash',
                        iconColor: eodPending
                            ? AppColors.warning
                            : AppColors.info,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RetailEODScreen(),
                            ),
                          );
                          // Refresh the day status after returning
                          _refreshDayStatus();
                        },
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // Printing Section — device connection first, then what goes on the
            // paper. Both use the same shared printer stack the restaurant side
            // uses (PrinterStore / ThermalPrinterService).
            if (RestaurantSession.canAccess('settings')) ...[
              _sectionHeader(context, 'PRINTING'),
              _buildSettingsCard(
                context,
                icon: Icons.print_outlined,
                title: 'Connect Printer',
                subtitle: 'Pair a thermal printer — Bluetooth · WiFi · USB',
                iconColor: AppColors.info,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const RetailPrinterConnectionScreen(),
                    ),
                  );
                },
              ),
              _buildSettingsCard(
                context,
                icon: Icons.print,
                title: 'Printer Settings',
                subtitle:
                    'Configure invoice layout, paper size, and print options',
                iconColor: const Color(0xFF673AB7),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrinterSettingsScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Product Settings Section
            // Attributes and field config change the catalogue, so they ride
            // catalogEdit rather than the generic settings key.
            if (RestaurantSession.canAccess('catalogEdit')) ...[
              _sectionHeader(context, 'PRODUCT SETTINGS'),
              _buildSettingsCard(
                context,
                icon: Icons.tune,
                title: 'Product Attributes',
                subtitle: 'Manage global attributes (Color, Size, etc.)',
                iconColor: const Color(0xFF9C27B0),
                onTap: () {
                  if (!PlanGuard.allowedOr(
                    context,
                    RetailEntKeys.catalog,
                    featureName: 'Product Attributes',
                  )) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AttributesScreen(),
                    ),
                  );
                },
              ),
              _buildSettingsCard(
                context,
                icon: Icons.checklist_rtl,
                title: 'Simple Product Fields',
                subtitle: 'Choose the fields shown on simple products',
                iconColor: const Color(0xFF3F51B5),
                onTap: () {
                  if (!PlanGuard.allowedOr(
                    context,
                    RetailEntKeys.catalog,
                    featureName: 'Simple Product Fields',
                  )) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SimpleProductFieldsScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Stock Alerts Section
            if (RestaurantSession.canAccess('settings')) ...[
              _sectionHeader(context, 'NOTIFICATIONS'),
              _buildStockAlertThresholdCard(context),

              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Display & Format Section
            if (RestaurantSession.canAccess('settings')) ...[
              _sectionHeader(context, 'DISPLAY & FORMAT'),
              _buildCurrencyCard(context),
              _buildDecimalPrecisionCard(context),

              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Billing Preferences — settings that already governed retail bills
            // but were only reachable from the RESTAURANT Personalization screen
            // (`customization_drawer.dart`), which a retail user never sees.
            // These write the same AppSettings keys, so it is one setting shown
            // in two places, not a retail copy that could drift.
            if (RestaurantSession.canAccess('settings')) ...[
              _sectionHeader(context, 'BILLING PREFERENCES'),
              _buildRoundOffCard(context),
              _buildVisualKeyboardCard(context),
              _buildRefundsCard(context),

              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Payment Settings Section
            if (RestaurantSession.canAccess('settings')) ...[
              _sectionHeader(context, 'PAYMENT SETTINGS'),
              _buildSettingsCard(
                context,
                icon: Icons.payment,
                title: 'Payment Methods',
                subtitle: 'Configure available payment options',
                iconColor: AppColors.success,
                onTap: () {
                  if (!PlanGuard.allowedOr(
                    context,
                    RetailEntKeys.settings,
                    featureName: 'Payment Methods',
                  )) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PaymentMethodsScreen(),
                    ),
                  );
                },
              ),

              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Tax Section — hidden entirely for a business that answered
            // "Not Registered" on Store Details. Same `taxEnabled` flag the setup
            // wizard uses to skip its Tax Setup step
            // (`setupWizardScreen.dart`), so a shop that never registered is not
            // offered tax configuration in either place.
            // Document numbering is NOT inside the TaxFeature gate below: a shop
            // that never registered for GST still issues numbered invoices.
            if (RestaurantSession.canAccess('taxSettings')) ...[
              _sectionHeader(context, 'INVOICE NUMBERING'),
              _buildSettingsCard(
                context,
                icon: Icons.tag,
                title: 'Invoice Numbering',
                subtitle: 'Invoice prefix and the next number in the series',
                iconColor: AppColors.info,
                onTap: () {
                  if (!PlanGuard.allowedOr(
                    context,
                    RetailEntKeys.settings,
                    featureName: 'Invoice Numbering',
                  )) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InvoiceNumberingScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            if (TaxFeature.enabled) ...[
              // Tax rates are Manager-only, matching restaurant's 'taxSettings'.
              if (RestaurantSession.canAccess('taxSettings')) ...[
                _sectionHeader(context, 'TAX SETTINGS'),
                _buildSettingsCard(
                  context,
                  icon: Icons.receipt_long,
                  title: 'Tax Settings',
                  subtitle: 'Tax rates, defaults and inclusive pricing',
                  iconColor: AppColors.success,
                  onTap: () {
                    if (!PlanGuard.allowedOr(
                      context,
                      RetailEntKeys.settings,
                      featureName: 'Tax Settings',
                    )) {
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TaxSettingsScreen(),
                      ),
                    );
                  },
                ),
                // GST Reports and EOD Reports used to live here — a reports section
                // filed under TAX SETTINGS. Both now sit in the Reports hub, which
                // is where someone looks for a report. Settings stays config only.
                SizedBox(height: AppResponsive.largeSpacing(context)),
              ],
            ],

            // Security & Account Section
            //
            // Everything here is store configuration, so the header sits inside
            // the gate — a cashier would otherwise see an empty heading. Logout
            // used to live here too; it is now a dashboard card so it is
            // reachable in one tap regardless of role.
            if (RestaurantSession.canAccess('settings')) ...[
              _sectionHeader(context, 'SECURITY & ACCOUNT'),
              _buildAutoLogoutTimeoutCard(context),
              _buildMaxSessionDurationCard(context),
              _buildSettingsCard(
                context,
                icon: Icons.lock_outline_rounded,
                title: 'Change Admin PIN',
                subtitle: 'Update your security PIN for admin access',
                iconColor: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],

            // Help & Support — deliberately outside the 'settings' gate.
            // A cashier sees almost none of the sections above; support
            // contact must still be one tap away for them.
            _sectionHeader(context, 'HELP & SUPPORT'),
            _buildSettingsCard(
              context,
              icon: Icons.support_agent_rounded,
              title: 'Need Help?',
              subtitle: 'Call or email support, and browse common questions',
              iconColor: AppColors.info,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RetailNeedHelpScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Shell for a switch-style settings row, matching [_buildSettingsCard]'s
  /// chrome so a toggle and a drill-down tile sit together cleanly.
  Widget _buildToggleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? child,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => onChanged(!value),
            leading: Container(
              padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: iconColor,
            ),
          ),
          if (child != null) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  /// Round Off — governs `roundOff` on every retail bill via
  /// `CartCalculationService`, which reads `AppSettings.roundOff` directly.
  Widget _buildRoundOffCard(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.settingsNotifier,
      builder: (context, _) {
        final enabled = AppSettings.roundOff;
        return _buildToggleCard(
          context,
          icon: Icons.calculate_outlined,
          title: 'Round Off',
          subtitle: 'Round bill totals to the nearest value',
          iconColor: AppColors.info,
          value: enabled,
          onChanged: (v) => AppSettings.updateSetting('Round Off', v),
          child: enabled ? _buildRoundOffValuePicker(context) : null,
        );
      },
    );
  }

  Widget _buildRoundOffValuePicker(BuildContext context) {
    const options = ['0.50', '1.00', '5.00', '10.00'];
    return ValueListenableBuilder<String>(
      valueListenable: AppSettings.roundOffNotifier,
      builder: (context, current, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round off to nearest',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((value) {
              final selected = current == value;
              return GestureDetector(
                onTap: () => AppSettings.updateRoundOffValue(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.info : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.info : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Visual Keyboard — every retail field is an AppTextField, which routes
  /// through the on-screen pad when this is on.
  Widget _buildVisualKeyboardCard(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.settingsNotifier,
      builder: (context, _) => _buildToggleCard(
        context,
        icon: Icons.keyboard_outlined,
        title: 'Visual Keyboard',
        subtitle: 'On-screen number pad instead of the system keyboard',
        iconColor: AppColors.primary,
        value: AppSettings.visualKeyboard,
        onChanged: (v) => AppSettings.updateSetting('Visual Keyboard', v),
      ),
    );
  }

  /// Refunds — master toggle switch & window duration for sales returns.
  Widget _buildRefundsCard(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.settingsNotifier,
      builder: (context, _) {
        final refundsOn =
            AppSettings.settingsNotifier.value["Allow Refunds"] ?? true;
        return _buildToggleCard(
          context,
          icon: Icons.undo_rounded,
          title: 'Allow Refunds',
          subtitle: refundsOn
              ? 'Refunds allowed within the configured window'
              : 'Refunds disabled — no refund option on sales',
          iconColor: Colors.deepPurple,
          value: refundsOn,
          onChanged: (val) => AppSettings.updateSetting("Allow Refunds", val),
          child: refundsOn ? _buildRefundWindowPicker(context) : null,
        );
      },
    );
  }

  Widget _buildRefundWindowPicker(BuildContext context) {
    const options = <(int, String)>[
      (30, '30 min'),
      (60, '1 hr'),
      (120, '2 hr'),
      (240, '4 hr'),
      (480, '8 hr'),
      (1440, '24 hr'),
      (0, 'No Limit'),
    ];
    return ValueListenableBuilder<int>(
      valueListenable: AppSettings.refundWindowNotifier,
      builder: (context, currentMinutes, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Refund Window (time limit for returns)',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final selected = currentMinutes == opt.$1;
              return GestureDetector(
                onTap: () => AppSettings.updateRefundWindow(opt.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.deepPurple
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? Colors.deepPurple : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    opt.$2,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Auto Logout Timeout — lock session after period of inactivity.
  Widget _buildAutoLogoutTimeoutCard(BuildContext context) {
    const options = <(int, String)>[
      (5, '5 min'),
      (10, '10 min'),
      (15, '15 min'),
      (30, '30 min'),
      (60, '1 hr'),
    ];
    return ValueListenableBuilder<int>(
      valueListenable: RestaurantSession.timeoutMinutesNotifier,
      builder: (context, current, _) => Container(
        margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(color: AppColors.divider),
        ),
        padding: AppResponsive.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                  child: Icon(
                    Icons.lock_clock_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto Logout Timeout',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lock session after period of inactivity',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            const Divider(height: 1, color: AppColors.divider),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((opt) {
                final selected = current == opt.$1;
                return GestureDetector(
                  onTap: () => RestaurantSession.setTimeoutMinutes(opt.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.orange : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? Colors.orange : AppColors.divider,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      opt.$2,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Maximum Session Duration & Stale Shift Auto Close.
  Widget _buildMaxSessionDurationCard(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.settingsNotifier,
      builder: (context, _) {
        final autoCloseOn =
            AppSettings.settingsNotifier.value["Auto Close Stale Shift"] ??
            true;
        return _buildToggleCard(
          context,
          icon: Icons.history_toggle_off_rounded,
          title: 'Auto Close Stale Shift',
          subtitle:
              'Automatically close open shift when session duration limit is reached',
          iconColor: Colors.blue,
          value: autoCloseOn,
          onChanged: (val) =>
              AppSettings.updateSetting("Auto Close Stale Shift", val),
          child: autoCloseOn ? _buildMaxSessionDurationPicker(context) : null,
        );
      },
    );
  }

  Widget _buildMaxSessionDurationPicker(BuildContext context) {
    const options = <(int, String)>[
      (12, '12 Hours'),
      (18, '18 Hours'),
      (24, '24 Hours'),
      (36, '36 Hours'),
      (48, '48 Hours'),
    ];
    return ValueListenableBuilder<int>(
      valueListenable: AppSettings.maxSessionDurationHoursNotifier,
      builder: (context, currentHours, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maximum Session Duration',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final selected = currentHours == opt.$1;
              return GestureDetector(
                onTap: () => AppSettings.updateMaxSessionDurationHours(opt.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? Colors.blue : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? Colors.blue : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    opt.$2,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlertThresholdCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () => _showThresholdDialog(context),
        leading: Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
          ),
          child: Icon(
            Icons.notifications_active,
            color: AppColors.warning,
            size: 24,
          ),
        ),
        title: Text(
          'Stock Alert Threshold',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Observer(
          builder: (_) => Text(
            'Alert when stock falls below ${stockAlertStore.threshold}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: Observer(
          builder: (_) => Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Text(
              '${stockAlertStore.threshold}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One selectable row, shared by all three pickers below.
  ///
  /// Every one of them was a hand-rolled `AlertDialog` + `Radio` + `ListTile`
  /// with slightly different behaviour — the threshold one never even closed on
  /// selection while the other two did.
  Widget _optionRow(
    BuildContext context, {
    required String label,
    String? sublabel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: AppResponsive.smallIconSize(context),
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (sublabel != null)
                        Text(
                          sublabel,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showThresholdDialog(BuildContext context) async {
    final current = stockAlertStore.threshold;
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Stock Alert Threshold',
        subtitle:
            'Alerts when stock reaches this level, unless the variant '
            'sets its own minimum.',
        icon: Icons.notifications_active_rounded,
        accent: AppColors.warning,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          // Shared list — Settings and the Stock Alerts screen used to offer
          // different options for the same stored value.
          children: StockAlertService.thresholdOptions
              .map(
                (value) => _optionRow(
                  dialogContext,
                  label: '$value units or fewer',
                  selected: value == current,
                  onTap: () => Navigator.pop(dialogContext, value),
                ),
              )
              .toList(),
        ),
        actions: [appDialogCancelButton(dialogContext)],
      ),
    );

    if (picked == null || picked == current) return;
    await stockAlertStore.setThreshold(picked);
  }

  Widget _buildCurrencyCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () => _showCurrencyDialog(context),
        leading: Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
          ),
          child: Icon(Icons.attach_money, color: AppColors.success, size: 24),
        ),
        title: Text(
          'Currency',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: ValueListenableBuilder<String>(
          valueListenable: CurrencyHelper.currencyNotifier,
          builder: (context, currencyCode, child) {
            final currency = CurrencyHelper.currencies[currencyCode];
            return Text(
              '${currency?.name ?? 'Indian Rupee'} (${currency?.symbol ?? '₹'})',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            );
          },
        ),
        trailing: ValueListenableBuilder<String>(
          valueListenable: CurrencyHelper.currencyNotifier,
          builder: (context, currencyCode, child) {
            final symbol =
                CurrencyHelper.currencies[currencyCode]?.symbol ?? '₹';
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
              ),
              child: Text(
                symbol,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCurrencyDialog(BuildContext context) async {
    final current = CurrencyHelper.currencyNotifier.value;
    final currencies = CurrencyHelper.getAllCurrencies();

    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Select Currency',
        subtitle: 'Applies to every amount shown and printed.',
        icon: Icons.attach_money_rounded,
        accent: AppColors.success,
        // The full currency list needs its own scroll — the shell sizes to its
        // body, so an unbounded Column here would overflow the dialog.
        body: SizedBox(
          height: AppResponsive.getValue(
            context,
            mobile: 320.0,
            tablet: 400.0,
            desktop: 440.0,
          ),
          child: ListView(
            children: currencies
                .map(
                  (currency) => _optionRow(
                    dialogContext,
                    label: currency.name,
                    sublabel: '${currency.code} · ${currency.symbol}',
                    selected: currency.code == current,
                    onTap: () => Navigator.pop(dialogContext, currency.code),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [appDialogCancelButton(dialogContext)],
      ),
    );

    if (picked == null || picked == current) return;
    await CurrencyHelper.setCurrency(picked);
  }

  Widget _buildDecimalPrecisionCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () => _showDecimalPrecisionDialog(context),
        leading: Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
          ),
          child: Icon(
            Icons.format_list_numbered,
            color: AppColors.info,
            size: 24,
          ),
        ),
        title: Text(
          'Decimal Precision',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: ValueListenableBuilder<int>(
          valueListenable: DecimalSettings.precisionNotifier,
          builder: (context, precision, child) {
            return Text(
              DecimalSettings.getPrecisionLabel(precision),
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            );
          },
        ),
        trailing: ValueListenableBuilder<int>(
          valueListenable: DecimalSettings.precisionNotifier,
          builder: (context, precision, child) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
              ),
              child: Text(
                '$precision',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: AppColors.info,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showDecimalPrecisionDialog(BuildContext context) async {
    final current = DecimalSettings.precisionNotifier.value;

    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Decimal Precision',
        subtitle: 'How many decimal places prices are shown to.',
        icon: Icons.format_list_numbered_rounded,
        accent: AppColors.info,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0, 1, 2, 3]
              .map(
                (precision) => _optionRow(
                  dialogContext,
                  label: DecimalSettings.getPrecisionLabel(precision),
                  selected: precision == current,
                  onTap: () => Navigator.pop(dialogContext, precision),
                ),
              )
              .toList(),
        ),
        actions: [appDialogCancelButton(dialogContext)],
      ),
    );

    if (picked == null || picked == current) return;
    await DecimalSettings.updatePrecision(picked);
  }
}
