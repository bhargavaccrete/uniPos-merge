import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// CREDIT REPORTS — Credit Sales, Collections, Outstanding.
///
/// None of this had tests, which is how the Collections tab came to compute the
/// same figure two different ways: the date-filtered path used
/// `CreditPaymentModel.isCollection` while the all-time path re-implemented an
/// older `isWriteOff`-only rule inline on the screen. A return offsetting an
/// unpaid invoice writes a payment row purely for the customer ledger — no
/// money moves — so counting it overstated the takings, and clearing the date
/// filter silently switched the report back to doing exactly that.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 4, 15, 10);
  final windowStart = DateTime(2026, 4, 15);
  final windowEnd = DateTime(2026, 4, 16);

  late CreditPaymentRepository payments;
  late SaleRepository sales;
  late CustomerRepository customers;

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('credit_reports_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox<Customer>(HiveBoxNames.customer);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));

    payments = CreditPaymentRepository();
    sales = SaleRepository();
    customers = CustomerRepository();
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Fixtures ─────────────────────────────────────────────────────────────

  Future<void> seedSale(
    String saleId, {
    required double total,
    String paymentType = 'credit',
    double paid = 0,
    DateTime? at,
  }) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        totalItems: 1,
        subtotal: total,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: total,
        paymentType: paymentType,
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        totalTaxableAmount: total,
        totalGstAmount: 0,
        grandTotal: total,
        paidAmount: paid,
        dueAmount: total - paid,
      ),
    );
  }

  Future<void> seedPayment(
    String paymentId, {
    required double amount,
    String mode = 'cash',
    bool isWriteOff = false,
    String customerId = 'C-1',
    DateTime? at,
  }) async {
    final iso = (at ?? day).toIso8601String();
    await Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).put(
      paymentId,
      CreditPaymentModel(
        paymentId: paymentId,
        customerId: customerId,
        saleId: 'S-1',
        amount: amount,
        paymentMode: mode,
        date: iso,
        createdAt: iso,
        balanceBefore: 0,
        balanceAfter: 0,
        isWriteOff: isWriteOff,
      ),
    );
  }

  Future<void> seedCustomer(
    String id, {
    required double creditBalance,
    String? name,
  }) async {
    await Hive.box<Customer>(HiveBoxNames.customer).put(
      id,
      Customer(
        customerId: id,
        name: name ?? id,
        creditBalance: creditBalance,
        createdAt: day.toIso8601String(),
      ),
    );
  }

  /// The two paths the Collections tab takes — they must agree.
  ///
  /// The unfiltered one now buckets the list the screen itself holds, so the
  /// cards can never describe a different set of rows than the list below them.
  Future<List<Map<String, double>>> bothBranches() async => [
        CreditPaymentRepository.bucketCollections(
            await payments.getAllPayments()),
        await payments.getCollectionByModeInRange(windowStart, windowEnd),
      ];

  double v(Map<String, double> m, String k) => m[k] ?? 0;

  /// Arms the plan so `ReportHistoryWindow.cutoff` becomes non-null.
  /// Unlicensed retail bypasses enforcement; a manifest flips that on.
  void armHistoryWindow(int days) {
    Entitlements.instance.loadFromManifest(
      ManifestData(
        entitlements: {RetailEntKeys.reportsHistoryLimitDays: days},
        license: const {},
        version: 1,
      ),
    );
  }

  /// The two report entry points the screen now uses — both apply the plan
  /// cutoff as well as the caller's bounds.
  Future<List<SaleModel>> creditSalesReport({DateTime? start, DateTime? end}) =>
      ReportService().getCreditSalesReport(startDate: start, endDate: end);
  Future<List<CreditPaymentModel>> collectionsReport({
    DateTime? start,
    DateTime? end,
  }) =>
      ReportService()
          .getCreditCollectionsReport(startDate: start, endDate: end);

  // ── CR-1 — what counts as a collection ───────────────────────────────────

  group('CR-1 collection rule', () {
    test('a RETURN ADJUSTMENT is not money collected — in both branches',
        () async {
      await seedPayment('P-1', amount: 500);
      // What `ReturnService` writes when a return offsets an unpaid invoice.
      await seedPayment('P-2',
          amount: 300, mode: CreditPaymentModel.returnAdjustmentMode);

      for (final result in await bothBranches()) {
        expect(v(result, 'total'), 500.0,
            reason: 'the ₹300 return never entered the till');
        expect(v(result, 'cash'), 500.0);
        expect(v(result, CreditPaymentRepository.otherMode), 0.0,
            reason: 'a return adjustment is excluded, not bucketed as Other');
      }
    });

    test('a WRITE-OFF is not money collected — in both branches', () async {
      await seedPayment('P-1', amount: 500);
      await seedPayment('P-2', amount: 900, isWriteOff: true);

      for (final result in await bothBranches()) {
        expect(v(result, 'total'), 500.0);
        expect(v(result, 'cash'), 500.0);
      }
    });

    test('a write-off recorded under an odd mode is still excluded', () async {
      await seedPayment('P-1', amount: 900, mode: 'adjustment',
          isWriteOff: true);

      for (final result in await bothBranches()) {
        expect(v(result, 'total'), 0.0);
        expect(v(result, CreditPaymentRepository.otherMode), 0.0);
      }
    });

    test('ordinary collections are counted in both branches', () async {
      await seedPayment('P-1', amount: 100, mode: 'cash');
      await seedPayment('P-2', amount: 200, mode: 'upi');
      await seedPayment('P-3', amount: 300, mode: 'card');

      for (final result in await bothBranches()) {
        expect(v(result, 'cash'), 100.0);
        expect(v(result, 'upi'), 200.0);
        expect(v(result, 'card'), 300.0);
        expect(v(result, 'total'), 600.0);
      }
    });
  });

  // ── CR-3 — the buckets must add up ───────────────────────────────────────

  group('CR-3 unknown modes', () {
    test('an unknown mode goes to Other, not into thin air', () async {
      await seedPayment('P-1', amount: 100, mode: 'cash');
      await seedPayment('P-2', amount: 250, mode: 'cheque');

      for (final result in await bothBranches()) {
        expect(v(result, CreditPaymentRepository.otherMode), 250.0);
        expect(v(result, 'total'), 350.0);
      }
    });

    test('several unknown modes share the Other bucket', () async {
      await seedPayment('P-1', amount: 10, mode: 'cheque');
      await seedPayment('P-2', amount: 20, mode: 'bank_transfer');
      await seedPayment('P-3', amount: 30, mode: 'wallet');

      for (final result in await bothBranches()) {
        expect(v(result, CreditPaymentRepository.otherMode), 60.0);
        expect(v(result, 'total'), 60.0);
      }
    });

    test('the four buckets always sum to total', () async {
      await seedPayment('P-1', amount: 100, mode: 'cash');
      await seedPayment('P-2', amount: 200, mode: 'upi');
      await seedPayment('P-3', amount: 300, mode: 'card');
      await seedPayment('P-4', amount: 400, mode: 'cheque');
      await seedPayment('P-5', amount: 500, isWriteOff: true);
      await seedPayment('P-6',
          amount: 600, mode: CreditPaymentModel.returnAdjustmentMode);

      for (final result in await bothBranches()) {
        final buckets = v(result, 'cash') +
            v(result, 'upi') +
            v(result, 'card') +
            v(result, CreditPaymentRepository.otherMode);
        expect(buckets, v(result, 'total'));
        expect(v(result, 'total'), 1000.0);
      }
    });

    test('mode matching ignores case and padding', () async {
      await seedPayment('P-1', amount: 100, mode: '  CASH ');

      for (final result in await bothBranches()) {
        expect(v(result, 'cash'), 100.0);
        expect(v(result, CreditPaymentRepository.otherMode), 0.0);
      }
    });

    test('a payment recorded under the literal mode "total" cannot clobber it',
        () async {
      await seedPayment('P-1', amount: 100, mode: 'cash');
      await seedPayment('P-2', amount: 70, mode: 'total');

      for (final result in await bothBranches()) {
        expect(v(result, CreditPaymentRepository.otherMode), 70.0);
        expect(v(result, 'total'), 170.0);
      }
    });

    test('an empty period gives zeroed buckets, not missing keys', () async {
      for (final result in await bothBranches()) {
        expect(v(result, 'cash'), 0.0);
        expect(v(result, 'card'), 0.0);
        expect(v(result, 'upi'), 0.0);
        expect(v(result, CreditPaymentRepository.otherMode), 0.0);
        expect(v(result, 'total'), 0.0);
      }
    });
  });

  // ── Credit Sales ─────────────────────────────────────────────────────────

  group('credit sales', () {
    test('only credit-payment-type sales are listed', () async {
      await seedSale('S-CREDIT', total: 500);
      await seedSale('S-CASH', total: 500, paymentType: 'cash', paid: 500);
      await seedSale('S-UPI', total: 500, paymentType: 'upi', paid: 500);

      final all = await sales.getCreditSales();
      expect(all.map((s) => s.saleId), ['S-CREDIT']);

      final ranged =
          await sales.getCreditSalesByDateRange(windowStart, windowEnd);
      expect(ranged.map((s) => s.saleId), ['S-CREDIT']);
    });

    test('the start bound is inclusive and the end bound is exclusive',
        () async {
      await seedSale('S-IN', total: 100, at: windowStart);
      await seedSale('S-OUT', total: 100, at: windowEnd);
      await seedSale('S-BEFORE',
          total: 100, at: windowStart.subtract(const Duration(seconds: 1)));

      final ranged =
          await sales.getCreditSalesByDateRange(windowStart, windowEnd);
      expect(ranged.map((s) => s.saleId), ['S-IN']);
    });

    test('a partially paid credit sale keeps its remaining due', () async {
      await seedSale('S-1', total: 500, paid: 200);

      expect((await sales.getCreditSales()).single.dueAmount, 300.0);
    });
  });

  // ── CR-4 — deterministic ordering ────────────────────────────────────────

  group('CR-4 ordering', () {
    test('credit sales: newest first, then sale id', () async {
      await seedSale('S-3', total: 100, at: day);
      await seedSale('S-1', total: 100, at: day);
      await seedSale('S-2', total: 100, at: day);
      await seedSale('S-NEW', total: 100, at: day.add(const Duration(hours: 2)));

      final ids = (await sales.getCreditSales()).map((s) => s.saleId).toList();
      expect(ids, ['S-NEW', 'S-1', 'S-2', 'S-3']);
      // Stable across loads — `List.sort` is not.
      expect((await sales.getCreditSales()).map((s) => s.saleId).toList(), ids);
    });

    test('a date filter does not change the credit-sales ORDER', () async {
      await seedSale('S-3', total: 100, at: day);
      await seedSale('S-1', total: 100, at: day);
      await seedSale('S-2', total: 100, at: day);

      final all = (await sales.getCreditSales()).map((s) => s.saleId).toList();
      final ranged = (await sales.getCreditSalesByDateRange(
              windowStart, windowEnd))
          .map((s) => s.saleId)
          .toList();
      expect(ranged, all);
      expect(ranged, ['S-1', 'S-2', 'S-3']);
    });

    test('collections: newest first, then payment id', () async {
      await seedPayment('P-3', amount: 10, at: day);
      await seedPayment('P-1', amount: 10, at: day);
      await seedPayment('P-2', amount: 10, at: day);

      final ids =
          (await payments.getAllPayments()).map((p) => p.paymentId).toList();
      expect(ids, ['P-1', 'P-2', 'P-3']);

      final ranged =
          (await payments.getPaymentsByDateRange(windowStart, windowEnd))
              .map((p) => p.paymentId)
              .toList();
      expect(ranged, ids);
    });

    test('the collections tie-break never overrides the date', () async {
      await seedPayment('P-1', amount: 10, at: day);
      await seedPayment('P-9',
          amount: 10, at: day.add(const Duration(hours: 3)));

      expect((await payments.getAllPayments()).map((p) => p.paymentId).toList(),
          ['P-9', 'P-1']);
    });

    test('outstanding: largest balance first, then customer id', () async {
      await seedCustomer('C-3', creditBalance: 100);
      await seedCustomer('C-1', creditBalance: 100);
      await seedCustomer('C-2', creditBalance: 100);
      await seedCustomer('C-BIG', creditBalance: 900);

      final ids = (await customers.getCustomersWithCredit())
          .map((c) => c.customerId)
          .toList();
      expect(ids, ['C-BIG', 'C-1', 'C-2', 'C-3']);
      expect(
          (await customers.getCustomersWithCredit())
              .map((c) => c.customerId)
              .toList(),
          ids);
    });
  });

  // ── Collections date window ──────────────────────────────────────────────

  group('collections date window', () {
    test('the start bound is inclusive and the end bound is exclusive',
        () async {
      await seedPayment('P-IN', amount: 100, at: windowStart);
      await seedPayment('P-OUT', amount: 100, at: windowEnd);

      final ranged =
          await payments.getPaymentsByDateRange(windowStart, windowEnd);
      expect(ranged.map((p) => p.paymentId), ['P-IN']);

      final buckets =
          await payments.getCollectionByModeInRange(windowStart, windowEnd);
      expect(v(buckets, 'total'), 100.0);
      // The all-time branch sees both.
      expect(v(CreditPaymentRepository.bucketCollections(await payments.getAllPayments()), 'total'), 200.0);
    });

    test('a payment with an unreadable date is excluded from the range',
        () async {
      await Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).put(
        'P-BAD',
        CreditPaymentModel(
          paymentId: 'P-BAD',
          customerId: 'C-1',
          saleId: 'S-1',
          amount: 100,
          paymentMode: 'cash',
          date: 'not-a-date',
          createdAt: day.toIso8601String(),
          balanceBefore: 0,
          balanceAfter: 0,
        ),
      );

      // Current behaviour, pinned: dropped from the range, kept by all-time.
      expect(await payments.getPaymentsByDateRange(windowStart, windowEnd),
          isEmpty);
      expect(v(CreditPaymentRepository.bucketCollections(await payments.getAllPayments()), 'total'), 100.0);
    });
  });

  // ── Outstanding ──────────────────────────────────────────────────────────

  group('outstanding', () {
    test('a partially-paid CASH sale still puts its balance on the customer',
        () async {
      // `checkout_screen` routes any unpaid balance onto the account, whatever
      // the payment type — so Outstanding is a superset of the credit-sale due,
      // and the two tabs are not meant to reconcile.
      await seedSale('S-CASH', total: 500, paymentType: 'cash', paid: 300);
      await seedCustomer('C-1', creditBalance: 200);

      expect((await sales.getCreditSales()), isEmpty,
          reason: 'a cash sale is not a credit sale');
      final owing = await customers.getCustomersWithCredit();
      expect(owing.single.creditBalance, 200.0);
    });

    test('a zero balance is not outstanding', () async {
      await seedCustomer('C-1', creditBalance: 0);
      expect(await customers.getCustomersWithCredit(), isEmpty);
    });

    test('a NEGATIVE balance is excluded too', () async {
      // A customer in credit with the store. Current behaviour, pinned: the
      // Outstanding tab lists debts only.
      await seedCustomer('C-1', creditBalance: -150);
      expect(await customers.getCustomersWithCredit(), isEmpty);
    });

    test('only customers with a balance are listed', () async {
      await seedCustomer('C-OWES', creditBalance: 400);
      await seedCustomer('C-CLEAR', creditBalance: 0);

      final owing = await customers.getCustomersWithCredit();
      expect(owing.map((c) => c.customerId), ['C-OWES']);
    });

    test('the total is the sum of the listed balances', () async {
      await seedCustomer('C-1', creditBalance: 400);
      await seedCustomer('C-2', creditBalance: 250);
      await seedCustomer('C-3', creditBalance: 0);

      final owing = await customers.getCustomersWithCredit();
      final total =
          owing.fold<double>(0, (sum, c) => sum + c.creditBalance);
      expect(total, 650.0);
    });
  });

  // ── CR-5 — the plan's report-history cutoff ──────────────────────────────

  group('CR-5 history cutoff', () {
    test('with no plan armed, everything is visible', () async {
      final now = DateTime.now();
      await seedSale('S-ANCIENT',
          total: 100, at: now.subtract(const Duration(days: 400)));
      await seedPayment('P-ANCIENT',
          amount: 100, at: now.subtract(const Duration(days: 400)));

      // Unlicensed retail bypasses enforcement — the pre-existing behaviour.
      expect(await creditSalesReport(), hasLength(1));
      expect(await collectionsReport(), hasLength(1));
    });

    test('CREDIT SALES older than the cutoff are dropped', () async {
      final now = DateTime.now();
      await seedSale('S-RECENT',
          total: 100, at: now.subtract(const Duration(days: 2)));
      await seedSale('S-ANCIENT',
          total: 100, at: now.subtract(const Duration(days: 400)));

      armHistoryWindow(30);

      // All-time: the cutoff is the only thing that can exclude a row.
      expect((await creditSalesReport()).map((s) => s.saleId), ['S-RECENT']);

      // And a window wide enough to hold both still cannot reach past it.
      final wide = await creditSalesReport(
        start: now.subtract(const Duration(days: 500)),
        end: now.add(const Duration(days: 1)),
      );
      expect(wide.map((s) => s.saleId), ['S-RECENT']);
    });

    test('COLLECTIONS older than the cutoff are dropped', () async {
      final now = DateTime.now();
      await seedPayment('P-RECENT',
          amount: 100, at: now.subtract(const Duration(days: 2)));
      await seedPayment('P-ANCIENT',
          amount: 900, at: now.subtract(const Duration(days: 400)));

      armHistoryWindow(30);

      final rows = await collectionsReport();
      expect(rows.map((p) => p.paymentId), ['P-RECENT']);
      // The summary is bucketed from that same list, so it cannot describe rows
      // the tab is not allowed to show.
      final buckets = CreditPaymentRepository.bucketCollections(rows);
      expect(v(buckets, 'total'), 100.0);
    });

    test('OUTSTANDING is unaffected by the cutoff', () async {
      await seedCustomer('C-1', creditBalance: 750);

      armHistoryWindow(1);

      // A balance is what is owed NOW; it has no date to judge. The Outstanding
      // query takes no bounds at all.
      final owing = await customers.getCustomersWithCredit();
      expect(owing.single.creditBalance, 750.0);
    });

    test('a generous cutoff lets everything through again', () async {
      final now = DateTime.now();
      await seedSale('S-OLD',
          total: 100, at: now.subtract(const Duration(days: 100)));
      await seedPayment('P-OLD',
          amount: 100, at: now.subtract(const Duration(days: 100)));

      armHistoryWindow(365);

      expect(await creditSalesReport(), hasLength(1));
      expect(await collectionsReport(), hasLength(1));
    });

    test('the cutoff does not disturb the date bounds', () async {
      final now = DateTime.now();
      final inWindow = now.subtract(const Duration(days: 3));
      final alsoRecent = now.subtract(const Duration(days: 10));

      await seedSale('S-IN', total: 100, at: inWindow);
      await seedSale('S-OUT', total: 100, at: alsoRecent);

      armHistoryWindow(365);

      // Both clear the cutoff; only the explicit range separates them.
      final ranged = await creditSalesReport(
        start: DateTime(inWindow.year, inWindow.month, inWindow.day),
        end: DateTime(inWindow.year, inWindow.month, inWindow.day)
            .add(const Duration(days: 1)),
      );
      expect(ranged.map((s) => s.saleId), ['S-IN']);
    });
  });

  // ── CR-2 — Outstanding has no date dimension ─────────────────────────────

  group('CR-2 outstanding is not dated', () {
    test('the outstanding query takes no date bounds at all', () async {
      await seedCustomer('C-OLD', creditBalance: 100);
      await seedCustomer('C-NEW', creditBalance: 200);

      // There is no dated variant to call — which is the point: the tab cannot
      // respond to a filter, so the screen no longer shows it one.
      final owing = await customers.getCustomersWithCredit();
      expect(owing.map((c) => c.customerId), ['C-NEW', 'C-OLD']);
    });

    test('a balance stands whatever period the other tabs are showing',
        () async {
      final now = DateTime.now();
      await seedCustomer('C-1', creditBalance: 500);
      // Every credit sale is outside a one-day window…
      await seedSale('S-OLD',
          total: 500, at: now.subtract(const Duration(days: 90)));

      final narrow = await creditSalesReport(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1)),
      );
      expect(narrow, isEmpty);

      // …and the balance is still owed.
      expect(
          (await customers.getCustomersWithCredit()).single.creditBalance, 500.0);
    });
  });

  // ── The report entry points keep the Batch 1 guarantees ──────────────────

  group('report entry points', () {
    test('credit sales report lists only credit sales, newest first', () async {
      await seedSale('S-2', total: 100, at: day);
      await seedSale('S-1', total: 100, at: day);
      await seedSale('S-CASH', total: 100, paymentType: 'cash', paid: 100);

      expect((await creditSalesReport()).map((s) => s.saleId),
          ['S-1', 'S-2']);
    });

    test('collections report keeps write-offs and return adjustments in the '
        'LIST but out of the money', () async {
      await seedPayment('P-1', amount: 500);
      await seedPayment('P-2', amount: 900, isWriteOff: true);
      await seedPayment('P-3',
          amount: 300, mode: CreditPaymentModel.returnAdjustmentMode);

      final rows = await collectionsReport();
      // The tab shows all three — a write-off has its own icon there.
      expect(rows, hasLength(3));
      // Only one is money.
      expect(v(CreditPaymentRepository.bucketCollections(rows), 'total'), 500.0);
    });

    test('the report bounds are inclusive at the start, exclusive at the end',
        () async {
      await seedSale('S-IN', total: 100, at: windowStart);
      await seedSale('S-OUT', total: 100, at: windowEnd);
      await seedPayment('P-IN', amount: 10, at: windowStart);
      await seedPayment('P-OUT', amount: 10, at: windowEnd);

      expect(
          (await creditSalesReport(start: windowStart, end: windowEnd))
              .map((s) => s.saleId),
          ['S-IN']);
      expect(
          (await collectionsReport(start: windowStart, end: windowEnd))
              .map((p) => p.paymentId),
          ['P-IN']);
    });

    test('an all-time report returns everything', () async {
      await seedSale('S-1', total: 100, at: day);
      await seedSale('S-2',
          total: 100, at: day.subtract(const Duration(days: 200)));
      await seedPayment('P-1', amount: 10, at: day);

      expect(await creditSalesReport(), hasLength(2));
      expect(await collectionsReport(), hasLength(1));
    });
  });

  // ── Empty states ─────────────────────────────────────────────────────────

  group('empty', () {
    test('no credit sales', () async {
      expect(await sales.getCreditSales(), isEmpty);
      expect(await sales.getCreditSalesByDateRange(windowStart, windowEnd),
          isEmpty);
    });

    test('no collections', () async {
      expect(await payments.getAllPayments(), isEmpty);
      expect(await payments.getPaymentsByDateRange(windowStart, windowEnd),
          isEmpty);
    });

    test('nothing outstanding', () async {
      expect(await customers.getCustomersWithCredit(), isEmpty);
    });
  });
}
