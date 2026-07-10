import 'package:flutter/material.dart';

/// The period every report filters by. One enum, so the window arithmetic and
/// the history lock live in one place instead of once per screen.
enum ReportPeriod { today, thisWeek, thisMonth, thisYear, custom }

extension ReportPeriodX on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.thisYear:
        return 'This Year';
      case ReportPeriod.custom:
        return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportPeriod.today:
        return Icons.today;
      case ReportPeriod.thisWeek:
        return Icons.view_week;
      case ReportPeriod.thisMonth:
        return Icons.calendar_month;
      case ReportPeriod.thisYear:
        return Icons.calendar_today;
      case ReportPeriod.custom:
        return Icons.date_range;
    }
  }
}

/// Earliest date [period] reaches back to. This is the date the plan's history
/// window must cover, so the filter lock and the query must both call it.
/// [ReportPeriod.custom] has no fixed bound — the caller supplies the range.
DateTime reportPeriodStartBound(ReportPeriod period, DateTime now) {
  switch (period) {
    case ReportPeriod.today:
    case ReportPeriod.custom:
      return DateTime(now.year, now.month, now.day);
    case ReportPeriod.thisWeek:
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      return DateTime(weekStart.year, weekStart.month, weekStart.day);
    case ReportPeriod.thisMonth:
      return DateTime(now.year, now.month);
    case ReportPeriod.thisYear:
      return DateTime(now.year);
  }
}

/// Exclusive upper bound: an order at exactly this instant is NOT in [period].
DateTime reportPeriodEndBound(ReportPeriod period, DateTime now) {
  final start = reportPeriodStartBound(period, now);
  switch (period) {
    case ReportPeriod.today:
    case ReportPeriod.custom:
      return start.add(const Duration(days: 1));
    case ReportPeriod.thisWeek:
      return start.add(const Duration(days: 7));
    case ReportPeriod.thisMonth:
      return DateTime(now.year, now.month + 1);
    case ReportPeriod.thisYear:
      return DateTime(now.year + 1);
  }
}
