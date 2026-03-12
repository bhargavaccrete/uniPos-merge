import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/util/color.dart';

import '../../../../domain/services/common/auto_backup_service.dart';
import '../../../../domain/services/common/backup_encryption_service.dart';
import '../../../../util/common/currency_helper.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../../util/common/decimal_settings.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import '../../../widget/componets/restaurant/componets/filterButton.dart';
import '../../../widget/componets/common/app_text_field.dart';

class Settingsscreen extends StatefulWidget {
  const Settingsscreen({super.key});
  @override
  _settingsScreenState createState() => _settingsScreenState();
}

class _settingsScreenState extends State<Settingsscreen> {
  bool _isDecimalExpanded = false;
  bool _isCurrencyExpanded = false;
  bool _isRefundWindowExpanded = false;

  bool _backupEnabled = false;
  bool _hasBackupPassword = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await DecimalSettings.load();
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

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ]),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: children),
      ),
    );
  }

  Widget _navTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Widget _expandableTile({
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ]),
        ),
      ),
      if (isExpanded) ...[
        Divider(height: 1, color: AppColors.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: 8,
            ),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_rounded,
                  size: isTablet ? 22 : 20, color: AppColors.primary),
            ),
          ),
        ],
      ),
      drawer:
          DrawerManage(issync: false, isDelete: true, islogout: true),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          children: [

            // ── 1. Account & Security ───────────────────────────────────
            _sectionHeader('Account & Security', Icons.security_rounded),
            _sectionCard([
              _navTile(
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: (_hasBackupPassword
                              ? Colors.green
                              : Colors.orange)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _hasBackupPassword
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: 18,
                      color: _hasBackupPassword
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Backup Password',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          _hasBackupPassword
                              ? 'Backups are password-protected'
                              : 'No password — backups are unprotected',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _hasBackupPassword
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800),
                        ),
                      ],
                    ),
                  ),
                  if (!_hasBackupPassword)
                    _actionChip('Set', Colors.green,
                        () => _showSetPasswordDialog())
                  else ...[
                    _actionChip('Change', Colors.orange,
                        () => _showSetPasswordDialog(isChange: true)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () async {
                        await BackupEncryptionService.clearPassword();
                        setState(() => _hasBackupPassword = false);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.red),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
            SizedBox(height: isTablet ? 24 : 20),

            // ── 2. Display ──────────────────────────────────────────────
            _sectionHeader('Display', Icons.palette_outlined),
            _sectionCard([
              ValueListenableBuilder<String>(
                valueListenable: CurrencyHelper.currencyNotifier,
                builder: (context, _, __) => _expandableTile(
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
            SizedBox(height: isTablet ? 24 : 20),

            // ── 3. Orders & Payments ────────────────────────────────────
            _sectionHeader(
                'Orders & Payments', Icons.shopping_bag_outlined),
            _sectionCard([
              _navTile(
                'Payment Methods',
                'Manage accepted payment types',
                Icons.payment_rounded,
                Colors.teal,
                () => Navigator.pushNamed(
                    context, RouteNames.restaurantPaymentMethods),
              ),
              _tileDivider(),
              _navTile(
                'Order Settings',
                'Configure order behaviour & notifications',
                Icons.receipt_long_rounded,
                Colors.orange,
                () => Navigator.pushNamed(
                    context, RouteNames.restaurantOrderSettings),
              ),
              _tileDivider(),
              ValueListenableBuilder<int>(
                valueListenable: AppSettings.refundWindowNotifier,
                builder: (context, win, __) => _expandableTile(
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
            ]),
            SizedBox(height: isTablet ? 24 : 20),

            // ── 4. Staff & Shifts ───────────────────────────────────────
            _sectionHeader('Staff & Shifts', Icons.people_rounded),
            _sectionCard([
              ValueListenableBuilder<Map<String, bool>>(
                valueListenable: AppSettings.settingsNotifier,
                builder: (context, _, __) {
                  final enabled = AppSettings.shiftHandover;
                  return SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    secondary: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: (enabled ? Colors.indigo : Colors.grey)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.swap_horiz_rounded,
                          size: 18,
                          color:
                              enabled ? Colors.indigo : Colors.grey),
                    ),
                    title: Text('Shift Handover',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                    subtitle: Text(
                      enabled
                          ? 'Staff must count & hand over cash between shifts'
                          : 'Off — use End Day only (single-shift setup)',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                    value: enabled,
                    activeColor: Colors.indigo,
                    onChanged: (val) =>
                        AppSettings.updateSetting('Shift Handover', val),
                  );
                },
              ),
            ]),
            SizedBox(height: isTablet ? 24 : 20),

            // ── 5. Backup ───────────────────────────────────────────────
            _sectionHeader('Backup', Icons.backup_rounded),
            _sectionCard([
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                secondary: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (_backupEnabled ? Colors.green : Colors.grey)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.backup_rounded,
                      size: 18,
                      color:
                          _backupEnabled ? Colors.green : Colors.grey),
                ),
                title: Text('Daily Backup Reminder',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                subtitle: Text(
                  'Show backup prompt at the start of each day',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _backupEnabled,
                activeColor: Colors.green,
                onChanged: (val) async {
                  await AutoBackupService.setAutoBackupEnabled(val);
                  setState(() => _backupEnabled = val);
                },
              ),
            ]),
            SizedBox(height: isTablet ? 24 : 20),

            // ── 6. Developer ────────────────────────────────────────────
            _sectionHeader('Developer', Icons.code_rounded),
            _sectionCard([
              _navTile(
                'Performance Test Data Generator',
                'Generate sample data for load testing',
                Icons.science_rounded,
                Colors.purple,
                () => Navigator.pushNamed(
                    context, RouteNames.restaurantDataGenratorScreen),
              ),
            ]),
            SizedBox(height: isTablet ? 16 : 12),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(
      String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ),
    );
  }
}
