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
import 'package:billberrylite/util/common/quantity_format.dart';

/// SUPPLIER-WISE PURCHASES — spend per supplier, on goods actually received.
///
/// Reads confirmed GRNs only; purchase orders are never consulted. Two rules
/// this file exists to pin:
///
///   1. **Reconciliation.** This report and Purchase Summary's received side
///      read the same GRNs through the same helper, so their totals must be
///      EXACTLY equal — not merely close.
///   2. **Historical identity.** The GRN's own `supplierName` snapshot wins
///      over the live supplier record, so renaming a supplier today cannot
///      rename last year's purchases. Grouping stays on `supplierId`.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 8, 12, 10);
  final windowStart = DateTime(2026, 8, 1);
  final windowEnd = DateTime(2026, 9, 1);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('supplier_wise_');
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

  Future<void> seedGRN(
    String id, {
    required String supplierId,
    String? supplierName = 'Acme',
    GRNStatus status = GRNStatus.confirmed,
    double? amount = 1000,
    double receivedQty = 10,
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
        totalOrderedQty: receivedQty,
        totalReceivedQty: receivedQty,
        totalAmount: amount,
        status: status.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  Future<void> seedSupplier(String id, String name) async {
    await Hive.box<SupplierModel>(HiveBoxNames.suppliers).put(
      id,
      SupplierModel(
        supplierId: id,
        name: name,
        createdAt: day.toIso8601String(),
        updatedAt: day.toIso8601String(),
      ),
    );
  }

  Future<void> seedReturn(String id,
      {required String grnId,
      required PurchaseReturnStatus status,
      double amount = 200}) async {
    final iso = day.toIso8601String();
    await Hive.box<PurchaseReturnModel>(HiveBoxNames.purchaseReturns).put(
      id,
      PurchaseReturnModel(
        returnId: id,
        returnNumber: id,
        grnId: grnId,
        grnNumber: grnId,
        poId: 'PO-1',
        poNumber: 'PO-1',
        supplierId: 'SUP-A',
        supplierName: 'Acme',
        returnDate: iso,
        totalQty: 2,
        totalAmount: amount,
        status: status.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  /// Boxes are seeded first; every store hydrates asynchronously from its own
  /// constructor, so the observables must be reloaded before a report reads
  /// them or the test races the box.
  Future<void> hydrate() async {
    await purchaseOrderStore.loadPurchaseOrders();
    await purchaseOrderStore.loadGRNs();
    await damagedGoodsStore.loadAll();
    await supplierStore.loadSuppliers();
  }

  Future<List<Map<String, dynamic>>> report() async {
    await hydrate();
    return ReportService().getSupplierWisePurchaseReport(
        startDate: windowStart, endDate: windowEnd);
  }

  double num_(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  List<String> names(List<Map<String, dynamic>> rows) =>
      rows.map((r) => r['supplierName'] as String).toList();
  List<String> ids(List<Map<String, dynamic>> rows) =>
      rows.map((r) => r['supplierId'] as String).toList();

  // ── K: reconciliation with Purchase Summary ────────────────────────────

  test('K supplier-wise totals equal Purchase Summary received-side totals',
      () async {
    await seedSupplier('SUP-A', 'Acme');
    await seedSupplier('SUP-B', 'Bolt');
    await seedGRN('GRN-1',
        supplierId: 'SUP-A', amount: 1000, receivedQty: 10);
    await seedGRN('GRN-2',
        supplierId: 'SUP-A', amount: 500, receivedQty: 5.5);
    await seedGRN('GRN-3',
        supplierId: 'SUP-B',
        supplierName: 'Bolt',
        amount: 750,
        receivedQty: 7);
    // Excluded from both reports by the same helper.
    await seedGRN('GRN-DRAFT',
        supplierId: 'SUP-B', status: GRNStatus.draft, amount: 9999);
    await seedReturn('RET-1',
        grnId: 'GRN-1', status: PurchaseReturnStatus.pending, amount: 200);
    await seedReturn('RET-2',
        grnId: 'GRN-3', status: PurchaseReturnStatus.cancelled, amount: 90);

    final rows = await report();
    final summary = await ReportService()
        .getPurchaseSummaryReport(startDate: windowStart, endDate: windowEnd);

    double sum(String key) =>
        double.parse(rows.fold<double>(0, (s, r) => s + num_(r, key))
            .toStringAsFixed(2));

    expect(sum('totalAmount'), num_(summary, 'receivedValue'));
    expect(sum('totalItems'), num_(summary, 'receivedQty'));
    expect(rows.fold<int>(0, (s, r) => s + (r['receiptCount'] as int)),
        summary['receiptCount']);
    expect(rows.length, summary['supplierCount']);
    // Recovery is now dated by its own event and grouped by the DOCUMENT's
    // supplier, so the two reports must still agree figure for figure.
    expect(sum('damagedExpected'), num_(summary, 'damagedExpected'));
    expect(sum('damagedRecovered'), num_(summary, 'damagedRecovered'));
    expect(sum('damagedAbsorbed'), num_(summary, 'damagedAbsorbed'));

    // And the absolute values, so a shared regression can't move both together.
    expect(sum('totalAmount'), 2250.0);
    expect(sum('totalItems'), 22.5);
    expect(rows.length, 2);
  });

  // ── Grouping ───────────────────────────────────────────────────────────

  test('one supplier, one row', () async {
    await seedSupplier('SUP-A', 'Acme');
    await seedGRN('GRN-1', supplierId: 'SUP-A');

    final rows = await report();
    expect(rows.length, 1);
    expect(rows.single['supplierName'], 'Acme');
    expect(rows.single['receiptCount'], 1);
    expect(num_(rows.single, 'totalAmount'), 1000.0);
  });

  test('multiple suppliers, ranked by amount', () async {
    await seedSupplier('SUP-A', 'Acme');
    await seedSupplier('SUP-B', 'Bolt');
    await seedGRN('GRN-1', supplierId: 'SUP-A', amount: 400);
    await seedGRN('GRN-2',
        supplierId: 'SUP-B', supplierName: 'Bolt', amount: 900);

    final rows = await report();
    expect(ids(rows), ['SUP-B', 'SUP-A']);
  });

  test('the same supplier across several GRNs collapses into one row',
      () async {
    await seedSupplier('SUP-A', 'Acme');
    await seedGRN('GRN-1', supplierId: 'SUP-A', amount: 400, receivedQty: 4);
    await seedGRN('GRN-2', supplierId: 'SUP-A', amount: 600, receivedQty: 6);
    await seedGRN('GRN-3', supplierId: 'SUP-A', amount: 100, receivedQty: 1);

    final rows = await report();
    expect(rows.length, 1);
    expect(rows.single['receiptCount'], 3);
    expect(num_(rows.single, 'totalAmount'), 1100.0);
    expect(num_(rows.single, 'totalItems'), 11.0);
  });

  test('the same NAME with different IDs stays two rows', () async {
    await seedSupplier('SUP-A', 'Sharma Traders');
    await seedSupplier('SUP-B', 'Sharma Traders');
    await seedGRN('GRN-1',
        supplierId: 'SUP-A', supplierName: 'Sharma Traders', amount: 600);
    await seedGRN('GRN-2',
        supplierId: 'SUP-B', supplierName: 'Sharma Traders', amount: 400);

    final rows = await report();
    expect(rows.length, 2, reason: 'grouped by supplierId, never by name');
    expect(ids(rows), ['SUP-A', 'SUP-B']);
    expect(names(rows), ['Sharma Traders', 'Sharma Traders']);
  });

  // ── E1: historical supplier identity ───────────────────────────────────

  test('E1 a renamed supplier does NOT rename historical receipts', () async {
    // The receipt was taken under the old name; the master record has since
    // been renamed.
    await seedSupplier('SUP-A', 'New Name');
    await seedGRN('GRN-1', supplierId: 'SUP-A', supplierName: 'Old Name');

    final rows = await report();
    expect(rows.single['supplierName'], 'Old Name');
  });

  test('E1 a renamed supplier still groups all its receipts together',
      () async {
    await seedSupplier('SUP-A', 'New Name');
    await seedGRN('GRN-1',
        supplierId: 'SUP-A', supplierName: 'Old Name', amount: 400);
    await seedGRN('GRN-2',
        supplierId: 'SUP-A', supplierName: 'New Name', amount: 600);

    final rows = await report();
    expect(rows.length, 1, reason: 'one supplierId is one row, whatever it is called');
    expect(num_(rows.single, 'totalAmount'), 1000.0);
  });

  test('E1 a blank snapshot falls back to the current supplier name', () async {
    await seedSupplier('SUP-A', 'Current Name');
    await seedGRN('GRN-1', supplierId: 'SUP-A', supplierName: null);

    final rows = await report();
    expect(rows.single['supplierName'], 'Current Name');
  });

  test('E1 whitespace-only counts as blank', () async {
    await seedSupplier('SUP-A', 'Current Name');
    await seedGRN('GRN-1', supplierId: 'SUP-A', supplierName: '   ');

    final rows = await report();
    expect(rows.single['supplierName'], 'Current Name',
        reason: '`??` alone would have rendered an empty cell');
  });

  test('E1 blank snapshot and no supplier record → Unknown Supplier',
      () async {
    // Deleted supplier: no master row at all, and the receipt kept no name.
    await seedGRN('GRN-1', supplierId: 'SUP-GONE', supplierName: '');

    final rows = await report();
    expect(rows.single['supplierName'], 'Unknown Supplier');
  });

  test('E1 a DELETED supplier still reports under its snapshot', () async {
    // No master record, but the receipt remembers who it came from.
    await seedGRN('GRN-1', supplierId: 'SUP-GONE', supplierName: 'Gone Ltd');

    final rows = await report();
    expect(rows.single['supplierName'], 'Gone Ltd');
    expect(num_(rows.single, 'totalAmount'), 1000.0);
  });

  // ── D-3: deterministic ordering ────────────────────────────────────────

  test('D-3 ties break by units desc, then supplierId asc, and stay stable',
      () async {
    // Equal amount, different units → more units first.
    await seedGRN('GRN-1',
        supplierId: 'SUP-B', supplierName: 'B', amount: 500, receivedQty: 9);
    await seedGRN('GRN-2',
        supplierId: 'SUP-A', supplierName: 'A', amount: 500, receivedQty: 2);
    // Equal amount AND equal units → supplierId ascending.
    await seedGRN('GRN-3',
        supplierId: 'SUP-Z', supplierName: 'Z', amount: 300, receivedQty: 1);
    await seedGRN('GRN-4',
        supplierId: 'SUP-M', supplierName: 'M', amount: 300, receivedQty: 1);

    expect(ids(await report()), ['SUP-B', 'SUP-A', 'SUP-M', 'SUP-Z']);
    // Unstable sorts pass once by luck — assert it does not move.
    for (var i = 0; i < 3; i++) {
      expect(ids(await report()), ['SUP-B', 'SUP-A', 'SUP-M', 'SUP-Z']);
    }
  });

  // ── Quantities ─────────────────────────────────────────────────────────

  test('D-2 decimal quantities survive and format correctly', () async {
    await seedSupplier('SUP-A', 'Acme');
    await seedGRN('GRN-1', supplierId: 'SUP-A', receivedQty: 12, amount: 1200);
    await seedGRN('GRN-2', supplierId: 'SUP-A', receivedQty: 2.5, amount: 250);

    final rows = await report();
    expect(rows.single['totalItems'], isA<double>());
    expect(num_(rows.single, 'totalItems'), 14.5);

    expect(formatQty(12.0), '12');
    expect(formatQty(2.5), '2.5');
    expect(formatQty(num_(rows.single, 'totalItems')), '14.5');
    // A `num`, so Excel keeps a numeric cell; integral when whole so the PDF
    // prints "12" rather than "12.0".
    expect(exportQty(12.0), 12);
    expect(exportQty(12.0), isA<int>());
    expect(exportQty(2.5), 2.5);
  });

  // ── Filtering ──────────────────────────────────────────────────────────

  test('a draft GRN is excluded entirely', () async {
    await seedSupplier('SUP-A', 'Acme');
    await seedGRN('GRN-OK', supplierId: 'SUP-A', amount: 400);
    await seedGRN('GRN-DRAFT',
        supplierId: 'SUP-A', status: GRNStatus.draft, amount: 9999);

    final rows = await report();
    expect(rows.single['receiptCount'], 1);
    expect(num_(rows.single, 'totalAmount'), 400.0);
  });

  test('date boundaries: receivedDate, inclusive start and exclusive end',
      () async {
    await seedGRN('GRN-START',
        supplierId: 'SUP-A', supplierName: 'A', at: DateTime(2026, 8, 1));
    await seedGRN('GRN-LAST',
        supplierId: 'SUP-A',
        supplierName: 'A',
        at: DateTime(2026, 8, 31, 23, 59, 59));
    await seedGRN('GRN-OUT',
        supplierId: 'SUP-A',
        supplierName: 'A',
        at: DateTime(2026, 9, 1));

    final rows = await report();
    expect(rows.single['receiptCount'], 2,
        reason: '1 September is the exclusive end');
  });

  test('an empty period returns no rows', () async {
    expect(await report(), isEmpty);
  });

  // ── Damaged columns ────────────────────────────────────────────────────

  test('damaged value is INSIDE Amount, and an open return is EXPECTED',
      () async {
    await seedSupplier('SUP-A', 'Acme');
    await seedGRN('GRN-1', supplierId: 'SUP-A', amount: 1000);
    await seedReturn('RET-1',
        grnId: 'GRN-1', status: PurchaseReturnStatus.pending, amount: 200);

    final rows = await report();
    // The subtitle used to say damaged was "excluded from spend". It is not.
    expect(num_(rows.single, 'totalAmount'), 1000.0);
    // Raised, not credited.
    expect(num_(rows.single, 'damagedExpected'), 200.0);
    expect(num_(rows.single, 'damagedRecovered'), 0.0);
    expect(num_(rows.single, 'damagedAmount'), 200.0);
  });

  test('a cancelled return is in NO recovery bucket', () async {
    await seedSupplier('SUP-A', 'Acme');
    await seedGRN('GRN-1', supplierId: 'SUP-A', amount: 1000);
    await seedReturn('RET-1',
        grnId: 'GRN-1', status: PurchaseReturnStatus.cancelled, amount: 150);

    final rows = await report();
    // Never went back, never credited, no dependable cancellation date.
    expect(num_(rows.single, 'damagedExpected'), 0.0);
    expect(num_(rows.single, 'damagedRecovered'), 0.0);
    expect(num_(rows.single, 'damagedAbsorbed'), 0.0);
    expect(num_(rows.single, 'totalAmount'), 1000.0,
        reason: 'the receipt itself is untouched');
  });
}
