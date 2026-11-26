import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/common/attendance_model.dart';
import 'package:billberrylite/domain/services/common/attendance_report_calc.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';

/// The Attendance report's ONE calculation helper (Restaurant + Retail share
/// the screen). These pin the screen's original rules and the new exports.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // "Now" for every test: Tue 24 Nov 2026, 18:00.
  final now = DateTime(2026, 11, 24, 18);
  var seq = 0;

  AttendanceModel rec(
    String name,
    DateTime clockIn, {
    DateTime? clockOut,
    int? totalMinutes,
    String role = 'Waiter',
    int? breakTotal,
    DateTime? breakStart,
    String? dateKey,
  }) =>
      AttendanceModel(
        id: 'r${seq++}',
        staffName: name,
        staffRole: role,
        clockIn: clockIn,
        clockOut: clockOut,
        totalMinutes:
            totalMinutes ?? clockOut?.difference(clockIn).inMinutes,
        date: dateKey ?? AttendanceReportCalc.dayKey(clockIn),
        breakTotalMinutes: breakTotal,
        breakStartTime: breakStart,
      );

  AttendanceReportCalc calc(
    List<AttendanceModel> records, {
    required DateTime from,
    required DateTime periodEnd,
    List<String> active = const [],
    Map<String, String> roles = const {},
  }) =>
      AttendanceReportCalc(
        records: records,
        from: from,
        periodEnd: periodEnd,
        activeStaffNames: active,
        staffRoles: roles,
        now: now,
      );

  group('working days (original rule: every calendar day)', () {
    test('current month runs to today; a past month is complete', () {
      final nov = DateTime(2026, 11, 1);
      expect(
          AttendanceReportCalc.workingDaysBetween(
              nov, AttendanceReportCalc.monthPeriodEnd(nov, now)),
          24);
      final oct = DateTime(2026, 10, 1);
      expect(
          AttendanceReportCalc.workingDaysBetween(
              oct, AttendanceReportCalc.monthPeriodEnd(oct, now)),
          31);
    });

    test('a custom range crossing months is inclusive (26 Oct – 25 Nov)', () {
      expect(
          AttendanceReportCalc.workingDaysBetween(
              DateTime(2026, 10, 26), DateTime(2026, 11, 25)),
          31);
    });
  });

  group('per staff', () {
    test('two shifts on one day count as ONE present day', () {
      final c = calc([
        rec('Asha', DateTime(2026, 11, 3, 9),
            clockOut: DateTime(2026, 11, 3, 13)),
        rec('Asha', DateTime(2026, 11, 3, 17),
            clockOut: DateTime(2026, 11, 3, 21)),
        rec('Asha', DateTime(2026, 11, 4, 9),
            clockOut: DateTime(2026, 11, 4, 17)),
      ], from: DateTime(2026, 11, 1), periodEnd: DateTime(2026, 11, 10));

      expect(c.presentDays('Asha'), 2);
      expect(c.absentDays('Asha'), 8);
      expect(c.totalMinutes('Asha'), 4 * 60 + 4 * 60 + 8 * 60);
    });

    test('absent is never negative', () {
      final c = calc([
        rec('Ravi', DateTime(2026, 11, 1, 9), totalMinutes: 60),
        rec('Ravi', DateTime(2026, 11, 2, 9), totalMinutes: 60),
        rec('Ravi', DateTime(2026, 11, 3, 9), totalMinutes: 60),
      ], from: DateTime(2026, 11, 1), periodEnd: DateTime(2026, 11, 2));
      expect(c.workingDays, 2);
      expect(c.absentDays('Ravi'), 0);
    });

    test('an open shift adds LIVE time minus breaks (kept as before)', () {
      final c = calc([
        // In at 10:00, 30 min of breaks taken, still in at 18:00 → 450.
        rec('Meena', DateTime(2026, 11, 24, 10), breakTotal: 30),
      ], from: DateTime(2026, 11, 1), periodEnd: now);
      expect(c.totalMinutes('Meena'), 8 * 60 - 30);
      expect(c.openShifts, 1);
    });

    test('an open shift ON BREAK also subtracts the running break', () {
      final c = calc([
        rec('Meena', DateTime(2026, 11, 24, 10),
            breakTotal: 30, breakStart: DateTime(2026, 11, 24, 17)),
      ], from: DateTime(2026, 11, 1), periodEnd: now);
      expect(c.totalMinutes('Meena'), 8 * 60 - 30 - 60);
    });

    test('staff list: active without records + records of anyone, sorted', () {
      final c = calc([
        rec('Zoya', DateTime(2026, 11, 2, 9), totalMinutes: 60),
      ],
          from: DateTime(2026, 11, 1),
          periodEnd: DateTime(2026, 11, 5),
          active: ['Bala', 'Asha']);
      expect(c.staffNames, ['Asha', 'Bala', 'Zoya']);
      expect(c.presentDays('Asha'), 0);
      expect(c.absentDays('Asha'), 5);
    });

    test('role: staff list first, then the first record, else blank', () {
      final c = calc([
        rec('Asha', DateTime(2026, 11, 2, 9), totalMinutes: 60, role: 'Old'),
        rec('Ravi', DateTime(2026, 11, 2, 9), totalMinutes: 60, role: 'Chef'),
      ],
          from: DateTime(2026, 11, 1),
          periodEnd: DateTime(2026, 11, 2),
          active: ['Nina'],
          roles: {'Asha': 'Manager'});
      expect(c.roleOf('Asha'), 'Manager');
      expect(c.roleOf('Ravi'), 'Chef');
      expect(c.roleOf('Nina'), '');
    });
  });

  group('summary export', () {
    test('rows equal the per-staff totals the screen shows', () {
      final c = calc([
        rec('Asha', DateTime(2026, 11, 3, 9),
            clockOut: DateTime(2026, 11, 3, 16, 20)),
      ], from: DateTime(2026, 11, 1), periodEnd: DateTime(2026, 11, 3));
      final row = c.summaryRows().single;
      final t = c.totalsOf('Asha');

      expect(row.sublist(0, 5),
          ['Asha', 'Waiter', t.presentDays, t.absentDays, '7h 20m']);
      final hours = row[5] as ExportNumber;
      expect(hours.value, closeTo(440 / 60, 1e-9),
          reason: 'full precision kept');
      expect(ReportExportService.pdfRows([row]).single[5], '7.33');
    });

    test('summary block totals; monthly keeps its "Month" label', () {
      final c = calc([
        rec('Asha', DateTime(2026, 11, 3, 9), totalMinutes: 90),
        rec('Ravi', DateTime(2026, 11, 3, 9), totalMinutes: 30),
      ], from: DateTime(2026, 11, 1), periodEnd: DateTime(2026, 11, 3));
      final block = c.summaryBlock('Month', 'November 2026');
      expect(block['Month'], 'November 2026');
      expect(block['Total Staff'], '2');
      expect(block['Working Days'], '3');
      expect(block['Days Present'], '2');
      expect(block['Total Hours'], '2h 0m (2.00 h)');
    });
  });

  group('day-wise export', () {
    test('custom range crossing months: only days inside, absent rows filled',
        () {
      final c = calc([
        rec('Asha', DateTime(2026, 10, 31, 9),
            clockOut: DateTime(2026, 10, 31, 17)),
        rec('Asha', DateTime(2026, 11, 1, 9),
            clockOut: DateTime(2026, 11, 1, 17)),
      ], from: DateTime(2026, 10, 30), periodEnd: DateTime(2026, 11, 2));
      final rows = c.dayRows();

      // 4 days × 1 staff; 2 shifts + 2 generated absences.
      expect(rows, hasLength(4));
      expect(rows.map((r) => (r[0] as ExportDate).value.day), [30, 31, 1, 2]);
      expect(rows.map((r) => r[9]), [
        AttendanceReportCalc.statusAbsent,
        AttendanceReportCalc.statusCompleted,
        AttendanceReportCalc.statusCompleted,
        AttendanceReportCalc.statusAbsent,
      ]);
      // Absent rows == the summary's absent days (same rule).
      expect(rows.where((r) => r[9] == 'Absent').length, c.absentDays('Asha'));
    });

    test('overnight shift: one row on the clock-in day, clock-out shows date',
        () {
      final c = calc([
        rec('Ravi', DateTime(2026, 11, 20, 22),
            clockOut: DateTime(2026, 11, 21, 6)),
      ], from: DateTime(2026, 11, 20), periodEnd: DateTime(2026, 11, 21));
      final rows = c.dayRows();
      final pdf = ReportExportService.pdfRows(rows);

      expect(rows.first[9], 'Completed');
      expect(pdf.first[4], '22:00');
      expect(pdf.first[5], '21 Nov, 06:00');
      expect((rows.first[8] as ExportNumber).value, 8);
      expect(rows.last[9], 'Absent', reason: 'nothing clocked in on the 21st');
    });

    test('open shift: blank clock-out, marked Open; on break: "On break"', () {
      final c = calc([
        rec('Meena', DateTime(2026, 11, 24, 10)),
        rec('Ravi', DateTime(2026, 11, 24, 11),
            breakStart: DateTime(2026, 11, 24, 17)),
      ], from: DateTime(2026, 11, 24), periodEnd: now);
      final rows = c.dayRows();

      final meena = rows.firstWhere((r) => r[2] == 'Meena');
      expect(meena[5], '');
      expect(meena[9], AttendanceReportCalc.statusOpen);
      expect(meena[7], '8h 0m', reason: 'live hours, as the screen counts');
      expect(rows.firstWhere((r) => r[2] == 'Ravi')[9],
          AttendanceReportCalc.statusOnBreak);
      expect(c.dayBlock('x', rows)['Open Shifts'], '2');
    });

    test('multiple shifts on one day: one row each, clock-in order', () {
      final c = calc([
        rec('Asha', DateTime(2026, 11, 3, 17),
            clockOut: DateTime(2026, 11, 3, 21), breakTotal: 15),
        rec('Asha', DateTime(2026, 11, 3, 9),
            clockOut: DateTime(2026, 11, 3, 13)),
      ], from: DateTime(2026, 11, 3), periodEnd: DateTime(2026, 11, 3));
      final rows = c.dayRows();
      final pdf = ReportExportService.pdfRows(rows);

      expect(rows, hasLength(2));
      expect(pdf.map((r) => r[4]), ['09:00', '17:00']);
      expect(rows.last[6], 15, reason: 'break minutes as a whole number');
      final block = c.dayBlock('3 Nov', rows);
      expect(block['Shifts'], '2');
      expect(block['Staff-days Present'], '1');
      expect(block['Absent Rows'], '0');
      expect(block['Total Hours'], '8h 0m (8.00 h)');
    });

    test('Excel: real date, date-time and number cells', () {
      final c = calc([
        rec('Asha', DateTime(2026, 11, 3, 9),
            clockOut: DateTime(2026, 11, 3, 16, 20)),
      ], from: DateTime(2026, 11, 3), periodEnd: DateTime(2026, 11, 3));
      final bytes = ReportExportService.buildExcelBytesForTesting(
        headers: AttendanceReportCalc.dayHeaders,
        data: c.dayRows(),
      );
      final sheet = Excel.decodeBytes(bytes).tables.values.first.rows;
      final h = sheet.indexWhere(
          (r) => r.isNotEmpty && r.first?.value.toString() == 'Date');
      final row = sheet[h + 1];

      expect(row[0]!.value, isA<DateCellValue>());
      expect(row[4]!.value, isA<DateTimeCellValue>());
      expect(row[5]!.value, isA<DateTimeCellValue>());
      final hours = row[8]!.value;
      final asNum = hours is DoubleCellValue
          ? hours.value
          : (hours as IntCellValue).value.toDouble();
      expect(asNum, closeTo(440 / 60, 1e-9));
      expect(row[8]!.cellStyle?.numberFormat.formatCode, '0.00');
      expect(row[6]!.value.toString(), '0');
    });

    test('PDF: 10 staff × 93 days → capped at 500 rows, file still builds',
        () async {
      final staff = [for (var i = 0; i < 10; i++) 'Staff $i'];
      final c = calc(const [],
          from: DateTime(2026, 8, 24),
          periodEnd: DateTime(2026, 11, 24),
          active: staff);
      final rows = c.dayRows();
      expect(c.days, hasLength(93));
      expect(rows, hasLength(930));
      expect(ReportExportService.pdfRows(rows), hasLength(500),
          reason: 'over the cap: the PDF adds its "Showing first 500 of 930" '
              'notice (wasTruncated = rows > maxPdfRows)');
      expect(rows.length > ReportExportService.maxPdfRows, isTrue);

      final bytes = await ReportExportService.buildPdfBytesForTesting(
        headers: AttendanceReportCalc.dayHeaders,
        data: rows,
        fontBytes: Uint8List.fromList(
            File('assets/fonts/Poppins-Regular.ttf').readAsBytesSync()),
        fontBoldBytes: Uint8List.fromList(
            File('assets/fonts/Poppins-Bold.ttf').readAsBytesSync()),
        summary: {'Rows': '930'},
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
