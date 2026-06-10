
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/util/color.dart';

import '../../../../domain/services/common/auto_backup_service.dart';
import '../../../../domain/services/common/device_id_service.dart';
import '../../../../domain/services/common/backup_encryption_service.dart';
import '../../../../util/common/currency_helper.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../../util/common/decimal_settings.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import '../../../widget/componets/restaurant/componets/filterButton.dart';
import '../../../../util/restaurant/restaurant_session.dart';
import '../../../widget/componets/common/app_text_field.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../widget/componets/common/primary_app_bar.dart';

class Settingsscreen extends StatefulWidget {
  const Settingsscreen({super.key});
  @override
  _settingsScreenState createState() => _settingsScreenState();
}

class _settingsScreenState extends State<Settingsscreen> {
  bool _isDecimalExpanded = false;
  bool _isCurrencyExpanded = false;
  bool _isRefundWindowExpanded = false;
  bool _isTimeoutExpanded = false;
  bool _isLowStockExpanded = false;
  final TextEditingController _customThresholdController = TextEditingController();

  bool _backupEnabled = false;
  bool _hasBackupPassword = false;
  DeviceIdResult? _deviceIdResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _customThresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await DecimalSettings.load();
    final result = await DeviceIdService.getResult();
    if (mounted) setState(() => _deviceIdResult = result);
    final backupEnabled = await AutoBackupService.isAutoBackupEnabled();
    final hasPassword = await BackupEncryptionService.hasPassword();
    setState(() {
      _backupEnabled = backupEnabled;
      _hasBackupPassword = hasPassword;
    });
  }

  Future<void> _showSetPasswordDialog({bool isChange = false}) async {
    final pwdController = TextEditingController();
    bool obscure = true;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            isChange ? 'Change Backup Password' : 'Set Backup Password',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: AppTextField(
            controller: pwdController,
            label: 'Password',
            hint: 'Enter password',
            icon: Icons.lock_outline_rounded,
            obscureText: obscure,
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setDlgState(() => obscure = !obscure),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final pwd = pwdController.text.trim();
                if (pwd.isNotEmpty) {
                  await BackupEncryptionService.setPassword(pwd);
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _hasBackupPassword = true);
                }
              },
              child: Text('Confirm',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeoutLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    return '1 hr';
  }

  String _getRefundWindowLabel(int minutes) {
    if (minutes == 0) return 'No Limit';
    if (minutes < 60) return '$minutes min';
    if (minutes == 60) return '1 hr';
    if (minutes % 60 == 0) return '${minutes ~/ 60} hr';
    return '${(minutes / 60).toStringAsFixed(1)} hr';
  }

  String _getDecimalFilter(int precision) {
    switch (precision) {
      case 0: return 'None';
      case 1: return '0.0';
      case 2: return '0.00';
      case 3: return '0.000';
      default: return '0.00';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(
          left: AppResponsive.smallSpacing(context),
          bottom: AppResponsive.smallSpacing(context)),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
          ),
          child: Icon(icon,
              size: AppResponsive.smallIconSize(context),
              color: AppColors.primary),
        ),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ]),
    );
  }

  Widget _sectionCard(BuildContext context, List<Widget> children) {
    final radius = AppResponsive.borderRadius(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(children: children),
      ),
    );
  }

  Widget _navTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.largeSpacing(context),
            vertical: AppResponsive.mediumSpacing(context)),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
            ),
            child: Icon(icon, size: AppResponsive.iconSize(context), color: color),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: AppResponsive.iconSize(context),
              color: AppColors.textSecondary.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Widget _expandableTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget expandedChild,
  }) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.largeSpacing(context),
              vertical: AppResponsive.mediumSpacing(context)),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Icon(icon, size: AppResponsive.iconSize(context), color: color),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: AppResponsive.iconSize(context),
              color: AppColors.textSecondary,
            ),
          ]),
        ),
      ),
      if (isExpanded) ...[
        Divider(height: 1, color: AppColors.divider),
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppResponsive.largeSpacing(context),
              AppResponsive.mediumSpacing(context),
              AppResponsive.largeSpacing(context),
              AppResponsive.mediumSpacing(context)),
          child: expandedChild,
        ),
      ],
    ]);
  }

  Widget _tileDivider() =>
      Divider(height: 1, color: AppColors.divider, indent: 56);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Settings',
        titleFontSize: AppResponsive.headingFontSize(context),
      ),
      drawer:
          DrawerManage(issync: false, isDelete: true, islogout: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppResponsive.maxFormWidth(context)),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.isMobile(context)
                    ? AppResponsive.largeSpacing(context)
                    : 0,
                vertical: AppResponsive.largeSpacing(context),
              ),
          children: [

            // ── 1. Account & Security ───────────────────────────────────
            _sectionHeader(context, 'Account & Security', Icons.security_rounded),
            _sectionCard(context, [
              _navTile(
                context,
                'Password Change',
                'Update your login password',
                Icons.lock_reset_rounded,
                Colors.blue,
                () => Navigator.pushNamed(
                    context, RouteNames.restaurantChangePassword),
              ),
              _tileDivider(),

              // Backup Password row
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.largeSpacing(context),
                    vertical: AppResponsive.mediumSpacing(context)),
                child: Row(children: [
                  Container(
                    padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                    decoration: BoxDecoration(
                      color: (_hasBackupPassword
                              ? Colors.green
                              : Colors.orange)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                    ),
                    child: Icon(
                      _hasBackupPassword
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: AppResponsive.iconSize(context),
                      color: _hasBackupPassword
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  SizedBox(width: AppResponsive.mediumSpacing(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Backup Password',
                            style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          _hasBackupPassword
                              ? 'Backups are password-protected'
                              : 'No password — backups are unprotected',
                          style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: _hasBackupPassword
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800),
                        ),
                      ],
                    ),
                  ),
                  if (!_hasBackupPassword)
                    _actionChip(context, 'Set', Colors.green,
                        () => _showSetPasswordDialog())
                  else ...[
                    _actionChip(context, 'Change', Colors.orange,
                        () => _showSetPasswordDialog(isChange: true)),
                    SizedBox(width: AppResponsive.smallSpacing(context) * 0.5),
                    InkWell(
                      onTap: () async {
                        await BackupEncryptionService.clearPassword();
                        setState(() => _hasBackupPassword = false);
                      },
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                      child: Container(
                        padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            size: AppResponsive.smallIconSize(context),
                            color: Colors.red),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── 2. Display ──────────────────────────────────────────────
            _sectionHeader(context, 'Display', Icons.palette_outlined),
            _sectionCard(context, [
              ValueListenableBuilder<String>(
                valueListenable: CurrencyHelper.currencyNotifier,
                builder: (context, _, __) => _expandableTile(
                  context: context,
                  title: 'Currency Symbol',
                  subtitle:
                      '${CurrencyHelper.currentSymbol}  ${CurrencyHelper.currentCurrencyCode}',
                  icon: Icons.currency_exchange_rounded,
                  color: Colors.green,
                  isExpanded: _isCurrencyExpanded,
                  onTap: () => setState(
                      () => _isCurrencyExpanded = !_isCurrencyExpanded),
                  expandedChild: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: CurrencyHelper.currencies.entries.map((e) {
                      final info = e.value;
                      final btn = '${info.symbol} ${info.code}';
                      final sel =
                          '${CurrencyHelper.currentSymbol} ${CurrencyHelper.currentCurrencyCode}';
                      return Filterbutton(
                        title: btn,
                        selectedFilter: sel,
                        onpressed: () =>
                            CurrencyHelper.setCurrency(info.code),
                      );
                    }).toList(),
                  ),
                ),
              ),
              _tileDivider(),
              ValueListenableBuilder<int>(
                valueListenable: DecimalSettings.precisionNotifier,
                builder: (context, prec, __) => _expandableTile(
                  context: context,
                  title: 'Decimal Precision',
                  subtitle:
                      'Current: ${_getDecimalFilter(prec)}',
                  icon: Icons.numbers_rounded,
                  color: Colors.indigo,
                  isExpanded: _isDecimalExpanded,
                  onTap: () => setState(
                      () => _isDecimalExpanded = !_isDecimalExpanded),
                  expandedChild: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Filterbutton(
                          title: 'None',
                          selectedFilter: _getDecimalFilter(prec),
                          onpressed: () =>
                              DecimalSettings.updatePrecision(0)),
                      Filterbutton(
                          title: '0.0',
                          selectedFilter: _getDecimalFilter(prec),
                          onpressed: () =>
                              DecimalSettings.updatePrecision(1)),
                      Filterbutton(
                          title: '0.00',
                          selectedFilter: _getDecimalFilter(prec),
                          onpressed: () =>
                              DecimalSettings.updatePrecision(2)),
                      Filterbutton(
                          title: '0.000',
                          selectedFilter: _getDecimalFilter(prec),
                          onpressed: () =>
                              DecimalSettings.updatePrecision(3)),
                    ],
                  ),
                ),
              ),
            ]),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── 3. Orders & Payments ────────────────────────────────────
            _sectionHeader(context, 'Orders & Payments', Icons.shopping_bag_outlined),
            _sectionCard(context, [
              _navTile(
                context,
                'Payment Methods',
                'Manage accepted payment types',
                Icons.payment_rounded,
                Colors.teal,
                () => Navigator.pushNamed(
                    context, RouteNames.restaurantPaymentMethods),
              ),
              _tileDivider(),
              _navTile(
                context,
                'Order Settings',
                'Configure order behaviour & notifications',
                Icons.receipt_long_rounded,
                Colors.orange,
                () => Navigator.pushNamed(
                    context, RouteNames.restaurantOrderSettings),
              ),
              _tileDivider(),
              ValueListenableBuilder<Map<String, bool>>(
                valueListenable: AppSettings.settingsNotifier,
                builder: (context, settings, ___) {
                  final refundsOn = settings["Allow Refunds"] ?? true;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: AppResponsive.largeSpacing(context),
                            vertical: AppResponsive.smallSpacing(context) * 0.5),
                        secondary: Container(
                          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                          decoration: BoxDecoration(
                            color: (refundsOn ? Colors.deepPurple : AppColors.textSecondary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                          ),
                          child: Icon(Icons.undo_rounded,
                              size: AppResponsive.iconSize(context),
                              color: refundsOn ? Colors.deepPurple : AppColors.textSecondary),
                        ),
                        title: Text('Allow Refunds',
                            style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                        subtitle: Text(
                          refundsOn
                              ? 'Refunds allowed within the window below'
                              : 'Refunds are off — no refund option appears on orders',
                          style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary),
                        ),
                        value: refundsOn,
                        activeColor: AppColors.primary,
                        onChanged: (val) =>
                            AppSettings.updateSetting("Allow Refunds", val),
                      ),
                      if (refundsOn) ...[
                        _tileDivider(),
                        ValueListenableBuilder<int>(
                          valueListenable: AppSettings.refundWindowNotifier,
                          builder: (context, win, __) => _expandableTile(
                            context: context,
                            title: 'Refund Window',
                            subtitle: 'Current: ${_getRefundWindowLabel(win)}',
                            icon: Icons.undo_rounded,
                            color: Colors.deepPurple,
                            isExpanded: _isRefundWindowExpanded,
                            onTap: () => setState(() =>
                                _isRefundWindowExpanded =
                                    !_isRefundWindowExpanded),
                            expandedChild: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                Filterbutton(
                                    title: '30 min',
                                    selectedFilter: _getRefundWindowLabel(win),
                                    onpressed: () =>
                                        AppSettings.updateRefundWindow(30)),
                                Filterbutton(
                                    title: '1 hr',
                                    selectedFilter: _getRefundWindowLabel(win),
                                    onpressed: () =>
                                        AppSettings.updateRefundWindow(60)),
                                Filterbutton(
                                    title: '2 hr',
                                    selectedFilter: _getRefundWindowLabel(win),
                                    onpressed: () =>
                                        AppSettings.updateRefundWindow(120)),
                                Filterbutton(
                                    title: '4 hr',
                                    selectedFilter: _getRefundWindowLabel(win),
                                    onpressed: () =>
                                        AppSettings.updateRefundWindow(240)),
                                Filterbutton(
                                    title: '8 hr',
                                    selectedFilter: _getRefundWindowLabel(win),
                                    onpressed: () =>
                                        AppSettings.updateRefundWindow(480)),
                                Filterbutton(
                                    title: '24 hr',
                                    selectedFilter: _getRefundWindowLabel(win),
                                    onpressed: () =>
                                        AppSettings.updateRefundWindow(1440)),
                                Filterbutton(
                                    title: 'No Limit',
                                    selectedFilter: _getRefundWindowLabel(win),
                                    onpressed: () =>
                                        AppSettings.updateRefundWindow(0)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              _tileDivider(),
              ValueListenableBuilder<double>(
                valueListenable: AppSettings.lowStockThresholdNotifier,
                builder: (context, threshold, __) {
                  final label = threshold % 1 == 0
                      ? threshold.toStringAsFixed(0)
                      : threshold.toString();
                  return _expandableTile(
                    context: context,
                    title: 'Low Stock Threshold',
                    subtitle: 'Default alert when stock ≤ $label',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.amber.shade800,
                    isExpanded: _isLowStockExpanded,
                    onTap: () => setState(
                        () => _isLowStockExpanded = !_isLowStockExpanded),
                    expandedChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [3, 5, 10, 15, 20, 25]
                              .map((n) => Filterbutton(
                                    title: '$n',
                                    selectedFilter: label,
                                    onpressed: () => AppSettings
                                        .updateLowStockThreshold(n.toDouble()),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _customThresholdController,
                                hint: 'Custom value',
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                final v = double.tryParse(
                                    _customThresholdController.text.trim());
                                if (v == null || v <= 0) {
                                  NotificationService.instance
                                      .showError('Enter a valid number');
                                  return;
                                }
                                AppSettings.updateLowStockThreshold(v);
                                _customThresholdController.clear();
                                FocusScope.of(context).unfocus();
                              },
                              child: Text('Set',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Tip: weight-based items (kg/gm) should set their own '
                            'threshold on the item — this default suits count-based items.',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ]),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── 4. Staff & Shifts ───────────────────────────────────────
            _sectionHeader(context, 'Staff & Shifts', Icons.people_rounded),
            _sectionCard(context, [
              ValueListenableBuilder<int>(
                valueListenable: RestaurantSession.timeoutMinutesNotifier,
                builder: (context, minutes, __) => _expandableTile(
                  context: context,
                  title: 'Auto Logout Timeout',
                  subtitle: 'Current: ${_getTimeoutLabel(minutes)}',
                  icon: Icons.lock_clock_rounded,
                  color: Colors.orange,
                  isExpanded: _isTimeoutExpanded,
                  onTap: () => setState(
                      () => _isTimeoutExpanded = !_isTimeoutExpanded),
                  expandedChild: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [5, 10, 15, 30, 60].map((min) {
                      return Filterbutton(
                        title: min < 60 ? '$min min' : '1 hr',
                        selectedFilter: _getTimeoutLabel(minutes),
                        onpressed: () =>
                            RestaurantSession.setTimeoutMinutes(min),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ]),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── 5. Backup ───────────────────────────────────────────────
            _sectionHeader(context, 'Backup', Icons.backup_rounded),
            _sectionCard(context, [
              SwitchListTile(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.largeSpacing(context),
                    vertical: AppResponsive.smallSpacing(context) * 0.5),
                secondary: Container(
                  padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                  decoration: BoxDecoration(
                    color: (_backupEnabled ? Colors.green : AppColors.textSecondary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                  ),
                  child: Icon(Icons.backup_rounded,
                      size: AppResponsive.iconSize(context),
                      color: _backupEnabled ? Colors.green : AppColors.textSecondary),
                ),
                title: Text('Daily Backup Reminder',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                subtitle: Text(
                  'Show backup prompt at the start of each day',
                  style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary),
                ),
                value: _backupEnabled,
                activeColor: Colors.green,
                onChanged: (val) async {
                  await AutoBackupService.setAutoBackupEnabled(val);
                  setState(() => _backupEnabled = val);
                },
              ),
            ]),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── 6. License & Subscription ───────────────────────────────
            _sectionHeader(context, 'License & Subscription', Icons.verified_outlined),
            _sectionCard(context, [
              _navTile(
                context,
                'License Management',
                'View status, activate or manage your license key',
                Icons.verified_rounded,
                AppColors.primary,
                () => Navigator.pushNamed(context, RouteNames.restaurantLicensing),
              ),
            ]),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── 7. About / Device ───────────────────────────────────────
            _sectionHeader(context, 'About This Device', Icons.info_outline_rounded),
            _buildDeviceIdCard(context),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── 7. Developer ────────────────────────────────────────────
            _sectionHeader(context, 'Developer', Icons.code_rounded),
            _sectionCard(context, [
              _navTile(
                context,
                'Performance Test Data Generator',
                'Generate sample data for load testing',
                Icons.science_rounded,
                Colors.purple,
                () => Navigator.pushNamed(
                    context, RouteNames.restaurantDataGenratorScreen),
              ),
            ]),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIdCard(BuildContext context) {
    final id = _deviceIdResult?.id ?? 'Loading...';
    return _sectionCard(context, [
      Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.largeSpacing(context),
            vertical: AppResponsive.mediumSpacing(context)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Icon(Icons.fingerprint_rounded,
                  color: AppColors.primary,
                  size: AppResponsive.iconSize(context)),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device ID',
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(id,
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.textSecondary),
              tooltip: 'Copy Device ID',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device ID copied'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _actionChip(
      BuildContext context, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.mediumSpacing(context),
            vertical: AppResponsive.smallSpacing(context)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: color)),
      ),
    );
  }
}
