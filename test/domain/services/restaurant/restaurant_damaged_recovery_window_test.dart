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

/// **RECOVERY IS DATED BY ITS OWN EVENT, NOT BY THE RECEIPT.**
///
/// Damage belongs to the period the goods arrived. Recovery belongs to the
/// period the money actually moved — which the app already records: a credit
/// note carries `creditNoteDate`, a settled claim carries `resolvedAt`, a
/// write-off carries `recordedAt`.
///
/// Date it by the receipt instead and two things break: recovery appears
/// before it happened, and a closed period changes retroactively the moment
/// someone records a credit note against an old delivery.
///
/// **Expected is not Recovered.** A raised return or claim is value *owed*;
/// only a credit note or a settlement is value *received*.
void main() {
  late Directory tempDir;
  late RestaurantPurchaseReportService service;

  DateTime jan(int d) => DateTime(2026, 1, d, 10);
  DateTime mar(int d) => DateTime(2026, 3, d, 10);

  ({DateTime start, DateTime end}) month(int m) =>
      (start: DateTime(2026, m, 1), end: DateTime(2026, m + 1, 1));

  const supplierId = 'SUP-A';
  const damaged = 20.0;

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('restaurant_recovery_');
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

  /// Built by hand rather than through `.create()` so every date is explicit —
  /// the factories stamp "now", which is exactly what this file must control.
  Future<void> seedReturn({
    required DateTime raisedOn,
    required String status,
    DateTime? creditedOn,
    double? creditAmount,
  }) async {
    await restaurantPurchaseReturnRepository.save(
      RestaurantPurchaseReturnModel(
        returnId: 'RET-1',
        returnNumber: 'PR-1',
        grnId: 'GRN-1',
        grnNumber: 'GRN-1',
        poId: 'PO-1',
        poNumber: 'PO-1',
        supplierId: supplierId,
        supplierName: 'Dairy Co',
        returnDate: raisedOn.toIso8601String(),
        totalQty: 2,
        totalAmount: damaged,
        status: status,
        creditNoteDate: creditedOn?.toIso8601String(),
        creditNoteAmount: creditAmount,
        createdAt: raisedOn.toIso8601String(),
        updatedAt: raisedOn.toIso8601String(),
      ),
    );
  }

  Future<void> seedClaim({
    required DateTime raisedOn,
    required String status,
    DateTime? resolvedOn,
    bool lossRecorded = false,
  }) async {
    await restaurantSupplierClaimRepository.save(
      RestaurantSupplierClaimModel(
        claimId: 'CLM-1',
        claimNumber: 'CLM-1',
        grnId: 'GRN-1',
        grnNumber: 'GRN-1',
        poId: 'PO-1',
        poNumber: 'PO-1',
        supplierId: supplierId,
        supplierName: 'Dairy Co',
        claimDate: raisedOn.toIso8601String(),
        totalQty: 2,
        totalAmount: damaged,
        status: status,
        resolvedAt: resolvedOn?.toIso8601String(),
        createdAt: raisedOn.toIso8601String(),
        updatedAt: raisedOn.toIso8601String(),
        lossRecorded: lossRecorded,
      ),
    );
  }

  Future<void> seedLoss({required DateTime recordedOn}) async {
    await restaurantInventoryLossRepository.save(
      RestaurantInventoryLossModel(
        lossId: 'LOSS-1',
        lossNumber: 'LOSS-1',
        source: RestaurantInventoryLossSource.grnDamage,
        grnId: 'GRN-1',
        grnNumber: 'GRN-1',
        poId: 'PO-1',
        supplierId: supplierId,
        supplierName: 'Dairy Co',
        itemId: 'ITEM-1',
        itemName: 'Bun',
        quantity: 2,
        costPrice: 10,
        lossValue: damaged,
        reason: 'Damaged on receipt',
        recordedAt: recordedOn.toIso8601String(),
      ),
    );
  }

  Future<({double expected, double recovered, double absorbed})> buckets(
    int m,
  ) async {
    final w = month(m);
    final s = await service.getPurchaseSummaryReport(
      startDate: w.start,
      endDate: w.end,
    );
    return (
      expected: s['damagedExpected'] as double,
      recovered: s['damagedRecovered'] as double,
      absorbed: s['damagedAbsorbed'] as double,
    );
  }

  test('a return raised in January and credited in March splits across both',
      () async {
    await seedReturn(
      raisedOn: jan(10),
      status: RestaurantPurchaseReturnStatus.creditReceived.name,
      creditedOn: mar(5),
      creditAmount: damaged,
    );

    final janBuckets = await buckets(1);
    final marBuckets = await buckets(3);

    // January sees nothing: by the time it was credited, the return had left
    // the pending state, and the credit itself happened in March.
    expect(janBuckets.recovered, 0.0,
        reason: 'money that moved in March cannot appear in January');
    expect(marBuckets.recovered, damaged);
    expect(marBuckets.expected, 0.0,
        reason: 'once credited it is no longer expected');
  });

  test('a still-pending return is expected in the month it was raised',
      () async {
    await seedReturn(
      raisedOn: jan(10),
      status: RestaurantPurchaseReturnStatus.pending.name,
    );

    expect((await buckets(1)).expected, damaged);
    expect((await buckets(1)).recovered, 0.0);
    expect((await buckets(3)).expected, 0.0);
  });

  test('a claim settled in March is recovered in March, not when raised',
      () async {
    await seedClaim(
      raisedOn: jan(12),
      status: RestaurantSupplierClaimStatus.settled.name,
      resolvedOn: mar(8),
    );

    expect((await buckets(1)).recovered, 0.0);
    expect((await buckets(3)).recovered, damaged);
  });

  test('an approved claim is a promise, not money', () async {
    await seedClaim(
      raisedOn: jan(12),
      status: RestaurantSupplierClaimStatus.approved.name,
    );

    final janBuckets = await buckets(1);
    expect(janBuckets.expected, damaged,
        reason: 'approved is still only expected');
    expect(janBuckets.recovered, 0.0);
  });

  test('a cancelled return appears in no bucket, in any month', () async {
    await seedReturn(
      raisedOn: jan(10),
      status: RestaurantPurchaseReturnStatus.cancelled.name,
    );

    for (final m in [1, 2, 3]) {
      final b = await buckets(m);
      expect(b.expected, 0.0, reason: 'month $m');
      expect(b.recovered, 0.0, reason: 'month $m');
      expect(b.absorbed, 0.0, reason: 'month $m');
    }
  });

  test('a rejected claim written off is absorbed ONCE, on the loss date',
      () async {
    await seedClaim(
      raisedOn: jan(12),
      status: RestaurantSupplierClaimStatus.rejected.name,
      resolvedOn: mar(2),
      lossRecorded: true,
    );
    await seedLoss(recordedOn: mar(3));

    final marBuckets = await buckets(3);
    // The claim is skipped because lossRecorded is set; only the loss row
    // counts. Counting both would double the absorbed value.
    expect(marBuckets.absorbed, damaged);
  });

  test('a rejected claim NOT written off is absorbed on its resolution date',
      () async {
    await seedClaim(
      raisedOn: jan(12),
      status: RestaurantSupplierClaimStatus.rejected.name,
      resolvedOn: mar(2),
    );

    expect((await buckets(1)).absorbed, 0.0);
    expect((await buckets(3)).absorbed, damaged,
        reason: 'the rejection is what made it a loss');
  });

  test('a loss with no supplier is inventory, not purchasing', () async {
    await restaurantInventoryLossRepository.save(
      RestaurantInventoryLossModel(
        lossId: 'LOSS-ADJ',
        lossNumber: 'LOSS-ADJ',
        source: RestaurantInventoryLossSource.stockAdjustment,
        // No grnId, no supplierId — a wastage adjustment, not a delivery.
        itemId: 'ITEM-1',
        itemName: 'Milk',
        quantity: 2,
        costPrice: 10,
        lossValue: damaged,
        reason: 'Wastage / Spoilage',
        recordedAt: mar(4).toIso8601String(),
      ),
    );

    expect((await buckets(3)).absorbed, 0.0,
        reason: 'a stock-adjustment loss belongs to inventory reporting');
  });
}
