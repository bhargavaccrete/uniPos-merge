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

/// D2 — DAMAGE RECOVERY IS DATED BY ITS OWN EVENT.
///
/// Damage belongs to the receiving period. Recovery belongs to the period the
/// recovery actually happened in, which the app already knows: the supplier
/// ledger posts a credit note with `creditNoteDate` and a settled claim with
/// `resolvedAt` (`damaged_goods_store.dart:313, :45`). The reports used to
/// attribute all of it to the GRN's `receivedDate` with no date filter at all,
/// so recovery appeared before it happened and closed periods changed
/// retroactively.
///
/// **Expected is not Recovered.** A raised return or claim is value owed; only
/// a credit note or settlement is value received — and a credit note may be for
/// less than the return's face value.
void main() {
  late Directory tempDir;

  DateTime jan(int d) => DateTime(2026, 1, d, 10);
  DateTime feb(int d) => DateTime(2026, 2, d, 10);
  DateTime mar(int d) => DateTime(2026, 3, d, 10);

  ({DateTime start, DateTime end}) month(int m) =>
      (start: DateTime(2026, m, 1), end: DateTime(2026, m + 1, 1));

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('recovery_window_');
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

  Future<void> seedGRN(String id,
      {required DateTime at,
      String supplierId = 'SUP-A',
      String? supplierName = 'Acme',
      double amount = 1000}) async {
    final iso = at.toIso8601String();
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
        totalOrderedQty: 10,
        totalReceivedQty: 10,
        totalAmount: amount,
        status: GRNStatus.confirmed.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  Future<void> seedReturn(
    String id, {
    String grnId = 'GRN-JAN',
    String supplierId = 'SUP-A',
    String? supplierName = 'Acme',
    required DateTime returnDate,
    double totalAmount = 600,
    PurchaseReturnStatus status = PurchaseReturnStatus.pending,
    DateTime? creditNoteDate,
    double? creditNoteAmount,
  }) async {
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
        returnDate: returnDate.toIso8601String(),
        totalQty: 3,
        totalAmount: totalAmount,
        status: status.name,
        creditNoteNumber: creditNoteDate == null ? null : 'CN-$id',
        creditNoteDate: creditNoteDate?.toIso8601String(),
        creditNoteAmount: creditNoteAmount,
        createdAt: returnDate.toIso8601String(),
        updatedAt: returnDate.toIso8601String(),
      ),
    );
  }

  Future<void> seedClaim(
    String id, {
    String grnId = 'GRN-JAN',
    String supplierId = 'SUP-A',
    String? supplierName = 'Acme',
    required DateTime claimDate,
    double totalAmount = 500,
    SupplierClaimStatus status = SupplierClaimStatus.pending,
    DateTime? resolvedAt,
    bool lossRecorded = false,
  }) async {
    await Hive.box<SupplierClaimModel>(HiveBoxNames.supplierClaims).put(
      id,
      SupplierClaimModel(
        claimId: id,
        claimNumber: id,
        grnId: grnId,
        grnNumber: grnId,
        poId: 'PO-$grnId',
        poNumber: 'PO-$grnId',
        supplierId: supplierId,
        supplierName: supplierName,
        claimDate: claimDate.toIso8601String(),
        totalQty: 2,
        totalAmount: totalAmount,
        status: status.name,
        resolvedAt: resolvedAt?.toIso8601String(),
        lossRecorded: lossRecorded,
        createdAt: claimDate.toIso8601String(),
        updatedAt: claimDate.toIso8601String(),
      ),
    );
  }

  Future<void> seedLoss(String id,
      {String? grnId = 'GRN-JAN',
      String? supplierId = 'SUP-A',
      required DateTime recordedAt,
      double lossValue = 300}) async {
    await Hive.box<InventoryLossModel>(HiveBoxNames.inventoryLosses).put(
      id,
      InventoryLossModel(
        lossId: id,
        lossNumber: id,
        source: 'grn',
        grnId: grnId,
        supplierId: supplierId,
        supplierName: 'Acme',
        variantId: 'V-1',
        productId: 'P-1',
        quantity: 3,
        costPrice: 100,
        lossValue: lossValue,
        reason: 'damaged on arrival',
        recordedAt: recordedAt.toIso8601String(),
      ),
    );
  }

  Future<void> hydrate() async {
    await purchaseOrderStore.loadPurchaseOrders();
    await purchaseOrderStore.loadGRNs();
    await damagedGoodsStore.loadAll();
    await supplierStore.loadSuppliers();
  }

  Future<Map<String, dynamic>> summaryFor(int m) async {
    await hydrate();
    final w = month(m);
    return ReportService()
        .getPurchaseSummaryReport(startDate: w.start, endDate: w.end);
  }

  Future<List<Map<String, dynamic>>> supplierWiseFor(int m) async {
    await hydrate();
    final w = month(m);
    return ReportService()
        .getSupplierWisePurchaseReport(startDate: w.start, endDate: w.end);
  }

  double n(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();

  ({double expected, double recovered, double absorbed}) totals(
          Map<String, dynamic> d) =>
      (
        expected: n(d, 'damagedExpected'),
        recovered: n(d, 'damagedRecovered'),
        absorbed: n(d, 'damagedAbsorbed'),
      );

  // ── The critical scenario ──────────────────────────────────────────────

  group('GRN Jan 10 ₹1,000 · Return Feb 5 ₹600 · Credit Mar 1 ₹400', () {
    Future<void> seedScenario() async {
      await seedGRN('GRN-JAN', at: jan(10), amount: 1000);
      await seedReturn('RET-1',
          returnDate: feb(5),
          totalAmount: 600,
          status: PurchaseReturnStatus.creditReceived,
          creditNoteDate: mar(1),
          creditNoteAmount: 400);
    }

    test('January: damage only — no recovery', () async {
      await seedScenario();
      final t = totals(await summaryFor(1));
      expect(t.expected, 0.0);
      expect(t.recovered, 0.0);
      expect(t.absorbed, 0.0);
      // The receipt itself still belongs to January.
      expect((await summaryFor(1))['receiptCount'], 1);
      expect(n(await summaryFor(1), 'receivedValue'), 1000.0);
    });

    test('February: nothing — the return is already credited in March',
        () async {
      // A creditReceived return is placed by its CREDIT date, not its raise
      // date: the money moved in March.
      await seedScenario();
      final t = totals(await summaryFor(2));
      expect(t.expected, 0.0);
      expect(t.recovered, 0.0);
    });

    test('March: recovered ₹400 — the note face value, not the ₹600 return',
        () async {
      await seedScenario();
      final t = totals(await summaryFor(3));
      expect(t.recovered, 400.0,
          reason: 'the ₹200 shortfall is NOT recovered');
      expect(t.expected, 0.0);
      expect((await summaryFor(3))['receiptCount'], 0);
    });

    test('January never changes when February and March documents exist',
        () async {
      await seedGRN('GRN-JAN', at: jan(10), amount: 1000);
      final before = totals(await summaryFor(1));

      await seedReturn('RET-1',
          returnDate: feb(5),
          totalAmount: 600,
          status: PurchaseReturnStatus.creditReceived,
          creditNoteDate: mar(1),
          creditNoteAmount: 400);
      final after = totals(await summaryFor(1));

      expect(after, before, reason: 'a closed period must not move');
      expect(after.expected, 0.0);
      expect(after.recovered, 0.0);
    });
  });

  // ── Expected vs recovered ──────────────────────────────────────────────

  test('a pending return is expected in its return month, never recovered',
      () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedReturn('RET-1', returnDate: feb(5), totalAmount: 600);

    expect(totals(await summaryFor(1)).expected, 0.0);
    final f = totals(await summaryFor(2));
    expect(f.expected, 600.0);
    expect(f.recovered, 0.0);
  });

  test('creditNoteAmount below totalAmount: only the note is recovered',
      () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedReturn('RET-1',
        returnDate: feb(5),
        totalAmount: 600,
        status: PurchaseReturnStatus.creditReceived,
        creditNoteDate: feb(20),
        creditNoteAmount: 400);

    final f = totals(await summaryFor(2));
    expect(f.recovered, 400.0);
    expect(f.expected, 0.0, reason: 'the return is no longer open');
  });

  test('same-month recovery: damage and credit land together', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedReturn('RET-1',
        returnDate: jan(15),
        totalAmount: 600,
        status: PurchaseReturnStatus.creditReceived,
        creditNoteDate: jan(20),
        creditNoteAmount: 600);

    final j = totals(await summaryFor(1));
    expect(j.recovered, 600.0);
    expect(n(await summaryFor(1), 'receivedValue'), 1000.0);
  });

  test('multiple partial returns land in their own months', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedReturn('RET-1', returnDate: feb(5), totalAmount: 300);
    await seedReturn('RET-2', returnDate: feb(20), totalAmount: 200);
    await seedReturn('RET-3', returnDate: mar(10), totalAmount: 500);

    expect(totals(await summaryFor(1)).expected, 0.0);
    expect(totals(await summaryFor(2)).expected, 500.0, reason: '300 + 200');
    expect(totals(await summaryFor(3)).expected, 500.0);
  });

  // ── Claims ─────────────────────────────────────────────────────────────

  test('a claim is expected at claimDate and recovered at resolvedAt',
      () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedClaim('CLM-1',
        claimDate: feb(5),
        totalAmount: 500,
        status: SupplierClaimStatus.settled,
        resolvedAt: mar(3));

    expect(totals(await summaryFor(2)).expected, 0.0,
        reason: 'a settled claim is placed by its settlement');
    expect(totals(await summaryFor(3)).recovered, 500.0);
  });

  test('an approved claim is still only expected', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedClaim('CLM-1',
        claimDate: feb(5),
        totalAmount: 500,
        status: SupplierClaimStatus.approved);

    final f = totals(await summaryFor(2));
    expect(f.expected, 500.0, reason: 'agreed is not paid');
    expect(f.recovered, 0.0);
  });

  test('a rejected claim is absorbed at its resolution date', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedClaim('CLM-1',
        claimDate: feb(5),
        totalAmount: 500,
        status: SupplierClaimStatus.rejected,
        resolvedAt: mar(3));

    expect(totals(await summaryFor(2)).absorbed, 0.0);
    expect(totals(await summaryFor(3)).absorbed, 500.0);
  });

  test('a rejected claim already written off is not absorbed twice', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedClaim('CLM-1',
        claimDate: feb(5),
        totalAmount: 500,
        status: SupplierClaimStatus.rejected,
        resolvedAt: mar(3),
        lossRecorded: true);
    await seedLoss('LOSS-1', recordedAt: mar(3), lossValue: 500);

    expect(totals(await summaryFor(3)).absorbed, 500.0,
        reason: 'counted through the loss row only');
  });

  // ── Write-offs ─────────────────────────────────────────────────────────

  test('a write-off is absorbed at recordedAt', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedLoss('LOSS-1', recordedAt: feb(12), lossValue: 300);

    expect(totals(await summaryFor(1)).absorbed, 0.0);
    expect(totals(await summaryFor(2)).absorbed, 300.0);
  });

  test('a loss with no GRN is inventory, not purchasing', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedLoss('LOSS-ADJ',
        grnId: null, recordedAt: jan(12), lossValue: 900);

    expect(totals(await summaryFor(1)).absorbed, 0.0);
  });

  // ── Cancellation ───────────────────────────────────────────────────────

  test('a cancelled return is in NO bucket, in any month', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedReturn('RET-X',
        returnDate: feb(5),
        totalAmount: 500,
        status: PurchaseReturnStatus.cancelled);

    for (final m in [1, 2, 3]) {
      final t = totals(await summaryFor(m));
      expect(t.expected, 0.0, reason: 'month $m');
      expect(t.recovered, 0.0, reason: 'month $m');
      expect(t.absorbed, 0.0, reason: 'month $m');
    }
  });

  // ── Window mechanics ───────────────────────────────────────────────────

  test('date boundaries: inclusive start, exclusive end on the event date',
      () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedReturn('RET-FIRST',
        returnDate: DateTime(2026, 2, 1), totalAmount: 100);
    await seedReturn('RET-LAST',
        returnDate: DateTime(2026, 2, 28, 23, 59, 59), totalAmount: 200);
    await seedReturn('RET-OUT',
        returnDate: DateTime(2026, 3, 1), totalAmount: 400);

    expect(totals(await summaryFor(2)).expected, 300.0,
        reason: '1 March is the exclusive end');
    expect(totals(await summaryFor(3)).expected, 400.0);
  });

  test('the history cutoff applies to recovery documents', () async {
    final now = DateTime.now();
    await seedGRN('GRN-OLD', at: now.subtract(const Duration(days: 400)));
    await seedReturn('RET-RECENT',
        returnDate: now.subtract(const Duration(days: 2)), totalAmount: 100);
    await seedReturn('RET-ANCIENT',
        returnDate: now.subtract(const Duration(days: 400)), totalAmount: 900);

    Entitlements.instance.loadFromManifest(
      ManifestData(
        entitlements: {RetailEntKeys.reportsHistoryLimitDays: 30},
        license: const {},
        version: 1,
      ),
    );

    await hydrate();
    final d = await ReportService().getPurchaseSummaryReport(
      startDate: now.subtract(const Duration(days: 500)),
      endDate: now.add(const Duration(days: 1)),
    );
    expect(n(d, 'damagedExpected'), 100.0);
  });

  // ── Parity and supplier attribution ────────────────────────────────────

  test('Purchase Summary and Supplier-wise agree in every month', () async {
    await seedGRN('GRN-JAN', at: jan(10), amount: 1000);
    await seedReturn('RET-1', returnDate: feb(5), totalAmount: 600);
    await seedClaim('CLM-1',
        claimDate: feb(8),
        totalAmount: 200,
        status: SupplierClaimStatus.settled,
        resolvedAt: mar(2));
    await seedLoss('LOSS-1', recordedAt: mar(4), lossValue: 150);

    for (final m in [1, 2, 3]) {
      final d = await summaryFor(m);
      final rows = await supplierWiseFor(m);
      double sum(String k) => double.parse(
          rows.fold<double>(0, (s, r) => s + n(r, k)).toStringAsFixed(2));

      expect(sum('damagedExpected'), n(d, 'damagedExpected'), reason: 'm$m');
      expect(sum('damagedRecovered'), n(d, 'damagedRecovered'), reason: 'm$m');
      expect(sum('damagedAbsorbed'), n(d, 'damagedAbsorbed'), reason: 'm$m');
    }
  });

  test('a supplier appears for recovery even with no receipt that month',
      () async {
    await seedGRN('GRN-JAN', at: jan(10), amount: 1000);
    await seedReturn('RET-1', returnDate: feb(5), totalAmount: 600);

    final feb2 = await supplierWiseFor(2);
    expect(feb2.length, 1);
    final row = feb2.single;
    expect(row['supplierId'], 'SUP-A');
    expect(row['supplierName'], 'Acme');
    expect(row['receiptCount'], 0, reason: 'nothing was received in February');
    expect(n(row, 'totalAmount'), 0.0);
    expect(n(row, 'damagedExpected'), 600.0);
  });

  test('reconciles with the Purchase Returns report on returnDate', () async {
    await seedGRN('GRN-JAN', at: jan(10));
    await seedReturn('RET-1', returnDate: feb(5), totalAmount: 600);
    await seedReturn('RET-2', returnDate: feb(20), totalAmount: 150);

    await hydrate();
    final w = month(2);
    final returns = await ReportService()
        .getPurchaseReturnReport(startDate: w.start, endDate: w.end);
    final returnValue =
        returns.fold<double>(0, (s, r) => s + (r['totalAmount'] as double));

    // Both now key on returnDate for an open return, so they agree.
    expect(totals(await summaryFor(2)).expected, returnValue);
    expect(returnValue, 750.0);
  });
}
