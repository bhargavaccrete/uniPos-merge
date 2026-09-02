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

/// GRN REPORT — every confirmed goods receipt.
///
/// The row mixes two sources on purpose: ordered / received / value come from
/// the GRN HEADER, while accepted and damaged come from its LINE items —
/// `GRNModel` has no accepted-quantity field. Both are folded from the same
/// receiving list when the GRN is written, so `received == accepted + damaged`
/// holds by construction and is pinned here.
///
/// `totalAmount` is `receivedQty * costPrice`: the supplier's invoice value,
/// damaged units INCLUDED. It is not an accepted-goods figure.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 11, 12, 10);
  final windowStart = DateTime(2026, 11, 1);
  final windowEnd = DateTime(2026, 12, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('grn_report_');
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
    String supplierId = 'SUP-1',
    double orderedQty = 10,
    double receivedQty = 10,
    double? amount = 1000,
    String? invoiceNumber = 'INV-1',
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
        supplierId: supplierId,
        supplierName: supplierName,
        receivedDate: iso,
        totalOrderedQty: orderedQty,
        totalReceivedQty: receivedQty,
        totalAmount: amount,
        status: status.name,
        invoiceNumber: invoiceNumber,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  /// A GRN line. `damagedQty` is nullable in the model, so null is seeded
  /// deliberately in one case.
  Future<void> seedItem(
    String id, {
    required String grnId,
    double orderedQty = 10,
    double receivedQty = 10,
    double acceptedQty = 10,
    double? damagedQty = 0,
    double costPrice = 100,
  }) async {
    await Hive.box<GRNItemModel>(HiveBoxNames.grnItems).put(
      id,
      GRNItemModel(
        grnItemId: id,
        grnId: grnId,
        poItemId: 'POI-$id',
        variantId: 'V-1',
        productId: 'P-1',
        productName: 'Widget',
        orderedQty: orderedQty,
        receivedQty: receivedQty,
        acceptedQty: acceptedQty,
        damagedQty: damagedQty,
        costPrice: costPrice,
        totalAmount: receivedQty * costPrice,
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
    return ReportService().getGRNReport(
      startDate: start ?? windowStart,
      endDate: end ?? windowEnd,
    );
  }

  double num_(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  List<String> ids(List<Map<String, dynamic>> rows) =>
      rows.map((r) => r['grnId'] as String).toList();

  /// The screen's own summary folds, after the G-1 fix.
  double sumQty(List<Map<String, dynamic>> rows, String key) =>
      rows.fold<double>(0, (s, r) => s + (r[key] as num).toDouble());

  // ── G-1: the type contract ─────────────────────────────────────────────

  test('G-1 acceptedQty and damagedQty are ALWAYS doubles', () async {
    // With items — the case that used to throw.
    await seedGRN('GRN-1');
    await seedItem('IT-1', grnId: 'GRN-1', acceptedQty: 8, damagedQty: 2);
    // With NO items — the `?? 0` path that used to yield an int literal.
    await seedGRN('GRN-EMPTY', at: DateTime(2026, 11, 13));

    final rows = await report();
    expect(rows.length, 2);
    for (final row in rows) {
      expect(row['acceptedQty'], isA<double>(),
          reason: 'the screen folds this as a double');
      expect(row['damagedQty'], isA<double>());
    }

    final empty = rows.firstWhere((r) => r['grnId'] == 'GRN-EMPTY');
    expect(num_(empty, 'acceptedQty'), 0.0);
    expect(num_(empty, 'damagedQty'), 0.0);

    // The screen's folds — these threw a TypeError before the fix.
    expect(() => sumQty(rows, 'acceptedQty'), returnsNormally);
    expect(sumQty(rows, 'acceptedQty'), 8.0);
    expect(sumQty(rows, 'damagedQty'), 2.0);
  });

  test('a null damagedQty on a line reads as zero', () async {
    await seedGRN('GRN-1');
    await seedItem('IT-1', grnId: 'GRN-1', acceptedQty: 10, damagedQty: null);

    final rows = await report();
    expect(num_(rows.single, 'damagedQty'), 0.0);
    expect(rows.single['damagedQty'], isA<double>());
  });

  // ── The row invariant ──────────────────────────────────────────────────

  test('received equals accepted plus damaged, across several lines',
      () async {
    await seedGRN('GRN-1', orderedQty: 20, receivedQty: 18, amount: 1800);
    await seedItem('IT-1',
        grnId: 'GRN-1', receivedQty: 10, acceptedQty: 9, damagedQty: 1);
    await seedItem('IT-2',
        grnId: 'GRN-1', receivedQty: 8, acceptedQty: 6, damagedQty: 2);

    final r = (await report()).single;
    expect(num_(r, 'orderedQty'), 20.0);
    expect(num_(r, 'receivedQty'), 18.0);
    expect(num_(r, 'acceptedQty'), 15.0);
    expect(num_(r, 'damagedQty'), 3.0);
    expect(num_(r, 'acceptedQty') + num_(r, 'damagedQty'),
        num_(r, 'receivedQty'));
  });

  test('items belonging to another GRN never leak in', () async {
    await seedGRN('GRN-1');
    await seedGRN('GRN-2', at: DateTime(2026, 11, 13));
    await seedItem('IT-1', grnId: 'GRN-1', acceptedQty: 7, damagedQty: 3);
    await seedItem('IT-2', grnId: 'GRN-2', acceptedQty: 4, damagedQty: 6);

    final rows = await report();
    final g1 = rows.firstWhere((r) => r['grnId'] == 'GRN-1');
    final g2 = rows.firstWhere((r) => r['grnId'] == 'GRN-2');
    expect(num_(g1, 'acceptedQty'), 7.0);
    expect(num_(g2, 'acceptedQty'), 4.0);
  });

  // ── G-3: what `totalAmount` actually is ────────────────────────────────

  test('G-3 value is the invoice total, damaged units INCLUDED', () async {
    // 10 received at 100, of which 2 damaged → the supplier still bills 1000.
    await seedGRN('GRN-1', receivedQty: 10, amount: 1000);
    await seedItem('IT-1',
        grnId: 'GRN-1',
        receivedQty: 10,
        acceptedQty: 8,
        damagedQty: 2,
        costPrice: 100);

    final r = (await report()).single;
    expect(num_(r, 'totalAmount'), 1000.0,
        reason: 'NOT 800 — this is not an accepted-goods figure');
    expect(num_(r, 'acceptedQty'), 8.0);
  });

  // ── G-2: quantity formatting ───────────────────────────────────────────

  test('G-2 decimal quantities survive and format correctly', () async {
    await seedGRN('GRN-1', orderedQty: 10, receivedQty: 2.5, amount: 250);
    await seedItem('IT-1',
        grnId: 'GRN-1', receivedQty: 2.5, acceptedQty: 2.5, damagedQty: 0);

    final r = (await report()).single;
    expect(num_(r, 'receivedQty'), 2.5);
    expect(num_(r, 'acceptedQty'), 2.5);

    expect(formatQty(num_(r, 'orderedQty')), '10');
    expect(formatQty(num_(r, 'receivedQty')), '2.5');
    expect(formatQty(num_(r, 'acceptedQty')), '2.5');
    expect(formatQty(num_(r, 'damagedQty')), '0');
    // A `num`, so Excel keeps a numeric cell; integral when whole.
    expect(exportQty(num_(r, 'orderedQty')), 10);
    expect(exportQty(num_(r, 'orderedQty')), isA<int>());
    expect(exportQty(num_(r, 'receivedQty')), 2.5);
  });

  // ── Filtering ──────────────────────────────────────────────────────────

  test('a draft GRN is excluded entirely', () async {
    await seedGRN('GRN-OK', amount: 400);
    await seedGRN('GRN-DRAFT',
        status: GRNStatus.draft, amount: 9999, at: DateTime(2026, 11, 13));
    await seedItem('IT-1', grnId: 'GRN-DRAFT', acceptedQty: 99);

    final rows = await report();
    expect(ids(rows), ['GRN-OK']);
  });

  test('a cancelled GRN is excluded entirely', () async {
    await seedGRN('GRN-OK', amount: 400);
    await seedGRN('GRN-X',
        status: GRNStatus.cancelled, amount: 9999, at: DateTime(2026, 11, 13));

    final rows = await report();
    expect(ids(rows), ['GRN-OK']);
  });

  test('filtered on receivedDate: inclusive start, exclusive end', () async {
    await seedGRN('GRN-START', at: DateTime(2026, 11, 1));
    await seedGRN('GRN-LAST', at: DateTime(2026, 11, 30, 23, 59, 59));
    await seedGRN('GRN-OUT', at: DateTime(2026, 12, 1));

    final rows = await report();
    expect(ids(rows).toSet(), {'GRN-START', 'GRN-LAST'},
        reason: '1 December is the exclusive end');
  });

  test('the history cutoff applies', () async {
    final now = DateTime.now();
    await seedGRN('GRN-RECENT', at: now.subtract(const Duration(days: 2)));
    await seedGRN('GRN-ANCIENT', at: now.subtract(const Duration(days: 400)));

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
    expect(ids(rows), ['GRN-RECENT']);
  });

  test('A1 receipts on the same date order by grnId, and stay stable',
      () async {
    // `_confirmedGRNs` sorts receivedDate DESC; several receipts confirmed in
    // one instant tied, and `List.sort` is not stable in Dart. The GRN Report
    // is the only consumer that inherits this order — Supplier-wise and
    // Damaged Items sort their own rows, Purchase Summary only folds.
    final tied = DateTime(2026, 11, 10);
    await seedGRN('GRN-TIE-C', at: tied);
    await seedGRN('GRN-TIE-A', at: tied);
    await seedGRN('GRN-TIE-B', at: tied);
    await seedGRN('GRN-NEW', at: DateTime(2026, 11, 20));
    await seedGRN('GRN-OLD', at: DateTime(2026, 11, 2));

    const expected = [
      'GRN-NEW',
      'GRN-TIE-A',
      'GRN-TIE-B',
      'GRN-TIE-C',
      'GRN-OLD',
    ];
    expect(ids(await report()), expected);
    // An unstable sort passes once by luck.
    for (var i = 0; i < 3; i++) {
      expect(ids(await report()), expected);
    }
  });

  test('an empty period returns no rows', () async {
    expect(await report(), isEmpty);
  });

  // ── Supplier ───────────────────────────────────────────────────────────

  test('the GRN snapshot names the supplier, never the live record', () async {
    // The master record has been renamed since the receipt.
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

    final rows = await report();
    expect(rows.single['supplierName'], 'Old Name');
  });

  test('a missing supplier name reads as Unknown Supplier', () async {
    await seedGRN('GRN-1', supplierName: null);

    final rows = await report();
    expect(rows.single['supplierName'], 'Unknown Supplier');
  });

  test('CURRENT BEHAVIOUR: a whitespace-only supplier name is not guarded',
      () async {
    // Documented, NOT endorsed. Supplier-wise and the PO status reports trim
    // this; the GRN report does not yet, so a blank name renders an empty cell.
    // Pinned so the inconsistency is visible rather than forgotten.
    await seedGRN('GRN-1', supplierName: '   ');

    final rows = await report();
    expect(rows.single['supplierName'], '   ');
  });

  // ── Reconciliation ─────────────────────────────────────────────────────

  test('R value and quantity reconcile with Purchase Summary and Supplier-wise',
      () async {
    await seedGRN('GRN-1',
        supplierId: 'SUP-A', receivedQty: 10, amount: 1000);
    await seedGRN('GRN-2',
        supplierId: 'SUP-A',
        receivedQty: 5.5,
        amount: 550,
        at: DateTime(2026, 11, 14));
    await seedGRN('GRN-3',
        supplierId: 'SUP-B',
        receivedQty: 7,
        amount: 700,
        at: DateTime(2026, 11, 15));
    await seedGRN('GRN-DRAFT',
        status: GRNStatus.draft, amount: 9999, at: DateTime(2026, 11, 16));

    final rows = await report();
    final summary = await ReportService()
        .getPurchaseSummaryReport(startDate: windowStart, endDate: windowEnd);
    final supplierWise = await ReportService().getSupplierWisePurchaseReport(
        startDate: windowStart, endDate: windowEnd);

    double round(double v) => double.parse(v.toStringAsFixed(2));
    final grnValue = round(sumQty(rows, 'totalAmount'));
    final grnQty = round(sumQty(rows, 'receivedQty'));

    // All three read `_confirmedGRNs` with one filter, so these must be equal.
    expect(grnValue, num_(summary, 'receivedValue'));
    expect(grnQty, num_(summary, 'receivedQty'));
    expect(rows.length, summary['receiptCount']);
    expect(grnValue,
        round(supplierWise.fold<double>(0, (s, r) => s + num_(r, 'totalAmount'))));
    expect(grnQty,
        round(supplierWise.fold<double>(0, (s, r) => s + num_(r, 'totalItems'))));

    // Pinned absolutely, so a shared regression cannot move them together.
    expect(grnValue, 2250.0);
    expect(grnQty, 22.5);
    expect(rows.length, 3);
  });
}
