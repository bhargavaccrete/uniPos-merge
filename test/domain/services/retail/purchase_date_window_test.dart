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
import 'package:billberrylite/data/models/retail/hive_model/inventory_loss_model_178.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_item_model_175.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_item_model_177.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';

/// PURCHASE DATE WINDOW — `ReportService._withinRange`.
///
/// The defect this pins: `_withinRange` opened with
/// `if (start == null && end == null) return true;`, which returned BEFORE
/// `_inWindow`. Two consequences, both fixed here:
///
///   1. an all-time query ignored the plan's report-history cutoff entirely;
///   2. a document whose date could not be parsed was INCLUDED all-time but
///      EXCLUDED whenever bounds were present.
///
/// The helper is shared by all eight purchase reports, so this is exercised
/// through the one that reads both POs and GRNs.
void main() {
  late Directory tempDir;

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('purchase_window_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<PurchaseOrderModel>(HiveBoxNames.purchaseOrders);
    await Hive.openBox<PurchaseOrderItemModel>(
        HiveBoxNames.purchaseOrderItems);
    await Hive.openBox<GRNModel>(HiveBoxNames.grns);
    await Hive.openBox<GRNItemModel>(HiveBoxNames.grnItems);
    // getPurchaseSummaryReport always consults the damaged-goods documents.
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

  /// A placed (sent) purchase order stamped with [createdAt] verbatim, so an
  /// unparseable value can be seeded on purpose.
  Future<void> seedOrder(String id, String createdAt,
      {double total = 100, double items = 1}) async {
    await Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).put(
      id,
      PurchaseOrderModel(
        poId: id,
        poNumber: id,
        supplierId: 'SUP-1',
        supplierName: 'Acme',
        expectedDeliveryDate: createdAt,
        totalItems: items,
        estimatedTotal: total,
        status: POStatus.sent.name,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
  }

  /// Boxes are seeded first; the store hydrates asynchronously from its own
  /// constructor, so the observables must be reloaded before a report reads
  /// them or the test races the box.
  Future<void> hydrate() async {
    await purchaseOrderStore.loadPurchaseOrders();
    await purchaseOrderStore.loadGRNs();
    await damagedGoodsStore.loadAll();
  }

  /// Arms the plan so `ReportHistoryWindow.cutoff` becomes non-null.
  /// Unlicensed retail bypasses enforcement; a manifest flips that on.
  void armHistoryWindow(int days) {
    Entitlements.instance.loadFromManifest(
      ManifestData(
        entitlements: {RetailEntKeys.reportsHistoryLimitDays: days},
        license: const {},
        version: 1,
      ),
    );
  }

  Future<Map<String, dynamic>> summary({
    DateTime? start,
    DateTime? end,
  }) async =>
      ReportService().getPurchaseSummaryReport(startDate: start, endDate: end);

  // ── The cutoff applies in BOTH query shapes ────────────────────────────

  test('bounded query respects the history cutoff', () async {
    final now = DateTime.now();
    await seedOrder('PO-RECENT', now.subtract(const Duration(days: 2))
        .toIso8601String());
    await seedOrder('PO-ANCIENT', now.subtract(const Duration(days: 400))
        .toIso8601String());
    await hydrate();

    armHistoryWindow(30);
    // A window wide enough to hold both — only the cutoff can exclude one.
    final data = await summary(
      start: now.subtract(const Duration(days: 500)),
      end: now.add(const Duration(days: 1)),
    );

    expect(data['orderCount'], 1, reason: 'the 400-day-old PO is out of plan');
    expect(data['orderedValue'], 100.0);
  });

  test('all-time query also respects the history cutoff', () async {
    final now = DateTime.now();
    await seedOrder('PO-RECENT', now.subtract(const Duration(days: 2))
        .toIso8601String());
    await seedOrder('PO-ANCIENT', now.subtract(const Duration(days: 400))
        .toIso8601String());
    await hydrate();

    armHistoryWindow(30);
    // Both bounds null. Before the fix this returned everything, because
    // `_withinRange` never reached `_inWindow`.
    final data = await summary();

    expect(data['orderCount'], 1);
    expect(data['orderedValue'], 100.0);
  });

  test('with no plan window, all-time returns everything', () async {
    final now = DateTime.now();
    await seedOrder('PO-RECENT', now.subtract(const Duration(days: 2))
        .toIso8601String());
    await seedOrder('PO-ANCIENT', now.subtract(const Duration(days: 400))
        .toIso8601String());
    await hydrate();

    // No manifest → unlicensed retail bypasses → cutoff null.
    final data = await summary();
    expect(data['orderCount'], 2);
  });

  // ── An unreadable date is excluded either way ──────────────────────────

  test('an unparseable date is excluded from a BOUNDED query', () async {
    await seedOrder('PO-GOOD', DateTime(2026, 6, 10).toIso8601String());
    await seedOrder('PO-BAD', 'not-a-date');
    await hydrate();

    final data = await summary(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 7, 1),
    );
    expect(data['orderCount'], 1);
  });

  test('an unparseable date is excluded from an ALL-TIME query too', () async {
    await seedOrder('PO-GOOD', DateTime(2026, 6, 10).toIso8601String());
    await seedOrder('PO-BAD', 'not-a-date');
    await hydrate();

    // The asymmetry this fixes: the bad row used to be counted here while the
    // bounded query above rejected it.
    final data = await summary();
    expect(data['orderCount'], 1);
    expect(data['orderedValue'], 100.0);
  });

  // ── Existing window semantics are unchanged ────────────────────────────

  test('start is inclusive and end is exclusive', () async {
    await seedOrder('PO-START', DateTime(2026, 6, 1).toIso8601String());
    await seedOrder('PO-LAST', DateTime(2026, 6, 30, 23, 59, 59)
        .toIso8601String());
    await seedOrder('PO-END', DateTime(2026, 7, 1).toIso8601String());
    await hydrate();

    final data = await summary(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 7, 1),
    );
    expect(data['orderCount'], 2, reason: '1 July is the exclusive end');
  });
}
