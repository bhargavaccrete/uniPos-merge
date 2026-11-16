import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/auto_backup_service.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/device_id_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/backup_password_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/settings_components.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

/// Ready-made Settings rows for the settings BOTH verticals share.
///
/// Each row reads and writes the one existing source of truth for its setting
/// (AppSettings, CurrencyHelper, DecimalSettings, RestaurantSession,
/// AutoBackupService, BackupEncryptionService, DeviceIdService) and listens to
/// it, so the restaurant and retail Settings screens cannot render the same
/// setting two ways or drift onto two values.

// ── Display ─────────────────────────────────────────────────────────────────

class CurrencySettingTile extends StatelessWidget {
  const CurrencySettingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CurrencyHelper.currencyNotifier,
      builder: (context, code, _) {
        final info = CurrencyHelper.currencies[code];
        return SettingsNavTile(
          title: 'Currency',
          subtitle: '${info?.name ?? code} (${info?.symbol ?? ''})',
          icon: Icons.currency_exchange_rounded,
          color: Colors.green,
          onTap: () => showCurrencyPickerDialog(context),
        );
      },
    );
  }
}

/// Scrollable currency list — a long list reads better here than as chips.
Future<void> showCurrencyPickerDialog(BuildContext context) async {
  final current = CurrencyHelper.currencyNotifier.value;
  final picked = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AppDialogShell(
      title: 'Select Currency',
      subtitle: 'Applies to every amount shown and printed.',
      icon: Icons.attach_money_rounded,
      accent: AppColors.success,
      // The shell sizes to its body, so the list needs its own bounded scroll.
      body: SizedBox(
        height: AppResponsive.getValue(
          context,
          mobile: 320.0,
          tablet: 400.0,
          desktop: 440.0,
        ),
        child: ListView(
          children: [
            for (final c in CurrencyHelper.getAllCurrencies())
              SettingsOptionRow(
                label: c.name,
                sublabel: '${c.code} · ${c.symbol}',
                selected: c.code == current,
                onTap: () => Navigator.pop(dialogContext, c.code),
              ),
          ],
        ),
      ),
      actions: [appDialogCancelButton(dialogContext)],
    ),
  );
  if (picked == null || picked == current) return;
  await CurrencyHelper.setCurrency(picked);
}

class DecimalPrecisionSettingTile extends StatelessWidget {
  const DecimalPrecisionSettingTile({super.key});

  static const _options = <(int, String)>[
    (0, 'None'),
    (1, '0.0'),
    (2, '0.00'),
    (3, '0.000'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: DecimalSettings.precisionNotifier,
      builder: (context, prec, _) => SettingsExpandableTile(
        title: 'Decimal Precision',
        subtitle:
            'Current: ${_options.firstWhere((o) => o.$1 == prec, orElse: () => _options[2]).$2}',
        icon: Icons.numbers_rounded,
        color: Colors.indigo,
        expandedChild: SettingsChipGroup<int>(
          options: _options,
          selected: prec,
          onSelected: DecimalSettings.updatePrecision,
        ),
      ),
    );
  }
}

// ── Billing ─────────────────────────────────────────────────────────────────

/// Round Off + step. Same AppSettings keys the restaurant Personalization
/// screen writes — one setting shown in two places.
class RoundOffSettingTile extends StatelessWidget {
  const RoundOffSettingTile({super.key});

  static const _steps = <(String, String)>[
    ('0.50', '0.50'),
    ('1.00', '1.00'),
    ('5.00', '5.00'),
    ('10.00', '10.00'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppSettings.settingsNotifier,
        AppSettings.roundOffNotifier,
      ]),
      builder: (context, _) => SettingsSwitchTile(
        title: 'Round Off',
        subtitle: 'Round bill totals to the nearest value',
        icon: Icons.calculate_outlined,
        color: AppColors.info,
        value: AppSettings.roundOff,
        onChanged: (v) => AppSettings.updateSetting('Round Off', v),
        expandedChild: SettingsChipGroup<String>(
          options: _steps,
          selected: AppSettings.selectedRoundOffValue,
          onSelected: AppSettings.updateRoundOffValue,
        ),
      ),
    );
  }
}

class VisualKeyboardSettingTile extends StatelessWidget {
  const VisualKeyboardSettingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.settingsNotifier,
      builder: (context, _) => SettingsSwitchTile(
        title: 'Visual Keyboard',
        subtitle: 'On-screen number pad instead of the system keyboard',
        icon: Icons.keyboard_outlined,
        color: AppColors.primary,
        value: AppSettings.visualKeyboard,
        onChanged: (v) => AppSettings.updateSetting('Visual Keyboard', v),
      ),
    );
  }
}

class RefundSettingTile extends StatelessWidget {
  const RefundSettingTile({super.key});

  static const _windows = <(int, String)>[
    (30, '30 min'),
    (60, '1 hr'),
    (120, '2 hr'),
    (240, '4 hr'),
    (480, '8 hr'),
    (1440, '24 hr'),
    (0, 'No Limit'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppSettings.settingsNotifier,
        AppSettings.refundWindowNotifier,
      ]),
      builder: (context, _) {
        final on = AppSettings.refundsEnabled;
        return SettingsSwitchTile(
          title: 'Allow Refunds',
          subtitle: on
              ? 'Refunds allowed within the window below'
              : 'Refunds are off — no refund option is offered',
          icon: Icons.undo_rounded,
          color: Colors.deepPurple,
          value: on,
          onChanged: (v) => AppSettings.updateSetting('Allow Refunds', v),
          expandedChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InlineLabel('Refund window (time limit for returns)'),
              SettingsChipGroup<int>(
                options: _windows,
                selected: AppSettings.refundWindowMinutes,
                onSelected: AppSettings.updateRefundWindow,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Account & Security ──────────────────────────────────────────────────────

class AutoLogoutSettingTile extends StatelessWidget {
  const AutoLogoutSettingTile({super.key});

  static const _options = <(int, String)>[
    (5, '5 min'),
    (10, '10 min'),
    (15, '15 min'),
    (30, '30 min'),
    (60, '1 hr'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RestaurantSession.timeoutMinutesNotifier,
      builder: (context, minutes, _) => SettingsExpandableTile(
        title: 'Auto Logout Timeout',
        subtitle:
            'Lock after inactivity · ${minutes < 60 ? '$minutes min' : '1 hr'}',
        icon: Icons.lock_clock_rounded,
        color: Colors.orange,
        expandedChild: SettingsChipGroup<int>(
          options: _options,
          selected: minutes,
          onSelected: RestaurantSession.setTimeoutMinutes,
        ),
      ),
    );
  }
}

class StaleShiftSettingTile extends StatelessWidget {
  const StaleShiftSettingTile({super.key});

  static const _hours = <(int, String)>[
    (12, '12 Hours'),
    (18, '18 Hours'),
    (24, '24 Hours'),
    (36, '36 Hours'),
    (48, '48 Hours'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppSettings.settingsNotifier,
        AppSettings.maxSessionDurationHoursNotifier,
      ]),
      builder: (context, _) => SettingsSwitchTile(
        title: 'Auto Close Stale Shift',
        subtitle:
            'Close open shifts and attendance when the session exceeds the '
            'maximum duration',
        icon: Icons.history_toggle_off_rounded,
        color: Colors.blue,
        value: AppSettings.autoCloseStaleShift,
        onChanged: (v) => AppSettings.updateSetting('Auto Close Stale Shift', v),
        expandedChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InlineLabel('Maximum session duration'),
            SettingsChipGroup<int>(
              options: _hours,
              selected: AppSettings.maxSessionDurationHours,
              onSelected: AppSettings.updateMaxSessionDurationHours,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Backup ──────────────────────────────────────────────────────────────────

/// Backup password status + Set / Change / Remove. Reads the password state
/// once on mount — give it a new key to re-read after leaving a screen that
/// may have changed it (the Backup screen has the same controls).
class BackupPasswordSettingTile extends StatefulWidget {
  const BackupPasswordSettingTile({super.key});

  @override
  State<BackupPasswordSettingTile> createState() =>
      _BackupPasswordSettingTileState();
}

class _BackupPasswordSettingTileState extends State<BackupPasswordSettingTile> {
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final has = await BackupEncryptionService.hasPassword();
    if (mounted) setState(() => _hasPassword = has);
  }

  Future<void> _set({required bool isChange}) async {
    if (await showBackupPasswordDialog(context, isChange: isChange)) _load();
  }

  Future<void> _remove() async {
    if (await confirmRemoveBackupPassword(context)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final color = _hasPassword ? Colors.green : Colors.orange;
    return SettingsNavTile(
      title: 'Backup Password',
      subtitleWidget: Text(
        _hasPassword
            ? 'Backups are password-protected'
            : 'No password — backups are unprotected',
        style: TextStyle(
          color: _hasPassword ? Colors.green.shade700 : Colors.orange.shade800,
        ),
      ),
      icon: _hasPassword ? Icons.lock_rounded : Icons.lock_open_rounded,
      color: color,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasPassword)
            _ActionChip(
              label: 'Set',
              color: Colors.green,
              onTap: () => _set(isChange: false),
            )
          else ...[
            _ActionChip(
              label: 'Change',
              color: Colors.orange,
              onTap: () => _set(isChange: true),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context) * 0.5),
            _ActionChip(
              icon: Icons.delete_outline_rounded,
              color: Colors.red,
              onTap: _remove,
            ),
          ],
        ],
      ),
    );
  }
}

class DailyBackupReminderTile extends StatefulWidget {
  const DailyBackupReminderTile({super.key});

  @override
  State<DailyBackupReminderTile> createState() =>
      _DailyBackupReminderTileState();
}

class _DailyBackupReminderTileState extends State<DailyBackupReminderTile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    AutoBackupService.isAutoBackupEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      title: 'Daily Backup Reminder',
      subtitle: 'Show backup prompt at the start of each day',
      icon: Icons.backup_rounded,
      color: Colors.green,
      value: _enabled,
      onChanged: (v) async {
        await AutoBackupService.setAutoBackupEnabled(v);
        if (mounted) setState(() => _enabled = v);
      },
    );
  }
}

/// BKP-6: read-only status of automatic backups — the last success and, when
/// the last attempt failed, when and why.
class AutoBackupStatusTile extends StatelessWidget {
  const AutoBackupStatusTile({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AutoBackupService.status();
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final failed = s.lastError != null;
    return SettingsNavTile(
      key: const Key('autoBackupStatus'),
      title: 'Automatic Backup Status',
      icon: failed ? Icons.cloud_off_rounded : Icons.history_rounded,
      color: failed ? AppColors.danger : AppColors.success,
      trailing: const SizedBox.shrink(),
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.lastSuccess == null
              ? 'No automatic backup yet'
              : 'Last successful: ${fmt.format(s.lastSuccess!)}'),
          if (failed)
            Text(
              'Last attempt failed'
              '${s.lastAttempt == null ? '' : ' (${fmt.format(s.lastAttempt!)})'}'
              ': ${s.lastError}',
              style: const TextStyle(color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

// ── About ───────────────────────────────────────────────────────────────────

class DeviceIdTile extends StatefulWidget {
  const DeviceIdTile({super.key});

  @override
  State<DeviceIdTile> createState() => _DeviceIdTileState();
}

class _DeviceIdTileState extends State<DeviceIdTile> {
  String? _id;

  @override
  void initState() {
    super.initState();
    DeviceIdService.getResult().then((r) {
      if (mounted) setState(() => _id = r.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = _id ?? 'Loading...';
    return SettingsNavTile(
      title: 'Device ID',
      subtitleWidget: Text(id, style: const TextStyle(letterSpacing: 1.2)),
      icon: Icons.fingerprint_rounded,
      color: AppColors.primary,
      trailing: IconButton(
        icon: Icon(
          Icons.copy_rounded,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.textSecondary,
        ),
        tooltip: 'Copy Device ID',
        onPressed: _id == null
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device ID copied'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
      ),
    );
  }
}

// ── Low stock threshold ─────────────────────────────────────────────────────

/// Low-stock threshold with presets + a custom value.
///
/// Storage-agnostic: restaurant passes `AppSettings.lowStockThreshold`
/// (double, decimals allowed), retail passes `stockAlertStore.threshold`
/// (int — [allowDecimal] false). Each side keeps its own key and type.
class LowStockThresholdTile extends StatelessWidget {
  final num value;
  final List<num> presets;
  final bool allowDecimal;
  final ValueChanged<num> onSelected;
  final String? tip;

  const LowStockThresholdTile({
    super.key,
    required this.value,
    required this.presets,
    required this.allowDecimal,
    required this.onSelected,
    this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsExpandableTile(
      title: 'Low Stock Threshold',
      subtitle: 'Default alert when stock ≤ ${formatThreshold(value)}',
      icon: Icons.warning_amber_rounded,
      color: Colors.amber.shade800,
      expandedChild: LowStockThresholdPicker(
        value: value,
        presets: presets,
        allowDecimal: allowDecimal,
        onSelected: onSelected,
        tip: tip,
      ),
    );
  }
}

String formatThreshold(num v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

/// Presets + "Custom". A stored value that is not a preset shows as Custom,
/// selected and pre-filled.
class LowStockThresholdPicker extends StatefulWidget {
  final num value;
  final List<num> presets;
  final bool allowDecimal;
  final ValueChanged<num> onSelected;
  final String? tip;

  const LowStockThresholdPicker({
    super.key,
    required this.value,
    required this.presets,
    required this.allowDecimal,
    required this.onSelected,
    this.tip,
  });

  @override
  State<LowStockThresholdPicker> createState() =>
      _LowStockThresholdPickerState();
}

class _LowStockThresholdPickerState extends State<LowStockThresholdPicker> {
  late final TextEditingController _controller;
  late bool _customOpen;
  String? _error;

  bool get _isCustomValue => !widget.presets.contains(widget.value);

  @override
  void initState() {
    super.initState();
    _customOpen = _isCustomValue;
    _controller = TextEditingController(
      text: _isCustomValue ? formatThreshold(widget.value) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final text = _controller.text.trim();
    final num? v = widget.allowDecimal
        ? double.tryParse(text)
        : int.tryParse(text);
    if (v == null || v <= 0) {
      setState(
        () => _error = widget.allowDecimal
            ? 'Enter a number greater than 0'
            : 'Enter a whole number of 1 or more',
      );
      return;
    }
    setState(() => _error = null);
    widget.onSelected(v);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final showCustom = _customOpen || _isCustomValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in widget.presets)
              SettingsOptionChip(
                label: formatThreshold(n),
                selected: !showCustom && widget.value == n,
                onTap: () {
                  setState(() {
                    _customOpen = false;
                    _error = null;
                  });
                  widget.onSelected(n);
                },
              ),
            SettingsOptionChip(
              label: 'Custom',
              icon: Icons.tune_rounded,
              selected: showCustom,
              onTap: () => setState(() => _customOpen = true),
            ),
          ],
        ),
        if (showCustom) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _controller,
                  hint: 'Custom value',
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: widget.allowDecimal,
                  ),
                  inputFormatters: [
                    widget.allowDecimal
                        ? FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,3}'),
                          )
                        : FilteringTextInputFormatter.digitsOnly,
                  ],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _apply,
                child: Text(
                  'Set',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.danger,
                ),
              ),
            ),
        ],
        if (widget.tip != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.tip!,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// [LowStockThresholdPicker] in a dialog, for screens outside Settings (the
/// retail Stock Alerts screen). Returns the chosen value, or null if dismissed.
Future<num?> showLowStockThresholdPicker(
  BuildContext context, {
  required num value,
  required List<num> presets,
  required bool allowDecimal,
  String? subtitle,
}) {
  return showDialog<num>(
    context: context,
    builder: (dialogContext) => AppDialogShell(
      title: 'Alert Threshold',
      subtitle: subtitle,
      icon: Icons.tune_rounded,
      accent: AppColors.primary,
      body: LowStockThresholdPicker(
        value: value,
        presets: presets,
        allowDecimal: allowDecimal,
        onSelected: (v) => Navigator.pop(dialogContext, v),
      ),
      actions: [appDialogCancelButton(dialogContext)],
    ),
  );
}

// ── Private bits ────────────────────────────────────────────────────────────

class _InlineLabel extends StatelessWidget {
  final String text;
  const _InlineLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    this.label,
    this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: Container(
        padding: label != null
            ? EdgeInsets.symmetric(
                horizontal: AppResponsive.mediumSpacing(context),
                vertical: AppResponsive.smallSpacing(context),
              )
            : EdgeInsets.all(AppResponsive.smallSpacing(context)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: label != null ? 0.1 : 0.08),
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: label != null
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
        ),
        child: label != null
            ? Text(
                label!,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              )
            : Icon(icon, size: AppResponsive.smallIconSize(context), color: color),
      ),
    );
  }
}
