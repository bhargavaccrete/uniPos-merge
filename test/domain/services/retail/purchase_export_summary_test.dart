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
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/domain/store/retail/supplier_store.dart';
import 'package:billberrylite/presentation/screens/retail/reports/purchase_order_status_report_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports/supplier_wise_purchase_report_screen.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// EXPORT SUMMARY PARITY.
///
/// An exported report must not omit a metric the screen shows, and must not
/// carry a different value for one. Both screens build their summary band and
/// their export summary from ONE totals function, so these tests assert the
/// real export map — keys present exactly once, values equal to the same fold
/// the cards use.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 5, 12, 10);
  final windowStart = DateTime(2026, 5, 1);
  final windowEnd = DateTime(2026, 6, 1);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('export_parity_');
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
      {required POStatus status,
      double ordered = 10,
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
        totalItems: ordered,
        estimatedTotal: estimatedTotal,
        status: status.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  Future<void> seedGRN(String id,
      {required String poId,
      String supplierId = 'SUP-A',
      double receivedQty = 4,
      double? amount = 400}) async {
    final iso = day.toIso8601String();
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
        status: GRNStatus.confirmed.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
  }

  Future<void> seedReturn(String id,
      {required String grnId,
      required PurchaseReturnStatus status,
      double amount = 200,
      DateTime? creditDate,
      double? creditAmount}) async {
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
        creditNoteNumber: creditDate == null ? null : 'CN-$id',
        creditNoteDate: creditDate?.toIso8601String(),
        creditNoteAmount: creditAmount,
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

  /// Every key must appear exactly once — a summary is a map, so a duplicated
  /// literal would silently overwrite rather than fail.
  void expectKeysOnce(Map<String, dynamic> summary, List<String> keys) {
    for (final k in keys) {
      expect(summary.containsKey(k), isTrue, reason: 'missing "$k"');
      expect(summary.keys.where((x) => x == k).length, 1,
          reason: '"$k" must appear exactly once');
    }
  }

  // ── Supplier-wise ──────────────────────────────────────────────────────

  group('Supplier-wise export summary', () {
    Future<List<Map<String, dynamic>>> rows() async {
      await hydrate();
      return ReportService().getSupplierWisePurchaseReport(
          startDate: windowStart, endDate: windowEnd);
    }

    test('carries all five screen metrics, each key exactly once', () async {
      await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 4, amount: 400);
      await seedReturn('RET-1',
          grnId: 'GRN-1', status: PurchaseReturnStatus.pending, amount: 200);

      final summary = supplierWiseExportSummary(await rows());
      expectKeysOnce(summary, const [
        'Suppliers',
        'Total Received',
        'Units',
        'Expected Recovery',
        'Recovered',
        'Absorbed',
      ]);
    });

    test('values equal the totals the summary band renders', () async {
      await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 4, amount: 400);
      await seedGRN('GRN-2', poId: 'PO-2', receivedQty: 2.5, amount: 250);
      await seedReturn('RET-OPEN',
          grnId: 'GRN-1', status: PurchaseReturnStatus.pending, amount: 200);
      await seedReturn('RET-CREDITED',
          grnId: 'GRN-2',
          status: PurchaseReturnStatus.creditReceived,
          amount: 150,
          creditDate: day,
          creditAmount: 120);

      final r = await rows();
      final t = supplierWiseTotals(r);
      final summary = supplierWiseExportSummary(r);

      // The export formats the SAME numbers the cards format.
      expect(summary['Total Received'],
          ReportExportService.formatCurrency(t.amount));
      expect(summary['Units'], formatQty(t.units));
      expect(summary['Expected Recovery'],
          ReportExportService.formatCurrency(t.expected));
      expect(summary['Recovered'],
          ReportExportService.formatCurrency(t.recovered));
      expect(summary['Absorbed'],
          ReportExportService.formatCurrency(t.absorbed));
      expect(summary['Suppliers'], r.length);

      // And those totals are the folds over the rows, pinned absolutely.
      expect(t.amount, 650.0);
      expect(t.units, 6.5);
      expect(t.expected, 200.0);
      expect(t.recovered, 120.0, reason: 'the note, not the 150 return');
      expect(t.absorbed, 0.0);
    });

    test('decimal units survive into the summary', () async {
      await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 2.5, amount: 250);

      final summary = supplierWiseExportSummary(await rows());
      expect(summary['Units'], '2.5');
    });

    test('an empty period yields zeroed totals, not missing keys', () async {
      final summary = supplierWiseExportSummary(await rows());
      expectKeysOnce(summary, const [
        'Suppliers',
        'Total Received',
        'Units',
        'Expected Recovery',
        'Recovered',
        'Absorbed',
      ]);
      expect(summary['Suppliers'], 0);
      expect(summary['Units'], '0');
    });
  });

  // ── PO Status ──────────────────────────────────────────────────────────

  group('PO Status export summary', () {
    Future<List<Map<String, dynamic>>> rowsFor(POStatus status) async {
      await hydrate();
      return ReportService().getPurchaseOrderStatusReport(status,
          startDate: windowStart, endDate: windowEnd);
    }

    test('Pending carries Orders, Ordered Value and Units Awaited', () async {
      await seedPO('PO-1', status: POStatus.sent, ordered: 10);
      await seedPO('PO-2',
          status: POStatus.sent, ordered: 5, estimatedTotal: 500);

      final r = await rowsFor(POStatus.sent);
      final summary = poStatusExportSummary(r, true);

      expectKeysOnce(summary, const [
        'Orders',
        'Ordered Value',
        'Units Awaited',
      ]);
      expect(summary.containsKey('Received Value'), isFalse,
          reason: 'the card shows Ordered Value while goods are awaited');

      final t = poStatusTotals(r);
      expect(summary['Orders'], r.length);
      expect(summary['Ordered Value'],
          ReportExportService.formatCurrency(t.ordered));
      expect(summary['Units Awaited'], formatQty(t.remainingQty));

      expect(summary['Orders'], 2);
      expect(t.ordered, 1500.0);
      expect(t.remainingQty, 15.0, reason: 'nothing received yet');
    });

    test('Partially Received reports progress', () async {
      await seedPO('PO-1',
          status: POStatus.partiallyCompleted, ordered: 10);
      await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 4, amount: 400);

      final r = await rowsFor(POStatus.partiallyCompleted);
      final summary = poStatusExportSummary(r, true);
      final t = poStatusTotals(r);

      expect(summary['Units Awaited'], formatQty(t.remainingQty));
      expect(t.remainingQty, 6.0);
      expect(summary['Units Awaited'], '6');
    });

    test('Completed carries Received Value and no Units Awaited', () async {
      await seedPO('PO-1', status: POStatus.fullyCompleted, ordered: 10);
      await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 10, amount: 1000);

      final r = await rowsFor(POStatus.fullyCompleted);
      final summary = poStatusExportSummary(r, false);

      expectKeysOnce(summary, const ['Orders', 'Received Value']);
      // Mirrors the screen: the card is hidden, so the key is absent.
      expect(summary.containsKey('Units Awaited'), isFalse);
      expect(summary.containsKey('Ordered Value'), isFalse);

      final t = poStatusTotals(r);
      expect(summary['Received Value'],
          ReportExportService.formatCurrency(t.received));
      expect(t.received, 1000.0);
    });

    test('decimal awaited units survive into the summary', () async {
      await seedPO('PO-1', status: POStatus.sent, ordered: 10);
      await seedGRN('GRN-1', poId: 'PO-1', receivedQty: 7.5, amount: 750);

      final summary = poStatusExportSummary(await rowsFor(POStatus.sent), true);
      expect(summary['Units Awaited'], '2.5');
    });

    test('an empty period yields zeroed totals, not missing keys', () async {
      final r = await rowsFor(POStatus.sent);
      final summary = poStatusExportSummary(r, true);

      expectKeysOnce(summary, const [
        'Orders',
        'Ordered Value',
        'Units Awaited',
      ]);
      expect(summary['Orders'], 0);
      expect(summary['Units Awaited'], '0');
    });
  });
}
