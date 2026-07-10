import 'package:flutter/material.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';
import 'package:billberrylite/widgets/upgrade_sheet.dart';

/// The standard period selector. Owns the history-window lock so no screen has
/// to remember it: a period reaching further back than the plan allows renders
/// locked and opens "More history needed" instead of quietly truncating.
///
/// [ReportPeriod.custom] is never locked — its date picker is clamped to the
/// window instead (see `ReportDateRangeCard`).
class ReportPeriodFilterBar extends StatelessWidget {
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onSelected;

  /// Names the data in the upgrade sheet, e.g. 'sales' → "This Year sales".
  final String featureNoun;

  /// Defaults to all five. Pass a subset for reports without a custom range.
  final List<ReportPeriod> periods;

  /// Screen-specific controls (a month/year dropdown) scrolled alongside.
  final List<Widget> trailing;

  const ReportPeriodFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.featureNoun,
    this.periods = ReportPeriod.values,
    this.trailing = const [],
  });

  static bool _allows(ReportPeriod period) =>
      period == ReportPeriod.custom ||
      ReportHistoryWindow.allows(reportPeriodStartBound(period, DateTime.now()));

  @override
  Widget build(BuildContext context) {
    return ReportFilterBar<ReportPeriod>(
      selected: selected,
      onSelected: onSelected,
      trailing: trailing,
      options: [
        for (final period in periods)
          ReportFilterOption(
            value: period,
            label: period.label,
            icon: period.icon,
            locked: !_allows(period),
            onLockedTap: () => UpgradeSheet.showHistoryLimit(
              context,
              featureName: '${period.label} $featureNoun',
              neededDays: ReportHistoryWindow.requiredDays(
                  reportPeriodStartBound(period, DateTime.now())),
              allowedDays: ReportHistoryWindow.limitDays ?? 0,
            ),
          ),
      ],
    );
  }
}
