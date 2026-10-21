import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// STOCK ADJUSTMENTS — manual stock corrections, with their real quantities.
///
/// The defect this file exists for: the report called `.toInt()` on every
/// quantity, so a 2.5 kg correction was reported as 2. Silently — the screen's
/// `as int` casts never threw, because the truncation had already happened.
/// `StockMovementModel.quantity` and `balanceAfter` are `double`, and the
/// adjustment dialog lets a loose-goods variant type a fractional amount, so
/// the loss was reachable through the normal UI.
///
/// It also broke the row's own arithmetic: `balanceBefore` is derived from the
/// two doubles, so truncating all three separately let Before + Change
/// disagree with After.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 6, 15, 10);
  final windowStart = DateTime(2026, 6, 1);
  final windowEnd = DateTime(2026, 7, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('stock_adj_report_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);

    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// One recorded correction. [quantity] is always positive; [isIn] is the
  /// direction, exactly as `StockAdjustmentService` writes it.
  Future<void> seed(
    String id, {
    required bool isIn,
    required double quantity,
    required double balanceAfter,
    String unit = 'pcs',
    String itemName = 'Widget',
    // A real adjustment label — the report keeps only those (R-13).
    String reason = 'Stock count correction',
    String staffName = 'Admin',
    String? note,
    DateTime? at,
  }) async {
    await Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
        .put(
      id,
      StockMovementModel(
        id: id,
        timestamp: at ?? day,
        itemId: 'P-1',
        variantId: 'V-1',
        itemName: itemName,
        type: isIn ? 'in' : 'out',
        quantity: quantity,
        balanceAfter: balanceAfter,
        reason: reason,
        note: note,
        unit: unit,
        staffName: staffName,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> report({
    DateTime? start,
    DateTime? end,
  }) =>
      ReportService().getStockAdjustmentReport(
        startDate: start ?? windowStart,
        endDate: end ?? windowEnd,
      );

  double n(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  List<String> ids(List<Map<String, dynamic>> rows) =>
      rows.map((r) => r['itemName'] as String).toList();

  /// The screen's own cards, after SA-5: counts, never summed quantities.
  int addedCount(List<Map<String, dynamic>> rows) =>
      rows.where((r) => r['isIn'] as bool).length;
  int removedCount(List<Map<String, dynamic>> rows) =>
      rows.where((r) => !(r['isIn'] as bool)).length;

  // ── SA-1: decimals survive ─────────────────────────────────────────────

  test('SA-1 a 2.5 kg increase reports 2.5, not 2', () async {
    await seed('M-1', isIn: true, quantity: 2.5, balanceAfter: 12.5, unit: 'kg');

    final r = (await report()).single;
    expect(n(r, 'quantity'), 2.5);
    expect(n(r, 'signedQuantity'), 2.5);
    expect(n(r, 'balanceAfter'), 12.5);
    expect(n(r, 'balanceBefore'), 10.0);
  });

  test('SA-1 a 0.75 decrease reports -0.75', () async {
    await seed('M-1',
        isIn: false, quantity: 0.75, balanceAfter: 9.25, unit: 'kg');

    final r = (await report()).single;
    expect(n(r, 'quantity'), 0.75);
    expect(n(r, 'signedQuantity'), -0.75);
    expect(n(r, 'balanceBefore'), 10.0);
  });

  test('SA-1 every quantity field is a double', () async {
    await seed('M-1', isIn: true, quantity: 3, balanceAfter: 13);

    final r = (await report()).single;
    for (final k in [
      'quantity',
      'signedQuantity',
      'balanceBefore',
      'balanceAfter',
    ]) {
      expect(r[k], isA<double>(), reason: k);
      // The exact cast the screen used to run against a truncated value.
      expect(() => r[k] as int, throwsA(isA<TypeError>()), reason: k);
    }
  });

  test('SA-1 formatting: whole reads clean, fractional keeps its decimals',
      () async {
    await seed('M-WHOLE', isIn: true, quantity: 3, balanceAfter: 13);
    await seed('M-FRAC',
        isIn: true,
        quantity: 2.5,
        balanceAfter: 12.5,
        at: DateTime(2026, 6, 16));

    final rows = await report();
    final whole = rows.firstWhere((r) => n(r, 'quantity') == 3);
    final frac = rows.firstWhere((r) => n(r, 'quantity') == 2.5);

    expect(formatQty(n(whole, 'quantity')), '3');
    expect(formatQty(n(frac, 'quantity')), '2.5');
    // Export cells stay numeric; integral when whole, so no trailing ".0".
    expect(exportQty(n(whole, 'quantity')), 3);
    expect(exportQty(n(whole, 'quantity')), isA<int>());
    expect(exportQty(n(frac, 'quantity')), 2.5);
  });

  // ── SA-2: the row reconciles ───────────────────────────────────────────

  test('SA-2 before + change == after, for whole and fractional alike',
      () async {
    await seed('M-INT', isIn: true, quantity: 5, balanceAfter: 15);
    await seed('M-FRAC',
        isIn: true,
        quantity: 2.7,
        balanceAfter: 10.5,
        at: DateTime(2026, 6, 16));
    await seed('M-OUT',
        isIn: false,
        quantity: 1.25,
        balanceAfter: 8.75,
        at: DateTime(2026, 6, 17));

    for (final r in await report()) {
      expect(n(r, 'balanceBefore') + n(r, 'signedQuantity'),
          closeTo(n(r, 'balanceAfter'), 1e-9),
          reason: r['itemName'] as String);
    }

    // The case that used to break: 10.5 - 2.7 = 7.8, truncated to 7, while
    // change truncated to 2 and after to 10 — so 7 + 2 read as 9, not 10.
    final frac = (await report()).firstWhere((r) => n(r, 'quantity') == 2.7);
    expect(n(frac, 'balanceBefore'), closeTo(7.8, 1e-9));
  });

  // ── Sign convention ────────────────────────────────────────────────────

  test('an increase is positive and isIn, a decrease is negative', () async {
    await seed('M-IN', isIn: true, quantity: 4, balanceAfter: 14);
    await seed('M-OUT',
        isIn: false,
        quantity: 3,
        balanceAfter: 11,
        at: DateTime(2026, 6, 16));

    final rows = await report();
    final inRow = rows.firstWhere((r) => r['isIn'] == true);
    final outRow = rows.firstWhere((r) => r['isIn'] == false);

    expect(n(inRow, 'signedQuantity'), 4.0);
    expect(n(outRow, 'signedQuantity'), -3.0);
    expect(n(inRow, 'quantity'), 4.0, reason: 'quantity is always positive');
    expect(n(outRow, 'quantity'), 3.0);
  });

  // ── SA-3: the unit ─────────────────────────────────────────────────────

  test('SA-3 the movement unit is carried through and rendered', () async {
    await seed('M-KG',
        isIn: true, quantity: 2.5, balanceAfter: 12.5, unit: 'kg');

    final r = (await report()).single;
    expect(r['unit'], 'kg');
    expect(formatQtyWithUnit(n(r, 'quantity'), r['unit'] as String), '2.5 kg');
  });

  test('SA-3 a blank unit renders as a bare number', () async {
    await seed('M-PCS', isIn: true, quantity: 3, balanceAfter: 13, unit: '');

    final r = (await report()).single;
    expect(formatQtyWithUnit(n(r, 'quantity'), r['unit'] as String?), '3');
  });

  // ── SA-4: deterministic order ──────────────────────────────────────────

  test('SA-4 movements sharing a timestamp order by id, and stay stable',
      () async {
    // A stock take applies many adjustments in one loop, so ties are routine.
    final tied = DateTime(2026, 6, 10, 9);
    await seed('M-C', isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'C', at: tied);
    await seed('M-A', isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'A', at: tied);
    await seed('M-B', isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'B', at: tied);
    await seed('M-NEW', isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'NEW', at: DateTime(2026, 6, 20));

    const expected = ['NEW', 'A', 'B', 'C'];
    expect(ids(await report()), expected);
    // An unstable sort passes once by luck.
    for (var i = 0; i < 3; i++) {
      expect(ids(await report()), expected);
    }
  });

  // ── SA-5: counts, never summed quantities ──────────────────────────────

  test('SA-5 the cards count adjustments, they do not sum quantities',
      () async {
    // Two increases in DIFFERENT units. Summing them would produce "5.5",
    // mixing kilograms and pieces into a number that means nothing.
    await seed('M-KG',
        isIn: true, quantity: 2.5, balanceAfter: 12.5, unit: 'kg');
    await seed('M-PCS',
        isIn: true,
        quantity: 3,
        balanceAfter: 13,
        unit: 'pcs',
        at: DateTime(2026, 6, 16));
    await seed('M-OUT',
        isIn: false,
        quantity: 1,
        balanceAfter: 12,
        unit: 'pcs',
        at: DateTime(2026, 6, 17));

    final rows = await report();
    expect(addedCount(rows), 2, reason: 'two increases, not 5.5 units');
    expect(removedCount(rows), 1);
    expect(rows.length, 3);

    // Guard the intent: the old figure would have been 5.5.
    final oldStyleSum = rows
        .where((r) => r['isIn'] as bool)
        .fold<double>(0, (s, r) => s + n(r, 'quantity'));
    expect(oldStyleSum, 5.5);
    expect(addedCount(rows), isNot(oldStyleSum.toInt()),
        reason: 'the card must not report a mixed-unit quantity');
  });

  test('SA-5 counts with no adjustments in a direction', () async {
    await seed('M-1', isIn: true, quantity: 2, balanceAfter: 12);

    final rows = await report();
    expect(addedCount(rows), 1);
    expect(removedCount(rows), 0);
  });

  // ── Window and empty state ─────────────────────────────────────────────

  test('inclusive start, exclusive end on the movement timestamp', () async {
    await seed('M-START',
        isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'START', at: DateTime(2026, 6, 1));
    await seed('M-LAST',
        isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'LAST', at: DateTime(2026, 6, 30, 23, 59, 59));
    await seed('M-OUT',
        isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'OUT', at: DateTime(2026, 7, 1));

    expect(ids(await report()).toSet(), {'START', 'LAST'},
        reason: '1 July is the exclusive end');
  });

  test('the history cutoff applies', () async {
    final now = DateTime.now();
    await seed('M-RECENT',
        isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'RECENT', at: now.subtract(const Duration(days: 2)));
    await seed('M-ANCIENT',
        isIn: true, quantity: 1, balanceAfter: 1,
        itemName: 'ANCIENT', at: now.subtract(const Duration(days: 400)));

    Entitlements.instance.loadFromManifest(
      ManifestData(
        entitlements: {RetailEntKeys.reportsHistoryLimitDays: 30},
        license: const {},
        version: 1,
      ),
    );

    final rows = await report(
      start: now.subtract(const Duration(days: 500)),
      end: now.add(const Duration(days: 1)),
    );
    expect(ids(rows), ['RECENT']);
  });

  test('an empty period returns no rows', () async {
    expect(await report(), isEmpty);
  });

  // ── Export parity ──────────────────────────────────────────────────────

  test('the export carries the same values as the screen, row for row',
      () async {
    await seed('M-1',
        isIn: false,
        quantity: 1.5,
        balanceAfter: 8.5,
        unit: 'kg',
        note: 'spillage');

    final r = (await report()).single;
    // Both surfaces read the same row map — no recomputation on either side.
    expect(formatQtyWithUnit(n(r, 'balanceBefore'), r['unit'] as String),
        '10 kg');
    expect(exportQty(n(r, 'balanceBefore')), 10);
    expect(formatQtyWithUnit(n(r, 'signedQuantity'), r['unit'] as String),
        '-1.5 kg');
    expect(exportQty(n(r, 'signedQuantity')), -1.5);
    expect(r['note'], 'spillage');
    expect(r['unit'], 'kg');
  });

  test('a missing note is an empty string, never null', () async {
    await seed('M-1', isIn: true, quantity: 1, balanceAfter: 1, note: null);

    expect((await report()).single['note'], '');
  });

  test('the staff name and reason are carried through', () async {
    await seed('M-1',
        isIn: true,
        quantity: 1,
        balanceAfter: 1,
        reason: 'Damaged / Broken',
        staffName: 'Priya');

    final r = (await report()).single;
    expect(r['reason'], 'Damaged / Broken');
    expect(r['staffName'], 'Priya');
  });

  // ── R-13: adjustments only ─────────────────────────────────────────────

  test('R-13 sales, receipts, returns and other movements stay out', () async {
    // The shared box holds every kind of movement; only adjustment reasons
    // (incl. stock-take commits, which use the same labels) belong here.
    const others = [
      'Sale',
      'Sale (bundle: Combo)',
      'Opening stock',
      'Stock edited',
      'Goods received',
      'Return',
      'Exchange',
      'Assembly batch',
    ];
    for (var i = 0; i < others.length; i++) {
      await seed('X-$i',
          isIn: false, quantity: 1, balanceAfter: 1,
          itemName: others[i], reason: others[i]);
    }
    await seed('ADJ-1',
        isIn: false, quantity: 2, balanceAfter: 8,
        itemName: 'THEFT', reason: 'Theft / Shrinkage');
    await seed('ADJ-2',
        isIn: true, quantity: 1, balanceAfter: 9,
        itemName: 'COUNT', reason: 'Stock count correction',
        note: 'Stock take ST-00001');

    final rows = await report();
    expect(ids(rows).toSet(), {'THEFT', 'COUNT'});
    expect(removedCount(rows), 1, reason: 'a Sale must not count as removed');
  });
}
