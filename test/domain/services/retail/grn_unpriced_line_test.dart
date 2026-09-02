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

/// RECEIVED LINES WITH NO COST PRICE.
///
/// **Zero is the live case, not null.** The receiving screen seeds
/// `estimatedPrice ?? variant.costPrice ?? 0` and parses the price field as
/// `tryParse(text) ?? 0`, so a blank became ₹0 — which valued the line, the
/// receipt, the supplier accrual and any return raised from it at nothing.
/// Null only arrives from legacy or restored rows, and means the same thing.
///
/// Nothing is reconstructed: the reports keep their `?? 0` arithmetic and
/// SURFACE the condition instead. Receiving now blocks a zero-cost line at
/// entry, which is the only point where the figure can still be asked for.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 2, 12, 10);
  final windowStart = DateTime(2026, 2, 1);
  final windowEnd = DateTime(2026, 3, 1);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('grn_unpriced_');
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

  Future<void> seedGRN(String id,
      {GRNStatus status = GRNStatus.confirmed,
      double receivedQty = 10,
      double? amount = 1000,
      DateTime? at}) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<GRNModel>(HiveBoxNames.grns).put(
      id,
      GRNModel(
        grnId: id,
        grnNumber: id,
        poId: 'PO-$id',
        poNumber: 'PO-$id',
        supplierId: 'SUP-A',
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

  /// A GRN line. `damagedAmount` mirrors the model's own rule: null without a
  /// cost price, otherwise `damagedQty * costPrice`.
  Future<void> seedItem(String id,
      {required String grnId,
      String productName = 'Widget',
      double receivedQty = 10,
      double acceptedQty = 10,
      double damagedQty = 0,
      required double? costPrice}) async {
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
        damagedHandling:
            damagedQty > 0 ? DamagedHandling.keepForClaim.name : null,
        costPrice: costPrice,
        totalAmount: costPrice == null ? null : acceptedQty * costPrice,
        damagedAmount: (costPrice != null && damagedQty > 0)
            ? damagedQty * costPrice
            : null,
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

  Future<List<Map<String, dynamic>>> damagedRows() async {
    await hydrate();
    return ReportService()
        .getDamagedItemsReport(startDate: windowStart, endDate: windowEnd);
  }

  double n(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();

  /// The receiving screen's own gate, mirrored: a line that received goods but
  /// carries no usable cost blocks the save.
  bool wouldBlockReceiving(
          {required double receivedQty, required double costPrice}) =>
      receivedQty > 0 && costPrice <= 0;

  // ── A: the condition is surfaced ───────────────────────────────────────

  test('a zero-cost line is flagged on all three reports', () async {
    await seedGRN('GRN-1', receivedQty: 10, amount: 0);
    await seedItem('IT-1',
        grnId: 'GRN-1', acceptedQty: 8, damagedQty: 2, costPrice: 0);

    expect((await summary())['grnsWithUnpricedLines'], 1);
    expect((await grnRows()).single['hasUnpricedLine'], isTrue);
    expect((await damagedRows()).single['costMissing'], isTrue);
  });

  test('a null-cost line is flagged the same way', () async {
    await seedGRN('GRN-1', receivedQty: 10, amount: null);
    await seedItem('IT-1',
        grnId: 'GRN-1', acceptedQty: 8, damagedQty: 2, costPrice: null);

    expect((await summary())['grnsWithUnpricedLines'], 1);
    expect((await grnRows()).single['hasUnpricedLine'], isTrue);
    expect((await damagedRows()).single['costMissing'], isTrue);
  });

  test('a priced line is not flagged', () async {
    await seedGRN('GRN-1', amount: 1000);
    await seedItem('IT-1',
        grnId: 'GRN-1', acceptedQty: 8, damagedQty: 2, costPrice: 100);

    expect((await summary())['grnsWithUnpricedLines'], 0);
    expect((await grnRows()).single['hasUnpricedLine'], isFalse);
    expect((await damagedRows()).single['costMissing'], isFalse);
  });

  test('a receipt with SOME unpriced lines is still flagged', () async {
    // A header-only check would miss this: totalAmount is non-zero because the
    // other line is priced.
    await seedGRN('GRN-1', receivedQty: 20, amount: 1000);
    await seedItem('IT-PRICED', grnId: 'GRN-1', costPrice: 100);
    await seedItem('IT-FREE', grnId: 'GRN-1', costPrice: 0);

    expect((await summary())['grnsWithUnpricedLines'], 1);
    expect((await grnRows()).single['hasUnpricedLine'], isTrue);
  });

  test('a line that received nothing is ignored', () async {
    // An unpriced line only matters once goods have arrived against it.
    await seedGRN('GRN-1', receivedQty: 10, amount: 1000);
    await seedItem('IT-OK', grnId: 'GRN-1', costPrice: 100);
    await seedItem('IT-NONE',
        grnId: 'GRN-1', receivedQty: 0, acceptedQty: 0, costPrice: 0);

    expect((await summary())['grnsWithUnpricedLines'], 0);
    expect((await grnRows()).single['hasUnpricedLine'], isFalse);
  });

  test('several affected receipts are counted', () async {
    await seedGRN('GRN-1', amount: 0);
    await seedItem('IT-1', grnId: 'GRN-1', costPrice: 0);
    await seedGRN('GRN-2', amount: 0, at: DateTime(2026, 2, 13));
    await seedItem('IT-2', grnId: 'GRN-2', costPrice: null);
    await seedGRN('GRN-3', amount: 900, at: DateTime(2026, 2, 14));
    await seedItem('IT-3', grnId: 'GRN-3', costPrice: 90);

    expect((await summary())['grnsWithUnpricedLines'], 2);
    expect((await grnRows()).where((r) => r['hasUnpricedLine'] == true).length,
        2);
  });

  test('the count respects the window and the confirmed-only rule', () async {
    await seedGRN('GRN-IN', amount: 0);
    await seedItem('IT-IN', grnId: 'GRN-IN', costPrice: 0);
    await seedGRN('GRN-OUT', amount: 0, at: DateTime(2026, 3, 5));
    await seedItem('IT-OUT', grnId: 'GRN-OUT', costPrice: 0);
    await seedGRN('GRN-DRAFT',
        status: GRNStatus.draft, amount: 0, at: DateTime(2026, 2, 15));
    await seedItem('IT-DRAFT', grnId: 'GRN-DRAFT', costPrice: 0);

    expect((await summary())['grnsWithUnpricedLines'], 1);
    expect((await grnRows()).length, 1);
  });

  test('an empty period reports a zero count, not a missing key', () async {
    final d = await summary();
    expect(d.containsKey('grnsWithUnpricedLines'), isTrue);
    expect(d['grnsWithUnpricedLines'], 0);
  });

  // ── The consequences the flag explains ─────────────────────────────────

  test('an unpriced line values its damage — and any claim — at nothing',
      () async {
    await seedGRN('GRN-1', receivedQty: 10, amount: 0);
    await seedItem('IT-1',
        grnId: 'GRN-1', acceptedQty: 8, damagedQty: 2, costPrice: 0);

    final row = (await damagedRows()).single;
    expect(n(row, 'damagedQty'), 2.0, reason: 'the quantity is real');
    expect(n(row, 'damagedAmount'), 0.0,
        reason: 'and it is worth nothing on paper');
    expect(row['costMissing'], isTrue,
        reason: 'which is exactly what the notice explains');
  });

  test('the receipt value and Outstanding are unchanged by the flag',
      () async {
    // The arithmetic is deliberately untouched — only the disclosure is new.
    await seedGRN('GRN-1', receivedQty: 10, amount: 0);
    await seedItem('IT-1', grnId: 'GRN-1', costPrice: 0);

    final d = await summary();
    expect(n(d, 'receivedQty'), 10.0);
    expect(n(d, 'receivedValue'), 0.0);
    expect(d['grnsWithUnpricedLines'], 1);
  });

  test('this is separate from a missing GRN invoice value', () async {
    // Two different conditions, counted separately: a priced receipt can still
    // be missing its header amount, and vice versa.
    await seedGRN('GRN-NOAMOUNT', amount: null);
    await seedItem('IT-A', grnId: 'GRN-NOAMOUNT', costPrice: 100);
    await seedGRN('GRN-NOCOST', amount: 500, at: DateTime(2026, 2, 13));
    await seedItem('IT-B', grnId: 'GRN-NOCOST', costPrice: 0);

    final d = await summary();
    expect(d['grnsMissingAmount'], 1);
    expect(d['grnsWithUnpricedLines'], 1);
  });

  test('toMap/fromMap preserves a null and a zero cost distinctly', () async {
    await seedGRN('GRN-1');
    await seedItem('IT-NULL', grnId: 'GRN-1', costPrice: null);
    await seedItem('IT-ZERO', grnId: 'GRN-1', costPrice: 0);
    await seedItem('IT-VAL', grnId: 'GRN-1', costPrice: 12.5);

    final box = Hive.box<GRNItemModel>(HiveBoxNames.grnItems);
    expect(GRNItemModel.fromMap(box.get('IT-NULL')!.toMap()).costPrice, isNull);
    expect(GRNItemModel.fromMap(box.get('IT-ZERO')!.toMap()).costPrice, 0.0);
    expect(GRNItemModel.fromMap(box.get('IT-VAL')!.toMap()).costPrice, 12.5);
  });

  // ── B: the receiving gate ──────────────────────────────────────────────

  group('receiving blocks a zero-cost line', () {
    test('a zero cost on received goods is blocked', () {
      expect(wouldBlockReceiving(receivedQty: 10, costPrice: 0), isTrue);
    });

    test('a negative cost is blocked', () {
      expect(wouldBlockReceiving(receivedQty: 10, costPrice: -5), isTrue);
    });

    test('a real cost passes', () {
      expect(wouldBlockReceiving(receivedQty: 10, costPrice: 100), isFalse);
    });

    test('a line receiving nothing is not blocked', () {
      // Nothing arrived, so there is no value to capture.
      expect(wouldBlockReceiving(receivedQty: 0, costPrice: 0), isFalse);
    });

    test('a fractional cost passes', () {
      expect(wouldBlockReceiving(receivedQty: 2.5, costPrice: 0.5), isFalse);
    });
  });
}
