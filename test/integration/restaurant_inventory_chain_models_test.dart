import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

// Import via hive_init to get all adapters registered correctly
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';

import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';

/// HIVE ROUND-TRIP TESTS FOR THE RESTAURANT INVENTORY AFTERMARKET CHAIN
/// (purchase returns, supplier claims, inventory losses, stock takes) plus
/// the recipe UOM conversion / cost-history fields added alongside them.
///
/// Same pattern as test/integration/hive_all_models_test.dart:
///   Create → save to Hive → read from Hive → verify ALL fields match.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('restaurant_inv_chain_models_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANT PURCHASE RETURN
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantPurchaseReturnModel', () {
    test('save and read a full purchase return, all fields survive',
        () async {
      final box = await Hive.openBox<RestaurantPurchaseReturnModel>(
          HiveBoxNames.restaurantPurchaseReturns);

      final original = RestaurantPurchaseReturnModel(
        returnId: 'ret-1',
        returnNumber: 'PR-20260813-001',
        grnId: 'grn-1',
        grnNumber: 'GRN-001',
        poId: 'po-1',
        poNumber: 'PO-001',
        supplierId: 'sup-1',
        supplierName: 'Fresh Farms',
        returnDate: '2026-08-13T10:00:00.000',
        totalQty: 5,
        totalAmount: 500,
        status: RestaurantPurchaseReturnStatus.pending.name,
        creditNoteNumber: 'CN-001',
        creditNoteDate: '2026-08-14T10:00:00.000',
        creditNoteAmount: 450,
        notes: 'Damaged in transit',
        createdAt: '2026-08-13T10:00:00.000',
        updatedAt: '2026-08-13T10:00:00.000',
        creditApplied: true,
      );

      await box.put(original.returnId, original);
      final loaded = box.get('ret-1');

      expect(loaded, isNotNull);
      expect(loaded!.returnNumber, equals('PR-20260813-001'));
      expect(loaded.grnId, equals('grn-1'));
      expect(loaded.grnNumber, equals('GRN-001'));
      expect(loaded.poId, equals('po-1'));
      expect(loaded.poNumber, equals('PO-001'));
      expect(loaded.supplierId, equals('sup-1'));
      expect(loaded.supplierName, equals('Fresh Farms'));
      expect(loaded.returnDate, equals('2026-08-13T10:00:00.000'));
      expect(loaded.totalQty, equals(5));
      expect(loaded.totalAmount, equals(500));
      expect(loaded.status, equals('pending'));
      expect(loaded.creditNoteNumber, equals('CN-001'));
      expect(loaded.creditNoteDate, equals('2026-08-14T10:00:00.000'));
      expect(loaded.creditNoteAmount, equals(450));
      expect(loaded.notes, equals('Damaged in transit'));
      expect(loaded.creditApplied, isTrue);

      // Computed helpers on deserialized data.
      expect(loaded.statusEnum, equals(RestaurantPurchaseReturnStatus.pending));
      expect(loaded.isOpen, isTrue);
      expect(loaded.isCreditApplied, isTrue);
      expect(loaded.statusDisplay, equals('Pending'));

      await box.close();
    });

    test('.create() factory defaults to pending status and stamps ids',
        () async {
      final created = RestaurantPurchaseReturnModel.create(
        returnNumber: 'PR-20260813-002',
        grnId: 'grn-2',
        grnNumber: 'GRN-002',
        poId: 'po-2',
        poNumber: 'PO-002',
        supplierId: 'sup-2',
      );

      expect(created.returnId, isNotEmpty);
      expect(created.status, equals(RestaurantPurchaseReturnStatus.pending.name));
      expect(created.totalQty, equals(0));
      expect(created.totalAmount, equals(0));
      expect(created.creditApplied, isNull);
      expect(created.isCreditApplied, isFalse);
    });

    test('copyWith updates status to creditReceived, other fields unchanged',
        () async {
      final original = RestaurantPurchaseReturnModel.create(
        returnNumber: 'PR-20260813-003',
        grnId: 'grn-3',
        grnNumber: 'GRN-003',
        poId: 'po-3',
        poNumber: 'PO-003',
        supplierId: 'sup-3',
        totalAmount: 300,
      );

      final updated = original.copyWith(
        status: RestaurantPurchaseReturnStatus.creditReceived.name,
        creditApplied: true,
      );

      expect(updated.returnId, equals(original.returnId));
      expect(updated.status,
          equals(RestaurantPurchaseReturnStatus.creditReceived.name));
      expect(updated.statusDisplay, equals('Credit Received'));
      expect(updated.creditApplied, isTrue);
      expect(updated.totalAmount, equals(300)); // unchanged
    });

    test('status "cancelled" round-trips and displays correctly', () async {
      final box = await Hive.openBox<RestaurantPurchaseReturnModel>(
          'test_pr_cancelled');
      final cancelled = RestaurantPurchaseReturnModel.create(
        returnNumber: 'PR-004',
        grnId: 'grn-4',
        grnNumber: 'GRN-004',
        poId: 'po-4',
        poNumber: 'PO-004',
        supplierId: 'sup-4',
      ).copyWith(status: RestaurantPurchaseReturnStatus.cancelled.name);

      await box.put(cancelled.returnId, cancelled);
      final loaded = box.get(cancelled.returnId);

      expect(loaded!.statusEnum, equals(RestaurantPurchaseReturnStatus.cancelled));
      expect(loaded.statusDisplay, equals('Cancelled'));
      expect(loaded.isOpen, isFalse);

      await box.close();
    });
  });

  group('RestaurantPurchaseReturnModel.creditAdjustment', () {
    test('returns negative noteAmount when credit not yet applied', () {
      final r = RestaurantPurchaseReturnModel.create(
        returnNumber: 'PR-1',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
        totalAmount: 500,
      );

      expect(RestaurantPurchaseReturnModel.creditAdjustment(r, 450),
          equals(-450));
    });

    test('falls back to totalAmount when noteAmount is null', () {
      final r = RestaurantPurchaseReturnModel.create(
        returnNumber: 'PR-1',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
        totalAmount: 500,
      );

      expect(RestaurantPurchaseReturnModel.creditAdjustment(r, null),
          equals(-500));
    });

    test('returns 0 when credit already applied (guards double-credit)', () {
      final r = RestaurantPurchaseReturnModel.create(
        returnNumber: 'PR-1',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
        totalAmount: 500,
      ).copyWith(creditApplied: true);

      expect(RestaurantPurchaseReturnModel.creditAdjustment(r, 450),
          equals(0));
      expect(RestaurantPurchaseReturnModel.creditAdjustment(r, null),
          equals(0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANT PURCHASE RETURN ITEM
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantPurchaseReturnItemModel', () {
    test('save and read a return item, all fields survive', () async {
      final box = await Hive.openBox<RestaurantPurchaseReturnItemModel>(
          HiveBoxNames.restaurantPurchaseReturnItems);

      final original = RestaurantPurchaseReturnItemModel(
        returnItemId: 'ri-1',
        returnId: 'ret-1',
        grnItemId: 'gi-1',
        itemId: 'item-1',
        itemName: 'Tomatoes',
        returnedQty: 10,
        costPrice: 20,
        totalAmount: 200,
        remarks: 'Rotten',
        createdAt: '2026-08-13T10:00:00.000',
      );

      await box.put(original.returnItemId, original);
      final loaded = box.get('ri-1');

      expect(loaded, isNotNull);
      expect(loaded!.returnId, equals('ret-1'));
      expect(loaded.grnItemId, equals('gi-1'));
      expect(loaded.itemId, equals('item-1'));
      expect(loaded.itemName, equals('Tomatoes'));
      expect(loaded.returnedQty, equals(10));
      expect(loaded.costPrice, equals(20));
      expect(loaded.totalAmount, equals(200));
      expect(loaded.remarks, equals('Rotten'));

      await box.close();
    });

    test('.create() factory computes totalAmount = returnedQty * costPrice',
        () {
      final created = RestaurantPurchaseReturnItemModel.create(
        returnId: 'ret-2',
        grnItemId: 'gi-2',
        itemId: 'item-2',
        returnedQty: 4,
        costPrice: 15,
      );

      expect(created.totalAmount, equals(60));
    });

    test('.create() leaves totalAmount null when costPrice is null', () {
      final created = RestaurantPurchaseReturnItemModel.create(
        returnId: 'ret-3',
        grnItemId: 'gi-3',
        itemId: 'item-3',
        returnedQty: 4,
      );

      expect(created.costPrice, isNull);
      expect(created.totalAmount, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANT SUPPLIER CLAIM
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantSupplierClaimModel', () {
    test('save and read a full supplier claim, all fields survive', () async {
      final box = await Hive.openBox<RestaurantSupplierClaimModel>(
          HiveBoxNames.restaurantSupplierClaims);

      final original = RestaurantSupplierClaimModel(
        claimId: 'claim-1',
        claimNumber: 'CLM-20260813-001',
        grnId: 'grn-1',
        grnNumber: 'GRN-001',
        poId: 'po-1',
        poNumber: 'PO-001',
        supplierId: 'sup-1',
        supplierName: 'Fresh Farms',
        claimDate: '2026-08-13T10:00:00.000',
        totalQty: 8,
        totalAmount: 800,
        status: RestaurantSupplierClaimStatus.approved.name,
        resolutionNote: 'Approved for credit',
        resolvedAt: '2026-08-15T10:00:00.000',
        notes: 'Awaiting settlement',
        createdAt: '2026-08-13T10:00:00.000',
        updatedAt: '2026-08-15T10:00:00.000',
        creditApplied: false,
        lossRecorded: false,
      );

      await box.put(original.claimId, original);
      final loaded = box.get('claim-1');

      expect(loaded, isNotNull);
      expect(loaded!.claimNumber, equals('CLM-20260813-001'));
      expect(loaded.grnId, equals('grn-1'));
      expect(loaded.poId, equals('po-1'));
      expect(loaded.supplierId, equals('sup-1'));
      expect(loaded.supplierName, equals('Fresh Farms'));
      expect(loaded.totalQty, equals(8));
      expect(loaded.totalAmount, equals(800));
      expect(loaded.status, equals('approved'));
      expect(loaded.resolutionNote, equals('Approved for credit'));
      expect(loaded.resolvedAt, equals('2026-08-15T10:00:00.000'));
      expect(loaded.notes, equals('Awaiting settlement'));
      expect(loaded.creditApplied, isFalse);
      expect(loaded.lossRecorded, isFalse);

      expect(loaded.statusEnum, equals(RestaurantSupplierClaimStatus.approved));
      expect(loaded.statusDisplay, equals('Approved'));
      expect(loaded.isOpen, isFalse); // approved, not pending
      expect(loaded.isResolved, isFalse); // only rejected/settled count
      expect(loaded.isCreditApplied, isFalse);
      expect(loaded.isLossRecorded, isFalse);

      await box.close();
    });

    test('.create() factory defaults to pending status', () {
      final created = RestaurantSupplierClaimModel.create(
        claimNumber: 'CLM-2',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
      );

      expect(created.status, equals(RestaurantSupplierClaimStatus.pending.name));
      expect(created.isOpen, isTrue);
      expect(created.isResolved, isFalse);
    });

    test('rejected and settled statuses both count as resolved', () {
      final base = RestaurantSupplierClaimModel.create(
        claimNumber: 'CLM-3',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
      );

      final rejected =
          base.copyWith(status: RestaurantSupplierClaimStatus.rejected.name);
      final settled =
          base.copyWith(status: RestaurantSupplierClaimStatus.settled.name);

      expect(rejected.isResolved, isTrue);
      expect(rejected.statusDisplay, equals('Rejected'));
      expect(settled.isResolved, isTrue);
      expect(settled.statusDisplay, equals('Settled'));
    });

    test('copyWith updates lossRecorded independently of creditApplied', () {
      final base = RestaurantSupplierClaimModel.create(
        claimNumber: 'CLM-4',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
      );

      final withLoss = base.copyWith(lossRecorded: true);
      expect(withLoss.isLossRecorded, isTrue);
      expect(withLoss.isCreditApplied, isFalse);
    });
  });

  group('RestaurantSupplierClaimModel.claimBalanceAdjustment', () {
    test('returns -totalAmount when transitioning to settled, uncredited',
        () {
      final c = RestaurantSupplierClaimModel.create(
        claimNumber: 'CLM-1',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
        totalAmount: 800,
      );

      expect(
        RestaurantSupplierClaimModel.claimBalanceAdjustment(
            c, RestaurantSupplierClaimStatus.settled),
        equals(-800),
      );
    });

    test('returns 0 for non-settled targets (approved, rejected, pending)',
        () {
      final c = RestaurantSupplierClaimModel.create(
        claimNumber: 'CLM-1',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
        totalAmount: 800,
      );

      expect(
        RestaurantSupplierClaimModel.claimBalanceAdjustment(
            c, RestaurantSupplierClaimStatus.approved),
        equals(0),
      );
      expect(
        RestaurantSupplierClaimModel.claimBalanceAdjustment(
            c, RestaurantSupplierClaimStatus.rejected),
        equals(0),
      );
      expect(
        RestaurantSupplierClaimModel.claimBalanceAdjustment(
            c, RestaurantSupplierClaimStatus.pending),
        equals(0),
      );
    });

    test('returns 0 when settling but credit already applied', () {
      final c = RestaurantSupplierClaimModel.create(
        claimNumber: 'CLM-1',
        grnId: 'g',
        grnNumber: 'g',
        poId: 'p',
        poNumber: 'p',
        supplierId: 's',
        totalAmount: 800,
      ).copyWith(creditApplied: true);

      expect(
        RestaurantSupplierClaimModel.claimBalanceAdjustment(
            c, RestaurantSupplierClaimStatus.settled),
        equals(0),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANT SUPPLIER CLAIM ITEM
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantSupplierClaimItemModel', () {
    test('save and read a claim item, all fields survive', () async {
      final box = await Hive.openBox<RestaurantSupplierClaimItemModel>(
          HiveBoxNames.restaurantSupplierClaimItems);

      final original = RestaurantSupplierClaimItemModel(
        claimItemId: 'ci-1',
        claimId: 'claim-1',
        grnItemId: 'gi-1',
        itemId: 'item-1',
        itemName: 'Milk',
        claimedQty: 6,
        costPrice: 40,
        totalAmount: 240,
        remarks: 'Spoiled batch',
        createdAt: '2026-08-13T10:00:00.000',
      );

      await box.put(original.claimItemId, original);
      final loaded = box.get('ci-1');

      expect(loaded, isNotNull);
      expect(loaded!.claimId, equals('claim-1'));
      expect(loaded.grnItemId, equals('gi-1'));
      expect(loaded.itemId, equals('item-1'));
      expect(loaded.itemName, equals('Milk'));
      expect(loaded.claimedQty, equals(6));
      expect(loaded.costPrice, equals(40));
      expect(loaded.totalAmount, equals(240));
      expect(loaded.remarks, equals('Spoiled batch'));

      await box.close();
    });

    test('.create() factory computes totalAmount = claimedQty * costPrice',
        () {
      final created = RestaurantSupplierClaimItemModel.create(
        claimId: 'claim-2',
        grnItemId: 'gi-2',
        itemId: 'item-2',
        claimedQty: 3,
        costPrice: 25,
      );

      expect(created.totalAmount, equals(75));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANT INVENTORY LOSS
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantInventoryLossModel', () {
    test('save and read a full inventory loss, all fields survive',
        () async {
      final box = await Hive.openBox<RestaurantInventoryLossModel>(
          HiveBoxNames.restaurantInventoryLosses);

      final original = RestaurantInventoryLossModel(
        lossId: 'loss-1',
        lossNumber: 'LOSS-20260813-001',
        source: RestaurantInventoryLossSource.grnDamage,
        grnId: 'grn-1',
        grnNumber: 'GRN-001',
        grnItemId: 'gi-1',
        poId: 'po-1',
        supplierId: 'sup-1',
        supplierName: 'Fresh Farms',
        itemId: 'item-1',
        itemName: 'Tomatoes',
        quantity: 5,
        costPrice: 20,
        lossValue: 100,
        reason: 'Damaged on receipt',
        note: 'Crushed in transit',
        recordedAt: '2026-08-13T10:00:00.000',
      );

      await box.put(original.lossId, original);
      final loaded = box.get('loss-1');

      expect(loaded, isNotNull);
      expect(loaded!.lossNumber, equals('LOSS-20260813-001'));
      expect(loaded.source, equals(RestaurantInventoryLossSource.grnDamage));
      expect(loaded.grnId, equals('grn-1'));
      expect(loaded.grnNumber, equals('GRN-001'));
      expect(loaded.grnItemId, equals('gi-1'));
      expect(loaded.poId, equals('po-1'));
      expect(loaded.supplierId, equals('sup-1'));
      expect(loaded.supplierName, equals('Fresh Farms'));
      expect(loaded.itemId, equals('item-1'));
      expect(loaded.itemName, equals('Tomatoes'));
      expect(loaded.quantity, equals(5));
      expect(loaded.costPrice, equals(20));
      expect(loaded.lossValue, equals(100));
      expect(loaded.reason, equals('Damaged on receipt'));
      expect(loaded.note, equals('Crushed in transit'));

      await box.close();
    });

    test('.create() factory computes lossValue = quantity * costPrice', () {
      final created = RestaurantInventoryLossModel.create(
        lossNumber: 'LOSS-2',
        itemId: 'item-2',
        quantity: 4,
        costPrice: 30,
        reason: 'Wastage / Spoilage',
      );

      expect(created.lossValue, equals(120));
      expect(created.source, equals(RestaurantInventoryLossSource.grnDamage));
    });

    test('.create() defaults lossValue to 0 when costPrice is null', () {
      final created = RestaurantInventoryLossModel.create(
        lossNumber: 'LOSS-3',
        itemId: 'item-3',
        quantity: 4,
        reason: 'Theft / Loss',
      );

      expect(created.costPrice, isNull);
      expect(created.lossValue, equals(0));
    });

    test('source constants have the expected string values', () {
      expect(RestaurantInventoryLossSource.grnDamage, equals('grn_damage'));
      expect(RestaurantInventoryLossSource.claimRejected,
          equals('claim_rejected'));
      expect(RestaurantInventoryLossSource.stockAdjustment,
          equals('stock_adjustment'));
    });

    test('claimRejected and stockAdjustment sources round-trip', () async {
      final box =
          await Hive.openBox<RestaurantInventoryLossModel>('test_loss_src');

      final claimRejected = RestaurantInventoryLossModel.create(
        lossNumber: 'LOSS-4',
        source: RestaurantInventoryLossSource.claimRejected,
        itemId: 'item-4',
        quantity: 2,
        reason: 'Claim rejected by supplier',
      );
      final stockAdj = RestaurantInventoryLossModel.create(
        lossNumber: 'LOSS-5',
        source: RestaurantInventoryLossSource.stockAdjustment,
        itemId: 'item-5',
        quantity: 1,
        reason: 'Wastage / Spoilage',
      );

      await box.put(claimRejected.lossId, claimRejected);
      await box.put(stockAdj.lossId, stockAdj);

      expect(box.get(claimRejected.lossId)!.source,
          equals('claim_rejected'));
      expect(box.get(stockAdj.lossId)!.source, equals('stock_adjustment'));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANT STOCK TAKE
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantStockTakeModel', () {
    test('save and read a full stock take, all fields survive', () async {
      final box = await Hive.openBox<RestaurantStockTakeModel>(
          HiveBoxNames.restaurantStockTakes);

      final original = RestaurantStockTakeModel(
        takeId: 'take-1',
        takeNumber: 'ST-20260820-001',
        status: RestaurantStockTakeStatus.completed.name,
        scopeNote: 'Walk-in fridge',
        varianceReason: 'Wastage / Spoilage',
        note: 'Monthly count',
        countedBy: 'Priya',
        createdAt: '2026-08-20T09:00:00.000',
        updatedAt: '2026-08-20T11:00:00.000',
        completedAt: '2026-08-20T11:00:00.000',
        committedLineCount: 3,
        committedNetQty: -4.5,
      );

      await box.put(original.takeId, original);
      final loaded = box.get('take-1');

      expect(loaded, isNotNull);
      expect(loaded!.takeNumber, equals('ST-20260820-001'));
      expect(loaded.status, equals('completed'));
      expect(loaded.scopeNote, equals('Walk-in fridge'));
      expect(loaded.varianceReason, equals('Wastage / Spoilage'));
      expect(loaded.note, equals('Monthly count'));
      expect(loaded.countedBy, equals('Priya'));
      expect(loaded.completedAt, equals('2026-08-20T11:00:00.000'));
      expect(loaded.committedLineCount, equals(3));
      expect(loaded.committedNetQty, equals(-4.5));

      expect(loaded.statusEnum, equals(RestaurantStockTakeStatus.completed));
      expect(loaded.isCompleted, isTrue);
      expect(loaded.isDraft, isFalse);
      expect(loaded.isEditable, isFalse);
      expect(loaded.statusDisplay, equals('Completed'));

      await box.close();
    });

    test('.create() factory defaults to draft, editable', () {
      final created = RestaurantStockTakeModel.create(
        takeNumber: 'ST-2',
        countedBy: 'Admin',
      );

      expect(created.status, equals(RestaurantStockTakeStatus.draft.name));
      expect(created.isDraft, isTrue);
      expect(created.isEditable, isTrue);
      expect(created.isCancelled, isFalse);
      expect(created.isCompleted, isFalse);
    });

    test('cancelled stock take is not editable and displays correctly', () {
      final cancelled = RestaurantStockTakeModel.create(
        takeNumber: 'ST-3',
        countedBy: 'Admin',
      ).copyWith(status: RestaurantStockTakeStatus.cancelled.name);

      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isEditable, isFalse);
      expect(cancelled.statusDisplay, equals('Cancelled'));
    });

    test('copyWith with clearScopeNote/clearNote nulls those fields', () {
      final withNotes = RestaurantStockTakeModel.create(
        takeNumber: 'ST-4',
        countedBy: 'Admin',
        scopeNote: 'Bar fridge',
      ).copyWith(note: 'Initial note');

      expect(withNotes.scopeNote, equals('Bar fridge'));
      expect(withNotes.note, equals('Initial note'));

      final cleared =
          withNotes.copyWith(clearScopeNote: true, clearNote: true);

      expect(cleared.scopeNote, isNull);
      expect(cleared.note, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANT STOCK TAKE ITEM — round-trip + variance getters
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantStockTakeItemModel', () {
    test('save and read a stock take item, all fields survive', () async {
      final box = await Hive.openBox<RestaurantStockTakeItemModel>(
          HiveBoxNames.restaurantStockTakeItems);

      final original = RestaurantStockTakeItemModel(
        takeItemId: 'ti-1',
        takeId: 'take-1',
        itemId: 'item-1',
        itemName: 'Rice',
        systemQty: 50,
        countedQty: 45,
        costPrice: 40,
        countedAt: '2026-08-20T10:00:00.000',
        appliedQty: -5,
      );

      await box.put(original.takeItemId, original);
      final loaded = box.get('ti-1');

      expect(loaded, isNotNull);
      expect(loaded!.takeId, equals('take-1'));
      expect(loaded.itemId, equals('item-1'));
      expect(loaded.itemName, equals('Rice'));
      expect(loaded.systemQty, equals(50));
      expect(loaded.countedQty, equals(45));
      expect(loaded.costPrice, equals(40));
      expect(loaded.appliedQty, equals(-5));

      await box.close();
    });

    test('variance/hasVariance/isShortage/varianceValue — shortage case', () {
      final item = RestaurantStockTakeItemModel.create(
        takeId: 'take-1',
        itemId: 'item-1',
        systemQty: 50,
        countedQty: 45, // 5 units missing
        costPrice: 40,
      );

      expect(item.variance, equals(-5));
      expect(item.hasVariance, isTrue);
      expect(item.isShortage, isTrue);
      expect(item.varianceValue, equals(-200)); // -5 * 40
    });

    test('variance/hasVariance/isShortage/varianceValue — surplus case', () {
      final item = RestaurantStockTakeItemModel.create(
        takeId: 'take-1',
        itemId: 'item-1',
        systemQty: 50,
        countedQty: 53, // 3 units extra
        costPrice: 10,
      );

      expect(item.variance, equals(3));
      expect(item.hasVariance, isTrue);
      expect(item.isShortage, isFalse);
      expect(item.varianceValue, equals(30)); // 3 * 10
    });

    test('variance/hasVariance/isShortage/varianceValue — no variance', () {
      final item = RestaurantStockTakeItemModel.create(
        takeId: 'take-1',
        itemId: 'item-1',
        systemQty: 20,
        countedQty: 20,
        costPrice: 15,
      );

      expect(item.variance, equals(0));
      expect(item.hasVariance, isFalse);
      expect(item.isShortage, isFalse); // variance not < 0
      expect(item.varianceValue, equals(0));
    });

    test('varianceValue is 0 when costPrice is null, even with a variance',
        () {
      final item = RestaurantStockTakeItemModel.create(
        takeId: 'take-1',
        itemId: 'item-1',
        systemQty: 50,
        countedQty: 45,
      );

      expect(item.variance, equals(-5));
      expect(item.hasVariance, isTrue);
      expect(item.costPrice, isNull);
      expect(item.varianceValue, equals(0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANT GRN ITEM — new damagedHandling field
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantGRNItemModel.damagedHandling', () {
    test('round-trips each damagedHandling value', () async {
      final box = await Hive.openBox<RestaurantGRNItemModel>(
          HiveBoxNames.restaurantGrnItems);

      for (final handling in [
        'returnToSupplier',
        'keepForClaim',
        'writeOff',
      ]) {
        final item = RestaurantGRNItemModel.create(
          grnId: 'grn-1',
          poItemId: 'poi-$handling',
          itemId: 'item-$handling',
          orderedQty: 10,
          receivedQty: 10,
          acceptedQty: 8,
          damagedQty: 2,
          costPrice: 20,
          damagedHandling: handling,
        );
        await box.put(item.grnItemId, item);

        final loaded = box.get(item.grnItemId);
        expect(loaded!.damagedHandling, equals(handling));
        expect(loaded.damagedQty, equals(2));
        expect(loaded.goodQty, equals(8)); // receivedQty - damagedQty
        expect(loaded.shortageQty, equals(0)); // orderedQty - receivedQty
      }

      await box.close();
    });

    test('damagedHandling is null when no damage recorded', () async {
      final item = RestaurantGRNItemModel.create(
        grnId: 'grn-2',
        poItemId: 'poi-2',
        itemId: 'item-2',
        orderedQty: 10,
        receivedQty: 10,
        acceptedQty: 10,
      );

      expect(item.damagedQty, isNull);
      expect(item.damagedHandling, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // STOCK MOVEMENT — new unitCost field
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: StockMovementModel.unitCost', () {
    test('unitCost round-trips when set', () async {
      final box = await Hive.openBox<StockMovementModel>(
          HiveBoxNames.restaurantStockMovements);

      final movement = StockMovementModel(
        id: 'mov-1',
        timestamp: DateTime(2026, 8, 13, 10, 0),
        itemId: 'item-1',
        itemName: 'Flour',
        type: 'out',
        quantity: 5,
        balanceAfter: 45,
        reason: 'Sale (recipe: Cake)',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 32.5,
      );

      await box.put(movement.id, movement);
      final loaded = box.get('mov-1');

      expect(loaded, isNotNull);
      expect(loaded!.unitCost, equals(32.5));

      await box.close();
    });

    test('unitCost is null for movements logged before the field existed',
        () async {
      final box =
          await Hive.openBox<StockMovementModel>('test_stock_mov_legacy');

      final legacyMovement = StockMovementModel(
        id: 'mov-2',
        timestamp: DateTime(2026, 1, 1, 9, 0),
        itemId: 'item-2',
        itemName: 'Sugar',
        type: 'in',
        quantity: 10,
        balanceAfter: 10,
        reason: 'Opening stock',
        unit: 'kg',
        staffName: 'Admin',
        // unitCost intentionally omitted
      );

      await box.put(legacyMovement.id, legacyMovement);
      final loaded = box.get('mov-2');

      expect(loaded, isNotNull);
      expect(loaded!.unitCost, isNull);

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RECIPE INGREDIENT — new conversionFactor field + effectiveQuantity
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RecipeIngredientModel.conversionFactor', () {
    test('round-trips embedded inside a RecipeModel', () async {
      final box =
          await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);

      final recipe = RecipeModel(
        id: 'recipe-1',
        itemId: 'item-cake',
        yieldQty: 1,
        ingredients: [
          RecipeIngredientModel(
            ingredientItemId: 'ing-flour',
            quantity: 250,
            unit: 'g',
            conversionFactor: 0.001, // recipe in g, item stocked in kg
          ),
          RecipeIngredientModel(
            ingredientItemId: 'ing-sugar',
            quantity: 2,
            unit: 'kg',
            // conversionFactor omitted → defaults to 1.0
          ),
        ],
      );

      await box.put(recipe.id, recipe);
      final loaded = box.get('recipe-1');

      expect(loaded, isNotNull);
      expect(loaded!.ingredients.length, equals(2));
      expect(loaded.ingredients[0].conversionFactor, equals(0.001));
      expect(loaded.ingredients[1].conversionFactor, equals(1.0));

      await box.close();
    });

    test('effectiveQuantity: conversionFactor=1, no wastage — quantity as-is',
        () {
      final ingredient = RecipeIngredientModel(
        ingredientItemId: 'ing-1',
        quantity: 100,
        conversionFactor: 1.0,
        wastagePercent: 0,
      );

      expect(ingredient.effectiveQuantity, equals(100));
    });

    test('effectiveQuantity: conversionFactor != 1, no wastage — converts',
        () {
      // 250 g of an ingredient stocked in kg → 0.25 kg consumed.
      final ingredient = RecipeIngredientModel(
        ingredientItemId: 'ing-2',
        quantity: 250,
        unit: 'g',
        conversionFactor: 0.001,
        wastagePercent: 0,
      );

      expect(ingredient.effectiveQuantity, closeTo(0.25, 1e-9));
    });

    test(
        'effectiveQuantity: conversionFactor != 1 combined with wastagePercent > 0',
        () {
      // 250 g @ 0.001 conversion = 0.25 kg base, +10% wastage = 0.275 kg.
      final ingredient = RecipeIngredientModel(
        ingredientItemId: 'ing-3',
        quantity: 250,
        unit: 'g',
        conversionFactor: 0.001,
        wastagePercent: 10,
      );

      expect(ingredient.effectiveQuantity, closeTo(0.275, 1e-9));
    });

    test('effectiveQuantity: default conversionFactor from fromMap is 1.0',
        () {
      final ingredient = RecipeIngredientModel.fromMap({
        'ingredientItemId': 'ing-4',
        'quantity': 5.0,
        'wastagePercent': 0.0,
      });

      expect(ingredient.conversionFactor, equals(1.0));
      expect(ingredient.effectiveQuantity, equals(5.0));
    });

    test('copyWith updates conversionFactor independently', () {
      final original = RecipeIngredientModel(
        ingredientItemId: 'ing-5',
        quantity: 10,
        conversionFactor: 1.0,
      );

      final updated = original.copyWith(conversionFactor: 0.5);

      expect(updated.conversionFactor, equals(0.5));
      expect(updated.quantity, equals(10)); // unchanged
      expect(updated.effectiveQuantity, equals(5.0));
    });
  });
}
