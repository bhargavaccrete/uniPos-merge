import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/expensemodel_315.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/repositories/restaurant/eod_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_category_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/retail/attribute_repository.dart';
import 'package:billberrylite/data/repositories/retail/cart_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/hold_sale_repository.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/store/retail/hold_sale_store.dart';

import '../helpers/backup_box_registry.dart';

/// Batch 4b (BKP-2), Retail: the nine boxes whose repositories work BY ID
/// come back from a restore keyed by those IDs — held bills (and their
/// lines), expenses, expense categories, End of Day reports, credit
/// payments, product attribute links, cart lines and billing tabs. Each is
/// driven through the app's own repository (or store) after the restore.
/// No record is lost: a repeated or blank ID keeps an automatic key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
  Box<T> box<T>(String name) => Hive.box<T>(name);

  const t0 = '2026-11-12T10:00:00.000';

  HoldSaleModel held(String id) => HoldSaleModel(
      holdSaleId: id, totalItems: 2, subtotal: 300, createdAt: t0,
      updatedAt: t0);
  HoldSaleItemModel heldLine(String id, String holdId) => HoldSaleItemModel(
      holdSaleItemId: id, holdSaleId: holdId, variantId: 'v1',
      productId: 'p1', productName: 'Shirt', price: 150, qty: 1, total: 150,
      createdAt: t0);
  Expense expense(String id, double amount) =>
      Expense(id: id, dateandTime: DateTime(2026, 11, 12, 9), amount: amount);
  ExpenseCategory category(String id, String name) =>
      ExpenseCategory(id: id, name: name);
  CreditPaymentModel credit(String id) => CreditPaymentModel(
      paymentId: id, customerId: 'c1', saleId: 's1', amount: 200,
      paymentMode: 'cash', date: t0, createdAt: t0, balanceBefore: 500,
      balanceAfter: 300);
  ProductAttributeModel link(String id, String productId, List<String> values) =>
      ProductAttributeModel(id: id, productId: productId, attributeId: 'size',
          selectedValueIds: values, createdAt: t0);
  CartItemModel cartLine(String id, double qty) => CartItemModel(
      cartItemId: id, variantId: 'v1', productId: 'p1', productName: 'Shirt',
      price: 150, qty: qty, total: 150 * qty, addedAt: t0);
  BillingTabModel tab(String id, String name) => BillingTabModel(
      id: id, name: name, items: const [], createdAt: DateTime(2026, 11, 12),
      updatedAt: DateTime(2026, 11, 12));
  EndOfDayReport eod(String id, {double sales = 1000}) => EndOfDayReport(
        reportId: id,
        date: DateTime(2026, 11, 12),
        openingBalance: 500,
        orderSummaries: const [],
        totalDiscount: 0,
        totalTax: 0,
        categorySales: const [],
        paymentSummaries: const [],
        cashReconciliation: CashReconciliation(
          systemExpectedCash: 1500,
          actualCash: 1500,
          difference: 0,
          reconciliationStatus: 'Balanced',
        ),
        totalSales: sales,
        closingBalance: 1500,
        taxSummaries: const [],
        totalOrderCount: 3,
        totalRefunds: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        mode: 'retail',
      );

  Future<void> clearAll() async {
    await box<HoldSaleModel>(HiveBoxNames.holdSales).clear();
    await box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems).clear();
    await box<Expense>('expenseBox').clear();
    await box<ExpenseCategory>('expenseCategory').clear();
    await box<EndOfDayReport>('eodBox').clear();
    await box<CreditPaymentModel>(HiveBoxNames.creditPayments).clear();
    await box<ProductAttributeModel>(HiveBoxNames.productAttributes).clear();
    await box<CartItemModel>(HiveBoxNames.cartItems).clear();
    await box<BillingTabModel>(HiveBoxNames.billingTabs).clear();
  }

  /// One record set per box, written as the app writes them (put by ID).
  Future<void> seed(String tag) async {
    await clearAll();
    final holds = HoldSaleRepository()..init();
    await holds.addHoldSale(held('h-$tag'));
    await holds.addHoldSaleItems(
        [heldLine('hl1-$tag', 'h-$tag'), heldLine('hl2-$tag', 'h-$tag')]);
    await ExpenseRepository().addExpense(expense('x1-$tag', 120));
    await ExpenseRepository().addExpense(expense('x2-$tag', 80));
    await ExpenseCategoryRepository()
        .addExpenseCategory(category('k1-$tag', 'Rent'));
    await EodRepository().addEODReport(eod('r1-$tag'));
    await CreditPaymentRepository().addPayment(credit('cp1-$tag'));
    final attrs = AttributeRepository();
    // Two products share the same attribute: keyed by attributeId they
    // would collapse into one.
    await attrs.assignAttributeToProduct(link('pa1-$tag', 'p1', ['s', 'm']));
    await attrs.assignAttributeToProduct(link('pa2-$tag', 'p2', ['l']));
    final cart = CartRepository();
    await cart.saveCartItem(cartLine('ci1-$tag', 1));
    await cart.saveTab(tab('t1-$tag', 'Bill 1'));
  }

  Future<Map<String, dynamic>> backupOfSeed(String tag) async {
    await seed(tag);
    return copy(await UnifiedBackupService.collectAllDataForTesting());
  }

  Future<void> restore(Map<String, dynamic> backup) =>
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_bkp2_retail_');
    await openBoxesFor('retail', tempDir);
    // openBoxesFor sets the mode; the repositories pick their box from it.
    expect(AppConfig.businessMode, BusinessMode.retail);
    await AppConfig.box.put('isSetupComplete', true);
  });

  setUp(() {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('every affected box is keyed by its records\' own IDs after a restore',
      () async {
    final backup = await backupOfSeed('b');
    await seed('device');

    await restore(backup);

    expect(box<HoldSaleModel>(HiveBoxNames.holdSales).keys, ['h-b']);
    expect(box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems).keys.toSet(),
        {'hl1-b', 'hl2-b'});
    expect(box<Expense>('expenseBox').keys.toSet(), {'x1-b', 'x2-b'});
    expect(box<ExpenseCategory>('expenseCategory').keys, ['k1-b']);
    expect(box<EndOfDayReport>('eodBox').keys, ['r1-b']);
    expect(box<CreditPaymentModel>(HiveBoxNames.creditPayments).keys,
        ['cp1-b']);
    expect(box<ProductAttributeModel>(HiveBoxNames.productAttributes)
        .keys.toSet(), {'pa1-b', 'pa2-b'},
        reason: 'keyed by the link id, so both links survive');
    expect(box<CartItemModel>(HiveBoxNames.cartItems).keys, ['ci1-b']);
    expect(box<BillingTabModel>(HiveBoxNames.billingTabs).keys, ['t1-b']);
    expect(UnifiedBackupService.lastRestoreUnkeyedRecords, isEmpty);
  });

  test('a recalled held bill is deleted with its lines — it cannot be billed '
      'twice', () async {
    final backup = await backupOfSeed('b');
    await seed('device');
    await restore(backup);

    final store = HoldSaleStore(HoldSaleRepository());
    await store.init();
    expect(store.holdSales.map((h) => h.holdSaleId), ['h-b']);
    expect(await store.getHoldSaleById('h-b'), isNotNull);

    // HoldSaleService.restore's last step after loading the bill to the cart.
    await store.deleteHoldSale('h-b');

    expect(box<HoldSaleModel>(HiveBoxNames.holdSales).isEmpty, isTrue);
    expect(box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems).isEmpty, isTrue);
    expect(store.holdSales, isEmpty, reason: 'nothing left to recall again');
  });

  test('editing an expense after a restore does not duplicate it; delete '
      'works', () async {
    final backup = await backupOfSeed('b');
    await seed('device');
    await restore(backup);

    final repo = ExpenseRepository();
    expect((await repo.getExpenseById('x1-b'))?.amount, 120);
    await repo.updateExpense(expense('x1-b', 150));
    expect(box<Expense>('expenseBox').length, 2, reason: 'no duplicate');
    expect((await repo.getExpenseById('x1-b'))?.amount, 150);
    expect(await repo.getTotalExpenses(), 230, reason: '150 + 80, counted once');

    await repo.deleteExpense('x2-b');
    expect(box<Expense>('expenseBox').keys, ['x1-b']);
  });

  test('expense categories, EOD reports and credit payments: get, update, '
      'delete by ID', () async {
    final backup = await backupOfSeed('b');
    await seed('device');
    await restore(backup);

    final cats = ExpenseCategoryRepository();
    await cats.updateExpenseCategory(category('k1-b', 'Rent & lights'));
    expect(box<ExpenseCategory>('expenseCategory').length, 1);
    expect((await cats.getExpenseCategoryById('k1-b'))?.name, 'Rent & lights');
    await cats.deleteExpenseCategory('k1-b');
    expect(box<ExpenseCategory>('expenseCategory').isEmpty, isTrue);

    final eods = EodRepository();
    await eods.updateEODReport(eod('r1-b', sales: 4000));
    expect(box<EndOfDayReport>('eodBox').length, 1);
    expect(box<EndOfDayReport>('eodBox').get('r1-b')!.totalSales, 4000);
    await eods.deleteEODReport('r1-b');
    expect(box<EndOfDayReport>('eodBox').isEmpty, isTrue);

    final credits = CreditPaymentRepository();
    expect(await credits.getPaymentById('cp1-b'), isNotNull);
    await credits.deletePayment('cp1-b');
    expect(box<CreditPaymentModel>(HiveBoxNames.creditPayments).isEmpty,
        isTrue);
  });

  test('product attribute links, cart lines and tabs: update in place, '
      'delete by ID', () async {
    final backup = await backupOfSeed('b');
    await seed('device');
    await restore(backup);

    final attrs = AttributeRepository();
    await attrs.updateProductAttribute(link('pa1-b', 'p1', ['xl']));
    expect(box<ProductAttributeModel>(HiveBoxNames.productAttributes).length,
        2);
    expect((await attrs.getProductAttributes('p1')).single.selectedValueIds,
        ['xl']);
    await attrs.removeAttributeFromProduct('p2', 'size');
    expect(await attrs.getProductAttributes('p2'), isEmpty);

    final cart = CartRepository();
    await cart.saveCartItem(cartLine('ci1-b', 3));
    expect(cart.getAllCartItems().single.qty, 3, reason: 'no duplicate line');
    await cart.deleteCartItem('ci1-b');
    expect(cart.getAllCartItems(), isEmpty);

    await cart.saveTab(tab('t1-b', 'Bill 1 (renamed)'));
    expect(cart.getAllTabs().single.name, 'Bill 1 (renamed)');
    await cart.deleteTab('t1-b');
    expect(cart.getAllTabs(), isEmpty);
  });

  test('a repeated ID loses no record; the last copy takes the ID key',
      () async {
    final backup = await backupOfSeed('b');
    final list = (backup['data'] as Map)['expenses'] as List;
    // As exported from a device restored before BKP-2 and then edited:
    // the stale copy first (automatic key), the edited one last (ID key).
    final stale = {...(list.first as Map), 'amount': 120};
    final edited = {...(list.first as Map), 'amount': 150};
    list
      ..clear()
      ..addAll([stale, edited]);

    await restore(backup);

    expect(box<Expense>('expenseBox').length, 2, reason: 'none dropped');
    expect((await ExpenseRepository().getExpenseById('x1-b'))?.amount, 150);
    expect(UnifiedBackupService.lastRestoreUnkeyedRecords, {'expenses': 1});
  });

  test('a failed restore rolls all nine boxes back under their IDs, verified',
      () async {
    final backup = await backupOfSeed('b');
    await seed('device');
    // printers is written after every one of the nine boxes.
    UnifiedBackupService.failWritingKeyForTesting = 'printers';

    await expectLater(
      restore(backup),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );

    expect(box<HoldSaleModel>(HiveBoxNames.holdSales).keys, ['h-device']);
    expect(box<Expense>('expenseBox').keys.toSet(),
        {'x1-device', 'x2-device'});
    expect(box<ProductAttributeModel>(HiveBoxNames.productAttributes)
        .keys.toSet(), {'pa1-device', 'pa2-device'});
    expect(box<BillingTabModel>(HiveBoxNames.billingTabs).keys, ['t1-device']);

    final store = HoldSaleStore(HoldSaleRepository());
    await store.init();
    await store.deleteHoldSale('h-device');
    expect(box<HoldSaleModel>(HiveBoxNames.holdSales).isEmpty, isTrue,
        reason: 'ID operations work after the rollback');
  });
}
