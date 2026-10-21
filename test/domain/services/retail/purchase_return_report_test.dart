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

/// PURCHASE RETURNS — goods sent back, and where each credit note stands.
///
/// Reads only `PurchaseReturnModel`; no GRNs, no items, no claims. Two things
/// this file establishes:
///
///   1. **The date basis is `returnDate`** — deliberately unlike every other
///      purchase report. That is why this report and Purchase Summary place the
///      same return in different periods, and it is not a defect.
///   2. **A return is money owed, not paperwork.** The GRN billed the damaged
///      units; the balance moves only when the credit note is recorded.
///
/// A cancelled return stays visible as history but is OUT of both the returned
/// VALUE and the returned UNITS: the goods never went back, which is why
/// `cancelPurchaseReturn` moves no supplier balance. Cases marked CURRENT BEHAVIOUR are documentation of
/// behaviour that has not been decided yet, not endorsement.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 7, 14, 10);
  final windowStart = DateTime(2026, 7, 1);
  final windowEnd = DateTime(2026, 8, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('purchase_returns_');
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

  Future<void> seedReturn(
    String id, {
    String grnId = 'GRN-1',
    String? supplierName = 'Acme',
    String supplierId = 'SUP-1',
    double totalQty = 2,
    double totalAmount = 200,
    String status = 'pending',
    String? creditNoteNumber,
    double? creditNoteAmount,
    DateTime? at,
    String? rawDate,
  }) async {
    final iso = rawDate ?? (at ?? day).toIso8601String();
    await Hive.box<PurchaseReturnModel>(HiveBoxNames.purchaseReturns).put(
      id,
      PurchaseReturnModel(
        returnId: id,
        returnNumber: id,
        grnId: grnId,
        grnNumber: grnId,
        poId: 'PO-$grnId',
        poNumber: 'PO-$grnId',
        supplierId: supplierId,
        supplierName: supplierName,
        returnDate: iso,
        totalQty: totalQty,
        totalAmount: totalAmount,
        status: status,
        creditNoteNumber: creditNoteNumber,
        creditNoteAmount: creditNoteAmount,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  /// A GRN line marked for return, used by the reconciliation test.
  Future<void> seedReturnLine(
    String id, {
    required String grnId,
    required double damagedQty,
    required double costPrice,
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
        orderedQty: 10,
        receivedQty: 10,
        acceptedQty: 10 - damagedQty,
        damagedQty: damagedQty,
        damagedHandling: DamagedHandling.returnToSupplier.name,
        costPrice: costPrice,
        totalAmount: 10 * costPrice,
        damagedAmount: damagedQty * costPrice,
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
    return ReportService().getPurchaseReturnReport(
      startDate: start ?? windowStart,
      endDate: end ?? windowEnd,
    );
  }

  double num_(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  List<String> ids(List<Map<String, dynamic>> rows) =>
      rows.map((r) => r['returnId'] as String).toList();

  /// The screen's own units fold, after the PR-1 fix.
  double sumQty(List<Map<String, dynamic>> rows) =>
      rows.fold<double>(0, (s, r) => s + (r['totalQty'] as num).toDouble());
  double sumValue(List<Map<String, dynamic>> rows) =>
      rows.fold<double>(0, (s, r) => s + (r['totalAmount'] as double));

  /// Rows the screen counts as actually returned: everything except cancelled.
  /// The goods never went back on a cancelled return, so neither its value nor
  /// its units belong in a total.
  List<Map<String, dynamic>> returnedRows(List<Map<String, dynamic>> rows) =>
      rows
          .where((r) => r['status'] != PurchaseReturnStatus.cancelled.name)
          .toList();

  /// The screen's "Returned Value" fold.
  double returnedValue(List<Map<String, dynamic>> rows) =>
      sumValue(returnedRows(rows));

  /// The screen's "Returned Units" fold.
  double returnedQty(List<Map<String, dynamic>> rows) =>
      sumQty(returnedRows(rows));

  // ── PR-1: the type contract ────────────────────────────────────────────

  test('PR-1 totalQty is ALWAYS a double, and the screen fold works', () async {
    await seedReturn('RET-1', totalQty: 2);
    await seedReturn('RET-2', totalQty: 3, at: DateTime(2026, 7, 15));

    final rows = await report();
    for (final row in rows) {
      expect(row['totalQty'], isA<double>());
      // The exact expression the screen used to run.
      expect(() => row['totalQty'] as int, throwsA(isA<TypeError>()));
    }

    expect(() => sumQty(rows), returnsNormally);
    expect(sumQty(rows), 5.0);
  });

  test('PR-1/PR-2 decimal quantity survives and formats correctly', () async {
    await seedReturn('RET-1', totalQty: 2.5, totalAmount: 250);

    final r = (await report()).single;
    expect(num_(r, 'totalQty'), 2.5);
    expect(formatQty(num_(r, 'totalQty')), '2.5');
    expect(formatQty(3.0), '3');
    // A `num`, so Excel keeps a numeric cell; integral when whole so the PDF
    // prints "3" rather than "3.0".
    expect(exportQty(3.0), 3);
    expect(exportQty(3.0), isA<int>());
    expect(exportQty(num_(r, 'totalQty')), 2.5);
  });

  // ── Rows ───────────────────────────────────────────────────────────────

  test('one return', () async {
    await seedReturn('RET-1', totalQty: 2, totalAmount: 200);

    final r = (await report()).single;
    expect(r['returnNumber'], 'RET-1');
    expect(r['grnNumber'], 'GRN-1');
    expect(num_(r, 'totalQty'), 2.0);
    expect(num_(r, 'totalAmount'), 200.0);
    expect(r['status'], 'pending');
    expect(r['statusDisplay'], 'Pending');
  });

  test('multiple returns accumulate', () async {
    await seedReturn('RET-1', totalQty: 2, totalAmount: 200);
    await seedReturn('RET-2',
        totalQty: 3, totalAmount: 300, at: DateTime(2026, 7, 15));
    await seedReturn('RET-3',
        totalQty: 1, totalAmount: 100, at: DateTime(2026, 7, 16));

    final rows = await report();
    expect(rows.length, 3);
    expect(sumQty(rows), 6.0);
    expect(sumValue(rows), 600.0);
  });

  test('several partial returns against ONE GRN are separate rows', () async {
    // The model documents this: one GRN can raise several returns, so the link
    // is many-to-one on grnId.
    await seedReturn('RET-1',
        grnId: 'GRN-1', totalQty: 2, totalAmount: 200);
    await seedReturn('RET-2',
        grnId: 'GRN-1',
        totalQty: 3,
        totalAmount: 300,
        at: DateTime(2026, 7, 20));

    final rows = await report();
    expect(rows.length, 2);
    expect(rows.every((r) => r['grnNumber'] == 'GRN-1'), isTrue);
    expect(sumQty(rows), 5.0);
    expect(sumValue(rows), 500.0);
  });

  // ── Statuses ───────────────────────────────────────────────────────────

  test('a pending return has no credit note', () async {
    await seedReturn('RET-1', status: 'pending');

    final r = (await report()).single;
    expect(r['statusDisplay'], 'Pending');
    expect(r['creditNoteNumber'], isNull);
    expect(r['creditNoteAmount'], isNull);
  });

  test('a creditReceived return carries its credit note', () async {
    await seedReturn('RET-1',
        status: 'creditReceived',
        creditNoteNumber: 'CN-9',
        creditNoteAmount: 200);

    final r = (await report()).single;
    expect(r['statusDisplay'], 'Credit Received');
    expect(r['creditNoteNumber'], 'CN-9');
    expect(num_(r, 'creditNoteAmount'), 200.0);
  });

  test('A2 a cancelled return stays visible but is out of value AND units',
      () async {
    // `cancelPurchaseReturn` moves no supplier balance because the goods never
    // went back, and `_damagedRecoveryByGRN` treats a cancelled return as
    // ABSORBED for the same reason. Counting it as returned value contradicted
    // both.
    await seedReturn('RET-OK', totalQty: 2, totalAmount: 200);
    await seedReturn('RET-X',
        totalQty: 5,
        totalAmount: 500,
        status: 'cancelled',
        at: DateTime(2026, 7, 15));

    final rows = await report();
    expect(rows.length, 2, reason: 'both rows remain visible as history');
    expect(returnedValue(rows), 200.0, reason: 'the cancelled 500 is excluded');
    expect(returnedQty(rows), 2.0,
        reason: 'the cancelled 5 units never went back either');

    // "Awaiting Credit" counts only pending, so it is unaffected.
    final pending = rows.where((r) => r['status'] == 'pending').toList();
    expect(pending.length, 1);
    expect(sumValue(pending), 200.0);
  });

  test('A2 several cancelled returns are all excluded', () async {
    await seedReturn('RET-OK', totalAmount: 300);
    await seedReturn('RET-X1',
        totalAmount: 500, status: 'cancelled', at: DateTime(2026, 7, 15));
    await seedReturn('RET-X2',
        totalAmount: 700, status: 'cancelled', at: DateTime(2026, 7, 16));

    final rows = await report();
    expect(rows.length, 3);
    expect(returnedValue(rows), 300.0);
    expect(returnedQty(rows), 2.0, reason: 'only the one live return counts');
  });

  test('A2 when every return is cancelled both totals are zero',
      () async {
    await seedReturn('RET-X1', totalAmount: 500, status: 'cancelled');
    await seedReturn('RET-X2',
        totalAmount: 700, status: 'cancelled', at: DateTime(2026, 7, 15));

    final rows = await report();
    expect(rows.length, 2, reason: 'still listed');
    expect(returnedValue(rows), 0.0);
    expect(returnedQty(rows), 0.0);
  });

  test('A2 a creditReceived return counts towards value and units',
      () async {
    // Only `cancelled` is excluded — a credited return did go back.
    await seedReturn('RET-1',
        totalAmount: 200,
        status: 'creditReceived',
        creditNoteNumber: 'CN-1',
        creditNoteAmount: 200);

    final rows = await report();
    expect(returnedValue(rows), 200.0);
    expect(returnedQty(rows), 2.0);
  });

  test('A2 decimal return amounts survive the exclusion', () async {
    await seedReturn('RET-1', totalQty: 2.5, totalAmount: 262.75);
    await seedReturn('RET-2',
        totalQty: 1.5,
        totalAmount: 137.25,
        at: DateTime(2026, 7, 15));
    await seedReturn('RET-X',
        totalQty: 4.5,
        totalAmount: 999.99,
        status: 'cancelled',
        at: DateTime(2026, 7, 16));

    final rows = await report();
    expect(returnedValue(rows), closeTo(400.0, 0.001));
    // 2.5 + 1.5 returned; the cancelled 4.5 is out of the total but still a row.
    expect(returnedQty(rows), 4.0);
    expect(sumQty(rows), 8.5, reason: 'every row is still present');
  });

  test('CURRENT BEHAVIOUR: an unknown status string falls back to Pending',
      () async {
    // `_statusOf` on the screen uses `orElse: () => PurchaseReturnStatus.pending`,
    // so a corrupt value renders as Pending rather than throwing.
    await seedReturn('RET-1', status: 'not-a-status');

    final r = (await report()).single;
    expect(r['status'], 'not-a-status', reason: 'passed through unchanged');
    final resolved = PurchaseReturnStatus.values.firstWhere(
      (e) => e.name == r['status'],
      orElse: () => PurchaseReturnStatus.pending,
    );
    expect(resolved, PurchaseReturnStatus.pending);
  });

  // ── Window ─────────────────────────────────────────────────────────────

  test('filtered on returnDate: inclusive start, exclusive end', () async {
    await seedReturn('RET-START', at: DateTime(2026, 7, 1));
    await seedReturn('RET-LAST', at: DateTime(2026, 7, 31, 23, 59, 59));
    await seedReturn('RET-OUT', at: DateTime(2026, 8, 1));

    final rows = await report();
    expect(ids(rows).toSet(), {'RET-START', 'RET-LAST'},
        reason: '1 August is the exclusive end');
  });

  test('an unparseable returnDate is excluded', () async {
    await seedReturn('RET-GOOD');
    await seedReturn('RET-BAD', rawDate: 'not-a-date');

    final rows = await report();
    expect(ids(rows), ['RET-GOOD']);
  });

  test('the history cutoff applies', () async {
    final now = DateTime.now();
    await seedReturn('RET-RECENT', at: now.subtract(const Duration(days: 2)));
    await seedReturn('RET-ANCIENT', at: now.subtract(const Duration(days: 400)));

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
    expect(ids(rows), ['RET-RECENT']);
  });

  test('an empty period returns no rows', () async {
    expect(await report(), isEmpty);
  });

  // ── Supplier ───────────────────────────────────────────────────────────

  test('the return snapshot names the supplier, never the live record',
      () async {
    await Hive.box<SupplierModel>(HiveBoxNames.suppliers).put(
      'SUP-1',
      SupplierModel(
        supplierId: 'SUP-1',
        name: 'New Name',
        createdAt: day.toIso8601String(),
        updatedAt: day.toIso8601String(),
      ),
    );
    await seedReturn('RET-1', supplierName: 'Old Name');

    expect((await report()).single['supplierName'], 'Old Name');
  });

  test('a deleted supplier still reports under the return snapshot', () async {
    // No master record exists at all in this test.
    await seedReturn('RET-1', supplierId: 'SUP-GONE', supplierName: 'Gone Ltd');

    expect((await report()).single['supplierName'], 'Gone Ltd');
  });

  test('blank, whitespace and missing supplier names read as Unknown Supplier',
      () async {
    await seedReturn('RET-BLANK', supplierName: '');
    await seedReturn('RET-WS',
        supplierName: '   ', at: DateTime(2026, 7, 15));
    await seedReturn('RET-NULL',
        supplierName: null, at: DateTime(2026, 7, 16));

    final rows = await report();
    expect(rows.length, 3);
    expect(rows.every((r) => r['supplierName'] == 'Unknown Supplier'), isTrue);
  });

  // ── PR-5: deterministic ordering ───────────────────────────────────────

  test('PR-5 newest first, ties broken by returnId, and stable', () async {
    await seedReturn('RET-OLD', at: DateTime(2026, 7, 2));
    await seedReturn('RET-NEW', at: DateTime(2026, 7, 25));
    // One receipt raising several returns in the same instant.
    await seedReturn('RET-TIE-Z', at: DateTime(2026, 7, 10));
    await seedReturn('RET-TIE-A', at: DateTime(2026, 7, 10));

    const expected = ['RET-NEW', 'RET-TIE-A', 'RET-TIE-Z', 'RET-OLD'];
    expect(ids(await report()), expected);
    // An unstable sort passes once by luck.
    for (var i = 0; i < 3; i++) {
      expect(ids(await report()), expected);
    }
  });

  // ── Reconciliation with the damaged lines that produced the returns ────

  test('R per GRN: return value equals the returnToSupplier damaged value',
      () async {
    // The return header is built as `Σ item.damagedAmount` over the lines marked
    // returnToSupplier (`damaged_goods_store.dart:170`), so these must tie.
    await seedReturnLine('IT-1', grnId: 'GRN-1', damagedQty: 2, costPrice: 100);
    await seedReturnLine('IT-2', grnId: 'GRN-1', damagedQty: 1.5, costPrice: 40);
    await seedReturn('RET-1',
        grnId: 'GRN-1',
        totalQty: 3.5,
        totalAmount: 260); // 2*100 + 1.5*40

    final r = (await report()).single;

    final lines = Hive.box<GRNItemModel>(HiveBoxNames.grnItems)
        .values
        .where((i) =>
            i.grnId == 'GRN-1' &&
            i.damagedHandling == DamagedHandling.returnToSupplier.name);
    final lineValue = lines.fold<double>(0, (s, i) => s + (i.damagedAmount ?? 0));
    final lineQty = lines.fold<double>(0, (s, i) => s + (i.damagedQty ?? 0));

    expect(num_(r, 'totalAmount'), lineValue);
    expect(num_(r, 'totalQty'), lineQty);

    // Pinned absolutely.
    expect(num_(r, 'totalAmount'), 260.0);
    expect(num_(r, 'totalQty'), 3.5);
  });

  test('R several returns against one GRN sum to that GRN damaged value',
      () async {
    await seedReturnLine('IT-1', grnId: 'GRN-1', damagedQty: 2, costPrice: 100);
    await seedReturnLine('IT-2', grnId: 'GRN-1', damagedQty: 3, costPrice: 100);
    // Sent back in two instalments.
    await seedReturn('RET-1',
        grnId: 'GRN-1', totalQty: 2, totalAmount: 200);
    await seedReturn('RET-2',
        grnId: 'GRN-1',
        totalQty: 3,
        totalAmount: 300,
        at: DateTime(2026, 7, 20));

    final rows = await report();
    final lines = Hive.box<GRNItemModel>(HiveBoxNames.grnItems)
        .values
        .where((i) => i.grnId == 'GRN-1');
    final lineValue = lines.fold<double>(0, (s, i) => s + (i.damagedAmount ?? 0));

    expect(sumValue(rows), lineValue);
    expect(sumValue(rows), 500.0);
    expect(sumQty(rows), 5.0);
  });
}
