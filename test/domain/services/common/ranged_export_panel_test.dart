import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';

/// The export dialog: All is the default, the count follows the choice, the
/// page option shows the on-screen rows, and an empty range disables export.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 120 records over 30 days (4 a day), newest first.
  final items = List.generate(
      120, (i) => DateTime(2026, 11, 30, 18).subtract(Duration(hours: 6 * i)));

  Future<List<ExportSelection<DateTime>>> pump(WidgetTester tester,
      {int page = 1, List<DateTime>? list}) async {
    final exported = <ExportSelection<DateTime>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RangedExportPanel<DateTime>(
          items: list ?? items,
          dateOf: (d) => d,
          currentPage: page,
          rowsPerPage: 50,
          unit: 'orders',
          dateLabel: 'Date',
          onCancel: () {},
          onExport: (s, excel) => exported.add(s),
        ),
      ),
    ));
    return exported;
  }

  String countText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('exportCount'))).data!;

  testWidgets('All filtered is the default and exports every record',
      (tester) async {
    final exported = await pump(tester);
    expect(find.text('All filtered orders (120)'), findsOneWidget);
    expect(countText(tester), 'Exporting 120 orders');
    await tester.tap(find.text('Export to Excel'));
    expect(exported.single.rows.length, 120);
    expect(exported.single.label, isNull, reason: 'no extra label for All');
  });

  testWidgets('Current page shows the on-screen rows and exports only them',
      (tester) async {
    final exported = await pump(tester, page: 1);
    expect(find.text('Current page only (rows 51–100)'), findsOneWidget);
    await tester.tap(find.text('Current page only (rows 51–100)'));
    await tester.pump();
    expect(countText(tester), 'Exporting 50 orders');
    await tester.tap(find.text('Export to PDF'));
    expect(exported.single.rows, items.sublist(50, 100));
    expect(exported.single.label, 'Page 2 (rows 51–100)');
    expect(exported.single.fileSuffix, '_page2');
  });

  testWidgets('no page option when everything fits on one page',
      (tester) async {
    await pump(tester, page: 0, list: items.sublist(0, 30));
    expect(find.textContaining('Current page only'), findsNothing);
  });

  testWidgets('Custom date range: picker bounded to the filtered dates; '
      'count follows the range', (tester) async {
    final exported = await pump(tester);
    await tester.tap(find.text('Custom date range'));
    await tester.pumpAndSettle();
    // The picker opened with the whole filtered span; accept it.
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    final picker =
        tester.widget<DateRangePickerDialog>(find.byType(DateRangePickerDialog));
    expect(picker.firstDate, DateTime(2026, 11, 1));
    expect(picker.lastDate, DateTime(2026, 11, 30));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(countText(tester), 'Exporting 120 orders');
    await tester.tap(find.text('Export to Excel'));
    expect(exported.single.label, '01 Nov 2026 – 30 Nov 2026');
    expect(exported.single.fileSuffix, '_01Nov2026-30Nov2026');
  });

  testWidgets('an empty selection disables Excel and PDF', (tester) async {
    final exported = await pump(tester, page: 0, list: const []);
    expect(countText(tester), 'No orders in this range');
    await tester.tap(find.text('Export to Excel'));
    await tester.tap(find.text('Export to PDF'));
    expect(exported, isEmpty);
  });
}
