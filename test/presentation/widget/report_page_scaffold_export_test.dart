import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';

import '../../helpers/backup_box_registry.dart';

/// ReportPageScaffold export is opt-in: without `rangedExport` (every Retail
/// screen) the export button opens the old format dialog exactly as before;
/// with it, the All / Current page / Date range dialog over the same rows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    dir = await Directory.systemTemp.createTemp('scaffold_export_');
    await initHiveForBackupTest(dir);
    locator.registerSingleton<LicenseStore>(
        LicenseStore(LicenseApiService())..licenseBypassed = true);
  });

  tearDownAll(() async {
    await locator.reset();
    await Hive.close();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {/* Windows handle release */}
  });

  // 60 rows over two days, so there are 2 pages.
  final rows = [
    for (var i = 0; i < 60; i++)
      {
        'name': 'Row $i',
        'date': DateTime(2026, 11, i < 30 ? 10 : 11, 9).toIso8601String(),
      }
  ];

  Future<void> pump(WidgetTester tester, {bool ranged = false, bool dates = true}) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    await tester.pumpWidget(MaterialApp(
      home: ReportPageScaffold(
        title: 'GRN Report',
        featureNoun: 'receipts',
        loader: (_, __) async => rows,
        summaryCards: (_) => const [],
        columns: (_) => const [DataColumn(label: Text('Name'))],
        rowBuilder: (_, r) => DataRow(cells: [DataCell(Text(r['name'] as String))]),
        emptyIcon: Icons.inbox,
        emptyTitle: 'Empty',
        emptyMessage: 'Nothing',
        rowUnit: 'receipts',
        exportFileName: 'grn',
        exportData: (list) => ReportExportData(
          headers: const ['Name'],
          rows: list.map((r) => [r['name']]).toList(),
          summary: {'Count': list.length.toString()},
        ),
        rangedExport: ranged,
        exportRowDate:
            dates ? (r) => DateTime.parse(r['date'] as String) : null,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Report').first);
    await tester.pumpAndSettle();
  }

  testWidgets('default (Retail and every screen not opting in): old dialog',
      (tester) async {
    await pump(tester);
    expect(find.text('Choose export format'), findsOneWidget);
    expect(find.text('What to export'), findsNothing);
  });

  testWidgets('opted in: All / Current page / Date range over the same rows',
      (tester) async {
    await pump(tester, ranged: true);
    expect(find.text('What to export'), findsOneWidget);
    expect(find.text('All filtered receipts (60)'), findsOneWidget);
    expect(find.text('Current page only (rows 1–50)'), findsOneWidget);
    expect(find.text('Custom date range'), findsOneWidget);
  });

  testWidgets('opted in without a row date: no date range option',
      (tester) async {
    await pump(tester, ranged: true, dates: false);
    expect(find.text('All filtered receipts (60)'), findsOneWidget);
    expect(find.text('Custom date range'), findsNothing);
  });
}
