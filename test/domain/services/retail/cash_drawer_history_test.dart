import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/manifest_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/util/retail/cash_drawer_ledger.dart';

/// CASH DRAWER HISTORY — the ledger rules, pinned.
///
/// `getCashDrawerReport` had no tests, which is how the live Cash Drawer screen
/// came to open-code its own refund rule (`totalAmount.abs()`) while the report
/// used `CashDrawerLedger.cashRefundOf`. On an exchange the two disagreed about
/// real money: the report counted only the cash leg that actually left the
/// till, the screen counted the whole value of the goods handed back.
///
/// Both now call the shared helper, so most of what follows is really a test of
/// `CashDrawerLedger` as reached THROUGH the report.
void main() {
  late Directory tempDir;

  final day = DateTime(2026, 4, 15, 10);
  final windowStart = DateTime(2026, 4, 15);
  final windowEnd = DateTime(2026, 4, 16);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('cash_drawer_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    // Both boxes live in the restaurant typeId range but are COMMON — retail
    // writes its drawer movements and expenses to them too.
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCashMovement)) {
      Hive.registerAdapter(CashMovementModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantExpense1)) {
      Hive.registerAdapter(ExpenseAdapter());
    }

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    // Retail's expense box — `ExpenseRepository` picks it by business mode.
    await Hive.openBox<Expense>(HiveBoxNames.retailExpense);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<SaleItemRepository>(
        () => SaleItemRepository());
    locator.registerLazySingleton<ExpenseStore>(
        () => ExpenseStore(ExpenseRepository()));
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Fixtures ─────────────────────────────────────────────────────────────

  /// A sale header. [legs] writes `paymentListJson`, which is what an exchange
  /// or a split bill carries — return legs are stored NEGATIVE, matching the
  /// negated header.
  Future<void> seedSale(
    String saleId, {
    required double total,
    String paymentType = 'cash',
    bool isReturn = false,
    bool isSplit = false,
    List<Map<String, Object>>? legs,
    DateTime? at,
  }) async {
    final iso = (at ?? day).toIso8601String();
    final signed = isReturn ? -1 : 1;
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        totalItems: 1,
        subtotal: signed * total,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: signed * total,
        paymentType: paymentType,
        isSplitPayment: isSplit,
        paymentListJson: legs == null ? null : jsonEncode(legs),
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        isReturn: isReturn,
        originalSaleId: isReturn ? 'S-1' : null,
        totalTaxableAmount: signed * total,
        totalGstAmount: 0,
        grandTotal: signed * total,
      ),
    );
  }

  Future<void> seedMovement(
    String id, {
    required String type,
    required double amount,
    String reason = 'Petty cash',
    String? note,
    String staffName = 'Asha',
    DateTime? at,
  }) async {
    await Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements).put(
      id,
      CashMovementModel(
        id: id,
        timestamp: at ?? day,
        type: type,
        amount: amount,
        reason: reason,
        note: note,
        staffName: staffName,
      ),
    );
  }

  Future<void> seedExpense(
    String id, {
    required double amount,
    String? paymentType = 'cash',
    String? reason = 'Courier',
    DateTime? at,
  }) async {
    await Hive.box<Expense>(HiveBoxNames.retailExpense).put(
      id,
      Expense(
        id: id,
        dateandTime: at ?? day,
        amount: amount,
        reason: reason,
        paymentType: paymentType,
      ),
    );
  }

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

  Future<List<Map<String, dynamic>>> report({
    DateTime? start,
    DateTime? end,
  }) =>
      ReportService().getCashDrawerReport(
        startDate: start ?? windowStart,
        endDate: end ?? windowEnd,
      );

  double amountOf(Map<String, dynamic> row) => (row['amount'] as num).toDouble();

  // ── Refunds — the CD-1 rules ─────────────────────────────────────────────

  group('refunds', () {
    test('a plain cash refund takes the whole header out of the till',
        () async {
      await seedSale('R-1', total: 500, isReturn: true);

      final row = (await report()).single;
      expect(row['type'], 'Refund');
      expect(amountOf(row), -500.0);
      expect(row['description'], 'Cash Refund');
    });

    test('an EXCHANGE refund counts only the cash leg, not the goods value',
        () async {
      // ₹2,000 of goods handed back, ₹1,800 of it exchanged for a replacement;
      // only ₹200 physically left the drawer. Legs are stored negative.
      await seedSale('R-1',
          total: 2000,
          isReturn: true,
          legs: [
            {'method': 'cash', 'amount': -200},
          ]);

      final row = (await report()).single;
      expect(amountOf(row), -200.0,
          reason: 'the whole ₹2,000 never left the till');
      // The rule the live screen used to apply.
      expect(amountOf(row), isNot(-2000.0));
    });

    test('a split refund headed "card" still counts its cash leg', () async {
      await seedSale('R-1',
          total: 1000,
          paymentType: 'card',
          isReturn: true,
          legs: [
            {'method': 'card', 'amount': -700},
            {'method': 'cash', 'amount': -300},
          ]);

      // The old header-only rule skipped this row entirely.
      expect(amountOf((await report()).single), -300.0);
    });

    test('a card-only refund puts no row in the drawer ledger', () async {
      await seedSale('R-1', total: 500, paymentType: 'card', isReturn: true);

      expect(await report(), isEmpty);
    });

    test('a refund with legs but no cash leg contributes nothing', () async {
      await seedSale('R-1',
          total: 500,
          isReturn: true,
          legs: [
            {'method': 'upi', 'amount': -500},
          ]);

      expect(await report(), isEmpty);
    });

    test('the live screen and the report now use the SAME helper', () async {
      // Both call `CashDrawerLedger.cashRefundOf`; this pins the value they
      // share for the case that used to diverge.
      await seedSale('R-1',
          total: 2000,
          isReturn: true,
          legs: [
            {'method': 'cash', 'amount': -200},
          ]);

      final stored = Hive.box<SaleModel>(HiveBoxNames.sales).get('R-1')!;
      expect(CashDrawerLedger.cashRefundOf(stored), 200.0);
      expect(amountOf((await report()).single), -200.0);
    });
  });

  // ── Sales ────────────────────────────────────────────────────────────────

  group('sales', () {
    test('a split-payment sale contributes only its cash portion', () async {
      await seedSale('S-1',
          total: 1000,
          isSplit: true,
          legs: [
            {'method': 'card', 'amount': 600},
            {'method': 'cash', 'amount': 400},
          ]);

      final row = (await report()).single;
      expect(row['type'], 'Sale');
      expect(amountOf(row), 400.0);
      expect(row['description'], 'Sale (cash portion)');
    });

    test('a card sale contributes nothing', () async {
      await seedSale('S-1', total: 1000, paymentType: 'card');
      expect(await report(), isEmpty);
    });

    test('a UPI sale contributes nothing', () async {
      await seedSale('S-1', total: 1000, paymentType: 'upi');
      expect(await report(), isEmpty);
    });

    test('a plain cash sale contributes its whole total', () async {
      await seedSale('S-1', total: 750);

      final row = (await report()).single;
      expect(amountOf(row), 750.0);
      expect(row['description'], 'Cash Sale');
      expect(row['reference'], 'S-1');
    });
  });

  // ── Manual movements ─────────────────────────────────────────────────────

  group('movements', () {
    test('Cash In is positive', () async {
      await seedMovement('M-1', type: 'in', amount: 2000, reason: 'Owner float');

      final row = (await report()).single;
      expect(row['type'], 'Cash In');
      expect(amountOf(row), 2000.0);
      expect(row['description'], 'Owner float');
      expect(row['reference'], 'Asha');
    });

    test('Cash Out is negative', () async {
      await seedMovement('M-1', type: 'out', amount: 350, reason: 'Safe drop');

      final row = (await report()).single;
      expect(row['type'], 'Cash Out');
      expect(amountOf(row), -350.0);
    });

    test('a note is appended to the reason', () async {
      await seedMovement('M-1',
          type: 'out', amount: 100, reason: 'Petty cash', note: 'stationery');

      expect((await report()).single['description'], 'Petty cash — stationery');
    });

    test('the OPENING float is not a movement', () async {
      await seedMovement('M-1', type: 'opening', amount: 5000);
      // It is the day's starting balance, shown as its own line on the live
      // screen — counting it here would double the drawer.
      expect(await report(), isEmpty);
    });

    test('an ADJUSTMENT is audit-only and excluded', () async {
      await seedMovement('M-1', type: 'adjustment', amount: 120);
      expect(await report(), isEmpty);
    });

    test('the refund AUDIT movement is not double-counted', () async {
      // `ReturnService` writes both: the return sale AND an audit movement.
      await seedSale('R-1', total: 500, isReturn: true);
      await seedMovement('M-1',
          type: ReturnService.refundMovementType, amount: 500);

      final rows = await report();
      expect(rows, hasLength(1), reason: 'the audit movement must not add a row');
      expect(rows.single['type'], 'Refund');
      expect(amountOf(rows.single), -500.0);
    });
  });

  // ── Expenses ─────────────────────────────────────────────────────────────

  group('expenses', () {
    test('a cash expense leaves the drawer', () async {
      await seedExpense('E-1', amount: 260, reason: 'Courier');

      final row = (await report()).single;
      expect(row['type'], 'Expense');
      expect(amountOf(row), -260.0);
      expect(row['description'], 'Courier');
    });

    test('a card expense is not a drawer movement', () async {
      await seedExpense('E-1', amount: 260, paymentType: 'card');
      expect(await report(), isEmpty);
    });

    test('an expense with no payment type is not counted as cash', () async {
      await seedExpense('E-1', amount: 260, paymentType: null);
      expect(await report(), isEmpty);
    });

    test('payment type matching ignores case and padding', () async {
      await seedExpense('E-1', amount: 100, paymentType: '  CASH ');
      expect(amountOf((await report()).single), -100.0);
    });
  });

  // ── CD-2 — deterministic ordering ────────────────────────────────────────

  group('ordering', () {
    test('newest first', () async {
      await seedSale('S-OLD', total: 100, at: DateTime(2026, 4, 15, 9));
      await seedSale('S-NEW', total: 100, at: DateTime(2026, 4, 15, 17));

      expect((await report()).map((r) => r['id']).toList(),
          ['sale:S-NEW', 'sale:S-OLD']);
    });

    test('rows sharing a timestamp break on their id, stably', () async {
      // Three sources, one instant — exactly what an unstable sort reorders.
      await seedSale('S-3', total: 100, at: day);
      await seedSale('S-1', total: 100, at: day);
      await seedMovement('M-2', type: 'in', amount: 50, at: day);
      await seedExpense('E-9', amount: 20, at: day);

      final first = (await report()).map((r) => r['id']).toList();
      expect(first, [
        'expense:E-9',
        'movement:M-2',
        'sale:S-1',
        'sale:S-3',
      ]);
      // And it does not drift between loads.
      expect((await report()).map((r) => r['id']).toList(), first);
      expect((await report()).map((r) => r['id']).toList(), first);
    });

    test('the tie-break never overrides the timestamp', () async {
      // 'sale:S-1' sorts before 'sale:S-9' by id, but it is older.
      await seedSale('S-1', total: 100, at: DateTime(2026, 4, 15, 8));
      await seedSale('S-9', total: 100, at: DateTime(2026, 4, 15, 20));

      expect((await report()).map((r) => r['id']).toList(),
          ['sale:S-9', 'sale:S-1']);
    });

    test('every row carries a unique id', () async {
      await seedSale('S-1', total: 100);
      await seedSale('R-1', total: 50, isReturn: true);
      await seedMovement('M-1', type: 'in', amount: 10);
      await seedExpense('E-1', amount: 5);

      final ids = (await report()).map((r) => r['id'] as String).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  // ── Windows ──────────────────────────────────────────────────────────────

  group('date window', () {
    test('the start bound is INCLUSIVE', () async {
      await seedSale('S-1', total: 100, at: windowStart);
      await seedMovement('M-1', type: 'in', amount: 10, at: windowStart);
      await seedExpense('E-1', amount: 5, at: windowStart);

      expect(await report(), hasLength(3));
    });

    test('the end bound is EXCLUSIVE, for all three sources', () async {
      await seedSale('S-1', total: 100, at: windowEnd);
      await seedMovement('M-1', type: 'in', amount: 10, at: windowEnd);
      await seedExpense('E-1', amount: 5, at: windowEnd);

      expect(await report(), isEmpty);
    });

    test('a row before the start is excluded', () async {
      await seedSale('S-1',
          total: 100, at: windowStart.subtract(const Duration(seconds: 1)));
      expect(await report(), isEmpty);
    });

    test('the plan history cutoff clips all three sources', () async {
      final now = DateTime.now();
      final recent = now.subtract(const Duration(days: 2));
      final ancient = now.subtract(const Duration(days: 400));

      await seedSale('S-RECENT', total: 100, at: recent);
      await seedSale('S-ANCIENT', total: 100, at: ancient);
      await seedMovement('M-RECENT', type: 'in', amount: 10, at: recent);
      await seedMovement('M-ANCIENT', type: 'in', amount: 10, at: ancient);
      await seedExpense('E-RECENT', amount: 5, at: recent);
      await seedExpense('E-ANCIENT', amount: 5, at: ancient);

      armHistoryWindow(30);

      // A window wide enough to hold both — only the cutoff can exclude one.
      final rows = await report(
        start: ancient.subtract(const Duration(days: 1)),
        end: now.add(const Duration(days: 1)),
      );
      final ids = rows.map((r) => r['id'] as String).toSet();
      expect(ids, {'sale:S-RECENT', 'movement:M-RECENT', 'expense:E-RECENT'});
    });
  });

  // ── Whole-report contract ────────────────────────────────────────────────

  group('contract', () {
    test('an empty period returns no rows', () async {
      expect(await report(), isEmpty);
    });

    test('Cash In − Cash Out equals the sum of the signed amounts', () async {
      await seedSale('S-1', total: 1200);
      await seedSale('S-2',
          total: 800,
          isSplit: true,
          legs: [
            {'method': 'card', 'amount': 500},
            {'method': 'cash', 'amount': 300},
          ]);
      await seedSale('R-1', total: 250, isReturn: true);
      await seedMovement('M-1', type: 'in', amount: 2000, reason: 'Float');
      await seedMovement('M-2', type: 'out', amount: 400, reason: 'Safe drop');
      await seedExpense('E-1', amount: 150);

      final rows = await report();
      final moneyIn = rows
          .where((r) => amountOf(r) > 0)
          .fold<double>(0, (s, r) => s + amountOf(r));
      final moneyOut = rows
          .where((r) => amountOf(r) < 0)
          .fold<double>(0, (s, r) => s + amountOf(r))
          .abs();
      final signedSum =
          rows.fold<double>(0, (s, r) => s + amountOf(r));

      // The exact arithmetic the summary cards do.
      expect(moneyIn, closeTo(1200 + 300 + 2000, 0.001));
      expect(moneyOut, closeTo(250 + 400 + 150, 0.001));
      expect(moneyIn - moneyOut, closeTo(signedSum, 0.001));
    });

    test('every row carries the four fields the screen renders', () async {
      await seedSale('S-1', total: 100);
      await seedMovement('M-1', type: 'in', amount: 10);
      await seedExpense('E-1', amount: 5);

      for (final row in await report()) {
        expect(row['at'], isA<DateTime>());
        expect(row['type'], isA<String>());
        expect(row['description'], isA<String>());
        expect(row['amount'], isA<num>());
        // Export-only, but must never be null.
        expect(row['reference'], isNotNull);
      }
    });

    test('the four row types the screen colours are the only ones emitted',
        () async {
      await seedSale('S-1', total: 100);
      await seedSale('R-1', total: 50, isReturn: true);
      await seedMovement('M-1', type: 'in', amount: 10);
      await seedMovement('M-2', type: 'out', amount: 10);
      await seedExpense('E-1', amount: 5);

      final types = (await report()).map((r) => r['type']).toSet();
      expect(types, {'Sale', 'Refund', 'Cash In', 'Cash Out', 'Expense'});
    });
  });
}
