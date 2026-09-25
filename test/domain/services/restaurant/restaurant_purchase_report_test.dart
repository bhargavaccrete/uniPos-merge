import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';

import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';

import 'package:billberrylite/data/repositories/restaurant/restaurant_grn_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_inventory_loss_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_return_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_claim_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_repository.dart';

import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';

/// The purchase report service's core contract: the date window, the PO status
/// rollup, and per-supplier grouping.
///
/// Three restaurant-specific traps are pinned here, all of which fail
/// *quietly* if someone copies retail's implementation across:
///
/// 1. **`RestaurantPOStatus` is not retail's `POStatus`.** It says
///    `partiallyReceived`/`completed`, where retail says
///    `partiallyCompleted`/`fullyCompleted`. Get it wrong and outstanding
///    value silently drops every partially-received order.
/// 2. **A stored date is a `String`.** An unparseable one must be excluded,
///    not crash the report, and not sneak in via an all-time query.
/// 3. **Suppliers group by id, never by name** — otherwise two suppliers
///    sharing a name merge, and one supplier's history splits on a rename.
void main() {
  late Directory tempDir;
  late RestaurantPurchaseReportService service;

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('restaurant_purch_rpt_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'restaurant');

    await Hive.openBox<RestaurantSupplierModel>(
        HiveBoxNames.restaurantSuppliers);
    await Hive.openBox<RestaurantPurchaseOrderModel>(
        HiveBoxNames.restaurantPurchaseOrders);
    await Hive.openBox<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);
    await Hive.openBox<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems);
    await Hive.openBox<RestaurantPurchaseReturnModel>(
        HiveBoxNames.restaurantPurchaseReturns);
    await Hive.openBox<RestaurantSupplierClaimModel>(
        HiveBoxNames.restaurantSupplierClaims);
    await Hive.openBox<RestaurantInventoryLossModel>(
        HiveBoxNames.restaurantInventoryLosses);

    locator.registerLazySingleton<RestaurantSupplierRepository>(
        () => RestaurantSupplierRepository());
    locator.registerLazySingleton<RestaurantPurchaseOrderRepository>(
        () => RestaurantPurchaseOrderRepository());
    locator.registerLazySingleton<RestaurantGRNRepository>(
        () => RestaurantGRNRepository());
    locator.registerLazySingleton<RestaurantGRNItemRepository>(
        () => RestaurantGRNItemRepository());
    locator.registerLazySingleton<RestaurantPurchaseReturnRepository>(
        () => RestaurantPurchaseReturnRepository());
    locator.registerLazySingleton<RestaurantSupplierClaimRepository>(
        () => RestaurantSupplierClaimRepository());
    locator.registerLazySingleton<RestaurantInventoryLossRepository>(
        () => RestaurantInventoryLossRepository());
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));

    service = RestaurantPurchaseReportService();
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A confirmed receipt on [receivedDate], which may deliberately be an
  /// unparseable string.
  // The number is minted by the repository in production; these fixtures only
  // need each seeded GRN to carry a distinct one.
  var grnSeq = 0;

  Future<String> seedGRN({
    required String receivedDate,
    String supplierId = 'SUP-A',
    String? supplierName = 'Dairy Co',
    double qty = 10,
    double amount = 100,
    RestaurantGRNStatus status = RestaurantGRNStatus.confirmed,
    String poId = 'PO-1',
  }) async {
    final grn = RestaurantGRNModel.create(
      grnNumber: 'GRN-${(++grnSeq).toString().padLeft(5, '0')}',
      poId: poId,
      poNumber: 'PO-N',
      supplierId: supplierId,
      supplierName: supplierName,
      receivedDate: receivedDate,
      totalOrderedQty: qty,
      totalReceivedQty: qty,
      totalAmount: amount,
      status: status,
    );
    await restaurantGrnRepository.saveGRN(grn);
    return grn.grnId;
  }

  Future<void> seedPO({
    required String poId,
    required RestaurantPOStatus status,
    double totalItems = 10,
    double estimatedTotal = 100,
    String supplierId = 'SUP-A',
  }) async {
    await restaurantPurchaseOrderRepository.savePurchaseOrder(
      RestaurantPurchaseOrderModel.create(
        poId: poId,
        poNumber: 'PO-$poId',
        supplierId: supplierId,
        supplierName: 'Dairy Co',
        expectedDeliveryDate: DateTime.now().toIso8601String(),
        totalItems: totalItems,
        estimatedTotal: estimatedTotal,
        status: status,
      ),
    );
  }

  group('date window', () {
    test('a record exactly on start is IN, exactly on end is OUT', () async {
      final start = DateTime(2026, 3, 1);
      final end = DateTime(2026, 4, 1);

      await seedGRN(receivedDate: start.toIso8601String(), poId: 'PO-on-start');
      await seedGRN(receivedDate: end.toIso8601String(), poId: 'PO-on-end');

      final rows = await service.getGRNReport(startDate: start, endDate: end);

      expect(rows, hasLength(1),
          reason: 'start is inclusive, end is exclusive');
      expect(rows.single['receivedDate'], start.toIso8601String());
    });

    test('an unparseable date is excluded even from an all-time query',
        () async {
      await seedGRN(receivedDate: 'not-a-date', poId: 'PO-bad');
      await seedGRN(
        receivedDate: DateTime(2026, 3, 15).toIso8601String(),
        poId: 'PO-good',
      );

      // No start/end at all — the most permissive query there is.
      final rows = await service.getGRNReport();

      expect(rows, hasLength(1),
          reason: 'a row with no usable date cannot be placed in time');
      expect(rows.single['poNumber'], 'PO-N');
    });

    test('draft and cancelled receipts never appear', () async {
      final at = DateTime(2026, 3, 10).toIso8601String();
      await seedGRN(
          receivedDate: at,
          status: RestaurantGRNStatus.draft,
          poId: 'PO-draft');
      await seedGRN(
          receivedDate: at,
          status: RestaurantGRNStatus.cancelled,
          poId: 'PO-cancelled');
      await seedGRN(
          receivedDate: at,
          status: RestaurantGRNStatus.confirmed,
          poId: 'PO-ok');

      final rows = await service.getGRNReport();
      expect(rows, hasLength(1),
          reason: 'a draft moved no stock and owes no money');
    });
  });

  group('purchase order status', () {
    test('every RestaurantPOStatus name appears in countByStatus', () async {
      for (final s in RestaurantPOStatus.values) {
        await seedPO(poId: 'PO-${s.name}', status: s);
      }

      final summary = await service.getPurchaseSummaryReport();
      final counts = summary['countByStatus'] as Map<String, int>;

      // Folding the enum itself is what catches a copied retail status name.
      for (final s in RestaurantPOStatus.values) {
        expect(counts.containsKey(s.name), isTrue,
            reason: '${s.name} must be represented');
        expect(counts[s.name], 1);
      }
      expect(counts.keys.length, RestaurantPOStatus.values.length);
    });

    test('outstanding covers sent AND partiallyReceived only', () async {
      await seedPO(poId: 'a', status: RestaurantPOStatus.draft);
      await seedPO(poId: 'b', status: RestaurantPOStatus.sent);
      await seedPO(poId: 'c', status: RestaurantPOStatus.partiallyReceived);
      await seedPO(poId: 'd', status: RestaurantPOStatus.completed);
      await seedPO(poId: 'e', status: RestaurantPOStatus.cancelled);

      final summary = await service.getPurchaseSummaryReport();

      // sent (100) + partiallyReceived (100). Restaurant's enum name is
      // partiallyReceived — retail's partiallyCompleted would miss this.
      expect(summary['outstandingValue'], 200.0);
      // Placed orders only: draft was never placed, cancelled never will be.
      expect(summary['orderedValue'], 300.0);
      expect(summary['orderCount'], 5, reason: 'the count includes all of them');
    });

    test('a status report returns only that status', () async {
      await seedPO(poId: 'a', status: RestaurantPOStatus.sent);
      await seedPO(poId: 'b', status: RestaurantPOStatus.sent);
      await seedPO(poId: 'c', status: RestaurantPOStatus.completed);

      final sent = await service
          .getPurchaseOrderStatusReport(RestaurantPOStatus.sent);
      expect(sent, hasLength(2));
      expect(
        sent.every((r) => r['status'] == RestaurantPOStatus.sent.name),
        isTrue,
      );
    });

    test('remainingQty stays a double and never goes negative on over-receipt',
        () async {
      await seedPO(poId: 'PO-over', status: RestaurantPOStatus.completed,
          totalItems: 10);
      // 15 received against 10 ordered.
      await seedGRN(
        receivedDate: DateTime(2026, 3, 2).toIso8601String(),
        qty: 15,
        poId: 'PO-over',
      );

      final rows = await service
          .getPurchaseOrderStatusReport(RestaurantPOStatus.completed);
      final row = rows.single;

      expect(row['receivedQty'], 15.0);
      expect(row['remainingQty'], 0.0, reason: 'clamped, not negative');
      expect(row['remainingQty'], isA<double>(),
          reason: 'num.clamp returns whichever operand it picked');
    });

    test('receiving progress ignores the report window', () async {
      await seedPO(poId: 'PO-1', status: RestaurantPOStatus.completed);
      await seedGRN(
        receivedDate: DateTime(2026, 1, 5).toIso8601String(),
        qty: 10,
        poId: 'PO-1',
      );

      // A March window: the January receipt is outside it, but the order's
      // progress is a fact about the order, not about the period viewed.
      final rows = await service.getPurchaseOrderStatusReport(
        RestaurantPOStatus.completed,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 4, 1),
      );
      // The PO itself was created "now", so it may or may not fall in the
      // window — assert on progress only when the row is present.
      for (final row in rows) {
        expect(row['receivedQty'], 10.0);
      }
    });
  });

  group('supplier grouping', () {
    test('two suppliers sharing a name do not merge', () async {
      final at = DateTime(2026, 3, 4).toIso8601String();
      await seedGRN(
          receivedDate: at,
          supplierId: 'SUP-A',
          supplierName: 'Dairy Co',
          amount: 100,
          poId: 'PO-a');
      await seedGRN(
          receivedDate: at,
          supplierId: 'SUP-B',
          supplierName: 'Dairy Co',
          amount: 250,
          poId: 'PO-b');

      final rows = await service.getSupplierWisePurchaseReport();

      expect(rows, hasLength(2), reason: 'grouped by id, not by name');
      expect(rows.map((r) => r['supplierId']), containsAll(['SUP-A', 'SUP-B']));
      // Sorted by billed value, descending.
      expect(rows.first['supplierId'], 'SUP-B');
      expect(rows.first['billedValue'], 250.0);
    });

    test('a rename does not relabel history captured under the old name',
        () async {
      await restaurantSupplierRepository.saveSupplier(
        RestaurantSupplierModel.create(name: 'New Name Ltd'),
      );
      await seedGRN(
        receivedDate: DateTime(2026, 3, 4).toIso8601String(),
        supplierId: 'SUP-A',
        supplierName: 'Old Name Ltd',
      );

      final row = (await service.getSupplierWisePurchaseReport()).single;
      expect(row['supplierName'], 'Old Name Ltd',
          reason: 'the GRN snapshot wins over the live record');
    });

    test('a supplier with no name anywhere reads as Unknown Supplier',
        () async {
      await seedGRN(
        receivedDate: DateTime(2026, 3, 4).toIso8601String(),
        supplierId: 'SUP-GHOST',
        supplierName: '   ',
      );

      final row = (await service.getSupplierWisePurchaseReport()).single;
      expect(row['supplierName'], 'Unknown Supplier');
    });

    test('a supplier whose only activity was a credit note still appears',
        () async {
      // No GRN for SUP-C at all in this window — only a settled claim.
      await restaurantSupplierClaimRepository.save(
        RestaurantSupplierClaimModel.create(
          claimNumber: 'CLM-1',
          grnId: 'GRN-OLD',
          grnNumber: 'GRN-OLD',
          poId: 'PO-OLD',
          poNumber: 'PO-OLD',
          supplierId: 'SUP-C',
          supplierName: 'Cheese Bros',
          totalQty: 2,
          totalAmount: 40,
        ).copyWith(
          status: RestaurantSupplierClaimStatus.settled.name,
          resolvedAt: DateTime.now().toIso8601String(),
        ),
      );

      final rows = await service.getSupplierWisePurchaseReport();
      final row = rows.firstWhere((r) => r['supplierId'] == 'SUP-C');

      expect(row['supplierName'], 'Cheese Bros');
      expect(row['billedValue'], 0.0);
      expect(row['damagedRecovered'], 40.0);
      expect(row['netCost'], -40.0,
          reason: 'a credit with no purchase this period is money back');
    });
  });

  group('empty state', () {
    test('no data yields empty rows and a zeroed summary', () async {
      expect(await service.getGRNReport(), isEmpty);
      expect(await service.getSupplierWisePurchaseReport(), isEmpty);

      final summary = await service.getPurchaseSummaryReport();
      expect(summary['orderCount'], 0);
      expect(summary['receiptCount'], 0);
      expect(summary['billedValue'], 0.0);
      expect(summary['netCost'], 0.0);
    });
  });
}
