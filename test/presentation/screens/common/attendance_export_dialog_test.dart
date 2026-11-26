import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/presentation/screens/common/attendance/attendance_export_dialog.dart';

/// Attendance export: period + layout choice. The month on screen is the
/// default (the original export); custom ranges are limited and validated.
void main() {
  final now = DateTime(2026, 11, 24, 18);
  final month = DateTime(2026, 11, 1);

  Future<AttendanceExportChoice?> open(
    WidgetTester tester,
    Future<void> Function() interact,
  ) async {
    AttendanceExportChoice? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showDialog<AttendanceExportChoice>(
                context: context,
                builder: (_) =>
                    AttendanceExportDialog(month: month, now: now),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await interact();
    return result;
  }

  testWidgets('default: the month on screen, summary layout', (tester) async {
    final result = await open(tester, () async {
      expect(find.text('November 2026 (on screen)'), findsOneWidget);
      expect(find.text('Exporting 24 days'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    });

    expect(result, isNotNull);
    expect(result!.isMonth, isTrue);
    expect(result.dayWise, isFalse);
    expect(result.from, DateTime(2026, 11, 1));
    expect(result.to, DateTime(2026, 11, 24), reason: 'runs to today');
  });

  testWidgets('day-wise layout is passed through', (tester) async {
    final result = await open(tester, () async {
      await tester.tap(find.text('Day-wise detail (shifts and absent days)'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    });
    expect(result!.dayWise, isTrue);
  });

  testWidgets('custom range without dates cannot continue', (tester) async {
    final result = await open(tester, () async {
      await tester.tap(find.textContaining('Custom range'));
      await tester.pump();
      expect(find.text('Pick the dates to export.'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceExportDialog), findsOneWidget,
          reason: 'still open');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
    expect(result, isNull);
  });

  group('range rules', () {
    test('up to 93 days, across months, is fine', () {
      expect(
          AttendanceExportDialog.rangeError(
              DateTime(2026, 8, 24), DateTime(2026, 11, 24), now),
          isNull);
      expect(
          AttendanceExportDialog.rangeDays(
              DateTime(2026, 8, 24), DateTime(2026, 11, 24)),
          93);
    });

    test('94 days is refused', () {
      expect(
          AttendanceExportDialog.rangeError(
              DateTime(2026, 8, 23), DateTime(2026, 11, 24), now),
          contains('93'));
    });

    test('an end date in the future is refused', () {
      expect(
          AttendanceExportDialog.rangeError(
              DateTime(2026, 11, 20), DateTime(2026, 11, 25), now),
          contains('future'));
    });
  });
}
