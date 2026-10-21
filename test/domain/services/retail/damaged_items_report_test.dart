import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/inventory_loss_model_178.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_item_model_175.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_item_model_177.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/domain/store/retail/supplier_store.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// DAMAGED ITEMS — goods that arrived damaged, one row per GRN LINE.
///
/// Three things this file establishes, each settled during the audit:
///
///   1. **There is no damage-event date.** Damage is written as part of the GRN
///      at receiving, so `grn.receivedDate` is the only date and the basis is
///      unambiguous.
///   2. **Damaged units ARE billed.** `damagedAmount` is the damaged portion at
///      cost; the receipt still accrues the full received value.
///   3. **`damagedHandling` partitions damage** into mutually exclusive
///      return / claim / write-off outcomes.
///
/// Cases marked CURRENT BEHAVIOUR are documentation, not endorsement.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 9, 15, 10);
  final windowStart = DateTime(2026, 9, 1);
  final windowEnd = DateTime(2026, 10, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('damaged_items_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<PurchaseOrderModel>(HiveBoxNames.purchaseOrders);
    await Hive.openBox<PurchaseOrderItemModel>(
        HiveBoxNames.purchaseOrderItems);
    await Hive.openBox<GRNModel>(HiveBoxNames.grns);
    await Hive.openBox<GRNItemModel>(HiveBoxNames.grnItems);
    await Hive.openBox<SupplierModel>(HiveBoxNames.suppliers);
    await Hive.openBox<PurchaseReturnModel>(HiveBoxNames.purchaseReturns);
    await Hive.openBox<PurchaseReturnItemModel>(
        HiveBoxNames.purchaseReturnItems);
    await Hive.openBox<SupplierClaimModel>(HiveBoxNames.supplierClaims);
    await Hive.openBox<SupplierClaimItemModel>(HiveBoxNames.supplierClaimItems);
    await Hive.openBox<InventoryLossModel>(HiveBoxNames.inventoryLosses);

    locator.registerLazySingleton<PurchaseOrderStore>(
        () => PurchaseOrderStore());
    locator.registerLazySingleton<DamagedGoodsStore>(() => DamagedGoodsStore());
    locator.registerLazySingleton<SupplierStore>(() => SupplierStore());
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedGRN(
    String id, {
    GRNStatus status = GRNStatus.confirmed,
    String? supplierName = 'Acme',
    double receivedQty = 10,
    double? amount = 1000,
    DateTime? at,
  }) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<GRNModel>(HiveBoxNames.grns).put(
      id,
      GRNModel(
        grnId: id,
        grnNumber: id,
        poId: 'PO-$id',
        poNumber: 'PO-$id',
        supplierId: 'SUP-1',
        supplierName: supplierName,
        receivedDate: iso,
        totalOrderedQty: receivedQty,
        totalReceivedQty: receivedQty,
        totalAmount: amount,
        status: status.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  /// A GRN line. `damagedAmount` mirrors how the receiving screen computes it:
  /// `damagedQty * costPrice`, or null when there is no cost price.
  Future<void> seedItem(
    String id, {
    required String grnId,
    String productName = 'Widget',
    double receivedQty = 10,
    double acceptedQty = 8,
    double? damagedQty = 2,
    double? costPrice = 100,
    DamagedHandling? handling = DamagedHandling.keepForClaim,
  }) async {
    final dmg = damagedQty ?? 0;
    await Hive.box<GRNItemModel>(HiveBoxNames.grnItems).put(
      id,
      GRNItemModel(
        grnItemId: id,
        grnId: grnId,
        poItemId: 'POI-$id',
        variantId: 'V-1',
        productId: 'P-1',
        productName: productName,
        orderedQty: receivedQty,
        receivedQty: receivedQty,
        acceptedQty: acceptedQty,
        damagedQty: damagedQty,
        damagedHandling: handling?.name,
        costPrice: costPrice,
        totalAmount: costPrice == null ? null : receivedQty * costPrice,
        damagedAmount:
            (costPrice != null && dmg > 0) ? dmg * costPrice : null,
        createdAt: day.toIso8601String(),
      ),
    );
  }

  Future<void> hydrate() async {
    await purchaseOrderStore.loadPurchaseOrders();
    await purchaseOrderStore.loadGRNs();
    await damagedGoodsStore.loadAll();
    await supplierStore.loadSuppliers();
  }

  Future<List<Map<String, dynamic>>> report({
    DateTime? start,
    DateTime? end,
  }) async {
    await hydrate();
    return ReportService().getDamagedItemsReport(
      startDate: start ?? windowStart,
      endDate: end ?? windowEnd,
    );
  }

  double num_(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  List<String> ids(List<Map<String, dynamic>> rows) =>
      rows.map((r) => r['grnItemId'] as String).toList();

  /// The screen's own summary fold, after the DI-1 fix.
  double sumQty(List<Map<String, dynamic>> rows) =>
      rows.fold<double>(0, (s, r) => s + (r['damagedQty'] as num).toDouble());

  // ── DI-1: the type contract ────────────────────────────────────────────

  test('DI-1 damagedQty is ALWAYS a double, and the screen fold works',
      () async {
    await seedGRN('GRN-1');
    await seedItem('IT-1', grnId: 'GRN-1', damagedQty: 2);
    await seedItem('IT-2', grnId: 'GRN-1', damagedQty: 1.5, acceptedQty: 8.5);

    final rows = await report();
    expect(rows.length, 2);
    for (final row in rows) {
      expect(row['damagedQty'], isA<double>());
      // The exact expression the screen used to run.
      expect(() => row['damagedQty'] as int, throwsA(isA<TypeError>()));
    }

    // The screen's summary and export folds — these threw before the fix.
    expect(() => sumQty(rows), returnsNormally);
    expect(sumQty(rows), 3.5);
  });

  test('DI-1 the default path also yields a double', () async {
    // A line whose damagedQty is null is filtered out entirely, so the `?? 0`
    // branch is unreachable in a row — but the fallback is a double either way,
    // so the column can never carry two runtime types.
    await seedGRN('GRN-1');
    await seedItem('IT-NONE', grnId: 'GRN-1', damagedQty: null);
    await seedItem('IT-ZERO', grnId: 'GRN-1', damagedQty: 0);
    await seedItem('IT-OK', grnId: 'GRN-1', damagedQty: 3);

    final rows = await report();
    expect(ids(rows), ['IT-OK'], reason: 'null and zero damage are not rows');
    expect(rows.single['damagedQty'], isA<double>());
  });

  // ── Rows and aggregation ───────────────────────────────────────────────

  test('one damaged item', () async {
    await seedGRN('GRN-1');
    await seedItem('IT-1', grnId: 'GRN-1', damagedQty: 2, costPrice: 100);

    final r = (await report()).single;
    expect(r['grnNumber'], 'GRN-1');
    expect(r['productName'], 'Widget');
    expect(num_(r, 'damagedQty'), 2.0);
    expect(num_(r, 'damagedAmount'), 200.0);
    expect(r['handling'], 'keepForClaim');
  });

  test('multiple damaged lines on ONE GRN produce multiple rows', () async {
    await seedGRN('GRN-1', receivedQty: 20);
    await seedItem('IT-1',
        grnId: 'GRN-1', productName: 'Widget', damagedQty: 2);
    await seedItem('IT-2', grnId: 'GRN-1', productName: 'Gizmo', damagedQty: 3);

    final rows = await report();
    expect(rows.length, 2, reason: 'line-level report, one row per line');
    expect(rows.every((r) => r['grnNumber'] == 'GRN-1'), isTrue);
    expect(sumQty(rows), 5.0);
  });

  test('multiple GRNs each contribute their own lines', () async {
    await seedGRN('GRN-1');
    await seedGRN('GRN-2', at: DateTime(2026, 9, 16));
    await seedItem('IT-1', grnId: 'GRN-1', damagedQty: 2);
    await seedItem('IT-2', grnId: 'GRN-2', damagedQty: 4);

    final rows = await report();
    expect(rows.length, 2);
    expect(sumQty(rows), 6.0);
    // Newest receipt first.
    expect(ids(rows), ['IT-2', 'IT-1']);
  });

  test('DI-2 decimal damaged quantity survives and formats correctly',
      () async {
    await seedGRN('GRN-1');
    await seedItem('IT-1',
        grnId: 'GRN-1',
        receivedQty: 10,
        acceptedQty: 7.5,
        damagedQty: 2.5,
        costPrice: 40);

    final r = (await report()).single;
    expect(num_(r, 'damagedQty'), 2.5);
    expect(num_(r, 'damagedAmount'), 100.0);

    expect(formatQty(num_(r, 'damagedQty')), '2.5');
    expect(formatQty(2.0), '2');
    // A `num`, so Excel keeps a numeric cell; integral when whole so the PDF
    // prints "2" rather than "2.0".
    expect(exportQty(2.0), 2);
    expect(exportQty(2.0), isA<int>());
    expect(exportQty(num_(r, 'damagedQty')), 2.5);
  });

  test('partial damage: received equals accepted plus damaged', () async {
    await seedGRN('GRN-1', receivedQty: 10);
    await seedItem('IT-1',
        grnId: 'GRN-1', receivedQty: 10, acceptedQty: 8, damagedQty: 2);

    final r = (await report()).single;
    expect(num_(r, 'damagedQty'), 2.0);

    final item = Hive.box<GRNItemModel>(HiveBoxNames.grnItems).get('IT-1')!;
    expect(item.acceptedQty + (item.damagedQty ?? 0), item.receivedQty);
  });

  test('all received units damaged', () async {
    await seedGRN('GRN-1', receivedQty: 10);
    await seedItem('IT-1',
        grnId: 'GRN-1',
        receivedQty: 10,
        acceptedQty: 0,
        damagedQty: 10,
        costPrice: 50);

    final r = (await report()).single;
    expect(num_(r, 'damagedQty'), 10.0);
    expect(num_(r, 'damagedAmount'), 500.0);
  });

  test('no damaged items returns an empty report', () async {
    await seedGRN('GRN-1');
    await seedItem('IT-1',
        grnId: 'GRN-1', acceptedQty: 10, damagedQty: 0, handling: null);

    expect(await report(), isEmpty);
  });

  test('damaged amount is damagedQty times costPrice', () async {
    await seedGRN('GRN-1');
    await seedItem('IT-1',
        grnId: 'GRN-1', damagedQty: 3, costPrice: 12.5);

    final r = (await report()).single;
    expect(num_(r, 'damagedAmount'), 37.5);
    expect(num_(r, 'costPrice'), 12.5);
    // The damaged PORTION only — the GRN header still bills the full receipt.
    final grn = Hive.box<GRNModel>(HiveBoxNames.grns).get('GRN-1')!;
    expect(grn.totalAmount, 1000.0);
  });

  // ── Documented current behaviour, deliberately not fixed ───────────────

  test('CURRENT BEHAVIOUR: a null costPrice yields zero damaged value',
      () async {
    // Documented, NOT endorsed. `damagedAmount` is null without a cost price
    // and the report reads it as `?? 0.0`, so the line shows quantity but no
    // value — understating the Value card.
    await seedGRN('GRN-1', amount: null);
    await seedItem('IT-1', grnId: 'GRN-1', damagedQty: 4, costPrice: null);

    final r = (await report()).single;
    expect(num_(r, 'damagedQty'), 4.0);
    expect(num_(r, 'damagedAmount'), 0.0);
  });

  test('CURRENT BEHAVIOUR: a line with no handling still appears', () async {
    // Documented, NOT endorsed. `recordFromGRN` requires a non-null handling to
    // raise a return/claim/loss, so this line is counted as damaged yet has no
    // downstream document.
    await seedGRN('GRN-1');
    await seedItem('IT-1', grnId: 'GRN-1', damagedQty: 2, handling: null);

    final r = (await report()).single;
    expect(num_(r, 'damagedQty'), 2.0);
    expect(r['handling'], isNull);
  });

  // ── GRN status ─────────────────────────────────────────────────────────

  test('a draft GRN contributes no damaged lines', () async {
    await seedGRN('GRN-DRAFT', status: GRNStatus.draft);
    await seedItem('IT-1', grnId: 'GRN-DRAFT', damagedQty: 9);

    expect(await report(), isEmpty);
  });

  test('a cancelled GRN contributes no damaged lines', () async {
    await seedGRN('GRN-X', status: GRNStatus.cancelled);
    await seedItem('IT-1', grnId: 'GRN-X', damagedQty: 9);

    expect(await report(), isEmpty);
  });

  // ── Window ─────────────────────────────────────────────────────────────

  test('filtered on receivedDate: inclusive start, exclusive end', () async {
    await seedGRN('GRN-START', at: DateTime(2026, 9, 1));
    await seedGRN('GRN-LAST', at: DateTime(2026, 9, 30, 23, 59, 59));
    await seedGRN('GRN-OUT', at: DateTime(2026, 10, 1));
    await seedItem('IT-START', grnId: 'GRN-START', damagedQty: 1);
    await seedItem('IT-LAST', grnId: 'GRN-LAST', damagedQty: 1);
    await seedItem('IT-OUT', grnId: 'GRN-OUT', damagedQty: 1);

    final rows = await report();
    expect(ids(rows).toSet(), {'IT-START', 'IT-LAST'},
        reason: '1 October is the exclusive end');
  });

  test('the history cutoff applies', () async {
    final now = DateTime.now();
    await seedGRN('GRN-RECENT', at: now.subtract(const Duration(days: 2)));
    await seedGRN('GRN-ANCIENT', at: now.subtract(const Duration(days: 400)));
    await seedItem('IT-RECENT', grnId: 'GRN-RECENT', damagedQty: 1);
    await seedItem('IT-ANCIENT', grnId: 'GRN-ANCIENT', damagedQty: 1);

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
    expect(ids(rows), ['IT-RECENT']);
  });

  test('an empty period returns no rows', () async {
    expect(await report(), isEmpty);
  });

  // ── Supplier ───────────────────────────────────────────────────────────

  test('the GRN snapshot names the supplier, never the live record', () async {
    await Hive.box<SupplierModel>(HiveBoxNames.suppliers).put(
      'SUP-1',
      SupplierModel(
        supplierId: 'SUP-1',
        name: 'New Name',
        createdAt: day.toIso8601String(),
        updatedAt: day.toIso8601String(),
      ),
    );
    await seedGRN('GRN-1', supplierName: 'Old Name');
    await seedItem('IT-1', grnId: 'GRN-1', damagedQty: 2);

    expect((await report()).single['supplierName'], 'Old Name');
  });

  test('a blank or missing supplier name reads as Unknown Supplier', () async {
    await seedGRN('GRN-BLANK', supplierName: '   ');
    await seedGRN('GRN-NULL',
        supplierName: null, at: DateTime(2026, 9, 16));
    await seedItem('IT-BLANK', grnId: 'GRN-BLANK', damagedQty: 1);
    await seedItem('IT-NULL', grnId: 'GRN-NULL', damagedQty: 1);

    final rows = await report();
    expect(rows.every((r) => r['supplierName'] == 'Unknown Supplier'), isTrue);
  });

  // ── DI-4: deterministic ordering ───────────────────────────────────────

  test('DI-4 ties on receivedDate break by grnItemId, and stay stable',
      () async {
    // Several damaged lines from ONE receipt all share the same date — the tie
    // is the norm here, not the exception.
    await seedGRN('GRN-1');
    await seedItem('IT-C', grnId: 'GRN-1', damagedQty: 1);
    await seedItem('IT-A', grnId: 'GRN-1', damagedQty: 1);
    await seedItem('IT-B', grnId: 'GRN-1', damagedQty: 1);
    // A newer receipt still sorts first.
    await seedGRN('GRN-2', at: DateTime(2026, 9, 20));
    await seedItem('IT-Z', grnId: 'GRN-2', damagedQty: 1);

    const expected = ['IT-Z', 'IT-A', 'IT-B', 'IT-C'];
    expect(ids(await report()), expected);
    // An unstable sort passes once by luck.
    for (var i = 0; i < 3; i++) {
      expect(ids(await report()), expected);
    }
  });

  // ── Reconciliation with the GRN Report ─────────────────────────────────

  test('R damaged quantity reconciles with the GRN Report for the same window',
      () async {
    await seedGRN('GRN-1', receivedQty: 20);
    await seedItem('IT-1',
        grnId: 'GRN-1', receivedQty: 10, acceptedQty: 8, damagedQty: 2);
    await seedItem('IT-2',
        grnId: 'GRN-1', receivedQty: 10, acceptedQty: 6.5, damagedQty: 3.5);

    await seedGRN('GRN-2', receivedQty: 5, at: DateTime(2026, 9, 18));
    await seedItem('IT-3',
        grnId: 'GRN-2', receivedQty: 5, acceptedQty: 4, damagedQty: 1);

    // Undamaged receipt — present in the GRN Report, absent here.
    await seedGRN('GRN-3', receivedQty: 8, at: DateTime(2026, 9, 19));
    await seedItem('IT-4',
        grnId: 'GRN-3', receivedQty: 8, acceptedQty: 8, damagedQty: 0);

    // Excluded from both.
    await seedGRN('GRN-DRAFT',
        status: GRNStatus.draft, at: DateTime(2026, 9, 20));
    await seedItem('IT-5', grnId: 'GRN-DRAFT', damagedQty: 99);

    final damagedRows = await report();
    final grnRows = await ReportService()
        .getGRNReport(startDate: windowStart, endDate: windowEnd);

    double round(double v) => double.parse(v.toStringAsFixed(3));
    final fromDamaged = round(sumQty(damagedRows));
    final fromGRN = round(
        grnRows.fold<double>(0, (s, r) => s + (r['damagedQty'] as num).toDouble()));

    // Both are `Σ item.damagedQty` over confirmed in-window GRNs.
    expect(fromDamaged, fromGRN);

    // Pinned absolutely, so a shared regression cannot move both together.
    expect(fromDamaged, 6.5);
    expect(damagedRows.length, 3, reason: 'three damaged LINES');
    expect(grnRows.length, 3, reason: 'three confirmed RECEIPTS');
    expect(
      damagedRows.map((r) => r['grnNumber']).toSet(),
      {'GRN-1', 'GRN-2'},
      reason: 'the undamaged receipt has no damaged lines',
    );
  });
}
