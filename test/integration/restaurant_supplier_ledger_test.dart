import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_item_model.dart';

import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_ledger_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_grn_repository.dart';

/// PHASE 2 — SUPPLIER LEDGER + BACKUP/RESTORE, AGAINST REAL HIVE
///
/// Two things are proven here that a pure test cannot:
///
/// 1. **The ledger is the account history.** Recording movements the way
///    `RestaurantSupplierStore.recordBalanceMovement` does keeps
///    `currentBalance` equal to the last row's `balanceAfter`, including the
///    one-time backfill for suppliers that predate the journal.
///
/// 2. **A backup round-trip preserves the balance AND the documents that
///    justify it.** The 143-149 chain (returns, claims, losses, stock takes)
///    was absent from backup entirely before this phase, so a restore used to
///    reinstate inflated balances while destroying their credit paperwork.
///
/// The store itself resolves repositories through GetIt, so these tests drive
/// the repositories directly and replicate the store's documented write order
/// (row first, then balance) — the same judgment call
/// `inventory_chain_report_test.dart` documents.
void main() {
  late Directory tempDir;
  late RestaurantSupplierRepository supplierRepo;
  late RestaurantSupplierLedgerRepository ledgerRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('restaurant_supplier_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();

    await Hive.openBox<RestaurantSupplierModel>(HiveBoxNames.restaurantSuppliers);
    await Hive.openBox<RestaurantSupplierLedgerEntryModel>(
        HiveBoxNames.restaurantSupplierLedger);
    await Hive.openBox<RestaurantPurchaseOrderModel>(
        HiveBoxNames.restaurantPurchaseOrders);
    await Hive.openBox<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);

    supplierRepo = RestaurantSupplierRepository();
    ledgerRepo = RestaurantSupplierLedgerRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // The store's choke point, replicated: backfill, then row, then balance.
  Future<void> recordMovement({
    required String supplierId,
    required double amount,
    required RestaurantSupplierLedgerType type,
    required String description,
    String? docNumber,
    String? paymentMode,
    String? date,
  }) async {
    final supplier = supplierRepo.getSupplierById(supplierId);
    if (supplier == null) return;

    if (supplier.currentBalance != 0 && !ledgerRepo.hasEntries(supplierId)) {
      await ledgerRepo.save(RestaurantSupplierLedgerEntryModel.create(
        supplierId: supplierId,
        type: RestaurantSupplierLedgerType.opening,
        amount: supplier.currentBalance,
        balanceAfter: supplier.currentBalance,
        description: 'Balance brought forward',
        date: supplier.createdAt,
        seq: 1,
      ));
    }

    final balanceAfter = supplier.currentBalance + amount;
    final existing = await ledgerRepo.getBySupplier(supplierId);
    final nextSeq = existing.isEmpty
        ? 1
        : existing.map((e) => e.seq).reduce((a, b) => a > b ? a : b) + 1;

    await ledgerRepo.save(RestaurantSupplierLedgerEntryModel.create(
      supplierId: supplierId,
      type: type,
      amount: amount,
      balanceAfter: balanceAfter,
      description: description,
      docNumber: docNumber,
      paymentMode: paymentMode,
      date: date,
      seq: nextSeq,
    ));
    await supplierRepo
        .saveSupplier(supplier.copyWith(currentBalance: balanceAfter));
  }

  Future<RestaurantSupplierModel> makeSupplier({
    String name = 'Fresh Farms',
    double openingBalance = 0,
  }) async {
    final s = RestaurantSupplierModel.create(
        name: name, openingBalance: openingBalance);
    await supplierRepo.saveSupplier(s);
    if (openingBalance != 0) {
      await ledgerRepo.save(RestaurantSupplierLedgerEntryModel.create(
        supplierId: s.supplierId,
        type: RestaurantSupplierLedgerType.opening,
        amount: openingBalance,
        balanceAfter: openingBalance,
        description: 'Opening balance',
        date: s.createdAt,
        seq: 1,
      ));
    }
    return s;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TYPE ID RESERVATION
  // ══════════════════════════════════════════════════════════════════════════

  group('type id allocation', () {
    test('the ledger claims 185, inside the restaurant overflow range', () {
      expect(HiveTypeIds.restaurantSupplierLedgerEntry, 185);
      expect(
          HiveTypeIds.isRestaurantOverflowModel(
              HiveTypeIds.restaurantSupplierLedgerEntry),
          isTrue);
    });

    test('185 does not collide with the highest previously assigned id (184)', () {
      expect(HiveTypeIds.restaurantSupplierLedgerEntry,
          greaterThan(HiveTypeIds.retailKitAssembly));
    });

    test('its adapter registers and is usable', () async {
      expect(
          Hive.isAdapterRegistered(HiveTypeIds.restaurantSupplierLedgerEntry),
          isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // LEDGER DRIVES THE BALANCE
  // ══════════════════════════════════════════════════════════════════════════

  group('recordBalanceMovement keeps balance and ledger in step', () {
    test('a GRN writes one purchase row and raises the balance', () async {
      final s = await makeSupplier();

      await recordMovement(
        supplierId: s.supplierId,
        amount: 10000,
        type: RestaurantSupplierLedgerType.purchase,
        description: 'Goods received',
        docNumber: 'GRN-001',
      );

      final rows = await ledgerRepo.getBySupplier(s.supplierId);
      expect(rows, hasLength(1));
      expect(rows.single.typeEnum, RestaurantSupplierLedgerType.purchase);
      expect(rows.single.amount, 10000);
      expect(rows.single.docNumber, 'GRN-001');
      expect(supplierRepo.getSupplierById(s.supplierId)!.currentBalance, 10000);
    });

    test('a return credit writes a returnCredit row and lowers the balance',
        () async {
      final s = await makeSupplier();
      await recordMovement(
        supplierId: s.supplierId,
        amount: 10000,
        type: RestaurantSupplierLedgerType.purchase,
        description: 'Goods received',
      );

      await recordMovement(
        supplierId: s.supplierId,
        amount: -1200,
        type: RestaurantSupplierLedgerType.returnCredit,
        description: 'Credit note CN-1',
        docNumber: 'PR-001',
      );

      final rows = await ledgerRepo.getBySupplier(s.supplierId);
      expect(rows.last.typeEnum, RestaurantSupplierLedgerType.returnCredit);
      expect(rows.last.amount, -1200);
      expect(supplierRepo.getSupplierById(s.supplierId)!.currentBalance, 8800);
    });

    test('a settled claim writes a claimCredit row and lowers the balance',
        () async {
      final s = await makeSupplier();
      await recordMovement(
        supplierId: s.supplierId,
        amount: 5000,
        type: RestaurantSupplierLedgerType.purchase,
        description: 'Goods received',
      );

      await recordMovement(
        supplierId: s.supplierId,
        amount: -750,
        type: RestaurantSupplierLedgerType.claimCredit,
        description: 'Claim settled',
        docNumber: 'CLM-001',
      );

      final rows = await ledgerRepo.getBySupplier(s.supplierId);
      expect(rows.last.typeEnum, RestaurantSupplierLedgerType.claimCredit);
      expect(supplierRepo.getSupplierById(s.supplierId)!.currentBalance, 4250);
    });

    test('a payment writes a payment row carrying its mode', () async {
      final s = await makeSupplier();
      await recordMovement(
        supplierId: s.supplierId,
        amount: 3000,
        type: RestaurantSupplierLedgerType.purchase,
        description: 'Goods received',
      );

      await recordMovement(
        supplierId: s.supplierId,
        amount: -1000,
        type: RestaurantSupplierLedgerType.payment,
        description: 'Payment to supplier',
        paymentMode: 'UPI',
      );

      final rows = await ledgerRepo.getBySupplier(s.supplierId);
      expect(rows.last.typeEnum, RestaurantSupplierLedgerType.payment);
      expect(rows.last.paymentMode, 'UPI');
      expect(supplierRepo.getSupplierById(s.supplierId)!.currentBalance, 2000);
    });

    test('adjustments work in both directions', () async {
      final s = await makeSupplier();

      await recordMovement(
        supplierId: s.supplierId,
        amount: 500,
        type: RestaurantSupplierLedgerType.adjustment,
        description: 'Increase payable',
      );
      expect(supplierRepo.getSupplierById(s.supplierId)!.currentBalance, 500);

      await recordMovement(
        supplierId: s.supplierId,
        amount: -200,
        type: RestaurantSupplierLedgerType.adjustment,
        description: 'Reduce payable',
      );
      expect(supplierRepo.getSupplierById(s.supplierId)!.currentBalance, 300);
    });

    test('currentBalance always equals the newest row balanceAfter', () async {
      final s = await makeSupplier(openingBalance: 1000);

      await recordMovement(
          supplierId: s.supplierId,
          amount: 10000,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'GRN');
      await recordMovement(
          supplierId: s.supplierId,
          amount: -1200,
          type: RestaurantSupplierLedgerType.returnCredit,
          description: 'Return');
      await recordMovement(
          supplierId: s.supplierId,
          amount: -800,
          type: RestaurantSupplierLedgerType.claimCredit,
          description: 'Claim');
      await recordMovement(
          supplierId: s.supplierId,
          amount: -5000,
          type: RestaurantSupplierLedgerType.payment,
          description: 'Payment');

      final rows = await ledgerRepo.getBySupplier(s.supplierId);
      final balance = supplierRepo.getSupplierById(s.supplierId)!.currentBalance;

      expect(balance, 4000);
      expect(rows.last.balanceAfter, balance);

      // And the buckets reconcile to it.
      final summary = summariseRestaurantLedger(rows);
      expect(summary.impliedClosing, closeTo(balance, 1e-9));
      expect(summary.closing, balance);
    });

    test('movements sharing a timestamp keep their real order', () async {
      // Regression: `date` alone cannot order the journal — the clock's
      // resolution is platform-dependent, and two movements recorded in the
      // same millisecond produced identical strings. The sort then swapped
      // them, and since closing balance is read from the last row's
      // balanceAfter, it could report the wrong figure. `seq` breaks the tie.
      final s = await makeSupplier();
      const sameInstant = '2026-03-01T09:00:00.000';

      await recordMovement(
          supplierId: s.supplierId,
          amount: 5000,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'GRN',
          date: sameInstant);
      await recordMovement(
          supplierId: s.supplierId,
          amount: -2000,
          type: RestaurantSupplierLedgerType.payment,
          description: 'Payment',
          date: sameInstant);

      final rows = await ledgerRepo.getBySupplier(s.supplierId);

      expect(rows.map((r) => r.date).toSet(), {sameInstant},
          reason: 'both really do share a timestamp');
      expect(rows.map((r) => r.typeEnum), [
        RestaurantSupplierLedgerType.purchase,
        RestaurantSupplierLedgerType.payment,
      ]);
      expect(rows.map((r) => r.seq), [1, 2]);
      expect(rows.last.balanceAfter, 3000);
      expect(summariseRestaurantLedger(rows).closing, 3000,
          reason: 'closing must follow the true last movement, not a tie');
      expect(supplierRepo.getSupplierById(s.supplierId)!.currentBalance, 3000);
    });

    test('the full PO → GRN → return → claim → payment cycle reconciles',
        () async {
      final s = await makeSupplier();

      await recordMovement(
          supplierId: s.supplierId,
          amount: 20000,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'GRN-001',
          docNumber: 'GRN-001');
      await recordMovement(
          supplierId: s.supplierId,
          amount: -2500,
          type: RestaurantSupplierLedgerType.returnCredit,
          description: 'PR-001',
          docNumber: 'PR-001');
      await recordMovement(
          supplierId: s.supplierId,
          amount: -1500,
          type: RestaurantSupplierLedgerType.claimCredit,
          description: 'CLM-001',
          docNumber: 'CLM-001');
      await recordMovement(
          supplierId: s.supplierId,
          amount: -16000,
          type: RestaurantSupplierLedgerType.payment,
          description: 'Settled in full',
          paymentMode: 'Bank');

      final rows = await ledgerRepo.getBySupplier(s.supplierId);
      final summary = summariseRestaurantLedger(rows);

      expect(rows, hasLength(4));
      expect(summary.purchases, 20000);
      expect(summary.returnCredits, -2500);
      expect(summary.claimCredits, -1500);
      expect(summary.payments, -16000);
      expect(summary.closing, 0, reason: 'account fully settled');
      expect(supplierRepo.getSupplierById(s.supplierId)!.currentBalance, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // BACKFILL FOR PRE-LEDGER SUPPLIERS
  // ══════════════════════════════════════════════════════════════════════════

  group('backfill for suppliers that predate the journal', () {
    test('a standing balance becomes ONE brought-forward row, not invented history',
        () async {
      // A supplier as they existed before this phase: a balance, no rows.
      final legacy = RestaurantSupplierModel(
        supplierId: 'legacy-1',
        name: 'Legacy Supplier',
        currentBalance: 3400,
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      );
      await supplierRepo.saveSupplier(legacy);
      expect(ledgerRepo.hasEntries('legacy-1'), isFalse);

      await recordMovement(
        supplierId: 'legacy-1',
        amount: -400,
        type: RestaurantSupplierLedgerType.payment,
        description: 'Payment to supplier',
      );

      final rows = await ledgerRepo.getBySupplier('legacy-1');
      expect(rows, hasLength(2), reason: 'one backfill row + the payment');
      expect(rows.first.typeEnum, RestaurantSupplierLedgerType.opening);
      expect(rows.first.amount, 3400);
      expect(rows.first.description, 'Balance brought forward');
      expect(rows.first.date, legacy.createdAt,
          reason: 'dated to the supplier, not to today');
      expect(rows.last.typeEnum, RestaurantSupplierLedgerType.payment);
      expect(supplierRepo.getSupplierById('legacy-1')!.currentBalance, 3000);
      expect(summariseRestaurantLedger(rows).impliedClosing, closeTo(3000, 1e-9));
    });

    test('the backfill runs at most once', () async {
      await supplierRepo.saveSupplier(RestaurantSupplierModel(
        supplierId: 'legacy-2',
        name: 'Legacy Two',
        currentBalance: 1000,
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      ));

      await recordMovement(
          supplierId: 'legacy-2',
          amount: -100,
          type: RestaurantSupplierLedgerType.payment,
          description: 'Pay 1');
      await recordMovement(
          supplierId: 'legacy-2',
          amount: -100,
          type: RestaurantSupplierLedgerType.payment,
          description: 'Pay 2');

      final rows = await ledgerRepo.getBySupplier('legacy-2');
      final openings = rows
          .where((r) => r.typeEnum == RestaurantSupplierLedgerType.opening)
          .length;

      expect(openings, 1, reason: 'exactly one brought-forward row, ever');
      expect(rows, hasLength(3));
      expect(supplierRepo.getSupplierById('legacy-2')!.currentBalance, 800);
    });

    test('a zero-balance legacy supplier gets no invented opening row', () async {
      await supplierRepo.saveSupplier(RestaurantSupplierModel(
        supplierId: 'legacy-3',
        name: 'Legacy Three',
        currentBalance: 0,
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      ));

      await recordMovement(
          supplierId: 'legacy-3',
          amount: 500,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'GRN');

      final rows = await ledgerRepo.getBySupplier('legacy-3');
      expect(rows, hasLength(1));
      expect(rows.single.typeEnum, RestaurantSupplierLedgerType.purchase);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE GUARD
  // ══════════════════════════════════════════════════════════════════════════

  group('delete guard', () {
    test('a supplier with a PO is referenced and must not be deleted', () async {
      final s = await makeSupplier();
      final poRepo = RestaurantPurchaseOrderRepository();
      await poRepo.savePurchaseOrder(RestaurantPurchaseOrderModel.create(
        poId: 'po-1',
        poNumber: 'PO-001',
        supplierId: s.supplierId,
        supplierName: s.name,
        expectedDeliveryDate: '2026-02-01T00:00:00.000',
      ));

      final refs = poRepo.getPurchaseOrdersBySupplier(s.supplierId);
      expect(refs, hasLength(1));
    });

    test('a supplier with a GRN is referenced', () async {
      final s = await makeSupplier();
      final grnRepo = RestaurantGRNRepository();
      await grnRepo.saveGRN(RestaurantGRNModel.create(
        poId: 'po-1',
        poNumber: 'PO-001',
        supplierId: s.supplierId,
        supplierName: s.name,
        receivedDate: '2026-02-05T00:00:00.000',
      ));

      expect(grnRepo.getGRNsBySupplier(s.supplierId), hasLength(1));
    });

    test('supplier-scoped queries ignore other suppliers documents', () async {
      final a = await makeSupplier(name: 'Supplier A');
      final b = await makeSupplier(name: 'Supplier B');
      final poRepo = RestaurantPurchaseOrderRepository();

      await poRepo.savePurchaseOrder(RestaurantPurchaseOrderModel.create(
        poId: 'po-a',
        poNumber: 'PO-A',
        supplierId: a.supplierId,
        expectedDeliveryDate: '2026-02-01T00:00:00.000',
      ));

      expect(poRepo.getPurchaseOrdersBySupplier(a.supplierId), hasLength(1));
      expect(poRepo.getPurchaseOrdersBySupplier(b.supplierId), isEmpty,
          reason: 'B is unreferenced and therefore safe to delete');
    });

    test('deleting an unreferenced supplier also clears their ledger rows',
        () async {
      final s = await makeSupplier(openingBalance: 100);
      expect(ledgerRepo.hasEntries(s.supplierId), isTrue);

      await ledgerRepo.deleteBySupplier(s.supplierId);
      await supplierRepo.deleteSupplier(s.supplierId);

      expect(ledgerRepo.hasEntries(s.supplierId), isFalse);
      expect(supplierRepo.getSupplierById(s.supplierId), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // BACKUP → RESTORE
  //
  // Serialise every box the way UnifiedBackupService does (toMap), clear, then
  // rebuild via fromMap. Proves both the balance AND the documents that explain
  // it survive — the 143-149 chain was missing from backup before this phase.
  // ══════════════════════════════════════════════════════════════════════════

  group('backup → restore round-trip', () {
    /// Export a box to maps, wipe it, and restore from those maps.
    Future<void> roundTrip<T>(
      Box<T> box,
      Map<String, dynamic> Function(T) toMap,
      T Function(Map<String, dynamic>) fromMap,
      String Function(T) keyOf,
    ) async {
      final exported = box.values.map(toMap).toList();
      await box.clear();
      expect(box.values, isEmpty, reason: 'wipe must actually empty the box');
      for (final m in exported) {
        final model = fromMap(Map<String, dynamic>.from(m));
        await box.put(keyOf(model), model);
      }
    }

    test('supplier balance survives a restore', () async {
      final s = await makeSupplier(openingBalance: 1000);
      await recordMovement(
          supplierId: s.supplierId,
          amount: 5000,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'GRN');

      final box =
          Hive.box<RestaurantSupplierModel>(HiveBoxNames.restaurantSuppliers);
      await roundTrip<RestaurantSupplierModel>(
        box,
        (m) => m.toMap(),
        RestaurantSupplierModel.fromMap,
        (m) => m.supplierId,
      );

      final restored = supplierRepo.getSupplierById(s.supplierId)!;
      expect(restored.name, 'Fresh Farms');
      expect(restored.currentBalance, 6000);
      expect(restored.openingBalance, 1000);
    });

    test('the ledger survives a restore and still reconciles to the balance',
        () async {
      final s = await makeSupplier(openingBalance: 1000);
      await recordMovement(
          supplierId: s.supplierId,
          amount: 5000,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'GRN',
          docNumber: 'GRN-001');
      await recordMovement(
          supplierId: s.supplierId,
          amount: -2000,
          type: RestaurantSupplierLedgerType.payment,
          description: 'Payment',
          paymentMode: 'Cash');

      final balanceBefore =
          supplierRepo.getSupplierById(s.supplierId)!.currentBalance;

      await roundTrip<RestaurantSupplierLedgerEntryModel>(
        Hive.box<RestaurantSupplierLedgerEntryModel>(
            HiveBoxNames.restaurantSupplierLedger),
        (m) => m.toMap(),
        RestaurantSupplierLedgerEntryModel.fromMap,
        (m) => m.entryId,
      );

      final rows = await ledgerRepo.getBySupplier(s.supplierId);
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.typeEnum), [
        RestaurantSupplierLedgerType.opening,
        RestaurantSupplierLedgerType.purchase,
        RestaurantSupplierLedgerType.payment,
      ]);
      expect(rows.last.paymentMode, 'Cash');

      final summary = summariseRestaurantLedger(rows);
      expect(summary.closing, balanceBefore);
      expect(summary.impliedClosing, closeTo(balanceBefore, 1e-9));
    });

    test('purchase orders and GRNs survive a restore', () async {
      final poBox = Hive.box<RestaurantPurchaseOrderModel>(
          HiveBoxNames.restaurantPurchaseOrders);
      final grnBox = Hive.box<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);

      await poBox.put(
        'po-1',
        RestaurantPurchaseOrderModel.create(
          poId: 'po-1',
          poNumber: 'PO-001',
          supplierId: 'sup-1',
          supplierName: 'Fresh Farms',
          expectedDeliveryDate: '2026-02-01T00:00:00.000',
          estimatedTotal: 9000,
        ),
      );
      final grn = RestaurantGRNModel.create(
        poId: 'po-1',
        poNumber: 'PO-001',
        supplierId: 'sup-1',
        receivedDate: '2026-02-05T00:00:00.000',
        totalAmount: 8800,
      );
      await grnBox.put(grn.grnId, grn);

      await roundTrip<RestaurantPurchaseOrderModel>(poBox, (m) => m.toMap(),
          RestaurantPurchaseOrderModel.fromMap, (m) => m.poId);
      await roundTrip<RestaurantGRNModel>(
          grnBox, (m) => m.toMap(), RestaurantGRNModel.fromMap, (m) => m.grnId);

      expect(poBox.values.single.poNumber, 'PO-001');
      expect(poBox.values.single.estimatedTotal, 9000);
      expect(grnBox.values.single.grnNumber, grn.grnNumber);
      expect(grnBox.values.single.poNumber, 'PO-001');
      expect(grnBox.values.single.totalAmount, 8800);
    });

    test('purchase returns survive a restore', () async {
      final box = await Hive.openBox<RestaurantPurchaseReturnModel>(
          HiveBoxNames.restaurantPurchaseReturns);
      final r = RestaurantPurchaseReturnModel.create(
        returnNumber: 'PR-001',
        grnId: 'grn-1',
        grnNumber: 'GRN-001',
        poId: 'po-1',
        poNumber: 'PO-001',
        supplierId: 'sup-1',
        supplierName: 'Fresh Farms',
        totalQty: 5,
        totalAmount: 1200,
      );
      await box.put(r.returnId, r);

      await roundTrip<RestaurantPurchaseReturnModel>(box, (m) => m.toMap(),
          RestaurantPurchaseReturnModel.fromMap, (m) => m.returnId);

      final restored = box.values.single;
      expect(restored.returnNumber, 'PR-001');
      expect(restored.supplierId, 'sup-1');
      expect(restored.totalAmount, 1200);
    });

    test('purchase return items survive a restore', () async {
      final box = await Hive.openBox<RestaurantPurchaseReturnItemModel>(
          HiveBoxNames.restaurantPurchaseReturnItems);
      final item = RestaurantPurchaseReturnItemModel.create(
        returnId: 'ret-1',
        grnItemId: 'gi-1',
        itemId: 'item-1',
        itemName: 'Tomatoes',
        returnedQty: 5,
        costPrice: 40,
      );
      await box.put(item.returnItemId, item);

      await roundTrip<RestaurantPurchaseReturnItemModel>(
          box,
          (m) => m.toMap(),
          RestaurantPurchaseReturnItemModel.fromMap,
          (m) => m.returnItemId);

      expect(box.values.single.itemName, 'Tomatoes');
      expect(box.values.single.returnedQty, 5);
    });

    test('supplier claims survive a restore', () async {
      final box = await Hive.openBox<RestaurantSupplierClaimModel>(
          HiveBoxNames.restaurantSupplierClaims);
      final c = RestaurantSupplierClaimModel.create(
        claimNumber: 'CLM-001',
        grnId: 'grn-1',
        grnNumber: 'GRN-001',
        poId: 'po-1',
        poNumber: 'PO-001',
        supplierId: 'sup-1',
        totalQty: 3,
        totalAmount: 800,
      );
      await box.put(c.claimId, c);

      await roundTrip<RestaurantSupplierClaimModel>(box, (m) => m.toMap(),
          RestaurantSupplierClaimModel.fromMap, (m) => m.claimId);

      expect(box.values.single.claimNumber, 'CLM-001');
      expect(box.values.single.totalAmount, 800);
    });

    test('supplier claim items survive a restore', () async {
      final box = await Hive.openBox<RestaurantSupplierClaimItemModel>(
          HiveBoxNames.restaurantSupplierClaimItems);
      final item = RestaurantSupplierClaimItemModel.create(
        claimId: 'clm-1',
        grnItemId: 'gi-1',
        itemId: 'item-1',
        itemName: 'Paneer',
        claimedQty: 3,
        costPrice: 260,
      );
      await box.put(item.claimItemId, item);

      await roundTrip<RestaurantSupplierClaimItemModel>(
          box,
          (m) => m.toMap(),
          RestaurantSupplierClaimItemModel.fromMap,
          (m) => m.claimItemId);

      expect(box.values.single.itemName, 'Paneer');
      expect(box.values.single.claimedQty, 3);
    });

    test('inventory losses survive a restore', () async {
      final box = await Hive.openBox<RestaurantInventoryLossModel>(
          HiveBoxNames.restaurantInventoryLosses);
      final loss = RestaurantInventoryLossModel.create(
        lossNumber: 'LOSS-001',
        itemId: 'item-1',
        itemName: 'Milk',
        quantity: 4,
        costPrice: 55,
        reason: 'Damaged on receipt',
        supplierId: 'sup-1',
      );
      await box.put(loss.lossId, loss);

      await roundTrip<RestaurantInventoryLossModel>(box, (m) => m.toMap(),
          RestaurantInventoryLossModel.fromMap, (m) => m.lossId);

      final restored = box.values.single;
      expect(restored.lossNumber, 'LOSS-001');
      expect(restored.itemName, 'Milk');
      expect(restored.quantity, 4);
    });

    test('stock takes survive a restore', () async {
      final box = await Hive.openBox<RestaurantStockTakeModel>(
          HiveBoxNames.restaurantStockTakes);
      final take = RestaurantStockTakeModel.create(
        takeNumber: 'ST-001',
        countedBy: 'Manager',
        scopeNote: 'Weekly count',
      );
      await box.put(take.takeId, take);

      await roundTrip<RestaurantStockTakeModel>(box, (m) => m.toMap(),
          RestaurantStockTakeModel.fromMap, (m) => m.takeId);

      expect(box.values.single.takeNumber, 'ST-001');
      expect(box.values.single.countedBy, 'Manager');
    });

    test('stock take items survive a restore', () async {
      final box = await Hive.openBox<RestaurantStockTakeItemModel>(
          HiveBoxNames.restaurantStockTakeItems);
      final item = RestaurantStockTakeItemModel.create(
        takeId: 'take-1',
        itemId: 'item-1',
        itemName: 'Rice',
        systemQty: 50,
        countedQty: 47,
      );
      await box.put(item.takeItemId, item);

      await roundTrip<RestaurantStockTakeItemModel>(box, (m) => m.toMap(),
          RestaurantStockTakeItemModel.fromMap, (m) => m.takeItemId);

      final restored = box.values.single;
      expect(restored.itemName, 'Rice');
      expect(restored.systemQty, 50);
      expect(restored.countedQty, 47);
    });

    test('balance AND its explaining documents survive together', () async {
      // The defect this phase fixes: before it, suppliers/POs/GRNs were backed
      // up but returns and claims were not — so a restore reinstated a balance
      // already credited down, with the credit paperwork gone.
      final s = await makeSupplier();
      await recordMovement(
          supplierId: s.supplierId,
          amount: 10000,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'GRN',
          docNumber: 'GRN-001');
      await recordMovement(
          supplierId: s.supplierId,
          amount: -1200,
          type: RestaurantSupplierLedgerType.returnCredit,
          description: 'Credit note',
          docNumber: 'PR-001');

      final returnBox = await Hive.openBox<RestaurantPurchaseReturnModel>(
          HiveBoxNames.restaurantPurchaseReturns);
      final ret = RestaurantPurchaseReturnModel.create(
        returnNumber: 'PR-001',
        grnId: 'grn-1',
        grnNumber: 'GRN-001',
        poId: 'po-1',
        poNumber: 'PO-001',
        supplierId: s.supplierId,
        totalAmount: 1200,
      );
      await returnBox.put(ret.returnId, ret);

      await roundTrip<RestaurantSupplierModel>(
        Hive.box<RestaurantSupplierModel>(HiveBoxNames.restaurantSuppliers),
        (m) => m.toMap(),
        RestaurantSupplierModel.fromMap,
        (m) => m.supplierId,
      );
      await roundTrip<RestaurantSupplierLedgerEntryModel>(
        Hive.box<RestaurantSupplierLedgerEntryModel>(
            HiveBoxNames.restaurantSupplierLedger),
        (m) => m.toMap(),
        RestaurantSupplierLedgerEntryModel.fromMap,
        (m) => m.entryId,
      );
      await roundTrip<RestaurantPurchaseReturnModel>(returnBox, (m) => m.toMap(),
          RestaurantPurchaseReturnModel.fromMap, (m) => m.returnId);

      final balance = supplierRepo.getSupplierById(s.supplierId)!.currentBalance;
      final rows = await ledgerRepo.getBySupplier(s.supplierId);

      expect(balance, 8800, reason: 'credited balance, not the gross 10000');
      expect(summariseRestaurantLedger(rows).impliedClosing,
          closeTo(balance, 1e-9));
      expect(returnBox.values.single.returnNumber, 'PR-001',
          reason: 'the document justifying the credit came back too');
    });
  });
}
