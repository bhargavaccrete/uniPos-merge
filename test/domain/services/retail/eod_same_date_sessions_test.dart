import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/repositories/restaurant/eod_repository.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/store/restaurant/eod_store.dart';

/// Two closes on ONE calendar date must both survive.
///
/// `saveEODReport` replaces an existing record before writing, and picks the
/// record to replace by SESSION when there is one and by DATE when there is not.
/// Retail reports carried a null sessionId, so the date branch always ran: open
/// a second session on the same day, close it, and the first close was deleted —
/// its sales, its cash reconciliation and its safe drop gone with it.
void main() {
  late Directory tempDir;
  final day = DateTime(2026, 4, 15);

  setUp(() async {
    await locator.reset();
    tempDir = await Directory.systemTemp.createTemp('eod_sessions_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantEod)) {
      Hive.registerAdapter(EndOfDayReportAdapter());
      Hive.registerAdapter(OrderTypeSummaryAdapter());
      Hive.registerAdapter(CategorySalesAdapter());
      Hive.registerAdapter(PaymentSummaryAdapter());
      Hive.registerAdapter(CashReconciliationAdapter());
      Hive.registerAdapter(TaxSummaryAdapter());
    }
    // EodRepository picks its box from AppConfig, so the mode has to be set
    // before it is constructed.
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.retailEOD);
    locator.registerLazySingleton<EodStore>(() => EodStore(EodRepository()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EndOfDayReport report({
    required String id,
    String? sessionId,
    double counted = 0,
    DateTime? date,
  }) =>
      EndOfDayReport(
        reportId: id,
        date: date ?? day,
        openingBalance: 0,
        orderSummaries: const [],
        totalDiscount: 0,
        totalTax: 0,
        categorySales: const [],
        paymentSummaries: const [],
        cashReconciliation: CashReconciliation(
          systemExpectedCash: counted,
          actualCash: counted,
          difference: 0,
          reconciliationStatus: 'Balanced',
        ),
        totalSales: counted,
        closingBalance: counted,
        taxSummaries: const [],
        totalOrderCount: 0,
        totalRefunds: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        mode: 'retail',
        sessionId: sessionId,
      );

  Future<List<EndOfDayReport>> stored() async {
    await eodStore.loadEODReports();
    return eodStore.eodReports.toList();
  }

  test('two sessions closed on the same date are BOTH kept', () async {
    await EODService.saveEODReport(
      report(id: 'r-morning', sessionId: 's-morning', counted: 1000),
    );
    await EODService.saveEODReport(
      report(id: 'r-evening', sessionId: 's-evening', counted: 2000),
    );

    final all = await stored();
    expect(all.length, 2, reason: 'the morning close must not be deleted');
    expect(
      all.map((r) => r.reportId).toSet(),
      {'r-morning', 'r-evening'},
    );
    expect(
      all.map((r) => r.cashReconciliation.actualCash).toSet(),
      {1000.0, 2000.0},
    );
  });

  test('a retry of the SAME session replaces, it does not duplicate', () async {
    await EODService.saveEODReport(
      report(id: 'r-first', sessionId: 's-1', counted: 1000),
    );
    // Same session, corrected count — the cashier miscounted and closed again.
    await EODService.saveEODReport(
      report(id: 'r-second', sessionId: 's-1', counted: 1500),
    );

    final all = await stored();
    expect(all.length, 1);
    expect(all.single.reportId, 'r-second');
    expect(all.single.cashReconciliation.actualCash, 1500);
  });

  test('sessions on different dates never collide', () async {
    await EODService.saveEODReport(
      report(id: 'r-mon', sessionId: 's-mon', date: DateTime(2026, 4, 15)),
    );
    await EODService.saveEODReport(
      report(id: 'r-tue', sessionId: 's-tue', date: DateTime(2026, 4, 16)),
    );

    expect((await stored()).length, 2);
  });

  test('legacy records with no session still de-dup by date', () async {
    // The documented fallback: without a session there is no way to tell a
    // retry from a second close, and replacing is the safer of the two.
    await EODService.saveEODReport(report(id: 'r-old-1', counted: 1000));
    await EODService.saveEODReport(report(id: 'r-old-2', counted: 2000));

    final all = await stored();
    expect(all.length, 1);
    expect(all.single.reportId, 'r-old-2');
  });

  test('a new session does not overwrite a legacy same-date record', () async {
    await EODService.saveEODReport(report(id: 'r-legacy', counted: 1000));
    await EODService.saveEODReport(
      report(id: 'r-session', sessionId: 's-new', counted: 2000),
    );

    // The session lookup finds nothing to replace, so the legacy record stands.
    final all = await stored();
    expect(all.length, 2);
    expect(all.map((r) => r.reportId).toSet(), {'r-legacy', 'r-session'});
  });
}
