import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/domain/store/retail/supplier_store.dart';

/// R-03 in docs/modules/retail_inventory.md: the retail supplier ledger was
/// never exported or restored, so a restored balance lost the journal that
/// explains it. Round-trips both boxes the way UnifiedBackupService does —
/// toMap → JSON → fromMap, keyed by id.
void main() {
  late Directory tempDir;
  late SupplierStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retail_ledger_backup_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await Hive.openBox<SupplierModel>(HiveBoxNames.suppliers);
    await Hive.openBox<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger);

    await locator.reset();
    store = SupplierStore();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> roundTrip<T>(
    Box<T> box,
    Map<String, dynamic> Function(T) toMap,
    T Function(Map<String, dynamic>) fromMap,
    String Function(T) keyOf,
  ) async {
    final json = jsonEncode(box.values.map(toMap).toList());
    await box.clear();
    for (final m in jsonDecode(json) as List) {
      final model = fromMap(Map<String, dynamic>.from(m));
      await box.put(keyOf(model), model);
    }
  }

  test('ledger survives a restore and still reconciles to the balance', () async {
    final s = SupplierModel.create(name: 'Acme', openingBalance: 1000, currentBalance: 1000);
    await store.addSupplier(s);
    await store.recordBalanceMovement(
        supplierId: s.supplierId, amount: 5000, type: SupplierLedgerType.purchase,
        description: 'Goods received', docNumber: 'GRN-00001', docId: 'grn-1');
    await store.recordBalanceMovement(
        supplierId: s.supplierId, amount: -400, type: SupplierLedgerType.returnCredit,
        description: 'Credit note', docNumber: 'PR-00001');
    await store.recordBalanceMovement(
        supplierId: s.supplierId, amount: -2000, type: SupplierLedgerType.payment,
        description: 'Payment', paymentMode: 'upi', referenceNo: 'UTR123');

    final ledgerBox = Hive.box<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger);
    final before = ledgerBox.values.map((e) => e.toMap()).toList();

    await roundTrip<SupplierModel>(Hive.box<SupplierModel>(HiveBoxNames.suppliers),
        (m) => m.toMap(), SupplierModel.fromMap, (m) => m.supplierId);
    await roundTrip<SupplierLedgerEntryModel>(ledgerBox, (m) => m.toMap(),
        SupplierLedgerEntryModel.fromMap, (m) => m.entryId);
    await store.loadSuppliers();

    final after = ledgerBox.values.map((e) => e.toMap()).toList();
    expect(after, unorderedEquals(before), reason: 'every field of every row survives');
    expect(ledgerBox.get(before.first['entryId']), isNotNull, reason: 'keyed by entryId');

    final balance = store.suppliers.single.currentBalance;
    expect(balance, 3600);
    final summary = summariseLedger(await store.getLedger(s.supplierId));
    expect(summary.closing, closeTo(balance, 1e-9));
    expect(summary.payments, -2000);
    expect(summary.purchases, 5000);
  });

  test('R-51 a supplier with payments or a balance cannot be deleted',
      () async {
    // deleteBlockers also checks POs, receipts, returns and claims.
    await Hive.openBox<PurchaseOrderModel>(HiveBoxNames.purchaseOrders);
    await Hive.openBox<GRNModel>(HiveBoxNames.grns);
    await Hive.openBox<PurchaseReturnModel>(HiveBoxNames.purchaseReturns);
    await Hive.openBox<SupplierClaimModel>(HiveBoxNames.supplierClaims);

    final fresh = SupplierModel.create(name: 'Unused');
    await store.addSupplier(fresh);
    expect(await store.deleteBlockers(fresh.supplierId), isEmpty,
        reason: 'an unused supplier can still be deleted');

    // No PO or GRN — the old check let this one go, wiping its ledger.
    final paid = SupplierModel.create(
        name: 'Paid', openingBalance: 5000, currentBalance: 5000);
    await store.addSupplier(paid);
    await store.recordBalanceMovement(
        supplierId: paid.supplierId, amount: -1000,
        type: SupplierLedgerType.payment, description: 'Payment');

    final blockers = await store.deleteBlockers(paid.supplierId);
    expect(blockers, contains('1 payment or credit'));
    expect(blockers.any((b) => b.startsWith('Outstanding balance')), isTrue);
  });

  test('retail cash drawer movements survive a restore', () async {
    // Retail used to export neither this box nor its key; a restored shop lost
    // every Cash In / Cash Out and safe drop.
    final box = await Hive.openBox<CashMovementModel>(
        HiveBoxNames.restaurantCashMovements);
    await box.put('cm1', CashMovementModel(
      id: 'cm1',
      timestamp: DateTime(2026, 9, 25, 18, 30),
      type: 'out',
      amount: 1500.5,
      reason: 'Safe drop',
      note: 'EOD',
      staffName: 'Manager',
      sessionId: 'sess-1',
    ));

    await roundTrip<CashMovementModel>(box, (m) => m.toMap(),
        CashMovementModel.fromMap, (m) => m.id);

    final r = box.get('cm1')!;
    expect((r.type, r.amount, r.reason, r.note, r.staffName, r.sessionId),
        ('out', 1500.5, 'Safe drop', 'EOD', 'Manager', 'sess-1'));
    expect(r.timestamp, DateTime(2026, 9, 25, 18, 30));
  });

  test('an empty journal still reconciles via Balance brought forward', () async {
    // What an older backup (no supplierLedger key) restores to: balances,
    // no rows. The store must still explain the balance.
    final s = SupplierModel.create(name: 'Old', openingBalance: 700, currentBalance: 700);
    await store.addSupplier(s);
    await Hive.box<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger).clear();

    final summary = summariseLedger(await store.getLedger(s.supplierId));
    expect(summary.closing, closeTo(700, 1e-9));
  });
}
