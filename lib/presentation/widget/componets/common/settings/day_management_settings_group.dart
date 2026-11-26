import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/settings/settings_components.dart';
import 'package:billberrylite/presentation/widget/restaurant/opening_balance_dialog.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Start Day / Day In Progress / End of Day — the Day Management section of
/// both Settings screens. Both verticals share `DayManagementService` and
/// `promptStartDay`; only the End-of-Day screen differs, so the caller passes
/// [onOpenEndOfDay] (already guarded) and this widget refreshes when it
/// returns.
class DayManagementSettingsSection extends StatefulWidget {
  final Future<void> Function(BuildContext context) onOpenEndOfDay;

  const DayManagementSettingsSection({super.key, required this.onOpenEndOfDay});

  @override
  State<DayManagementSettingsSection> createState() =>
      _DayManagementSettingsSectionState();
}

class _DayManagementSettingsSectionState
    extends State<DayManagementSettingsSection> {
  late Future<({bool started, bool eodPending})> _state;

  @override
  void initState() {
    super.initState();
    _state = _read();
  }

  /// Read in one pass so the two rows can never disagree about whether the
  /// open session is overdue.
  Future<({bool started, bool eodPending})> _read() async => (
    started: await DayManagementService.isDayStarted(),
    eodPending:
        await DayManagementService.isEodStrictlyPending() ||
        await DayManagementService.hasPendingEOD(),
  );

  void _refresh() {
    if (mounted) setState(() => _state = _read());
  }

  /// Read-only. Re-running the start flow while a session is live would mint a
  /// second session and drop the day's earlier sales out of the EOD.
  Future<void> _showDayInfo() async {
    final startedAt = await DayManagementService.getDayStartTimestamp();
    final openingBalance = await DayManagementService.getOpeningBalance();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Day In Progress',
        subtitle: 'Close the day from End of Day to start a new one.',
        icon: Icons.wb_sunny_rounded,
        accent: AppColors.success,
        body: MoneyScope(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow(
                dialogContext,
                'Started at',
                startedAt == null
                    ? '—'
                    : DateFormat('dd MMM yyyy, h:mm a').format(startedAt),
              ),
              _infoRow(
                dialogContext,
                'Opening balance',
                formatMoney(openingBalance),
              ),
            ],
          ),
        ),
        actions: [appDialogCancelButton(dialogContext, label: 'Close')],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
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
    return FutureBuilder<({bool started, bool eodPending})>(
      future: _state,
      builder: (context, snapshot) {
        final started = snapshot.data?.started ?? false;
        // A session left open from an earlier day is OVERDUE and blocks
        // billing — say so instead of "in progress".
        final pending = snapshot.data?.eodPending ?? false;
        return SettingsSection(
          title: 'Day Management',
          icon: Icons.wb_sunny_outlined,
          children: [
            SettingsNavTile(
              title: !started
                  ? 'Start Day'
                  : pending
                  ? 'Previous Day Still Open'
                  : 'Day In Progress',
              subtitle: !started
                  ? 'Set opening balance to begin operations'
                  : pending
                  ? 'Complete End of Day below to settle it'
                  : 'View session start time and opening balance',
              icon: started ? Icons.wb_sunny_outlined : Icons.wb_sunny,
              color: pending ? AppColors.warning : AppColors.success,
              onTap: () async {
                if (started) {
                  await _showDayInfo();
                  return;
                }
                await promptStartDay(context);
                _refresh();
              },
            ),
            if (started)
              SettingsNavTile(
                title: pending ? 'End of Day — Pending' : 'End of Day',
                subtitle: pending
                    ? 'Settle the previous day to resume billing'
                    : 'Close day and reconcile cash',
                icon: Icons.nights_stay,
                color: pending ? AppColors.warning : AppColors.info,
                onTap: () async {
                  await widget.onOpenEndOfDay(context);
                  _refresh();
                },
              ),
          ],
        );
      },
    );
  }
}
