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
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// PURCHASE SUMMARY — ordered vs received.
///
/// The report joins two INDEPENDENT document streams: purchase orders (dated by
/// `createdAt`) and confirmed GRNs (dated by `receivedDate`), plus the
/// damaged-goods documents. Ordered and received are never added together —
/// they are the two sides the report exists to compare.
///
/// Where behaviour is currently uncertain or deliberately deferred (a null GRN
/// amount, the undated damage window, a return and a claim on one GRN), these
/// tests pin CURRENT behaviour and say so. They are documentation, not a
/// proposal.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 6, 15, 10);
  final windowStart = DateTime(2026, 6, 1);
  final windowEnd = DateTime(2026, 7, 1);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('purchase_summary_');
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
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedPO(
    String id, {
    required POStatus status,
    double total = 1000,
    double items = 10,
    DateTime? at,
    String supplierId = 'SUP-1',
  }) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).put(
      id,
      PurchaseOrderModel(
        poId: id,
        poNumber: id,
        supplierId: supplierId,
        supplierName: 'Acme',
        expectedDeliveryDate: iso,
        totalItems: items,
        estimatedTotal: total,
        status: status.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  Future<void> seedGRN(
    String id, {
    required String poId,
    required GRNStatus status,
    double? amount = 1000,
    double receivedQty = 10,
    double orderedQty = 10,
    DateTime? at,
    String supplierId = 'SUP-1',
  }) async {
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
        totalOrderedQty: orderedQty,
        totalReceivedQty: receivedQty,
        totalAmount: amount,
        status: status.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  Future<void> seedReturn(String id,
      {required String grnId,
      required PurchaseReturnStatus status,
      double amount = 200,
      DateTime? at}) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<PurchaseReturnModel>(HiveBoxNames.purchaseReturns).put(
      id,
      PurchaseReturnModel(
        returnId: id,
        returnNumber: id,
        grnId: grnId,
        grnNumber: grnId,
        poId: 'PO-1',
        poNumber: 'PO-1',
        supplierId: 'SUP-1',
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

  Future<void> seedClaim(String id,
      {required String grnId,
      required SupplierClaimStatus status,
      double amount = 150,
      bool lossRecorded = false,
      DateTime? resolvedAt}) async {
    final iso = day.toIso8601String();
    await Hive.box<SupplierClaimModel>(HiveBoxNames.supplierClaims).put(
      id,
      SupplierClaimModel(
        claimId: id,
        claimNumber: id,
        grnId: grnId,
        grnNumber: grnId,
        poId: 'PO-1',
        poNumber: 'PO-1',
        supplierId: 'SUP-1',
        supplierName: 'Acme',
        claimDate: iso,
        totalQty: 1,
        totalAmount: amount,
        status: status.name,
        lossRecorded: lossRecorded,
        resolvedAt: resolvedAt?.toIso8601String(),
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  /// Boxes are seeded first; both stores hydrate asynchronously from their own
  /// constructors, so the observables must be reloaded before the report reads
  /// them or the test races the box.
  Future<void> hydrate() async {
    await purchaseOrderStore.loadPurchaseOrders();
    await purchaseOrderStore.loadGRNs();
    await damagedGoodsStore.loadAll();
  }

  Future<Map<String, dynamic>> summary() async {
    await hydrate();
    return ReportService()
        .getPurchaseSummaryReport(startDate: windowStart, endDate: windowEnd);
  }

  double num_(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  Map<String, int> statuses(Map<String, dynamic> m) =>
      m['countByStatus'] as Map<String, int>;

  /// The screen's own emptiness test, after C3.
  bool rendersReport(Map<String, dynamic> d) =>
      statuses(d).values.any((c) => c > 0) || (d['receiptCount'] as int) > 0;

  // ── Ordered vs received ────────────────────────────────────────────────

  test('a normal purchase: ordered and received both counted, once each',
      () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);

    final d = await summary();
    expect(d['orderCount'], 1);
    expect(d['receiptCount'], 1);
    expect(num_(d, 'orderedValue'), 1000.0);
    expect(num_(d, 'receivedValue'), 1000.0);
    expect(num_(d, 'outstandingValue'), 0.0);
    expect(d['supplierCount'], 1);
  });

  test('multiple purchases accumulate', () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted, total: 1000);
    await seedPO('PO-2', status: POStatus.fullyCompleted, total: 500);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);
    await seedGRN('GRN-2',
        poId: 'PO-2', status: GRNStatus.confirmed, amount: 500, receivedQty: 5);

    final d = await summary();
    expect(d['orderCount'], 2);
    expect(num_(d, 'orderedValue'), 1500.0);
    expect(num_(d, 'receivedValue'), 1500.0);
    expect(num_(d, 'receivedQty'), 15.0);
  });

  test('a sent PO counts as ordered but NOT as received', () async {
    await seedPO('PO-1', status: POStatus.sent);

    final d = await summary();
    expect(num_(d, 'orderedValue'), 1000.0);
    expect(num_(d, 'receivedValue'), 0.0,
        reason: 'nothing has arrived — a PO is not a purchase');
    expect(d['receiptCount'], 0);
    expect(num_(d, 'outstandingValue'), 1000.0);
  });

  test('a partial receipt leaves the remainder outstanding', () async {
    await seedPO('PO-1', status: POStatus.partiallyCompleted, total: 1000);
    await seedGRN('GRN-1',
        poId: 'PO-1', status: GRNStatus.confirmed, amount: 400, receivedQty: 4);

    final d = await summary();
    expect(num_(d, 'orderedValue'), 1000.0);
    expect(num_(d, 'receivedValue'), 400.0);
    expect(num_(d, 'outstandingValue'), 600.0);
  });

  test('a full receipt leaves nothing outstanding', () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);

    final d = await summary();
    // fullyCompleted is not in the outstanding set at all.
    expect(num_(d, 'outstandingValue'), 0.0);
  });

  test('over-receipt clamps outstanding to zero, never negative', () async {
    await seedPO('PO-1', status: POStatus.partiallyCompleted, total: 1000);
    await seedGRN('GRN-1',
        poId: 'PO-1',
        status: GRNStatus.confirmed,
        amount: 1400,
        receivedQty: 14);

    final d = await summary();
    expect(num_(d, 'outstandingValue'), 0.0);
    expect(num_(d, 'receivedValue'), 1400.0);
  });

  // ── Draft / cancelled / unconfirmed ────────────────────────────────────

  test('a draft PO is excluded from money but counted in the breakdown',
      () async {
    await seedPO('PO-DRAFT', status: POStatus.draft);

    final d = await summary();
    expect(d['orderCount'], 0);
    expect(num_(d, 'orderedValue'), 0.0);
    expect(num_(d, 'orderedQty'), 0.0);
    expect(statuses(d)['draft'], 1);
    expect(num_(d, 'outstandingValue'), 0.0);
  });

  test('a cancelled PO is excluded from money but counted in the breakdown',
      () async {
    await seedPO('PO-X', status: POStatus.cancelled);

    final d = await summary();
    expect(d['orderCount'], 0);
    expect(num_(d, 'orderedValue'), 0.0);
    expect(statuses(d)['cancelled'], 1);
  });

  test('a draft GRN is excluded entirely', () async {
    await seedPO('PO-1', status: POStatus.sent);
    await seedGRN('GRN-DRAFT', poId: 'PO-1', status: GRNStatus.draft);

    final d = await summary();
    expect(d['receiptCount'], 0);
    expect(num_(d, 'receivedValue'), 0.0);
    expect(num_(d, 'receivedQty'), 0.0);
    // ...and it does not reduce what is still expected.
    expect(num_(d, 'outstandingValue'), 1000.0);
  });

  // ── C3: the empty-state condition ──────────────────────────────────────

  test('C3 a period of ONLY drafts/cancelled renders, with its breakdown',
      () async {
    await seedPO('PO-D', status: POStatus.draft);
    await seedPO('PO-C', status: POStatus.cancelled);

    final d = await summary();
    expect(d['orderCount'], 0);
    expect(d['receiptCount'], 0);
    // The old test — orderCount + receiptCount — would have hidden this.
    expect(rendersReport(d), isTrue);
    expect(statuses(d)['draft'], 1);
    expect(statuses(d)['cancelled'], 1);
  });

  test('C3 a truly empty period still shows the empty state', () async {
    final d = await summary();
    expect(d['orderCount'], 0);
    expect(d['receiptCount'], 0);
    expect(statuses(d).values.every((c) => c == 0), isTrue);
    expect(rendersReport(d), isFalse);
  });

  // ── Damaged goods ──────────────────────────────────────────────────────

  test('an open purchase return is EXPECTED recovery, not recovered', () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);
    await seedReturn('RET-1',
        grnId: 'GRN-1', status: PurchaseReturnStatus.pending, amount: 200);

    final d = await summary();
    // Raised, not credited — owed by the supplier, not received.
    expect(num_(d, 'damagedExpected'), 200.0);
    expect(num_(d, 'damagedRecovered'), 0.0);
    expect(num_(d, 'damagedAbsorbed'), 0.0);
    // Received value is NOT reduced by a return — there is no net-purchase
    // metric in this report.
    expect(num_(d, 'receivedValue'), 1000.0);
  });

  test('a cancelled purchase return is in NO recovery bucket', () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);
    await seedReturn('RET-1',
        grnId: 'GRN-1', status: PurchaseReturnStatus.cancelled, amount: 200);

    final d = await summary();
    // The goods never went back, nothing was credited, and there is no reliable
    // cancellation date — so it is neither expected, recovered nor absorbed.
    expect(num_(d, 'damagedExpected'), 0.0);
    expect(num_(d, 'damagedRecovered'), 0.0);
    expect(num_(d, 'damagedAbsorbed'), 0.0);
  });

  test('a rejected supplier claim is absorbed', () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);
    // A rejection is dated by `resolvedAt` — that is when the cost became ours.
    await seedClaim('CLM-1',
        grnId: 'GRN-1',
        status: SupplierClaimStatus.rejected,
        amount: 150,
        resolvedAt: day);

    final d = await summary();
    expect(num_(d, 'damagedAbsorbed'), 150.0);
    expect(num_(d, 'damagedExpected'), 0.0);
    expect(num_(d, 'damagedRecovered'), 0.0);
  });

  test('an open supplier claim is EXPECTED recovery', () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);
    await seedClaim('CLM-1',
        grnId: 'GRN-1', status: SupplierClaimStatus.pending, amount: 150);

    final d = await summary();
    expect(num_(d, 'damagedExpected'), 150.0);
    expect(num_(d, 'damagedRecovered'), 0.0);
  });

  test('D3 CURRENT BEHAVIOUR: a return AND a claim on one GRN both count',
      () async {
    // Documented, NOT endorsed. There is no cross-guard between a return and a
    // claim (only between a rejected claim and its loss row), so if the same
    // damaged goods are both returned and claimed the value counts twice.
    // Pinned so a future decision is a deliberate change, not a surprise.
    await seedPO('PO-1', status: POStatus.fullyCompleted);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);
    await seedReturn('RET-1',
        grnId: 'GRN-1', status: PurchaseReturnStatus.pending, amount: 200);
    await seedClaim('CLM-1',
        grnId: 'GRN-1', status: SupplierClaimStatus.pending, amount: 150);

    final d = await summary();
    expect(num_(d, 'damagedExpected'), 350.0);
  });

  test('D2 recovery is bounded by its OWN event date, not the GRN date',
      () async {
    // The receipt is in this window; the return is raised in the NEXT month.
    await seedPO('PO-1', status: POStatus.fullyCompleted);
    await seedGRN('GRN-1', poId: 'PO-1', status: GRNStatus.confirmed);
    await seedReturn('RET-LATER',
        grnId: 'GRN-1',
        status: PurchaseReturnStatus.pending,
        amount: 200,
        at: DateTime(2026, 7, 5));

    final d = await summary();
    // Was 200 before D2 — the return was attributed to the GRN's period.
    expect(num_(d, 'damagedExpected'), 0.0,
        reason: 'a July return does not belong to June');
    expect(num_(d, 'damagedRecovered'), 0.0);
    expect(num_(d, 'damagedAbsorbed'), 0.0);
    // The damage itself still belongs to the receiving period.
    expect(d['receiptCount'], 1);
  });

  // ── Quantities and money ───────────────────────────────────────────────

  test('C1 decimal receipt quantities survive and format correctly', () async {
    await seedPO('PO-1', status: POStatus.fullyCompleted, items: 12);
    await seedGRN('GRN-1',
        poId: 'PO-1', status: GRNStatus.confirmed, receivedQty: 12);
    await seedPO('PO-2', status: POStatus.fullyCompleted, items: 2.5);
    await seedGRN('GRN-2',
        poId: 'PO-2',
        status: GRNStatus.confirmed,
        receivedQty: 2.5,
        amount: 250);

    final d = await summary();
    // The service keeps these as doubles — the screen must not print "14.5.0".
    expect(d['receivedQty'], isA<double>());
    expect(num_(d, 'receivedQty'), 14.5);

    // What the screen renders, and what the export writes.
    expect(formatQty(12.0), '12');
    expect(formatQty(2.5), '2.5');
    expect(formatQty(num_(d, 'receivedQty')), '14.5');
    // A `num`, so Excel keeps a numeric cell; integral when whole, so the PDF
    // prints "12" rather than "12.0".
    expect(exportQty(12.0), 12);
    expect(exportQty(12.0), isA<int>());
    expect(exportQty(2.5), 2.5);
  });

  test('D1 CURRENT BEHAVIOUR: a null GRN totalAmount contributes zero value',
      () async {
    // Documented, NOT endorsed. `totalAmount` is nullable and read as `?? 0`,
    // so such a GRN adds quantity but no value — understating Received and
    // overstating Outstanding. The one live creation path always supplies it.
    await seedPO('PO-1', status: POStatus.partiallyCompleted, total: 1000);
    await seedGRN('GRN-1',
        poId: 'PO-1',
        status: GRNStatus.confirmed,
        amount: null,
        receivedQty: 4);

    final d = await summary();
    expect(num_(d, 'receivedQty'), 4.0);
    expect(num_(d, 'receivedValue'), 0.0);
    expect(num_(d, 'outstandingValue'), 1000.0);
  });

  // ── Window ─────────────────────────────────────────────────────────────

  test('date boundaries: PO createdAt and GRN receivedDate, end exclusive',
      () async {
    await seedPO('PO-IN',
        status: POStatus.sent, at: DateTime(2026, 6, 30, 23, 59, 59));
    await seedPO('PO-OUT', status: POStatus.sent, at: DateTime(2026, 7, 1));
    await seedGRN('GRN-IN',
        poId: 'PO-IN',
        status: GRNStatus.confirmed,
        at: DateTime(2026, 6, 1));
    await seedGRN('GRN-OUT',
        poId: 'PO-OUT',
        status: GRNStatus.confirmed,
        at: DateTime(2026, 7, 1));

    final d = await summary();
    expect(d['orderCount'], 1, reason: '1 July is the exclusive end');
    expect(d['receiptCount'], 1, reason: '1 June is the inclusive start');
  });

  test('an unparseable PO date is excluded', () async {
    await seedPO('PO-GOOD', status: POStatus.sent);
    await Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).put(
      'PO-BAD',
      PurchaseOrderModel(
        poId: 'PO-BAD',
        poNumber: 'PO-BAD',
        supplierId: 'SUP-1',
        expectedDeliveryDate: 'not-a-date',
        totalItems: 5,
        estimatedTotal: 500,
        status: POStatus.sent.name,
        createdAt: 'not-a-date',
        updatedAt: 'not-a-date',
      ),
    );

    final d = await summary();
    expect(d['orderCount'], 1);
    expect(num_(d, 'orderedValue'), 1000.0);
  });

  test('supplierCount counts suppliers who DELIVERED, not who were ordered from',
      () async {
    await seedPO('PO-1', status: POStatus.sent, supplierId: 'SUP-A');
    await seedPO('PO-2', status: POStatus.sent, supplierId: 'SUP-B');

    final d = await summary();
    expect(d['orderCount'], 2);
    expect(d['supplierCount'], 0,
        reason: 'derived from receipts only — no GRN, no supplier counted');
  });
}
