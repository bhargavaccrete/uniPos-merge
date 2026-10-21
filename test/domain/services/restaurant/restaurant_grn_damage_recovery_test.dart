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

/// D-A2 — **BILLED VALUE INCLUDES DAMAGED UNITS, AND CREDITS ONLY EVER
/// REDUCE WHAT WAS ACTUALLY BILLED.**
///
/// The defect this pins: `confirmGRN` used to accrue only `acceptedQty`, while
/// a return credit note or a settled claim refunded `damagedQty`. Receiving 10
/// of which 2 were damaged accrued 8 and credited 2, leaving the supplier owed
/// 6 units for goods worth 8 — short by exactly `damagedQty * costPrice`.
///
/// Every case below is the same receipt — **10 units @ 10, of which 2 damaged**
/// — so only the damage handling differs:
///
/// | Handling | Billed | Accepted | Credit | Net Cost | Absorbed |
/// |---|---|---|---|---|---|
/// | Return, credit note received | 100 | 80 | 20 | 80 | 0 |
/// | Claim, settled | 100 | 80 | 20 | 80 | 0 |
/// | Claim, rejected then written off | 100 | 80 | 0 | 100 | 20 |
/// | Write-off at receipt | 100 | 80 | 0 | 100 | 20 |
/// | Return, cancelled | 100 | 80 | 0 | 100 | **0** |
///
/// The last row is the interesting one. A cancelled return recovers nothing
/// *and* writes no loss document, so `damagedAbsorbed` — which counts only
/// documented write-offs — is 0 while the business still bore the cost. That
/// gap is reported as `damagedUnrecovered`, so the reconciliation balances and
/// the limbo is visible rather than silently rounded away.
void main() {
  late Directory tempDir;
  late RestaurantPurchaseReportService service;

  const supplierId = 'SUP-A';
  const supplierName = 'Dairy Co';
  const poId = 'PO-1';
  const poNumber = 'PO-20260101-001';
  const grnNumber = 'GRN-20260102-001';
  const grnItemId = 'GRNI-1';

  // One receipt, priced so the arithmetic is unambiguous.
  const unitCost = 10.0;
  const receivedQty = 10.0;
  const damagedQty = 2.0;
  const acceptedQty = receivedQty - damagedQty;

  const billed = receivedQty * unitCost; // 100
  const accepted = acceptedQty * unitCost; // 80
  const damaged = damagedQty * unitCost; // 20

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('restaurant_damage_');
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

    // The service resolves repositories through GetIt and deliberately does
    // NOT read the MobX stores (they load from their constructors and can be
    // empty on a cold start), so only repositories are registered here.
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
    // ReportHistoryWindow.cutoff reads PlanEnforce, which reads LicenseStore.
    // With no manifest seeded the catalog default for
    // reports.history_limit_days is 'all', so the window is unlimited here.
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

  String nowIso() => DateTime.now().toIso8601String();

  /// The shared receipt: 10 units @ 10, 2 damaged, handled per [handling].
  Future<void> seedReceipt(String handling) async {
    await restaurantSupplierRepository.saveSupplier(
      RestaurantSupplierModel.create(name: supplierName),
    );
    await restaurantPurchaseOrderRepository.savePurchaseOrder(
      RestaurantPurchaseOrderModel.create(
        poId: poId,
        poNumber: poNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        expectedDeliveryDate: nowIso(),
        totalItems: receivedQty,
        estimatedTotal: billed,
        status: RestaurantPOStatus.completed,
      ),
    );

    final grn = RestaurantGRNModel.create(
      // The same constant the damage documents below reference, so the GRN and
      // the paperwork raised against it finally agree on one number.
      grnNumber: grnNumber,
      poId: poId,
      poNumber: poNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      receivedDate: nowIso(),
      totalOrderedQty: receivedQty,
      totalReceivedQty: receivedQty,
      // Billed, not accepted — the figure confirmGRN posts to the ledger.
      totalAmount: billed,
      status: RestaurantGRNStatus.confirmed,
    );
    await restaurantGrnRepository.saveGRN(grn);

    await restaurantGrnItemRepository.saveItem(
      RestaurantGRNItemModel(
        grnItemId: grnItemId,
        grnId: grn.grnId,
        poItemId: 'POI-1',
        itemId: 'ITEM-1',
        itemName: 'Bun',
        orderedQty: receivedQty,
        receivedQty: receivedQty,
        acceptedQty: acceptedQty,
        damagedQty: damagedQty,
        costPrice: unitCost,
        totalAmount: billed,
        createdAt: nowIso(),
        damagedHandling: handling,
      ),
    );
    // The header id is generated, so hand it back through a field the tests
    // below read rather than assuming it.
    _seededGrnId = grn.grnId;
  }

  Future<void> seedLoss({required String reason}) async {
    await restaurantInventoryLossRepository.save(
      RestaurantInventoryLossModel.create(
        lossNumber: 'LOSS-1',
        grnId: _seededGrnId,
        grnNumber: grnNumber,
        grnItemId: grnItemId,
        poId: poId,
        supplierId: supplierId,
        supplierName: supplierName,
        itemId: 'ITEM-1',
        itemName: 'Bun',
        quantity: damagedQty,
        costPrice: unitCost,
        reason: reason,
      ),
    );
  }

  /// Asserts the identity for the whole (all-time) window.
  Future<void> expectMoney({
    required double expectedRecovered,
    required double expectedAbsorbed,
    required double expectedUnrecovered,
  }) async {
    final summary = await service.getPurchaseSummaryReport();

    expect(summary['billedValue'], billed,
        reason: 'billed must include the damaged units');
    expect(summary['acceptedValue'], accepted);
    expect(summary['damagedValue'], damaged);
    expect(summary['damagedRecovered'], expectedRecovered);
    expect(summary['damagedAbsorbed'], expectedAbsorbed);
    expect(summary['damagedUnrecovered'], expectedUnrecovered);

    // Billed - Credit = Net Cost
    expect(summary['netCost'], billed - expectedRecovered);

    // Net Cost - Accepted = what the damage actually cost us.
    expect(
      (summary['netCost'] as double) - (summary['acceptedValue'] as double),
      expectedUnrecovered,
      reason: 'unrecovered damage must close the reconciliation',
    );

    // The same figures, per supplier.
    final perSupplier = await service.getSupplierWisePurchaseReport();
    expect(perSupplier, hasLength(1));
    final row = perSupplier.single;
    expect(row['billedValue'], billed);
    expect(row['damagedRecovered'], expectedRecovered);
    expect(row['damagedAbsorbed'], expectedAbsorbed);
    expect(row['netCost'], billed - expectedRecovered);
  }

  group('the receipt itself', () {
    test('GRN report separates billed, accepted and damaged', () async {
      await seedReceipt('returnToSupplier');

      final rows = await service.getGRNReport();
      expect(rows, hasLength(1));
      final row = rows.single;

      expect(row['receivedQty'], receivedQty);
      expect(row['acceptedQty'], acceptedQty);
      expect(row['damagedQty'], damagedQty);
      expect(row['billedValue'], billed,
          reason: 'the stored header total, damage included');
      expect(row['acceptedValue'], accepted);
      expect(row['damagedValue'], damaged);
      expect(
        (row['billedValue'] as double) - (row['acceptedValue'] as double),
        damaged,
        reason: 'billed minus accepted is exactly the damaged value',
      );
    });

    test('quantities are doubles, never ints', () async {
      await seedReceipt('writeOff');
      final row = (await service.getGRNReport()).single;
      for (final key in [
        'orderedQty',
        'receivedQty',
        'acceptedQty',
        'damagedQty',
        'billedValue',
        'acceptedValue',
        'damagedValue',
      ]) {
        expect(row[key], isA<double>(), reason: '$key must be a double');
      }
    });
  });

  group('damage handling', () {
    test('return to supplier, credit note received -> net cost = accepted',
        () async {
      await seedReceipt('returnToSupplier');
      await restaurantPurchaseReturnRepository.save(
        RestaurantPurchaseReturnModel.create(
          returnNumber: 'PR-1',
          grnId: _seededGrnId,
          grnNumber: grnNumber,
          poId: poId,
          poNumber: poNumber,
          supplierId: supplierId,
          supplierName: supplierName,
          totalQty: damagedQty,
          totalAmount: damaged,
        ).copyWith(
          status: RestaurantPurchaseReturnStatus.creditReceived.name,
          creditNoteNumber: 'CN-1',
          creditNoteDate: nowIso(),
          creditNoteAmount: damaged,
          creditApplied: true,
        ),
      );

      await expectMoney(
        expectedRecovered: damaged,
        expectedAbsorbed: 0,
        expectedUnrecovered: 0,
      );
    });

    test('claim settled -> net cost = accepted', () async {
      await seedReceipt('keepForClaim');
      await restaurantSupplierClaimRepository.save(
        RestaurantSupplierClaimModel.create(
          claimNumber: 'CLM-1',
          grnId: _seededGrnId,
          grnNumber: grnNumber,
          poId: poId,
          poNumber: poNumber,
          supplierId: supplierId,
          supplierName: supplierName,
          totalQty: damagedQty,
          totalAmount: damaged,
        ).copyWith(
          status: RestaurantSupplierClaimStatus.settled.name,
          resolvedAt: nowIso(),
          creditApplied: true,
        ),
      );

      await expectMoney(
        expectedRecovered: damaged,
        expectedAbsorbed: 0,
        expectedUnrecovered: 0,
      );
    });

    test('claim rejected then written off -> absorbed, counted ONCE', () async {
      await seedReceipt('keepForClaim');
      await restaurantSupplierClaimRepository.save(
        RestaurantSupplierClaimModel.create(
          claimNumber: 'CLM-1',
          grnId: _seededGrnId,
          grnNumber: grnNumber,
          poId: poId,
          poNumber: poNumber,
          supplierId: supplierId,
          supplierName: supplierName,
          totalQty: damagedQty,
          totalAmount: damaged,
        ).copyWith(
          status: RestaurantSupplierClaimStatus.rejected.name,
          resolvedAt: nowIso(),
          // Written off, so the loss row below is the record of absorption —
          // the claim itself must NOT also count, or it would double.
          lossRecorded: true,
        ),
      );
      await seedLoss(reason: 'Supplier claim rejected');

      await expectMoney(
        expectedRecovered: 0,
        expectedAbsorbed: damaged,
        expectedUnrecovered: damaged,
      );
    });

    test('write-off at receipt -> nothing recovered, full bill stands',
        () async {
      await seedReceipt('writeOff');
      await seedLoss(reason: 'Damaged on receipt');

      await expectMoney(
        expectedRecovered: 0,
        expectedAbsorbed: damaged,
        expectedUnrecovered: damaged,
      );
    });

    test('cancelled return recovers nothing and writes no loss', () async {
      await seedReceipt('returnToSupplier');
      await restaurantPurchaseReturnRepository.save(
        RestaurantPurchaseReturnModel.create(
          returnNumber: 'PR-1',
          grnId: _seededGrnId,
          grnNumber: grnNumber,
          poId: poId,
          poNumber: poNumber,
          supplierId: supplierId,
          supplierName: supplierName,
          totalQty: damagedQty,
          totalAmount: damaged,
        ).copyWith(
          status: RestaurantPurchaseReturnStatus.cancelled.name,
        ),
      );

      // The goods never went back, so the liability the GRN accrued stands.
      // Nothing was formally written off either, which is why absorbed is 0
      // while unrecovered is the full damaged value.
      await expectMoney(
        expectedRecovered: 0,
        expectedAbsorbed: 0,
        expectedUnrecovered: damaged,
      );
    });

    test('a pending return is expected, not recovered', () async {
      await seedReceipt('returnToSupplier');
      await restaurantPurchaseReturnRepository.save(
        RestaurantPurchaseReturnModel.create(
          returnNumber: 'PR-1',
          grnId: _seededGrnId,
          grnNumber: grnNumber,
          poId: poId,
          poNumber: poNumber,
          supplierId: supplierId,
          supplierName: supplierName,
          totalQty: damagedQty,
          totalAmount: damaged,
        ),
      );

      final summary = await service.getPurchaseSummaryReport();
      expect(summary['damagedExpected'], damaged,
          reason: 'raised but not yet credited');
      expect(summary['damagedRecovered'], 0);
      expect(summary['netCost'], billed,
          reason: 'nothing is recovered until the credit note lands');
    });

    test('a partial credit note recovers only its face value', () async {
      await seedReceipt('returnToSupplier');
      await restaurantPurchaseReturnRepository.save(
        RestaurantPurchaseReturnModel.create(
          returnNumber: 'PR-1',
          grnId: _seededGrnId,
          grnNumber: grnNumber,
          poId: poId,
          poNumber: poNumber,
          supplierId: supplierId,
          supplierName: supplierName,
          totalQty: damagedQty,
          totalAmount: damaged,
        ).copyWith(
          status: RestaurantPurchaseReturnStatus.creditReceived.name,
          creditNoteNumber: 'CN-1',
          creditNoteDate: nowIso(),
          // The supplier only credited half.
          creditNoteAmount: damaged / 2,
          creditApplied: true,
        ),
      );

      await expectMoney(
        expectedRecovered: damaged / 2,
        expectedAbsorbed: 0,
        expectedUnrecovered: damaged / 2,
      );
    });
  });
}

/// Set by `seedReceipt`; the GRN id is generated by `.create()`.
String _seededGrnId = '';
