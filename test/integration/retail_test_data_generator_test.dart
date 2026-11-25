import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/domain/services/common/attendance_report_calc.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/services/retail/retail_test_data_generator.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/sign_in_fixture.dart';

/// The debug Retail test-data generator (G1): everything goes through the
/// real services, so the reports, stock and balances must agree with each
/// other — and nothing that already existed may change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late RetailTestDataResult first;

  // A real (non-test) product and customer that must stay untouched.
  const realProductId = 'real-product';
  const realVariantId = 'real-variant';
  late String realCustomerId;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('retail_test_data');
    FlutterSecureStorage.setMockInitialValues({});
    await openBoxesFor('retail', dir);
    await setupServiceLocator();
    await signInForTest(); // admin: every permission

    await productStore.addProduct(ProductModel.fromProduct(
      productId: realProductId,
      productName: 'Real Shop Item',
      category: '',
      hasVariants: false,
    ));
    await productStore.addVariant(VarianteModel.create(
      varianteId: realVariantId,
      productId: realProductId,
      sellingPrice: 99,
      stockQty: 7,
    ));
    final real = Customer.create(
        customerId: await customerIdGeneratorService.generate(),
        name: 'Real Customer');
    await customerStore.addCustomer(real);
    realCustomerId = real.customerId;
  });

  tearDownAll(() async {
    await Hive.close();
    await locator.reset();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {/* Windows handle release */}
  });

  String prefixed(String s) => 'TEST-1 $s';
  bool isTest1(String? name) => (name ?? '').startsWith('TEST-1 ');

  test('a cart in use blocks the run and nothing is created', () async {
    final real = productStore.products.firstWhere(
        (p) => p.productId == realProductId);
    final variant = await productStore.getVariantById(realVariantId);
    await retailCartStore.addItem(real, variant!);

    final r = await RetailTestDataGenerator()
        .run(const RetailTestDataOptions());

    expect(r.success, isFalse);
    expect(r.failedStep, 'Precheck');
    expect(r.steps, isEmpty);
    expect(productStore.products.where((p) => isTest1(p.productName)),
        isEmpty);
    await retailCartStore.clearCartAndSave();
  });

  test('G1 runs every step through the real services', () async {
    final steps = <String>[];
    first = await RetailTestDataGenerator(onProgress: steps.add)
        .run(const RetailTestDataOptions());

    expect(first.error, isNull, reason: '${first.failedStep}: ${first.error}');
    expect(first.success, isTrue);
    expect(first.prefix, 'TEST-1');
    expect(first.steps.every((s) => s.ok), isTrue);
    expect(steps, contains('Purchase orders and GRNs'));
    expect(steps, isNot(contains('End of Day (₹50 short)')),
        reason: 'EOD is off by default');
  });

  test('catalogue, parties: everything is TEST-prefixed', () {
    expect(productStore.products.where((p) => isTest1(p.productName)),
        hasLength(10));
    expect(customerStore.customers.where((c) => isTest1(c.name)),
        hasLength(3));
    expect(supplierStore.suppliers.where((s) => isTest1(s.name)),
        hasLength(2));
  });

  test('existing real data is untouched', () async {
    expect((await productStore.getVariantById(realVariantId))!.stockQty, 7);
    final real = await customerStore.getCustomerById(realCustomerId);
    expect(real!.creditBalance, 0);
    expect(real.totalPurchaseAmount, 0);
    expect(retailCartStore.items, isEmpty, reason: 'cart left empty');
  });

  test('credit: balances, write-off and collections agree', () async {
    final custA = customerStore.customers
        .firstWhere((c) => c.name == prefixed('Credit A'));
    final custB = customerStore.customers
        .firstWhere((c) => c.name == prefixed('Credit B'));

    final sales = await ReportService().getCreditSalesReport();
    final aSales = sales.where((s) => s.customerId == custA.customerId);
    expect(aSales, isNotEmpty);

    final payments = await ReportService().getCreditCollectionsReport();
    final ours = payments
        .where((p) =>
            p.customerId == custA.customerId ||
            p.customerId == custB.customerId)
        .toList();
    expect(ours.where((p) => p.isDebtWriteOff), hasLength(1));
    final collected = ours.where((p) => !p.isDebtWriteOff &&
        !p.isReturnAdjustment);
    final buckets = CreditPaymentRepository.bucketCollections(ours);
    expect(buckets['total'],
        collected.fold<double>(0, (s, p) => s + p.amount),
        reason: 'the write-off is listed but never collected');

    // B's only debt was written off; A owes exactly what is still due.
    final b = await customerStore.getCustomerById(custB.customerId);
    expect(b!.creditBalance, closeTo(0, 0.01));
    final a = await customerStore.getCustomerById(custA.customerId);
    final dueA = (await ReportService().getCreditSalesReport())
        .where((s) => s.customerId == custA.customerId)
        .fold<double>(0, (s, x) => s + x.dueAmount);
    expect(a!.creditBalance, closeTo(dueA, 0.01));
  });

  test('purchasing: one PO per status, two returns (credited + cancelled)',
      () async {
    final ours = purchaseOrderStore.purchaseOrders
        .where((p) => (p.notes ?? '').startsWith('TEST-1 '))
        .map((p) => p.statusEnum)
        .toList();
    expect(ours, containsAll([
      POStatus.sent,
      POStatus.partiallyCompleted,
      POStatus.fullyCompleted,
    ]));

    final grnIds = Hive.box<GRNItemModel>(HiveBoxNames.grnItems)
        .values
        .where((i) => (i.damagedQty ?? 0) > 0)
        .map((i) => i.grnId)
        .toSet();
    final returns = Hive.box<PurchaseReturnModel>(HiveBoxNames.purchaseReturns)
        .values
        .where((r) => grnIds.contains(r.grnId))
        .toList();
    expect(returns, hasLength(2));
    expect(returns.where((r) => r.status == PurchaseReturnStatus.cancelled.name),
        hasLength(1));
    expect(returns.where((r) => r.creditNoteNumber == 'TEST-1-CN-1'),
        hasLength(1));
    expect(
        Hive.box<GRNItemModel>(HiveBoxNames.grnItems)
            .values
            .where((i) => (i.damagedQty ?? 0) > 0 && i.costPrice == null),
        hasLength(1),
        reason: 'one damaged line has no cost price');
  });

  test('stock: a product only sold equals opening − sold', () async {
    final detergent = productStore.products
        .firstWhere((p) => p.productName == prefixed('Detergent 1kg'));
    final variant = (await productStore.getVariantsForProduct(
            detergent.productId))
        .single;
    final sold = Hive.box<SaleItemModel>(HiveBoxNames.saleItems)
        .values
        .where((i) => i.varianteId == variant.varianteId)
        .fold<double>(0, (s, i) => s + i.qty);
    expect(sold, greaterThan(0));
    expect(variant.stockQty, closeTo(30 - sold, 1e-9));
  });

  test('attendance: crosses months, split, overnight, absent and open', () async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 26);
    final records = (await attendanceStore.getRecordsBetweenDates(start, now))
        .where((r) => isTest1(r.staffName))
        .toList();

    expect(records.first.clockIn.month, isNot(now.month),
        reason: 'starts in the previous month');
    expect(records.where((r) => r.isOpen), hasLength(1));
    expect(records.where((r) =>
            r.clockOut != null && r.clockOut!.day != r.clockIn.day),
        isNotEmpty, reason: 'overnight shifts');
    final raviDays = records
        .where((r) => r.staffName == prefixed('Ravi'))
        .map((r) => r.date)
        .toList();
    expect(raviDays.length, greaterThan(raviDays.toSet().length),
        reason: 'two shifts on one day');
    expect(records.any((r) => (r.breakTotalMinutes ?? 0) > 0), isTrue);

    final calc = AttendanceReportCalc(
      records: records,
      from: start,
      periodEnd: now,
      activeStaffNames: const [],
      staffRoles: const {},
    );
    expect(calc.absentDays(prefixed('Asha')), greaterThan(0),
        reason: 'Sundays off');
  });

  test('a second run is detected as a duplicate and gets its own prefix',
      () async {
    final check = await RetailTestDataGenerator.check();
    expect(check.existingRuns, contains('TEST-1'));
    expect(check.nextPrefix, 'TEST-2');
  });

  test('EOD is skipped when the day was already open (may hold real sales)',
      () async {
    final r = await RetailTestDataGenerator()
        .run(const RetailTestDataOptions(endOfDayShort: true));
    expect(r.failedStep, 'End of Day (₹50 short)');
    expect(r.error, contains('NOT run'));
    expect(await DayManagementService.isSessionOpen(), isTrue,
        reason: 'the day stays open');
    expect(r.steps.where((s) => s.ok).length, r.steps.length - 1,
        reason: 'every earlier step is reported as done');
  });

  test('EOD is skipped while a REAL staff member is clocked in', () async {
    await DayManagementService.markDayEnded();
    final real = await attendanceStore.clockIn(
        staffName: 'Real Staff', staffRole: 'Cashier');

    final r = await RetailTestDataGenerator()
        .run(const RetailTestDataOptions(endOfDayShort: true));

    expect(r.failedStep, 'End of Day (₹50 short)');
    expect(r.error, contains('real staff'));
    expect(await DayManagementService.isSessionOpen(), isTrue);
    final still = (await attendanceStore.getRecordsBetweenDates(
            DateTime.now().subtract(const Duration(days: 1)), DateTime.now()))
        .firstWhere((x) => x.id == real.id);
    expect(still.isOpen, isTrue, reason: 'their shift was not touched');
    await attendanceStore.clockOut(real.id);
  });

  test('EOD runs when the generator opened the day: ₹50 short, day closed',
      () async {
    await DayManagementService.markDayEnded();
    expect(await DayManagementService.isSessionOpen(), isFalse);

    final r = await RetailTestDataGenerator().run(const RetailTestDataOptions(
        endOfDayShort: true, lowStockVariants: true));

    expect(r.error, isNull, reason: '${r.failedStep}: ${r.error}');
    expect(await DayManagementService.isSessionOpen(), isFalse);
    final reports = (await EODService.getAllEODReports())
        .where((e) => e.mode == 'retail')
        .toList();
    expect(reports.last.cashReconciliation.difference, closeTo(-50, 0.01));
    final lowStock = productStore.products
        .firstWhere((p) => p.productName == '${r.prefix} Low stock item');
    expect(await productStore.getVariantsForProduct(lowStock.productId),
        hasLength(55));
  });

  test('release builds: tile, screen and generator are all guarded', () {
    final settings = File(
            'lib/presentation/screens/retail/settings_screen.dart')
        .readAsStringSync();
    expect(settings, contains("if (!kReleaseMode && _can('settings'))"));
    expect(
        File('lib/presentation/screens/retail/settings/retail_test_data_screen.dart')
            .readAsStringSync(),
        contains('if (kReleaseMode)'));
    expect(
        File('lib/domain/services/retail/retail_test_data_generator.dart')
            .readAsStringSync(),
        contains('if (kReleaseMode) {'));
  });

  test('the generator never writes Hive boxes directly', () {
    final src = File('lib/domain/services/retail/retail_test_data_generator.dart')
        .readAsStringSync();
    expect(src, isNot(contains('Hive.box')));
    expect(src, isNot(contains('package:hive')));
    expect(src, contains('CheckoutSaleLines.build'),
        reason: 'same line builder as Checkout');
  });
}
