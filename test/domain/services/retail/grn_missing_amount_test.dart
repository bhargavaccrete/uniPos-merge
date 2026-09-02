import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

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
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/domain/store/retail/supplier_store.dart';

/// GRN WITH NO RECORDED INVOICE VALUE.
///
/// `GRNModel.totalAmount == null` means the value was never recorded — NOT that
/// the receipt was free. The header amount and the supplier's `purchase` ledger
/// movement are written from one value in one block, so a GRN with no amount
/// also has no payable; reporting it as ₹0 is honest against the ledger, and
/// the condition is SURFACED rather than reconstructed.
///
/// A stored `0.0` is a legitimate value and is never flagged.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 3, 12, 10);
  final windowStart = DateTime(2026, 3, 1);
  final windowEnd = DateTime(2026, 4, 1);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('grn_missing_amount_');
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
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedPO(String id,
      {POStatus status = POStatus.partiallyCompleted,
      double estimatedTotal = 1000}) async {
    final iso = day.toIso8601String();
    await Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).put(
      id,
      PurchaseOrderModel(
        poId: id,
        poNumber: id,
        supplierId: 'SUP-A',
        supplierName: 'Acme',
        expectedDeliveryDate: iso,
        totalItems: 10,
        estimatedTotal: estimatedTotal,
        status: status.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  Future<void> seedGRN(String id,
      {String poId = 'PO-1',
      String supplierId = 'SUP-A',
      GRNStatus status = GRNStatus.confirmed,
      double receivedQty = 4,
      required double? amount,
      DateTime? at}) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<GRNModel>(HiveBoxNames.grns).put(
      id,
      GRNModel(
        grnId: id,
        grnNumber: id,
        poId: poId,
        poNumber: poId,
        supplierId: supplierId,
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
    await supplierStore.loadSuppliers();
  }

  Future<Map<String, dynamic>> summary() async {
    await hydrate();
    return ReportService()
        .getPurchaseSummaryReport(startDate: windowStart, endDate: windowEnd);
  }

  Future<List<Map<String, dynamic>>> grnRows() async {
    await hydrate();
    return ReportService()
        .getGRNReport(startDate: windowStart, endDate: windowEnd);
  }

  Future<List<Map<String, dynamic>>> supplierWise() async {
    await hydrate();
    return ReportService().getSupplierWisePurchaseReport(
        startDate: windowStart, endDate: windowEnd);
  }

  double n(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();

  /// The GRN Report screen's own notice condition.
  int missingRows(List<Map<String, dynamic>> rows) =>
      rows.where((r) => r['amountMissing'] == true).length;

  // ── 1. The condition itself ────────────────────────────────────────────

  test('1 a null amount keeps the quantity, reports ₹0, and is flagged',
      () async {
    await seedGRN('GRN-1', receivedQty: 4, amount: null);

    final d = await summary();
    expect(n(d, 'receivedQty'), 4.0, reason: 'quantities are unaffected');
    expect(n(d, 'receivedValue'), 0.0, reason: 'the existing `?? 0` rule');
    expect(d['grnsMissingAmount'], 1);

    final rows = await grnRows();
    expect(rows.single['amountMissing'], isTrue);
    expect(n(rows.single, 'receivedQty'), 4.0);
    expect(n(rows.single, 'totalAmount'), 0.0);
  });

  test('2 several null receipts are all counted', () async {
    await seedGRN('GRN-1', amount: null);
    await seedGRN('GRN-2', amount: null, at: DateTime(2026, 3, 13));
    await seedGRN('GRN-3', amount: 500, at: DateTime(2026, 3, 14));

    expect((await summary())['grnsMissingAmount'], 2);
    expect(missingRows(await grnRows()), 2);
  });

  test('3 a stored 0.0 is a real value and is NOT flagged', () async {
    // A free or sample receipt. Zero is a figure someone recorded; null is not.
    await seedGRN('GRN-FREE', amount: 0.0);

    expect((await summary())['grnsMissingAmount'], 0);
    final rows = await grnRows();
    expect(rows.single['amountMissing'], isFalse);
    expect(n(rows.single, 'totalAmount'), 0.0);
  });

  test('4 a normal amount is not flagged', () async {
    await seedGRN('GRN-1', amount: 400);

    expect((await summary())['grnsMissingAmount'], 0);
    expect(missingRows(await grnRows()), 0);
  });

  test('a zero and a null in one period are told apart', () async {
    await seedGRN('GRN-FREE', amount: 0.0);
    await seedGRN('GRN-NULL', amount: null, at: DateTime(2026, 3, 13));

    expect((await summary())['grnsMissingAmount'], 1);
    final rows = await grnRows();
    expect(rows.firstWhere((r) => r['grnNumber'] == 'GRN-FREE')['amountMissing'],
        isFalse);
    expect(rows.firstWhere((r) => r['grnNumber'] == 'GRN-NULL')['amountMissing'],
        isTrue);
  });

  // ── 5 & 6. The count respects each report's own window/status rules ────

  test('5 Purchase Summary counts only confirmed receipts in the window',
      () async {
    await seedGRN('GRN-IN', amount: null);
    // Out of window.
    await seedGRN('GRN-OUT', amount: null, at: DateTime(2026, 4, 5));
    // Not confirmed.
    await seedGRN('GRN-DRAFT',
        amount: null, status: GRNStatus.draft, at: DateTime(2026, 3, 15));

    expect((await summary())['grnsMissingAmount'], 1,
        reason: 'same window and confirmed-only rule as receivedValue');
  });

  test('6 the GRN Report flag follows the same rules', () async {
    await seedGRN('GRN-IN', amount: null);
    await seedGRN('GRN-OUT', amount: null, at: DateTime(2026, 4, 5));
    await seedGRN('GRN-DRAFT',
        amount: null, status: GRNStatus.draft, at: DateTime(2026, 3, 15));

    final rows = await grnRows();
    expect(rows.length, 1);
    expect(missingRows(rows), 1);
    expect(rows.single['grnNumber'], 'GRN-IN');
  });

  test('an empty period reports a zero count, not a missing key', () async {
    final d = await summary();
    expect(d.containsKey('grnsMissingAmount'), isTrue);
    expect(d['grnsMissingAmount'], 0);
  });

  // ── 7 & 8. Nothing else moved ──────────────────────────────────────────

  test('7 Supplier-wise calculations are unchanged', () async {
    await seedGRN('GRN-NULL', amount: null, receivedQty: 4);
    await seedGRN('GRN-OK',
        amount: 600, receivedQty: 6, at: DateTime(2026, 3, 13));

    final rows = await supplierWise();
    expect(rows.length, 1);
    // Still `?? 0` — the null receipt adds units but no value.
    expect(n(rows.single, 'totalAmount'), 600.0);
    expect(n(rows.single, 'totalItems'), 10.0);
    expect(rows.single.containsKey('grnsMissingAmount'), isFalse,
        reason: 'no generic notice on a per-supplier report');
  });

  test('8 Outstanding still treats a null amount as nothing received',
      () async {
    // Documented current behaviour, deliberately unchanged: `receivedValue`
    // is 0, so the PO looks fully outstanding.
    await seedPO('PO-1', status: POStatus.partiallyCompleted,
        estimatedTotal: 1000);
    await seedGRN('GRN-1', poId: 'PO-1', amount: null, receivedQty: 4);

    final d = await summary();
    expect(n(d, 'outstandingValue'), 1000.0);
    expect(d['grnsMissingAmount'], 1,
        reason: 'the count is what explains the overstated Outstanding');
  });

  // ── 9 & 10. Persistence and the live creation path ─────────────────────

  test('9 toMap/fromMap preserves null as null, and a value as a value',
      () async {
    await seedGRN('GRN-NULL', amount: null);
    await seedGRN('GRN-ZERO', amount: 0.0, at: DateTime(2026, 3, 13));
    await seedGRN('GRN-VAL', amount: 250.5, at: DateTime(2026, 3, 14));

    final box = Hive.box<GRNModel>(HiveBoxNames.grns);
    for (final id in ['GRN-NULL', 'GRN-ZERO', 'GRN-VAL']) {
      final original = box.get(id)!;
      final restored = GRNModel.fromMap(original.toMap());
      expect(restored.totalAmount, original.totalAmount, reason: id);
    }
    expect(GRNModel.fromMap(box.get('GRN-NULL')!.toMap()).totalAmount, isNull);
    expect(GRNModel.fromMap(box.get('GRN-ZERO')!.toMap()).totalAmount, 0.0);
    expect(GRNModel.fromMap(box.get('GRN-VAL')!.toMap()).totalAmount, 250.5);
  });

  test('10 the live creation path always supplies an amount', () async {
    // `GRNModel.create` has one call site, which passes `totalBillableAmount`.
    // A receipt made that way is never flagged.
    final grn = GRNModel.create(
      grnNumber: 'GRN-NEW',
      poId: 'PO-1',
      poNumber: 'PO-1',
      supplierId: 'SUP-A',
      supplierName: 'Acme',
      receivedDate: day.toIso8601String(),
      totalOrderedQty: 5,
      totalReceivedQty: 5,
      totalAmount: 500,
      status: GRNStatus.confirmed,
    );
    await Hive.box<GRNModel>(HiveBoxNames.grns).put(grn.grnId, grn);

    expect((await summary())['grnsMissingAmount'], 0);
    expect(missingRows(await grnRows()), 0);
  });
}
