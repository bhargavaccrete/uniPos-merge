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

/// The two row-level damage reports: **Damaged Items** and **Purchase
/// Returns**.
///
/// Both are dated by the document's own creation — a receipt's `receivedDate`,
/// a return's `returnDate` — not by any later recovery, which is dated
/// separately (see `restaurant_damaged_recovery_window_test.dart`).
///
/// The rule that costs the most if broken: **a cancelled return is listed but
/// contributes no value.** The goods never went back, so nothing is owed back,
/// yet the row has to stay visible or the decision disappears from the record.
void main() {
  late Directory tempDir;
  late RestaurantPurchaseReportService service;

  const supplierId = 'SUP-A';

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('restaurant_damage_docs_');
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

  // The number is minted by the repository in production; these fixtures only
  // need each seeded GRN to carry a distinct one.
  var grnSeq = 0;

  Future<String> seedGRN({
    required DateTime at,
    RestaurantGRNStatus status = RestaurantGRNStatus.confirmed,
    String poId = 'PO-1',
  }) async {
    final grn = RestaurantGRNModel.create(
      grnNumber: 'GRN-${(++grnSeq).toString().padLeft(5, '0')}',
      poId: poId,
      poNumber: 'PO-N',
      supplierId: supplierId,
      supplierName: 'Dairy Co',
      receivedDate: at.toIso8601String(),
      totalOrderedQty: 10,
      totalReceivedQty: 10,
      totalAmount: 100,
      status: status,
    );
    await restaurantGrnRepository.saveGRN(grn);
    return grn.grnId;
  }

  Future<void> seedDamagedLine({
    required String grnId,
    required String itemName,
    required String? handling,
    double damagedQty = 2,
    double? costPrice = 10,
  }) async {
    await restaurantGrnItemRepository.saveItem(
      RestaurantGRNItemModel.create(
        grnId: grnId,
        poItemId: 'POI-$itemName',
        itemId: 'ITEM-$itemName',
        itemName: itemName,
        orderedQty: 10,
        receivedQty: 10,
        acceptedQty: 10 - damagedQty,
        damagedQty: damagedQty,
        costPrice: costPrice,
        damagedHandling: handling,
      ),
    );
  }

  group('damaged items', () {
    test('only damaged lines from confirmed receipts appear', () async {
      final ok = await seedGRN(at: DateTime(2026, 3, 5));
      final draft = await seedGRN(
        at: DateTime(2026, 3, 6),
        status: RestaurantGRNStatus.draft,
        poId: 'PO-2',
      );

      await seedDamagedLine(
          grnId: ok, itemName: 'Bun', handling: 'returnToSupplier');
      // Undamaged line on the same good receipt.
      await restaurantGrnItemRepository.saveItem(
        RestaurantGRNItemModel.create(
          grnId: ok,
          poItemId: 'POI-clean',
          itemId: 'ITEM-clean',
          itemName: 'Cheese',
          orderedQty: 5,
          receivedQty: 5,
          acceptedQty: 5,
          costPrice: 10,
        ),
      );
      // Damaged, but on a draft receipt.
      await seedDamagedLine(
          grnId: draft, itemName: 'Ghost', handling: 'writeOff');

      final rows = await service.getDamagedItemsReport();

      expect(rows, hasLength(1));
      expect(rows.single['itemName'], 'Bun');
    });

    test('outcome label comes from the model, not a screen copy', () async {
      final grnId = await seedGRN(at: DateTime(2026, 3, 5));
      await seedDamagedLine(
          grnId: grnId, itemName: 'A', handling: 'returnToSupplier');
      await seedDamagedLine(
          grnId: grnId, itemName: 'B', handling: 'keepForClaim');
      await seedDamagedLine(grnId: grnId, itemName: 'C', handling: 'writeOff');

      final rows = await service.getDamagedItemsReport();
      final byItem = {
        for (final r in rows) r['itemName'] as String: r['handlingDisplay'],
      };

      expect(byItem['A'], 'Return to Supplier');
      expect(byItem['B'], 'Keep for Claim');
      expect(byItem['C'], 'Write Off');
    });

    test('damaged value is qty x cost, and an unpriced line is flagged',
        () async {
      final grnId = await seedGRN(at: DateTime(2026, 3, 5));
      await seedDamagedLine(
          grnId: grnId, itemName: 'Priced', handling: 'writeOff');
      await seedDamagedLine(
        grnId: grnId,
        itemName: 'Unpriced',
        handling: 'writeOff',
        costPrice: null,
      );

      final rows = await service.getDamagedItemsReport();
      final priced = rows.firstWhere((r) => r['itemName'] == 'Priced');
      final unpriced = rows.firstWhere((r) => r['itemName'] == 'Unpriced');

      expect(priced['damagedValue'], 20.0);
      expect(priced['costMissing'], isFalse);

      expect(unpriced['damagedValue'], 0.0);
      expect(unpriced['costMissing'], isTrue,
          reason: 'its value is unknown, not zero');
    });

    test('is dated by the receipt', () async {
      await seedDamagedLine(
        grnId: await seedGRN(at: DateTime(2026, 1, 20)),
        itemName: 'Jan',
        handling: 'writeOff',
      );
      await seedDamagedLine(
        grnId: await seedGRN(at: DateTime(2026, 3, 20), poId: 'PO-2'),
        itemName: 'Mar',
        handling: 'writeOff',
      );

      final march = await service.getDamagedItemsReport(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 4, 1),
      );

      expect(march, hasLength(1));
      expect(march.single['itemName'], 'Mar');
    });
  });

  group('purchase returns', () {
    Future<void> seedReturn({
      required String id,
      required DateTime raisedOn,
      required String status,
      double amount = 20,
      String? creditNote,
      double? creditAmount,
    }) async {
      await restaurantPurchaseReturnRepository.save(
        RestaurantPurchaseReturnModel(
          returnId: id,
          returnNumber: 'PR-$id',
          grnId: 'GRN-1',
          grnNumber: 'GRN-1',
          poId: 'PO-1',
          poNumber: 'PO-1',
          supplierId: supplierId,
          supplierName: 'Dairy Co',
          returnDate: raisedOn.toIso8601String(),
          totalQty: 2,
          totalAmount: amount,
          status: status,
          creditNoteNumber: creditNote,
          creditNoteAmount: creditAmount,
          createdAt: raisedOn.toIso8601String(),
          updatedAt: raisedOn.toIso8601String(),
        ),
      );
    }

    test('a cancelled return is listed but counts toward no value', () async {
      await seedReturn(
        id: 'a',
        raisedOn: DateTime(2026, 3, 2),
        status: RestaurantPurchaseReturnStatus.pending.name,
      );
      await seedReturn(
        id: 'b',
        raisedOn: DateTime(2026, 3, 3),
        status: RestaurantPurchaseReturnStatus.cancelled.name,
      );

      final rows = await service.getPurchaseReturnReport();

      expect(rows, hasLength(2), reason: 'the decision stays on the record');
      final cancelled = rows.firstWhere((r) => r['returnId'] == 'b');
      final pending = rows.firstWhere((r) => r['returnId'] == 'a');

      expect(cancelled['countsTowardValue'], isFalse);
      expect(pending['countsTowardValue'], isTrue);
    });

    test('a credit note may be for less than the return total', () async {
      await seedReturn(
        id: 'a',
        raisedOn: DateTime(2026, 3, 2),
        status: RestaurantPurchaseReturnStatus.creditReceived.name,
        amount: 20,
        creditNote: 'CN-1',
        creditAmount: 12,
      );

      final row = (await service.getPurchaseReturnReport()).single;
      expect(row['totalAmount'], 20.0);
      expect(row['creditNoteAmount'], 12.0);
      expect(row['creditNoteNumber'], 'CN-1');
    });

    test('open means pending only', () async {
      await seedReturn(
        id: 'a',
        raisedOn: DateTime(2026, 3, 2),
        status: RestaurantPurchaseReturnStatus.pending.name,
      );
      await seedReturn(
        id: 'b',
        raisedOn: DateTime(2026, 3, 3),
        status: RestaurantPurchaseReturnStatus.creditReceived.name,
        creditNote: 'CN-1',
        creditAmount: 20,
      );

      final rows = await service.getPurchaseReturnReport();
      expect(rows.where((r) => r['isOpen'] == true), hasLength(1));
      expect(
        rows.firstWhere((r) => r['isOpen'] == true)['returnId'],
        'a',
      );
    });

    test('is dated by returnDate, newest first', () async {
      await seedReturn(
        id: 'jan',
        raisedOn: DateTime(2026, 1, 10),
        status: RestaurantPurchaseReturnStatus.pending.name,
      );
      await seedReturn(
        id: 'mar',
        raisedOn: DateTime(2026, 3, 10),
        status: RestaurantPurchaseReturnStatus.pending.name,
      );

      final all = await service.getPurchaseReturnReport();
      expect(all.first['returnId'], 'mar', reason: 'newest first');

      final march = await service.getPurchaseReturnReport(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 4, 1),
      );
      expect(march, hasLength(1));
      expect(march.single['returnId'], 'mar');
    });
  });
}
