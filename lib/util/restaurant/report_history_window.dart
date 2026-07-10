import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';

/// The `reports.history_limit_days` data scope, asked as a question about a
/// WINDOW rather than about a single row.
///
/// Report screens clamp their data with [cutoff], but a filter that reaches
/// further back than the plan allows must be refused up front — otherwise the
/// screen silently renders a truncated period as if it were complete.
class ReportHistoryWindow {
  ReportHistoryWindow._();

  /// Window size in days, whatever the manifest sends (10, 50, 365, …).
  /// null = unlimited: bypass, `'all'`, absent, or a non-positive cap.
  ///
  /// A 0/negative cap means "no cap", matching `PlanEnforce.withinLimit`. Do NOT
  /// call `PlanEnforce.windowCutoff` directly from a report — it lacks this
  /// guard, so a 0 would push the cutoff to `now` and blank every report while
  /// the filter buttons stayed unlocked.
  static int? get limitDays {
    final days = PlanEnforce.windowDays(EntKeys.reportsHistoryLimitDays);
    return (days == null || days <= 0) ? null : days;
  }

  /// Earliest visible record date; null = unlimited. Rows older than this are
  /// dropped by every report's filter loop.
  static DateTime? get cutoff {
    final days = limitDays;
    return days == null ? null : DateTime.now().subtract(Duration(days: days));
  }

  /// Days of history a window starting at [earliest] needs, rounded UP: the
  /// cutoff is `now - days`, not `midnight - days`, so an order sitting exactly
  /// on [earliest] must still clear it.
  static int requiredDays(DateTime earliest, [DateTime? now]) {
    final span = (now ?? DateTime.now()).difference(earliest).inMicroseconds;
    if (span <= 0) return 1;
    return (span / Duration.microsecondsPerDay).ceil();
  }

  /// Can the plan see back as far as [earliest]?
  static bool allows(DateTime earliest, [DateTime? now]) {
    final days = limitDays;
    return days == null || days >= requiredDays(earliest, now);
  }
}
