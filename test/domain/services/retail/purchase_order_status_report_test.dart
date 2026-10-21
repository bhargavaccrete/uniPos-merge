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
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// PURCHASE ORDER STATUS REPORTS — Pending / Partially Received / Completed.
///
/// One screen, three named constructors, one service method. The bucket is the
/// STORED `po.status`; the quantities beside it are computed live from confirmed
/// GRNs. This file pins the classification, the quantities, and the count
/// invariant against Purchase Summary.
///
/// It does NOT test when a PO *becomes* Completed — `_updatePOStatusAfterGRN`
/// is deliberately out of scope for this batch, so every PO here is seeded with
/// the status under test.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 10, 14, 10);
  final windowStart = DateTime(2026, 10, 1);
  final windowEnd = DateTime(2026, 11, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('po_status_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<PurchaseOrderModel>(HiveBoxNames.purchaseOrders);
    await Hive.openBox<PurchaseOrderItemModel>(
        HiveBoxNames.purchaseOrderItems);
    await Hive.openBox<GRNModel>(HiveBoxNames.grns);
    await Hive.openBox<GRNItemModel>(HiveBoxNames.grnItems);
    await Hive.openBox<PurchaseReturnModel>(HiveBoxNames.purchaseReturns);
    await Hive.openBox<PurchaseReturnItemModel>(
        HiveBoxNames.purchaseReturnItems);
    await Hive.openBox<SupplierClaimModel>(HiveBoxNames.supplierClaims);
    await Hive.openBox<SupplierClaimItemModel>(HiveBoxNames.supplierClaimItems);
    await Hive.openBox<InventoryLossModel>(HiveBoxNames.inventoryLosses);

    locator.registerLazySingleton<PurchaseOrderStore>(
        () => PurchaseOrderStore());
    locator.registerLazySingleton<DamagedGoodsStore>(() => DamagedGoodsStore());
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedPO(
    String id, {
    required POStatus status,
    double ordered = 10,
    double estimatedTotal = 1000,
    String? supplierName = 'Acme',
    DateTime? at,
  }) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).put(
      id,
      PurchaseOrderModel(
        poId: id,
        poNumber: id,
        supplierId: 'SUP-1',
        supplierName: supplierName,
        expectedDeliveryDate: iso,
        totalItems: ordered,
        estimatedTotal: estimatedTotal,
        status: status.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  Future<void> seedGRN(
    String id, {
    required String poId,
    GRNStatus status = GRNStatus.confirmed,
    double receivedQty = 4,
    double? amount = 400,
    DateTime? at,
  }) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<GRNModel>(HiveBoxNames.grns).put(
      id,
      GRNModel(
        grnId: id,
        grnNumber: id,
        poId: poId,
        poNumber: poId,
        supplierId: 'SUP-1',
        supplierName: 'Acme',
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

  Future<void> hydrate() async {
    await purchaseOrderStore.loadPurchaseOrders();
    await purchaseOrderStore.loadGRNs();
    await damagedGoodsStore.loadAll();
  }

  Future<List<Map<String, dynamic>>> statusReport(POStatus status,
      {DateTime? start, DateTime? end}) async {
    await hydrate();
    return ReportService().getPurchaseOrderStatusReport(
      status,
      startDate: start ?? windowStart,
      endDate: end ?? windowEnd,
    );
  }

  double num_(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  List<String> ids(List<Map<String, dynamic>> rows) =>
      rows.map((r) => r['poId'] as String).toList();

  /// The screen's own Units Awaited fold, after the C-1 fix.
  double awaited(List<Map<String, dynamic>> rows) =>
      rows.fold<double>(0, (s, r) => s + (r['remainingQty'] as num).toDouble());

  // ── Classification ─────────────────────────────────────────────────────

  test('Pending lists sent orders with nothing received', () async {
    await seedPO('PO-1', status: POStatus.sent, ordered: 10);

    final rows = await statusReport(POStatus.sent);
    expect(rows.length, 1);
    expect(num_(rows.single, 'orderedQty'), 10.0);
    expect(num_(rows.single, 'receivedQty'), 0.0);
    expect(num_(rows.single, 'remainingQty'), 10.0);
    expect(num_(rows.single, 'estimatedTotal'), 1000.0);
  });

  test('Partially Received shows progress against the order', () async {
    await seedPO('PO-1', status: POStatus.partiallyCompleted, ordered: 10);
    await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 4, amount: 400);

    final rows = await statusReport(POStatus.partiallyCompleted);
    expect(num_(rows.single, 'receivedQty'), 4.0);
    expect(num_(rows.single, 'remainingQty'), 6.0);
    expect(num_(rows.single, 'receivedValue'), 400.0);
  });

  test('Completed shows the full receipt and nothing remaining', () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted, ordered: 10);
    await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 10, amount: 1000);

    final rows = await statusReport(POStatus.fullyCompleted);
    expect(num_(rows.single, 'receivedQty'), 10.0);
    expect(num_(rows.single, 'remainingQty'), 0.0);
    expect(num_(rows.single, 'receivedValue'), 1000.0);
  });

  test('multiple partial receipts aggregate across GRNs', () async {
    await seedPO('PO-1', status: POStatus.partiallyCompleted, ordered: 10);
    await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 3, amount: 300);
    await seedGRN('GRN-2', poId: 'PO-1', receivedQty: 4, amount: 400);
    await seedGRN('GRN-3', poId: 'PO-1', receivedQty: 2, amount: 200);

    final rows = await statusReport(POStatus.partiallyCompleted);
    expect(num_(rows.single, 'receivedQty'), 9.0);
    expect(num_(rows.single, 'remainingQty'), 1.0);
    expect(num_(rows.single, 'receivedValue'), 900.0);
  });

  test('a GRN against another PO never leaks in', () async {
    await seedPO('PO-1', status: POStatus.partiallyCompleted, ordered: 10);
    await seedPO('PO-2', status: POStatus.partiallyCompleted, ordered: 10);
    await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 4);
    await seedGRN('GRN-2', poId: 'PO-2', receivedQty: 7);

    final rows = await statusReport(POStatus.partiallyCompleted);
    final po1 = rows.firstWhere((r) => r['poId'] == 'PO-1');
    final po2 = rows.firstWhere((r) => r['poId'] == 'PO-2');
    expect(num_(po1, 'receivedQty'), 4.0);
    expect(num_(po2, 'receivedQty'), 7.0);
  });

  // ── C-1: remainingQty type contract ────────────────────────────────────

  test('C-1 remainingQty is ALWAYS a double, including on over-receipt',
      () async {
    await seedPO('PO-NORMAL', status: POStatus.fullyCompleted, ordered: 10);
    await seedGRN('GRN-1', poId: 'PO-NORMAL', receivedQty: 10);
    await seedPO('PO-OVER', status: POStatus.fullyCompleted, ordered: 10);
    // Over-receipt: `num.clamp` used to hand back the int literal 0 here, so
    // the same column carried a double on one row and an int on the other.
    await seedGRN('GRN-2', poId: 'PO-OVER', receivedQty: 12);

    final rows = await statusReport(POStatus.fullyCompleted);
    expect(rows.length, 2);
    for (final row in rows) {
      expect(row['remainingQty'], isA<double>(),
          reason: 'the screen folds this as a double');
    }

    final over = rows.firstWhere((r) => r['poId'] == 'PO-OVER');
    expect(num_(over, 'remainingQty'), 0.0, reason: 'clamped, never negative');
    expect(num_(over, 'receivedQty'), 12.0, reason: 'the surplus is still shown');

    // The screen's fold — this threw a TypeError before the fix.
    expect(() => awaited(rows), returnsNormally);
    expect(awaited(rows), 0.0);
  });

  test('C-2 decimal quantities survive and format correctly', () async {
    await seedPO('PO-1', status: POStatus.partiallyCompleted, ordered: 10);
    await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 2.5);

    final rows = await statusReport(POStatus.partiallyCompleted);
    expect(num_(rows.single, 'receivedQty'), 2.5);
    expect(num_(rows.single, 'remainingQty'), 7.5);

    // What the screen renders and what the export writes.
    expect(formatQty(num_(rows.single, 'receivedQty')), '2.5');
    expect(formatQty(num_(rows.single, 'orderedQty')), '10');
    expect(formatQty(num_(rows.single, 'remainingQty')), '7.5');
    expect(exportQty(num_(rows.single, 'orderedQty')), 10);
    expect(exportQty(num_(rows.single, 'orderedQty')), isA<int>());
    expect(exportQty(num_(rows.single, 'receivedQty')), 2.5);
  });

  // ── Exclusions ─────────────────────────────────────────────────────────

  test('a draft PO appears in no bucket', () async {
    await seedPO('PO-DRAFT', status: POStatus.draft);

    expect(await statusReport(POStatus.sent), isEmpty);
    expect(await statusReport(POStatus.partiallyCompleted), isEmpty);
    expect(await statusReport(POStatus.fullyCompleted), isEmpty);
  });

  test('a cancelled PO appears in no bucket', () async {
    await seedPO('PO-X', status: POStatus.cancelled);

    expect(await statusReport(POStatus.sent), isEmpty);
    expect(await statusReport(POStatus.partiallyCompleted), isEmpty);
    expect(await statusReport(POStatus.fullyCompleted), isEmpty);
  });

  test('a draft GRN does not count towards received quantity', () async {
    await seedPO('PO-1', status: POStatus.sent, ordered: 10);
    await seedGRN('GRN-DRAFT',
        poId: 'PO-1', status: GRNStatus.draft, receivedQty: 6, amount: 600);

    final rows = await statusReport(POStatus.sent);
    expect(num_(rows.single, 'receivedQty'), 0.0);
    expect(num_(rows.single, 'remainingQty'), 10.0);
    expect(num_(rows.single, 'receivedValue'), 0.0);
  });

  test('a PO appears in exactly one bucket', () async {
    await seedPO('PO-S', status: POStatus.sent);
    await seedPO('PO-P', status: POStatus.partiallyCompleted);
    await seedPO('PO-F', status: POStatus.fullyCompleted);

    expect(ids(await statusReport(POStatus.sent)), ['PO-S']);
    expect(ids(await statusReport(POStatus.partiallyCompleted)), ['PO-P']);
    expect(ids(await statusReport(POStatus.fullyCompleted)), ['PO-F']);
  });

  // ── Reconciliation with Purchase Summary ───────────────────────────────

  test('R bucket counts equal Purchase Summary countByStatus', () async {
    await seedPO('PO-S1', status: POStatus.sent);
    await seedPO('PO-S2', status: POStatus.sent);
    await seedPO('PO-P1', status: POStatus.partiallyCompleted);
    await seedPO('PO-F1', status: POStatus.fullyCompleted);
    await seedPO('PO-F2', status: POStatus.fullyCompleted);
    await seedPO('PO-F3', status: POStatus.fullyCompleted);
    // Present, but in no bucket.
    await seedPO('PO-D', status: POStatus.draft);
    await seedPO('PO-C', status: POStatus.cancelled);

    final pending = await statusReport(POStatus.sent);
    final partial = await statusReport(POStatus.partiallyCompleted);
    final completed = await statusReport(POStatus.fullyCompleted);

    final summary = await ReportService()
        .getPurchaseSummaryReport(startDate: windowStart, endDate: windowEnd);
    final counts = summary['countByStatus'] as Map<String, int>;

    // The invariant.
    expect(pending.length, counts['sent']);
    expect(partial.length, counts['partiallyCompleted']);
    expect(completed.length, counts['fullyCompleted']);

    // Pinned absolutely, so a shared regression cannot move both together.
    expect(pending.length, 2);
    expect(partial.length, 1);
    expect(completed.length, 3);
    expect(counts['draft'], 1);
    expect(counts['cancelled'], 1);

    // Draft and cancelled are counted by Purchase Summary but bucketed nowhere.
    expect(pending.length + partial.length + completed.length, 6);
  });

  // ── Ordering ───────────────────────────────────────────────────────────

  test('newest first, ties broken by poId ascending, and stable', () async {
    await seedPO('PO-OLD', status: POStatus.sent, at: DateTime(2026, 10, 2));
    await seedPO('PO-NEW', status: POStatus.sent, at: DateTime(2026, 10, 20));
    // Same instant — the tie the unstable sort could not order.
    await seedPO('PO-TIE-Z',
        status: POStatus.sent, at: DateTime(2026, 10, 10));
    await seedPO('PO-TIE-A',
        status: POStatus.sent, at: DateTime(2026, 10, 10));

    const expected = ['PO-NEW', 'PO-TIE-A', 'PO-TIE-Z', 'PO-OLD'];
    expect(ids(await statusReport(POStatus.sent)), expected);
    // An unstable sort passes once by luck.
    for (var i = 0; i < 3; i++) {
      expect(ids(await statusReport(POStatus.sent)), expected);
    }
  });

  // ── Supplier ───────────────────────────────────────────────────────────

  test('D-d a whitespace-only supplier name reads as Unknown Supplier',
      () async {
    await seedPO('PO-1', status: POStatus.sent, supplierName: '   ');

    final rows = await statusReport(POStatus.sent);
    expect(rows.single['supplierName'], 'Unknown Supplier',
        reason: '`??` alone would have rendered an empty cell');
  });

  test('a missing supplier name reads as Unknown Supplier', () async {
    await seedPO('PO-1', status: POStatus.sent, supplierName: null);

    final rows = await statusReport(POStatus.sent);
    expect(rows.single['supplierName'], 'Unknown Supplier');
  });

  test('a deleted supplier still reports under the PO snapshot', () async {
    // No supplier master record is registered in this suite at all, so this
    // also proves the report never consults the live record.
    await seedPO('PO-1', status: POStatus.sent, supplierName: 'Gone Ltd');

    final rows = await statusReport(POStatus.sent);
    expect(rows.single['supplierName'], 'Gone Ltd');
  });

  // ── Window ─────────────────────────────────────────────────────────────

  test('filtered on PO createdAt: inclusive start, exclusive end', () async {
    await seedPO('PO-START', status: POStatus.sent, at: DateTime(2026, 10, 1));
    await seedPO('PO-LAST',
        status: POStatus.sent, at: DateTime(2026, 10, 31, 23, 59, 59));
    await seedPO('PO-OUT', status: POStatus.sent, at: DateTime(2026, 11, 1));

    final rows = await statusReport(POStatus.sent);
    expect(ids(rows), ['PO-LAST', 'PO-START'],
        reason: '1 November is the exclusive end');
  });

  test('received quantity is NOT date-filtered — it is a lifetime figure',
      () async {
    // Documented behaviour: the PO is period-filtered, its receipts are not.
    // This is why these reports cannot reconcile with Purchase Summary's
    // date-filtered receivedQty.
    await seedPO('PO-1',
        status: POStatus.partiallyCompleted,
        ordered: 10,
        at: DateTime(2026, 10, 5));
    await seedGRN('GRN-LATER',
        poId: 'PO-1', receivedQty: 4, at: DateTime(2026, 12, 20));

    final rows = await statusReport(POStatus.partiallyCompleted);
    expect(num_(rows.single, 'receivedQty'), 4.0,
        reason: 'a December receipt still counts on an October order');
  });

  test('the history cutoff applies', () async {
    final now = DateTime.now();
    await seedPO('PO-RECENT',
        status: POStatus.sent, at: now.subtract(const Duration(days: 2)));
    await seedPO('PO-ANCIENT',
        status: POStatus.sent, at: now.subtract(const Duration(days: 400)));

    Entitlements.instance.loadFromManifest(
      ManifestData(
        entitlements: {RetailEntKeys.reportsHistoryLimitDays: 30},
        license: const {},
        version: 1,
      ),
    );

    final rows = await statusReport(
      POStatus.sent,
      start: now.subtract(const Duration(days: 500)),
      end: now.add(const Duration(days: 1)),
    );
    expect(ids(rows), ['PO-RECENT']);
  });

  test('an empty period returns no rows', () async {
    expect(await statusReport(POStatus.sent), isEmpty);
  });
}
