import 'package:intl/intl.dart';

import 'package:billberrylite/data/models/common/attendance_model.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';

/// One staff member's totals for a period.
typedef AttendanceStaffTotals = ({
  String name,
  String role,
  int presentDays,
  int absentDays,
  int totalMinutes,
});

/// The Attendance report's numbers, in ONE place.
///
/// Shared by Restaurant and Retail (they open the same screen). The monthly
/// screen cards, its staff list, the Print PDF and both exports read from
/// here, so they can never disagree. The rules are the screen's original
/// ones, unchanged:
/// - every calendar day is a working day (restaurants run 7 days a week);
/// - a staff member is present on a day if they have any record whose
///   stored `date` key is that day (two shifts on one day = one day);
/// - absent = working days − present days, never below 0;
/// - hours = Σ `totalMinutes` of closed shifts, plus the LIVE time of a shift
///   still open (minus its breaks, including a break in progress).
///
/// Pure: no Hive, no stores, no BuildContext. [now] is injectable for tests.
class AttendanceReportCalc {
  /// Records for the period, in clock-in order.
  final List<AttendanceModel> records;

  /// First day of the period (midnight).
  final DateTime from;

  /// Last day counted as a working day (today for a period still running).
  final DateTime periodEnd;

  final DateTime now;

  /// Every name on the report: active staff plus anyone with a record,
  /// sorted — absent staff still show up.
  final List<String> staffNames;

  final Map<String, String> _staffRoles;

  AttendanceReportCalc._({
    required this.records,
    required this.from,
    required this.periodEnd,
    required this.now,
    required this.staffNames,
    required Map<String, String> staffRoles,
  }) : _staffRoles = staffRoles;

  /// [activeStaffNames]: names of active staff (absent ones must appear).
  /// [staffRoles]: role by name from the staff list (first match wins, as the
  /// screen's `firstOrNull` lookup did).
  factory AttendanceReportCalc({
    required List<AttendanceModel> records,
    required DateTime from,
    required DateTime periodEnd,
    required Iterable<String> activeStaffNames,
    required Map<String, String> staffRoles,
    DateTime? now,
  }) {
    final names = {
      ...records.map((r) => r.staffName),
      ...activeStaffNames,
    }.toList()
      ..sort();
    return AttendanceReportCalc._(
      records: records,
      from: DateTime(from.year, from.month, from.day),
      periodEnd: DateTime(periodEnd.year, periodEnd.month, periodEnd.day),
      now: now ?? DateTime.now(),
      staffNames: names,
      staffRoles: staffRoles,
    );
  }

  // ── Period rules ────────────────────────────────────────────────────────

  /// Operating days between two dates, inclusive — every calendar day.
  static int workingDaysBetween(DateTime start, DateTime end) {
    var count = 0;
    var d = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(last)) {
      count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  /// The month's last counted day: today while the month is running, else
  /// its final day (the screen's original rule).
  static DateTime monthPeriodEnd(DateTime month, DateTime now) {
    final isCurrent = month.year == now.year && month.month == now.month;
    return isCurrent ? now : DateTime(month.year, month.month + 1, 0);
  }

  /// The stored day key, `yyyy-MM-dd`, exactly as attendance writes it.
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  int get workingDays => workingDaysBetween(from, periodEnd);

  /// Each counted day of the period, oldest first.
  List<DateTime> get days {
    final out = <DateTime>[];
    var d = from;
    while (!d.isAfter(periodEnd)) {
      out.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return out;
  }

  // ── Per-staff rules ─────────────────────────────────────────────────────

  List<AttendanceModel> recordsOf(String name) =>
      records.where((r) => r.staffName == name).toList();

  int presentDays(String name) =>
      recordsOf(name).map((r) => r.date).toSet().length;

  int absentDays(String name) =>
      (workingDays - presentDays(name)).clamp(0, workingDays);

  /// One record's worked minutes: stored total when closed; live time minus
  /// breaks while open; 0 for a closed record with no total.
  static int recordMinutes(AttendanceModel r, DateTime now) {
    if (r.totalMinutes != null) return r.totalMinutes!;
    if (!r.isOpen) return 0;
    final gross = now.difference(r.clockIn).inMinutes;
    final breaks = (r.breakTotalMinutes ?? 0) +
        (r.isOnBreak && r.breakStartTime != null
            ? now.difference(r.breakStartTime!).inMinutes
            : 0);
    final active = gross - breaks;
    return active < 0 ? 0 : active;
  }

  int totalMinutes(String name) =>
      recordsOf(name).fold(0, (s, r) => s + recordMinutes(r, now));

  /// Role from the staff list, else the first record's stored role, else ''.
  String roleOf(String name) =>
      _staffRoles[name] ??
      (recordsOf(name).isEmpty ? '' : recordsOf(name).first.staffRole);

  AttendanceStaffTotals totalsOf(String name) => (
        name: name,
        role: roleOf(name),
        presentDays: presentDays(name),
        absentDays: absentDays(name),
        totalMinutes: totalMinutes(name),
      );

  List<AttendanceStaffTotals> get staffTotals =>
      staffNames.map(totalsOf).toList();

  int get totalPresentDays =>
      staffNames.fold(0, (s, n) => s + presentDays(n));

  int get allMinutes => staffNames.fold(0, (s, n) => s + totalMinutes(n));

  int get openShifts => records.where((r) => r.isOpen).length;

  // ── Formatting (the screen's existing text) ─────────────────────────────

  /// "0m", "45m", "7h 5m" — the screen's readable hours.
  static String fmtMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0 && m == 0) return '0m';
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  /// Decimal hours at full precision (minutes ÷ 60); display is 2 places.
  static ExportNumber decimalHours(int mins) => ExportNumber(mins / 60);

  // ── Exports ─────────────────────────────────────────────────────────────

  static const summaryHeaders = [
    'Staff Name',
    'Role',
    'Days Present',
    'Days Absent',
    'Total Hours',
    'Hours (decimal)',
  ];

  /// One row per staff member.
  List<List<dynamic>> summaryRows() => staffTotals
      .map((t) => <dynamic>[
            t.name,
            t.role,
            t.presentDays,
            t.absentDays,
            fmtMins(t.totalMinutes),
            decimalHours(t.totalMinutes),
          ])
      .toList();

  /// [periodKey] is 'Month' for the monthly export (its original label) and
  /// 'Period' for a custom range.
  Map<String, dynamic> summaryBlock(String periodKey, String periodLabel) => {
        periodKey: periodLabel,
        'Total Staff': '${staffNames.length}',
        'Working Days': '$workingDays',
        'Days Present': '$totalPresentDays',
        'Total Hours':
            '${fmtMins(allMinutes)} (${(allMinutes / 60).toStringAsFixed(2)} h)',
      };

  static const dayHeaders = [
    'Date',
    'Day',
    'Staff Name',
    'Role',
    'Clock In',
    'Clock Out',
    'Break (min)',
    'Worked',
    'Hours (decimal)',
    'Status',
  ];

  static const statusCompleted = 'Completed';
  static const statusOpen = 'Open';
  static const statusOnBreak = 'On break';
  static const statusAbsent = 'Absent';

  static String statusOf(AttendanceModel r) {
    if (!r.isOpen) return statusCompleted;
    return r.isOnBreak ? statusOnBreak : statusOpen;
  }

  /// Day-wise register: for each counted day, each staff member's shifts in
  /// clock-in order, or one generated "Absent" row when they have no record
  /// on that day (the same rule [presentDays] uses — never stored).
  List<List<dynamic>> dayRows() {
    final byKey = <String, List<AttendanceModel>>{};
    for (final r in records) {
      byKey.putIfAbsent('${r.date}|${r.staffName}', () => []).add(r);
    }
    final rows = <List<dynamic>>[];
    for (final day in days) {
      final key = dayKey(day);
      final dayName = DateFormat('EEE').format(day);
      for (final name in staffNames) {
        final shifts = [...?byKey['$key|$name']]
          ..sort((a, b) => a.clockIn.compareTo(b.clockIn));
        if (shifts.isEmpty) {
          rows.add(<dynamic>[
            ExportDate(day),
            dayName,
            name,
            roleOf(name),
            '',
            '',
            0,
            fmtMins(0),
            decimalHours(0),
            statusAbsent,
          ]);
          continue;
        }
        for (final r in shifts) {
          final mins = recordMinutes(r, now);
          rows.add(<dynamic>[
            ExportDate(day),
            dayName,
            name,
            roleOf(name),
            ExportDateTime(r.clockIn, hour24: true, pdfPattern: 'HH:mm'),
            r.clockOut == null
                ? ''
                : ExportDateTime(
                    r.clockOut!,
                    hour24: true,
                    // A next-day clock-out shows its date, as on screen.
                    pdfPattern: _sameDay(r.clockOut!, r.clockIn)
                        ? 'HH:mm'
                        : 'dd MMM, HH:mm',
                  ),
            r.breakTotalMinutes ?? 0,
            fmtMins(mins),
            decimalHours(mins),
            statusOf(r),
          ]);
        }
      }
    }
    return rows;
  }

  /// Totals of exactly [rows] built by [dayRows].
  Map<String, dynamic> dayBlock(String periodLabel, List<List<dynamic>> rows) {
    final shifts = rows.where((r) => r[9] != statusAbsent).toList();
    final minutes = shifts.fold<double>(
        0, (s, r) => s + (r[8] as ExportNumber).value * 60);
    final presentStaffDays = shifts
        .map((r) => '${dayKey((r[0] as ExportDate).value)}|${r[2]}')
        .toSet()
        .length;
    return {
      'Period': periodLabel,
      'Staff': '${staffNames.length}',
      'Days': '${days.length}',
      'Shifts': '${shifts.length}',
      'Staff-days Present': '$presentStaffDays',
      'Absent Rows': '${rows.length - shifts.length}',
      'Total Hours':
          '${fmtMins(minutes.round())} (${(minutes / 60).toStringAsFixed(2)} h)',
      'Open Shifts': '${shifts.where((r) => r[9] != statusCompleted).length}',
    };
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
