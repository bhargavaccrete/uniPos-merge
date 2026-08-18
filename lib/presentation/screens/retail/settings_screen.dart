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
import 'package:billberrylite/presentation/screens/retail/tax_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/attributes_screen.dart';
import 'package:billberrylite/presentation/screens/retail/simple_product_fields_screen.dart';
import 'package:billberrylite/presentation/screens/retail/store_info_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings/printer_settings_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings/printer_connection_screen.dart';
import 'package:billberrylite/presentation/widget/restaurant/opening_balance_dialog.dart';
import 'package:billberrylite/presentation/screens/retail/eod_screen.dart';
import 'package:billberrylite/presentation/screens/retail/payment_methods_screen.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';

/// Display name and version shown in the About dialog.
///
/// Kept together so the two can't drift apart the way the name did — this
/// screen still said 'rPOS' after the rename. Version tracks `pubspec.yaml`.
const String _appName = 'Bill Berry Lite';
const String _appVersion = '1.0.0';

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
        child: ListView(
        padding: AppResponsive.padding(context),
        children: [
          // Store Information Section
          _sectionHeader(context, 'BUSINESS INFORMATION'),
          _buildSettingsCard(
            context,
            icon: Icons.store,
            title: 'Store Information',
            subtitle: 'Configure store name, address, and contact details',
            iconColor: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StoreInfoSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Data Management Section
          _sectionHeader(context, 'DATA MANAGEMENT'),
          _buildSettingsCard(
            context,
            icon: Icons.backup,
            title: 'Backup & Restore',
            subtitle: 'Manage your data backups',
            iconColor: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Day Management Section
          _sectionHeader(context, 'DAY MANAGEMENT'),
          FutureBuilder<bool>(
            key: ValueKey(_refreshKey), // Rebuild when _refreshKey changes
            future: DayManagementService.isDayStarted(),
            builder: (context, snapshot) {
              final isDayStarted = snapshot.data ?? false;

              return Column(
                children: [
                  _buildSettingsCard(
                    context,
                    icon: isDayStarted
                        ? Icons.wb_sunny_outlined
                        : Icons.wb_sunny,
                    title: isDayStarted ? 'Day In Progress' : 'Start Day',
                    subtitle: isDayStarted
                        ? 'View session start time and opening balance'
                        : 'Set opening balance to begin operations',
                    iconColor: AppColors.success,
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
                      title: 'End of Day',
                      subtitle: 'Close day and reconcile cash',
                      iconColor: AppColors.info,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RetailEODScreen()),
                        );
                        // Refresh the day status after returning
                        _refreshDayStatus();
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Printing Section — device connection first, then what goes on the
          // paper. Both use the same shared printer stack the restaurant side
          // uses (PrinterStore / ThermalPrinterService).
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
                        const RetailPrinterConnectionScreen()),
              );
            },
          ),
          _buildSettingsCard(
            context,
            icon: Icons.print,
            title: 'Printer Settings',
            subtitle: 'Configure invoice layout, paper size, and print options',
            iconColor: const Color(0xFF673AB7),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrinterSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Product Settings Section
          _sectionHeader(context, 'PRODUCT SETTINGS'),
          _buildSettingsCard(
            context,
            icon: Icons.tune,
            title: 'Product Attributes',
            subtitle: 'Manage global attributes (Color, Size, etc.)',
            iconColor: const Color(0xFF9C27B0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttributesScreen()),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SimpleProductFieldsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Stock Alerts Section
          _sectionHeader(context, 'NOTIFICATIONS'),
          _buildStockAlertThresholdCard(context),

          const SizedBox(height: 16),

          // Display & Format Section
          _sectionHeader(context, 'DISPLAY & FORMAT'),
          _buildCurrencyCard(context),
          _buildDecimalPrecisionCard(context),

          const SizedBox(height: 16),

          // Billing Preferences — settings that already governed retail bills
          // but were only reachable from the RESTAURANT Personalization screen
          // (`customization_drawer.dart`), which a retail user never sees.
          // These write the same AppSettings keys, so it is one setting shown
          // in two places, not a retail copy that could drift.
          _sectionHeader(context, 'BILLING PREFERENCES'),
          _buildRoundOffCard(context),
          _buildVisualKeyboardCard(context),

          const SizedBox(height: 16),

          // Payment Settings Section
          _sectionHeader(context, 'PAYMENT SETTINGS'),
          _buildSettingsCard(
            context,
            icon: Icons.payment,
            title: 'Payment Methods',
            subtitle: 'Configure available payment options',
            iconColor: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          // Tax Section — hidden entirely for a business that answered
          // "Not Registered" on Store Details. Same `taxEnabled` flag the setup
          // wizard uses to skip its Tax Setup step
          // (`setupWizardScreen.dart`), so a shop that never registered is not
          // offered tax configuration in either place.
          if (TaxFeature.enabled) ...[
            _sectionHeader(context, 'TAX SETTINGS'),
            _buildSettingsCard(
              context,
              icon: Icons.receipt_long,
              title: 'Tax Settings',
              subtitle: 'Tax rates, defaults and inclusive pricing',
              iconColor: AppColors.success,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TaxSettingsScreen()),
                );
              },
            ),
            // GST Reports and EOD Reports used to live here — a reports section
            // filed under TAX SETTINGS. Both now sit in the Reports hub, which
            // is where someone looks for a report. Settings stays config only.
            const SizedBox(height: 16),
          ],

          // App Information Section
          _sectionHeader(context, 'ABOUT'),
          _buildSettingsCard(
            context,
            icon: Icons.info_outline,
            title: 'App Information',
            subtitle: 'Version $_appVersion',
            iconColor: AppColors.textSecondary,
            onTap: () {
              showAboutDialog(
                context: context,
                // Was 'rPOS' — the app is Bill Berry Lite, and this dialog was
                // the one place still showing the pre-rename name to users.
                applicationName: _appName,
                applicationVersion: _appVersion,
                applicationIcon: const Icon(Icons.point_of_sale, size: 48),
                children: [
                  const Text(
                      'A modern Point of Sale system built with Flutter'),
                ],
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
          horizontal: 4, vertical: AppResponsive.smallSpacing(context)),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => onChanged(!value),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: iconColor,
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((value) {
              final selected = current == value;
              return GestureDetector(
                onTap: () => AppSettings.updateRoundOffValue(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        selected ? AppColors.info : AppColors.surfaceLight,
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

  Widget _buildStockAlertThresholdCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () => _showThresholdDialog(context),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.notifications_active, color: AppColors.warning, size: 24),
        ),
        title: Text(
          'Stock Alert Threshold',
          style: TextStyle(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Observer(
          builder: (_) => Text(
            'Alert when stock falls below ${stockAlertStore.threshold}',
            style: TextStyle(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: Observer(
          builder: (_) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${stockAlertStore.threshold}',
              style: TextStyle(
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
      padding: const EdgeInsets.only(bottom: 8),
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
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
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
        subtitle: 'Alerts when stock reaches this level, unless the variant '
            'sets its own minimum.',
        icon: Icons.notifications_active_rounded,
        accent: AppColors.warning,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          // Shared list — Settings and the Stock Alerts screen used to offer
          // different options for the same stored value.
          children: StockAlertService.thresholdOptions
              .map((value) => _optionRow(
                    dialogContext,
                    label: '$value units or fewer',
                    selected: value == current,
                    onTap: () => Navigator.pop(dialogContext, value),
                  ))
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () => _showCurrencyDialog(context),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.attach_money, color: AppColors.success, size: 24),
        ),
        title: Text(
          'Currency',
          style: TextStyle(
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
              style: TextStyle(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            );
          },
        ),
        trailing: ValueListenableBuilder<String>(
          valueListenable: CurrencyHelper.currencyNotifier,
          builder: (context, currencyCode, child) {
            final symbol = CurrencyHelper.currencies[currencyCode]?.symbol ?? '₹';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                symbol,
                style: TextStyle(
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
          height: AppResponsive.getValue(context,
              mobile: 320.0, tablet: 400.0, desktop: 440.0),
          child: ListView(
            children: currencies
                .map((currency) => _optionRow(
                      dialogContext,
                      label: currency.name,
                      sublabel: '${currency.code} · ${currency.symbol}',
                      selected: currency.code == current,
                      onTap: () => Navigator.pop(dialogContext, currency.code),
                    ))
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () => _showDecimalPrecisionDialog(context),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.format_list_numbered, color: AppColors.info, size: 24),
        ),
        title: Text(
          'Decimal Precision',
          style: TextStyle(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: ValueListenableBuilder<int>(
          valueListenable: DecimalSettings.precisionNotifier,
          builder: (context, precision, child) {
            return Text(
              DecimalSettings.getPrecisionLabel(precision),
              style: TextStyle(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$precision',
                style: TextStyle(
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
              .map((precision) => _optionRow(
                    dialogContext,
                    label: DecimalSettings.getPrecisionLabel(precision),
                    selected: precision == current,
                    onTap: () => Navigator.pop(dialogContext, precision),
                  ))
              .toList(),
        ),
        actions: [appDialogCancelButton(dialogContext)],
      ),
    );

    if (picked == null || picked == current) return;
    await DecimalSettings.updatePrecision(picked);
  }
}