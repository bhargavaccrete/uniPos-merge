import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/expensemodel_315.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/repositories/common/shift_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/cart_calculation_service.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/stores/payment_method_store.dart';
import 'package:billberrylite/util/common/loyalty_points.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

/// Outcome of a history run.
class HistoryDataResult {
  int days = 0;
  int orders = 0;
  int fullRefunds = 0;
  int partialRefunds = 0;
  int voids = 0;
  int expenses = 0;
  int cashMovements = 0;
  int eodReports = 0;
  int shifts = 0;
  int customersUpdated = 0;
  int ordersCappedByPlan = 0;

  /// Sessions where the EOD's expected cash differed from the generator's own
  /// mirror of the formula — a non-zero value means the two disagree.
  int eodCashMismatches = 0;
  double grossSales = 0;
  String? skippedReason;
  int eodTimeMs = 0;
}

/// Backdated restaurant sales history, day by day, shaped exactly like the
/// live settle path writes it: one closed session per day, orders priced by
/// [CartCalculationService] with the live tax/round-off/discount settings,
/// payment legs in `PaymentEntry.toMap` form, refund/void fields as
/// `RefundService` writes them, expenses and cash movements on the session —
/// then the day's EOD is produced by the real [EODService].
///
/// Only past days (up to yesterday) are written, so today's counters and any
/// open session are untouched. Stock is NOT deducted for history: lines are
/// stamped as taking nothing from stock, so refunds restore nothing either.
class HistoryDataGenerator {
  HistoryDataGenerator._();

  static final Random _random = Random();
  static const _uuid = Uuid();
  static const double _float = 2000;

  static const _expenseCategories = [
    'Vegetables', 'Gas Cylinder', 'Cleaning', 'Maintenance', 'Staff Meals',
    'Packaging',
  ];
  static const _refundReasons = [
    'Customer complaint', 'Wrong item served', 'Order delayed',
    'Food quality issue',
  ];
  static const _voidReasons = [
    'Customer left', 'Duplicate order', 'Order entered by mistake',
  ];

  static Future<HistoryDataResult> generate({
    required int days,
    required int ordersPerDay,
    void Function(String message)? onProgress,
  }) async {
    final r = HistoryDataResult();
    if (days <= 0 || ordersPerDay <= 0) return r;

    await Future.wait([
      itemStore.loadItems(),
      categoryStore.loadCategories(),
      variantStore.loadVariants(),
      extraStore.loadExtras(),
      choiceStore.loadChoices(),
      tableStore.loadTables(),
      staffStore.loadStaff(),
      customerStore.loadCustomers(),
      expenseCategoryStore.loadCategories(),
      locator<PaymentMethodStore>().loadPaymentMethods(),
    ]);

    final menu = itemStore.items
        .where((i) =>
            i.isEnabled &&
            ProductType.isMenuType(ProductType.effective(i.productType)) &&
            (i.price ?? 0) > 0)
        .toList();
    if (menu.isEmpty) {
      r.skippedReason = 'No sellable menu items — generate setup data first';
      return r;
    }

    final ctx = _Context(
      menu: menu,
      categoryNames: {for (final c in categoryStore.categories) c.id: c.name},
      variantNames: {for (final v in variantStore.variants) v.id: v.name},
      tables: tableStore.tables.map((t) => t.id).toList(),
      staff: staffStore.staff.where((s) => s.isActive).toList(),
      customers: customerStore.customers.toList(),
      methods: _paymentMethods(),
      expenseCategoryIds: await _ensureExpenseCategories(),
      gstNumber: await StoreSettingsService().gstNumberSnapshot(),
    );

    final sessionBox =
        Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
    final cashRepo = CashMovementRepository();
    final shiftRepo = ShiftRepository();
    final today = DateTime.now();
    var opening = _float;

    for (var d = days; d >= 1; d--) {
      final day = DateTime(today.year, today.month, today.day - d);
      onProgress?.call('Day ${days - d + 1}/$days · ${_date(day)}');

      final sessionId = _uuid.v4();
      final start = day.add(Duration(hours: 10, minutes: _random.nextInt(30)));
      final end = day.add(Duration(hours: 23, minutes: 15 + _random.nextInt(30)));
      final cashier = ctx.pickCashier();
      final shiftId = cashier == null ? null : _uuid.v4();
      final ds = _Day(sessionId, start, end, shiftId, _name(cashier));

      await cashRepo.saveMovement(CashMovementModel(
        id: _uuid.v4(),
        timestamp: start,
        type: 'opening',
        amount: opening,
        reason: 'Session Start — Carry Forward',
        note: 'Session ID: $sessionId',
        staffName: 'System',
      ));
      r.cashMovements++;

      final target =
          max(1, (ordersPerDay * (0.7 + _random.nextDouble() * 0.6)).round());
      for (var i = 0; i < target; i++) {
        if (!PlanEnforce.withinLimit(
            EntKeys.billingInvoicePerDayMax, ds.bills)) {
          r.ordersCappedByPlan += target - i;
          break;
        }
        await _order(ctx, ds, r);
      }

      await _expensesAndPettyCash(ctx, ds, cashRepo, r);

      // EOD through the real service, with this session's id so every
      // source is matched by session rather than by "now".
      final expected = opening + ds.cashIn - ds.cashOut;
      final actual = _random.nextDouble() < 0.8
          ? expected
          : expected + (_random.nextBool() ? 1 : -1) * (10 + _random.nextInt(190));
      final eodStart = DateTime.now();
      final report = await EODService.generateEODReport(
        date: start,
        openingBalance: opening,
        actualCash: double.parse(actual.toStringAsFixed(2)),
        sessionId: sessionId,
      );
      await EODService.saveEODReport(report);
      r.eodTimeMs += DateTime.now().difference(eodStart).inMilliseconds;
      r.eodReports++;
      if ((report.cashReconciliation.systemExpectedCash - expected).abs() >
          0.01) {
        r.eodCashMismatches++;
      }

      final drop = actual - _float;
      if (drop > 0) {
        await cashRepo.saveMovement(CashMovementModel(
          id: _uuid.v4(),
          timestamp: end.add(const Duration(minutes: 1)),
          type: 'out',
          amount: double.parse(drop.toStringAsFixed(2)),
          reason: 'Safe drop - End of Day',
          staffName: ds.staffName,
          sessionId: sessionId,
        ));
        r.cashMovements++;
      }

      await sessionBox.put(
        sessionId,
        RestaurantSessionModel(
          sessionId: sessionId,
          startTime: start,
          endTime: end,
          openingCash: opening,
          closingCash: double.parse(actual.toStringAsFixed(2)),
          isClosed: true,
        ),
      );

      if (cashier != null && shiftId != null) {
        await shiftRepo.saveShift(ShiftModel(
          id: shiftId,
          staffId: cashier.id,
          staffName: _name(cashier),
          startTime: start,
          endTime: end,
          status: 'closed',
          orderCount: ds.shiftOrders,
          totalSales: double.parse(ds.shiftSales.toStringAsFixed(2)),
        ));
        r.shifts++;
      }

      opening = drop > 0 ? _float : double.parse(actual.toStringAsFixed(2));
      r.days++;
    }

    onProgress?.call('Updating customer visits…');
    r.customersUpdated = await _applyCustomerStats(ctx);
    await Future.wait([
      pastOrderStore.loadPastOrders(),
      expenseStore.loadExpenses(),
      eodStore.loadEODReports(),
    ]);
    return r;
  }

  // ── One order ────────────────────────────────────────────────────────────

  static Future<void> _order(_Context ctx, _Day day, HistoryDataResult r) async {
    final roll = _random.nextDouble();
    final orderType = roll < 0.45
        ? 'Take Away'
        : roll < 0.85
            ? 'Dine In'
            : 'Delivery';
    final isDelivery = orderType == 'Delivery';
    final at = _orderTime(day);

    final lines = <CartItem>[
      for (var n = 1 + _random.nextInt(4); n > 0; n--) _line(ctx),
    ];

    final hasDiscount = _random.nextDouble() < 0.08;
    final calc = CartCalculationService(
      items: lines,
      discountType: DiscountType.percentage,
      discountValue: hasDiscount ? 10 : 0,
      deliveryCharge: isDelivery ? 40 : 0,
      isDeliveryOrder: isDelivery,
    );
    final total = calc.grandTotal;

    final customer = (isDelivery || _random.nextDouble() < 0.25)
        ? ctx.pickCustomer()
        : null;

    // Voided before payment: no bill, no money.
    if (_random.nextDouble() < 0.01) {
      await pastOrderStore.addOrder(PastOrderModel(
        id: _uuid.v4(),
        customerName: customer?.name ?? 'Quick Settle',
        totalPrice: total,
        items: lines,
        orderAt: at,
        orderType: orderType,
        paymentmode: 'N/A',
        subTotal: calc.subtotal,
        Discount: calc.discountAmount,
        gstRate: 0,
        gstAmount: calc.totalGST,
        orderStatus: 'VOID',
        kotNumbers: [day.nextKot()],
        kotBoundaries: [lines.length],
        isTaxInclusive: AppSettings.isTaxInclusive,
        tableNo: orderType == 'Dine In' ? ctx.pickTable() : null,
        sessionId: day.sessionId,
        voidedBy: day.staffName,
        voidReason: _pick(_voidReasons),
        taxEnabled: TaxFeature.enabled,
        storeGstNumber: ctx.gstNumber,
        roundOffStep: AppSettings.roundOffStepForRecord,
        discountOnItems: AppSettings.discountOnItems,
      ));
      r.voids++;
      return;
    }

    final legs = _paymentLegs(ctx, total);
    final isSplit = legs.length > 1;
    final change = legs
        .map((l) => (l['change'] as num?)?.toDouble() ?? 0)
        .fold(0.0, (a, b) => a + b);
    final billNumber = await orderStore.getNextBillNumber();
    day.bills++;

    var items = lines;
    String status = 'COMPLETED';
    double? refundAmount;
    String? refundReason;
    DateTime? refundedAt;
    String? refundEventsJson;

    final refundRoll = _random.nextDouble();
    if (refundRoll < 0.05) {
      refundedAt = _refundTime(at, day);
      final reason = _pick(_refundReasons);
      refundReason = '\n[${_date(refundedAt)} ${_hm(refundedAt)}] '
          '${day.staffName}: $reason';
      List<Map<String, dynamic>> refundLegs;
      if (refundRoll < 0.03) {
        items = [for (final l in lines) l.copyWith(refundedQuantity: l.quantity)];
        status = 'FULLY_REFUNDED';
        refundAmount = total;
        refundLegs = [
          for (final l in legs) {'method': l['method'], 'amount': l['amount']},
        ];
        r.fullRefunds++;
      } else {
        final idx = _random.nextInt(lines.length);
        final itemTotal =
            lines.fold<double>(0, (s, l) => s + l.price * l.quantity);
        final share = itemTotal <= 0 ? 0.0 : lines[idx].price / itemTotal;
        refundAmount = _r2(total * share);
        items = [
          for (var k = 0; k < lines.length; k++)
            k == idx ? lines[k].copyWith(refundedQuantity: 1) : lines[k],
        ];
        status = lines.length == 1 && lines[idx].quantity == 1
            ? 'FULLY_REFUNDED'
            : 'PARTIALLY_REFUNDED';
        refundLegs = [
          {'method': legs.first['method'], 'amount': refundAmount},
        ];
        r.partialRefunds++;
      }
      refundEventsJson = jsonEncode([
        {
          'amount': refundAmount,
          'at': refundedAt.toIso8601String(),
          'sessionId': day.sessionId,
          'legs': refundLegs,
        },
      ]);
      for (final l in refundLegs) {
        if (l['method'] == 'cash') day.cashOut += (l['amount'] as num).toDouble();
      }
    }

    for (final l in legs) {
      if (l['method'] == 'cash') day.cashIn += (l['amount'] as num).toDouble();
    }

    await pastOrderStore.addOrder(PastOrderModel(
      id: _uuid.v4(),
      customerName: customer?.name ?? 'Quick Settle',
      totalPrice: total,
      items: items,
      orderAt: at,
      orderType: orderType,
      paymentmode: isSplit ? 'Split Payment' : legs.first['method'] as String,
      subTotal: calc.subtotal,
      Discount: calc.discountAmount,
      gstRate: 0,
      gstAmount: calc.totalGST,
      orderStatus: status,
      kotNumbers: [day.nextKot()],
      kotBoundaries: [lines.length],
      billNumber: billNumber,
      paymentListJson: jsonEncode(legs),
      isSplitPayment: isSplit,
      totalPaid: total,
      changeReturn: change,
      isTaxInclusive: AppSettings.isTaxInclusive,
      tableNo: orderType == 'Dine In' ? ctx.pickTable() : null,
      shiftId: day.shiftId,
      sessionId: day.sessionId,
      discountAppliedBy: calc.discountAmount > 0.009 ? day.staffName : null,
      customerId: customer?.customerId,
      serviceCharge: calc.serviceChargeAmount,
      taxEnabled: TaxFeature.enabled,
      storeGstNumber: ctx.gstNumber,
      roundOffStep: AppSettings.roundOffStepForRecord,
      discountOnItems: AppSettings.discountOnItems,
      refundAmount: refundAmount,
      refundReason: refundReason,
      refundedAt: refundedAt,
      refundedBy: refundedAt != null ? day.staffName : null,
      refundEventsJson: refundEventsJson,
    ));

    r.orders++;
    if (status != 'FULLY_REFUNDED') {
      r.grossSales += total;
      day.shiftOrders++;
      day.shiftSales += total;
    }
    if (customer != null) ctx.recordVisit(customer, at, orderType, total);
  }

  static CartItem _line(_Context ctx) {
    final item = ctx.menu[_random.nextInt(ctx.menu.length)];
    double unit = item.price ?? 0;
    String? variantName;
    double? variantPrice;

    final variants = item.variant ?? const [];
    if (variants.isNotEmpty) {
      final v = variants[_random.nextInt(variants.length)];
      variantName = ctx.variantNames[v.variantId];
      variantPrice = v.price;
      unit = v.price;
    }

    final choiceNames = <String>[];
    for (final id in item.choiceIds ?? const <String>[]) {
      if (_random.nextBool()) continue;
      final choice = choiceStore.choices.where((c) => c.id == id).firstOrNull;
      if (choice != null && choice.choiceOption.isNotEmpty) {
        choiceNames.add(_pick(choice.choiceOption).name);
      }
    }

    final extras = <Map<String, dynamic>>[];
    for (final id in item.extraId ?? const <String>[]) {
      if (_random.nextDouble() > 0.25) continue;
      final group = extraStore.extras.where((e) => e.Id == id).firstOrNull;
      final toppings = group?.topping ?? const [];
      if (group == null || toppings.isEmpty) continue;
      final t = _pick(toppings);
      unit += t.price;
      extras.add({
        'name': t.name,
        'displayName': '${group.Ename} - ${t.name}',
        'price': t.price,
        'categoryName': group.Ename,
        'categoryId': group.Id,
        'quantity': 1,
      });
    }

    return CartItem(
      id: _uuid.v4(),
      productId: item.id,
      title: item.name,
      price: unit,
      quantity: 1 + (_random.nextDouble() < 0.25 ? _random.nextInt(3) : 0),
      isStockManaged: item.trackInventory,
      categoryName: ctx.categoryNames[item.categoryOfItem],
      variantName: variantName,
      variantPrice: variantPrice,
      choiceNames: choiceNames,
      taxRate: item.taxRate,
      extras: extras.isEmpty ? null : extras,
      // History deducts no stock: stamped as taking nothing, so a refund
      // restores nothing.
      ownStockQty: 0,
      freshQty: 0,
      restockedQuantity: 0,
    );
  }

  /// `PaymentEntry.toMap` legs: `method` is the PaymentMethod value key;
  /// cash legs carry received / cashInDrawer / change.
  static List<Map<String, dynamic>> _paymentLegs(_Context ctx, double total) {
    Map<String, dynamic> leg(String method, double amount, {bool tender = false}) {
      final m = <String, dynamic>{'method': method, 'amount': amount};
      if (method == 'cash') {
        final received = tender ? _tenderFor(amount) : amount;
        m['received'] = received;
        m['cashInDrawer'] = received;
        m['change'] = received > amount ? _r2(received - amount) : 0;
      }
      return m;
    }

    if (_random.nextDouble() < 0.05 && ctx.methods.length > 1) {
      final cashPart = _r2((total * (0.3 + _random.nextDouble() * 0.4)));
      final other = ctx.methods.firstWhere((m) => m != 'cash',
          orElse: () => ctx.methods.first);
      return [leg('cash', cashPart), leg(other, _r2(total - cashPart))];
    }
    final method = ctx.pickMethod();
    return [leg(method, total, tender: true)];
  }

  static double _tenderFor(double amount) {
    if (_random.nextDouble() < 0.5) return amount;
    for (final note in const [50, 100, 200, 500, 2000]) {
      if (note >= amount) return note.toDouble();
    }
    return ((amount / 500).ceil() * 500).toDouble();
  }

  // ── Expenses & petty cash ────────────────────────────────────────────────

  static Future<void> _expensesAndPettyCash(_Context ctx, _Day day,
      CashMovementRepository cashRepo, HistoryDataResult r) async {
    final count = _random.nextInt(4);
    for (var i = 0; i < count && ctx.expenseCategoryIds.isNotEmpty; i++) {
      final cash = _random.nextDouble() < 0.7;
      final amount = (100 + _random.nextInt(2900)).toDouble();
      final ok = await expenseStore.addExpense(Expense(
        id: _uuid.v4(),
        dateandTime: _orderTime(day),
        amount: amount,
        categoryOfExpense: _pick(ctx.expenseCategoryIds),
        reason: 'Daily purchase',
        paymentType: cash ? 'Cash' : 'Card/Online',
        sessionId: day.sessionId,
      ));
      if (ok) {
        r.expenses++;
        if (cash) day.cashOut += amount;
      }
    }

    if (_random.nextDouble() < 0.3) {
      final isIn = _random.nextBool();
      final amount = (200 + _random.nextInt(9) * 100).toDouble();
      await cashRepo.saveMovement(CashMovementModel(
        id: _uuid.v4(),
        timestamp: _orderTime(day),
        type: isIn ? 'in' : 'out',
        amount: amount,
        reason: isIn ? 'Change float added' : 'Petty cash',
        staffName: day.staffName,
        sessionId: day.sessionId,
      ));
      r.cashMovements++;
      if (isIn) {
        day.cashIn += amount;
      } else {
        day.cashOut += amount;
      }
    }
  }

  static Future<List<String>> _ensureExpenseCategories() async {
    final ids = <String>[];
    for (final name in _expenseCategories) {
      final existing = expenseCategoryStore.categories
          .where((c) => c.name.trim().toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        ids.add(existing.id);
        continue;
      }
      final cat = ExpenseCategory(id: _uuid.v4(), name: name);
      if (await expenseCategoryStore.addCategory(cat)) ids.add(cat.id);
    }
    return ids;
  }

  // ── Customers ────────────────────────────────────────────────────────────

  static Future<int> _applyCustomerStats(_Context ctx) async {
    if (!PlanEnforce.allows(EntKeys.customers)) return 0;
    var updated = 0;
    for (final v in ctx.visits.values) {
      final c = v.customer;
      final ok = await customerStore.updateCustomer(Customer(
        customerId: c.customerId,
        name: c.name,
        phone: c.phone,
        email: c.email,
        address: c.address,
        gstNumber: c.gstNumber,
        totalVisites: c.totalVisites + v.count,
        lastVisitAt: v.lastAt.toIso8601String(),
        lastorderType: v.lastType,
        totalPurchaseAmount: c.totalPurchaseAmount,
        favoriteItems: c.favoriteItems,
        foodPrefrence: c.foodPrefrence,
        notes: c.notes,
        loyaltyPoints: c.loyaltyPoints + v.points,
        totalPointEarned: c.totalPointEarned + v.points,
        totalPointRedeemed: c.totalPointRedeemed,
        creditBalance: c.creditBalance,
        creditLimit: c.creditLimit,
        createdAt: c.createdAt,
        updatedAt: v.lastAt.toIso8601String(),
      ));
      if (ok) updated++;
    }
    return updated;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static List<String> _paymentMethods() {
    final values = locator<PaymentMethodStore>().enabledMethods
        .map((m) => m.value)
        .where((v) => v != 'credit')
        .toList();
    return values.isEmpty ? ['cash'] : values;
  }

  /// Lunch and dinner peaks inside the session.
  static DateTime _orderTime(_Day day) {
    final r = _random.nextDouble();
    final hour = r < 0.40
        ? 12 + _random.nextInt(3)
        : r < 0.85
            ? 19 + _random.nextInt(3)
            : 11 + _random.nextInt(12);
    final t = DateTime(day.start.year, day.start.month, day.start.day, hour,
        _random.nextInt(60), _random.nextInt(60));
    if (t.isBefore(day.start)) return day.start.add(const Duration(minutes: 5));
    if (t.isAfter(day.end)) return day.end.subtract(const Duration(minutes: 5));
    return t;
  }

  static DateTime _refundTime(DateTime orderAt, _Day day) {
    final t = orderAt.add(Duration(minutes: 20 + _random.nextInt(40)));
    return t.isAfter(day.end) ? day.end : t;
  }

  static T _pick<T>(List<T> list) => list[_random.nextInt(list.length)];
  static double _r2(double v) => double.parse(v.toStringAsFixed(2));
  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  static String _name(StaffModel? s) =>
      s == null ? 'Admin' : '${s.firstName} ${s.lastName}'.trim();
}

class _Context {
  final List<Items> menu;
  final Map<String, String> categoryNames;
  final Map<String, String> variantNames;
  final List<String> tables;
  final List<StaffModel> staff;
  final List<Customer> customers;
  final List<String> methods;
  final List<String> expenseCategoryIds;
  final String gstNumber;
  final Map<String, _Visits> visits = {};
  final Random _random = Random();

  _Context({
    required this.menu,
    required this.categoryNames,
    required this.variantNames,
    required this.tables,
    required this.staff,
    required this.customers,
    required this.methods,
    required this.expenseCategoryIds,
    required this.gstNumber,
  });

  StaffModel? pickCashier() {
    final tills =
        staff.where((s) => s.isCashier == 'Cashier' || s.isCashier == 'Manager');
    final pool = tills.isNotEmpty ? tills.toList() : staff;
    return pool.isEmpty ? null : pool[_random.nextInt(pool.length)];
  }

  Customer? pickCustomer() =>
      customers.isEmpty ? null : customers[_random.nextInt(customers.length)];

  String? pickTable() =>
      tables.isEmpty ? null : tables[_random.nextInt(tables.length)];

  /// Cash 45%, UPI 35%, card 15%, anything else enabled the rest.
  String pickMethod() {
    final r = _random.nextDouble();
    final wanted = r < 0.45
        ? 'cash'
        : r < 0.80
            ? 'upi'
            : r < 0.95
                ? 'card'
                : null;
    if (wanted != null && methods.contains(wanted)) return wanted;
    return methods[_random.nextInt(methods.length)];
  }

  void recordVisit(Customer c, DateTime at, String type, double total) {
    final v = visits.putIfAbsent(c.customerId, () => _Visits(c));
    v.count++;
    v.points += LoyaltyPoints.earnedFor(total);
    if (at.isAfter(v.lastAt)) {
      v.lastAt = at;
      v.lastType = type;
    }
  }
}

class _Visits {
  final Customer customer;
  int count = 0;
  int points = 0;
  DateTime lastAt = DateTime(2000);
  String? lastType;
  _Visits(this.customer);
}

class _Day {
  final String sessionId;
  final DateTime start;
  final DateTime end;
  final String? shiftId;
  final String staffName;
  int bills = 0;
  int shiftOrders = 0;
  double shiftSales = 0;
  double cashIn = 0;
  double cashOut = 0;
  int _kot = 0;

  _Day(this.sessionId, this.start, this.end, this.shiftId, this.staffName);

  int nextKot() => ++_kot;
}
