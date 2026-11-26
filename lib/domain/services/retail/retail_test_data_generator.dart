import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/data/models/common/attendance_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/common/attendance_report_calc.dart';
import 'package:billberrylite/domain/services/restaurant/cart_calculation_service.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/retail/checkout_customer_posting.dart';
import 'package:billberrylite/domain/services/retail/checkout_sale_lines.dart';
import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/domain/services/retail/grn_receiving_service.dart';
import 'package:billberrylite/domain/services/retail/retail_checkout_commit.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_reason.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_service.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/util/common/loyalty_points.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// What to generate.
class RetailTestDataOptions {
  /// 55 low-stock variants, for the Low Stock "Current page" check.
  final bool lowStockVariants;

  /// Close the day with the counted cash ₹50 short. Only allowed when this run
  /// opened the day itself (so the closed session holds test data only).
  final bool endOfDayShort;

  const RetailTestDataOptions({
    this.lowStockVariants = false,
    this.endOfDayShort = false,
  });
}

/// One step's outcome, for the summary.
class RetailTestDataStep {
  final String name;
  final bool ok;
  final String detail;
  const RetailTestDataStep(this.name, this.ok, this.detail);
}

/// The run's result. [failedStep] is set when a step threw; everything listed
/// in [steps] before it really happened — nothing is rolled back.
class RetailTestDataResult {
  final String prefix;
  final List<RetailTestDataStep> steps;
  final String? failedStep;
  final String? error;
  const RetailTestDataResult({
    required this.prefix,
    required this.steps,
    this.failedStep,
    this.error,
  });
  bool get success => failedStep == null;
}

/// What already exists, before generating.
class RetailTestDataCheck {
  /// Prefixes of earlier runs found on this device (e.g. `TEST-1`).
  final Set<String> existingRuns;

  /// The live cart has lines — the generator would mix into a real sale.
  final bool cartInUse;

  /// A day from an earlier date is still open (End of Day pending).
  final bool staleDayOpen;

  const RetailTestDataCheck({
    required this.existingRuns,
    required this.cartInUse,
    required this.staleDayOpen,
  });

  /// The prefix the next run will use.
  String get nextPrefix {
    var n = 1;
    while (existingRuns.contains('TEST-$n')) {
      n++;
    }
    return 'TEST-$n';
  }
}

/// **Debug-only** Retail test data, created through the app's REAL write paths
/// (stores and services — never by writing Hive boxes), so stock, customer
/// credit, supplier balances, the cash drawer and every report stay
/// consistent.
///
/// Everything it names starts with a run prefix (`TEST-1 …`). It never edits,
/// clears or overwrites existing data, and there is no undo: each step that
/// completed stays.
///
/// Dates: all business records are dated NOW (the app stamps them), except
/// attendance, which is added for past days through the same path as the
/// staff screen's "Add shift".
class RetailTestDataGenerator {
  RetailTestDataGenerator({void Function(String step)? onProgress})
      : _onProgress = onProgress;

  final void Function(String step)? _onProgress;
  final _uuid = const Uuid();
  final _steps = <RetailTestDataStep>[];

  static final _prefixPattern = RegExp(r'^(TEST-\d+) ');

  /// Earlier runs, cart state and day state — call before [run].
  static Future<RetailTestDataCheck> check() async {
    final runs = <String>{};
    void scan(String? name) {
      final m = _prefixPattern.firstMatch(name ?? '');
      if (m != null) runs.add(m.group(1)!);
    }

    await productStore.ensureLoaded();
    for (final p in productStore.products) {
      scan(p.productName);
    }
    await customerStore.loadCustomers();
    for (final c in customerStore.customers) {
      scan(c.name);
    }
    await supplierStore.loadSuppliers();
    for (final s in supplierStore.suppliers) {
      scan(s.name);
    }
    final now = DateTime.now();
    for (final a in await attendanceStore.getRecordsBetweenDates(
        now.subtract(const Duration(days: 120)), now)) {
      scan(a.staffName);
    }

    final session = await DayManagementService.getCurrentSession();
    final staleDay = session != null &&
        !session.isClosed &&
        !_sameDay(session.startTime, now);

    return RetailTestDataCheck(
      existingRuns: runs,
      cartInUse: retailCartStore.items.isNotEmpty,
      staleDayOpen: staleDay,
    );
  }

  /// Generates one dataset. Throws [StateError] in release builds.
  Future<RetailTestDataResult> run(RetailTestDataOptions options) async {
    if (kReleaseMode) {
      throw StateError('Retail test data is not available in release builds');
    }
    final pre = await check();
    final prefix = pre.nextPrefix;
    String? failed;
    String? error;

    if (pre.cartInUse) {
      return RetailTestDataResult(
        prefix: prefix,
        steps: const [],
        failedStep: 'Precheck',
        error: 'The current cart has items. Finish or clear that sale first — '
            'test data must not be mixed into a real sale.',
      );
    }
    if (pre.staleDayOpen) {
      return RetailTestDataResult(
        prefix: prefix,
        steps: const [],
        failedStep: 'Precheck',
        error: 'A day from an earlier date is still open. Complete its End of '
            'Day first.',
      );
    }

    final previousCustomer = customerStore.selectedCustomer;
    final ctx = _Ctx(prefix);
    try {
      await _step('Catalogue', () => _catalogue(ctx));
      if (options.lowStockVariants) {
        await _step('Low-stock variants (55)', () => _lowStock(ctx));
      }
      await _step('Customers', () => _customers(ctx));
      await _step('Suppliers', () => _suppliers(ctx));
      await _step('Open the day', () => _openDay(ctx));
      await _step('Paid sales', () => _paidSales(ctx));
      await _step('Credit sales', () => _creditSales(ctx));
      await _step('Collection and write-off', () => _credit(ctx));
      await _step('Refund and exchange', () => _returns(ctx));
      await _step('Purchase orders and GRNs', () => _purchasing(ctx));
      await _step('Purchase returns', () => _purchaseReturns(ctx));
      await _step('Stock adjustments', () => _adjustments(ctx));
      await _step('Cash in / out', () => _cash(ctx));
      await _step('Attendance', () => _attendance(ctx));
      if (options.endOfDayShort) {
        await _step('End of Day (₹50 short)', () => _endOfDay(ctx));
      }
    } on _StepFailure catch (f) {
      failed = f.step;
      error = f.error;
    } finally {
      // Leave the POS as we found it: empty cart, the same selected customer.
      try {
        if (retailCartStore.items.isNotEmpty) {
          await retailCartStore.clearCartAndSave();
        }
        retailCartStore.selectSaleCustomer(previousCustomer);
      } catch (_) {}
    }

    return RetailTestDataResult(
      prefix: prefix,
      steps: List.unmodifiable(_steps),
      failedStep: failed,
      error: error,
    );
  }

  Future<void> _step(String name, Future<String> Function() body) async {
    _onProgress?.call(name);
    try {
      final detail = await body();
      _steps.add(RetailTestDataStep(name, true, detail));
    } catch (e) {
      _steps.add(RetailTestDataStep(name, false, '$e'));
      throw _StepFailure(name, '$e');
    }
  }

  // ── Catalogue ──────────────────────────────────────────────────────────

  Future<String> _catalogue(_Ctx ctx) async {
    if (!productStore.canAddProduct) {
      throw StateError('The plan does not allow adding more products');
    }
    final category = Category(
      id: _uuid.v4(),
      name: '${ctx.prefix} General',
      createdTime: DateTime.now(),
    );
    if (!await categoryStore.addCategory(category)) {
      throw StateError('Could not add the test category');
    }

    // (name, price, MRP, cost — null = no cost price, stock, reorder, GST)
    const specs = <(String, double, double?, double?, double, double, double)>[
      ('Rice 1kg', 80, 90, 60, 60, 10, 5),
      ('Sugar 1kg', 50, 55, 40, 60, 10, 5),
      ('Tea 250g', 120, 130, 90, 40, 8, 5),
      ('Soap', 35, 40, 25, 80, 15, 18),
      ('Shampoo', 150, 165, 110, 40, 8, 18),
      ('Notebook', 60, null, 35, 50, 10, 12),
      ('Pen pack', 40, null, null, 50, 10, 12), // no cost price
      ('Biscuits', 30, 30, 22, 80, 15, 18),
      ('Juice 1L', 110, 120, 80, 40, 8, 12),
      ('Detergent 1kg', 140, 150, 105, 30, 6, 18),
    ];
    for (final s in specs) {
      final (name, price, mrp, cost, stock, reorder, gst) = s;
      final p = await _addProduct(ctx, category, '${ctx.prefix} $name',
          price: price, mrp: mrp, cost: cost, stock: stock, reorder: reorder,
          gst: gst);
      ctx.products.add(p);
    }
    return '1 category, ${specs.length} products (1 without cost price)';
  }

  Future<_Item> _addProduct(
    _Ctx ctx,
    Category category,
    String name, {
    required double price,
    double? mrp,
    double? cost,
    required double stock,
    required double reorder,
    required double gst,
  }) async {
    final productId = _uuid.v4();
    final product = ProductModel.fromProduct(
      productId: productId,
      productName: name,
      category: category.id,
      hasVariants: false,
      productType: 'simple',
      gstRate: gst,
    );
    await productStore.addProduct(product);
    final variant = VarianteModel.create(
      varianteId: _uuid.v4(),
      productId: productId,
      sellingPrice: price,
      mrp: mrp,
      costPrice: cost,
      stockQty: stock, // opening stock is recorded by addVariant
      minStock: reorder,
      taxRate: gst,
      isDefault: true,
    );
    final added = await productStore.addVariant(variant);
    if (!added.success) {
      throw StateError('Could not add $name: ${added.errorMessage}');
    }
    return _Item(product, variant);
  }

  Future<String> _lowStock(_Ctx ctx) async {
    final category = Category(
      id: _uuid.v4(),
      name: '${ctx.prefix} Low stock',
      createdTime: DateTime.now(),
    );
    if (!await categoryStore.addCategory(category)) {
      throw StateError('Could not add the low-stock category');
    }
    final productId = _uuid.v4();
    await productStore.addProduct(ProductModel.fromProduct(
      productId: productId,
      productName: '${ctx.prefix} Low stock item',
      category: category.id,
      hasVariants: true,
      productType: 'variable',
      gstRate: 0,
    ));
    for (var i = 1; i <= 55; i++) {
      final added = await productStore.addVariant(VarianteModel.create(
        varianteId: _uuid.v4(),
        productId: productId,
        sellingPrice: 10,
        costPrice: 6,
        stockQty: 1,
        minStock: 10,
        taxRate: 0,
        customAttributes: {'Size': 'S$i'},
      ));
      if (!added.success) {
        throw StateError('Variant $i: ${added.errorMessage}');
      }
    }
    return '1 product with 55 variants at stock 1 (reorder 10)';
  }

  // ── Parties ────────────────────────────────────────────────────────────

  Future<String> _customers(_Ctx ctx) async {
    for (final (name, limit) in const [
      ('Regular', 0.0),
      ('Credit A', 20000.0),
      ('Credit B', 20000.0),
    ]) {
      final c = Customer.create(
        customerId: await customerIdGeneratorService.generate(),
        name: '${ctx.prefix} $name',
        creditLimit: limit,
      );
      if (!await customerStore.addCustomer(c)) {
        throw StateError('Could not add customer $name (plan limit?)');
      }
      ctx.customers.add(c);
    }
    return '3 customers (2 with credit limits)';
  }

  Future<String> _suppliers(_Ctx ctx) async {
    for (final name in const ['Wholesale', 'Distributor']) {
      final s = SupplierModel.create(name: '${ctx.prefix} $name');
      await supplierStore.addSupplier(s);
      ctx.suppliers.add(s);
    }
    return '2 suppliers';
  }

  Future<String> _openDay(_Ctx ctx) async {
    if (await DayManagementService.isSessionOpen()) {
      ctx.openedDay = false;
      return 'Used the day already open';
    }
    await DayManagementService.startSession(1000);
    ctx.openedDay = true;
    return 'Started a new day with ₹1000 opening cash';
  }

  // ── Sales ──────────────────────────────────────────────────────────────

  Future<String> _paidSales(_Ctx ctx) async {
    final p = ctx.products;
    final regular = ctx.customers[0];
    final methods = ['cash', 'upi', 'card'];

    // 12 plain sales across payment methods.
    for (var i = 0; i < 12; i++) {
      ctx.paid.add(await _sell(
        ctx,
        lines: [(p[i % p.length], 1 + i % 3), (p[(i + 3) % p.length], 1)],
        method: methods[i % 3],
        customer: i % 4 == 0 ? regular : null,
      ));
    }
    // Bill discount.
    ctx.paid.add(await _sell(ctx,
        lines: [(p[0], 2), (p[4], 1)],
        billDiscount: 10,
        billDiscountReason: 'Test bill discount'));
    // Line discount.
    ctx.paid.add(await _sell(ctx,
        lines: [(p[3], 3)], lineDiscountOn: 0, lineDiscountPercent: 10));
    // Price override.
    ctx.paid.add(await _sell(ctx,
        lines: [(p[8], 1)], overrideOn: 0, overridePrice: 95));
    // Quick item (not in the catalogue).
    ctx.paid.add(await _sell(ctx,
        lines: [(p[1], 1)], quickItem: '${ctx.prefix} Gift wrap'));
    // Partly paid by a customer: the rest goes on their account.
    ctx.paid.add(await _sell(ctx,
        lines: [(p[5], 2), (p[9], 1)],
        customer: ctx.customers[1],
        collectFraction: 0.5));

    // Loyalty: only when the regular customer has earned points.
    var loyalty = 'no points earned — loyalty sale skipped';
    final fresh = await customerStore.getCustomerById(regular.customerId);
    final points = fresh?.loyaltyPoints ?? 0;
    if (points > 0) {
      final redeem = points >= 10 ? 10 : points;
      ctx.paid.add(await _sell(ctx,
          lines: [(p[2], 2)], customer: fresh, redeemPoints: redeem));
      loyalty = '1 loyalty sale ($redeem points)';
    }
    return '${ctx.paid.length} paid sales (discounts, override, quick item, '
        'partial payment); $loyalty';
  }

  Future<String> _creditSales(_Ctx ctx) async {
    final p = ctx.products;
    ctx.creditA = await _sell(ctx,
        lines: [(p[0], 3), (p[6], 2)], customer: ctx.customers[1], credit: true);
    ctx.creditB = await _sell(ctx,
        lines: [(p[4], 2)], customer: ctx.customers[2], credit: true);
    return '2 Pay Later sales';
  }

  /// One sale through the real cart and the Checkout commit path.
  Future<SaleModel> _sell(
    _Ctx ctx, {
    required List<(_Item, double)> lines,
    String method = 'cash',
    Customer? customer,
    bool credit = false,
    double? collectFraction,
    double billDiscount = 0,
    String? billDiscountReason,
    int? lineDiscountOn,
    double lineDiscountPercent = 0,
    int? overrideOn,
    double? overridePrice,
    String? quickItem,
    int redeemPoints = 0,
  }) async {
    final billsToday = (await saleStore.getTodaySales()).length;
    if (!PlanEnforce.withinLimit(RetailEntKeys.billingPerDayMax, billsToday)) {
      throw StateError('Daily bill limit reached for this plan');
    }

    final cart = retailCartStore;
    cart.selectSaleCustomer(customer);
    for (final (item, qty) in lines) {
      final r = await cart.addItem(item.product, item.variant, qty: qty);
      if (!r.success) throw StateError('Add to cart: ${r.errorMessage}');
    }
    if (quickItem != null) {
      final r = await cart.addQuickItem(name: quickItem, price: 49);
      if (!r.success) throw StateError('Quick item: ${r.errorMessage}');
    }
    if (lineDiscountOn != null) {
      final r = await cart.setLineDiscount(
        variantId: lines[lineDiscountOn].$1.variant.varianteId,
        type: DiscountType.percentage,
        value: lineDiscountPercent,
        reason: 'promotional_discount',
        note: 'Test line discount',
      );
      if (!r.success) throw StateError('Line discount: ${r.errorMessage}');
    }
    if (overrideOn != null) {
      final r = await cart.overrideLinePrice(
        variantId: lines[overrideOn].$1.variant.varianteId,
        newPrice: overridePrice!,
        reason: 'customer_negotiation',
        note: 'Test price override',
      );
      if (!r.success) throw StateError('Price override: ${r.errorMessage}');
    }
    if (billDiscount > 0) {
      cart.setDiscount(type: DiscountType.amount, value: billDiscount);
    }
    if (redeemPoints > 0) cart.setLoyaltyRedemption(redeemPoints.toDouble());

    final saleId = _uuid.v4();
    final invoiceNumber = await saleStore.nextInvoiceNumber();
    final bill = cart.bill;
    final gst = await StoreSettingsService().gstNumberSnapshot();

    final SaleModel sale;
    final CheckoutCustomerPosting? posting;
    if (credit) {
      sale = SaleModel.createCreditSale(
        saleId: saleId,
        invoiceNumber: invoiceNumber,
        customerId: customer!.customerId,
        totalItems: bill.totalItems,
        subtotal: bill.itemTotal,
        discountAmount: bill.discountAmount,
        totalTaxableAmount: bill.taxableAmount,
        totalGstAmount: bill.totalGst,
        grandTotal: bill.grandTotal,
        discountType: cart.discountType.name,
        discountValue: cart.discountValue,
        discountReason: billDiscountReason,
        lineDiscountTotal: bill.lineDiscountTotal,
        loyaltyPointsUsed: bill.loyaltyRedemption.floor(),
        roundOff: bill.roundOff,
        isTaxInclusive: bill.isTaxInclusive,
        taxEnabled: TaxFeature.enabled,
        storeGstNumber: gst,
        shiftId: RestaurantSession.currentShiftId,
      );
      posting = CheckoutCustomerPosting.creditSale(
        customerId: customer.customerId,
        grandTotal: bill.grandTotal,
        pointsRedeemed: bill.loyaltyRedemption.floor(),
      );
    } else {
      final paid = collectFraction == null
          ? bill.grandTotal
          : (bill.grandTotal * collectFraction).roundToDouble();
      sale = SaleModel.createWithSplitPayment(
        saleId: saleId,
        invoiceNumber: invoiceNumber,
        customerId: customer?.customerId,
        totalItems: bill.totalItems,
        subtotal: bill.itemTotal,
        discountAmount: bill.discountAmount,
        totalTaxableAmount: bill.taxableAmount,
        totalGstAmount: bill.totalGst,
        grandTotal: bill.grandTotal,
        paymentList: [
          {'method': method, 'amount': paid},
        ],
        totalPaid: paid,
        changeReturn: 0,
        discountType: cart.discountType.name,
        discountValue: cart.discountValue,
        discountReason: billDiscountReason,
        lineDiscountTotal: bill.lineDiscountTotal,
        loyaltyPointsUsed: bill.loyaltyRedemption.floor(),
        roundOff: bill.roundOff,
        isTaxInclusive: bill.isTaxInclusive,
        taxEnabled: TaxFeature.enabled,
        storeGstNumber: gst,
        amountCollected: collectFraction == null ? null : paid,
        shiftId: RestaurantSession.currentShiftId,
      );
      posting = customer == null
          ? null
          : CheckoutCustomerPosting.paidSale(
              customerId: customer.customerId,
              pointsRedeemed: bill.loyaltyRedemption.floor(),
              dueAmount: sale.dueAmount,
              grandTotal: bill.grandTotal,
              pointsEarned: LoyaltyPoints.earnedFor(bill.grandTotal),
            );
    }

    // Exactly Checkout's commit: journal → save → post customer + stock.
    final items = await CheckoutSaleLines.build(saleId, bill);
    final entry = await RetailCheckoutCommit.begin(
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      tabId: cart.activeTabId,
      lines: cart.items.toList(),
      posting: posting,
    );
    await RetailCheckoutCommit.saveSale(entry, sale, items);
    await RetailCheckoutCommit.finish(entry, clearCart: cart.clearCartAndSave);
    if (credit || sale.dueAmount > 0) await creditStore.loadData();
    return sale;
  }

  // ── Credit ─────────────────────────────────────────────────────────────

  Future<String> _credit(_Ctx ctx) async {
    final a = ctx.creditA!;
    final pay = (a.dueAmount / 2).roundToDouble();
    final paid = await creditStore.receivePayment(
      customerId: ctx.customers[1].customerId,
      amount: pay,
      paymentMode: 'cash',
      note: '${ctx.prefix} collection',
    );
    if (!paid.success) throw StateError('Collection: ${paid.errorMessage}');

    // Debug-only use of writeOffDebt — Retail has no write-off screen.
    final off = await creditStore.writeOffDebt(
      customerId: ctx.customers[2].customerId,
      saleId: ctx.creditB!.saleId,
      note: '${ctx.prefix} write-off',
    );
    if (!off.success) throw StateError('Write-off: ${off.errorMessage}');
    return 'Collected ₹${pay.toStringAsFixed(0)}; wrote off one credit sale';
  }

  // ── Returns ────────────────────────────────────────────────────────────

  Future<String> _returns(_Ctx ctx) async {
    await ReturnService().processFullReturn(
      originalSaleId: ctx.paid[1].saleId,
      refundMethod: 'cash',
      returnReason: 'defective',
      returnNote: '${ctx.prefix} refund',
    );

    // Exchange the first line of another sale for a different product.
    final source = ctx.paid[2];
    final lines = await saleStore.getItemsForSale(source.saleId);
    final returned = lines.first;
    final replacement = ctx.products
        .firstWhere((p) => p.variant.varianteId != returned.varianteId);
    final ex = await ExchangeService().processExchange(
      originalSaleId: source.saleId,
      returnedVariantId: returned.varianteId,
      returnQty: 1,
      replacementVariantId: replacement.variant.varianteId,
      paymentMethod: 'cash',
      note: '${ctx.prefix} exchange',
    );
    if (!ex.success) throw StateError('Exchange: ${ex.error}');
    return '1 full refund, 1 exchange';
  }

  // ── Purchasing ─────────────────────────────────────────────────────────

  Future<PurchaseOrderModel> _po(
      _Ctx ctx, SupplierModel s, List<(_Item, double, double?)> lines) async {
    // PO ids are millisecond timestamps — keep two POs apart.
    await Future<void>.delayed(const Duration(milliseconds: 3));
    final draft = PurchaseOrderModel.create(
      poNumber: await purchaseOrderStore.generatePONumber(),
      supplierId: s.supplierId,
      supplierName: s.name,
      expectedDeliveryDate:
          DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      notes: '${ctx.prefix} purchase order',
    );
    final items = [
      for (final (item, qty, price) in lines)
        PurchaseOrderItemModel.create(
          poId: draft.poId,
          variantId: item.variant.varianteId,
          productId: item.product.productId,
          productName: item.product.productName,
          orderedQty: qty,
          estimatedPrice: price,
        ),
    ];
    final poId = await purchaseOrderStore.addPurchaseOrder(draft, items);
    await purchaseOrderStore.updatePOStatus(poId, POStatus.sent);
    ctx.poItems[poId] = items;
    return purchaseOrderStore.purchaseOrders.firstWhere((p) => p.poId == poId);
  }

  /// One receipt through the real GRN service. [lines]: (PO line, received,
  /// damaged, handling, cost).
  Future<GRNModel> _grn(
    _Ctx ctx,
    PurchaseOrderModel po,
    List<(PurchaseOrderItemModel, double, double, DamagedHandling, double?)>
        lines,
  ) async {
    final grn = GRNModel.create(
      grnNumber: await purchaseOrderStore.generateGRNNumber(),
      poId: po.poId,
      poNumber: po.poNumber,
      supplierId: po.supplierId,
      supplierName: po.supplierName,
      receivedDate: DateTime.now().toIso8601String(),
      totalOrderedQty: lines.fold(0.0, (s, l) => s + l.$1.orderedQty),
      totalReceivedQty: lines.fold(0.0, (s, l) => s + l.$2),
      totalAmount: lines.fold<double>(0, (s, l) => s + l.$2 * (l.$5 ?? 0)),
      invoiceNumber: '${ctx.prefix}-INV-${ctx.grnCount + 1}',
    );
    final items = [
      for (final (line, received, damaged, handling, cost) in lines)
        GRNItemModel.create(
          grnId: grn.grnId,
          poItemId: line.poItemId,
          variantId: line.variantId,
          productId: line.productId,
          productName: line.productName,
          orderedQty: line.orderedQty,
          receivedQty: received,
          acceptedQty: received - damaged,
          damagedQty: damaged > 0 ? damaged : null,
          damagedHandling: damaged > 0 ? handling : null,
          costPrice: cost,
        ),
    ];
    final result = await GrnReceivingService.receive(grn, items);
    if (!result.success) throw StateError('GRN: ${result.errorMessage}');
    ctx.grnCount++;
    return grn;
  }

  Future<String> _purchasing(_Ctx ctx) async {
    final p = ctx.products;
    final s1 = ctx.suppliers[0];
    final s2 = ctx.suppliers[1];

    // Pending: sent, nothing received.
    await _po(ctx, s1, [(p[0], 20, 60), (p[1], 20, 40)]);

    // Completed: everything received in one GRN.
    final done = await _po(ctx, s2, [(p[2], 10, 90), (p[3], 24, 25)]);
    final doneLines = ctx.poItems[done.poId]!;
    await _grn(ctx, done, [
      (doneLines[0], 10, 0, DamagedHandling.none, 90),
      (doneLines[1], 24, 0, DamagedHandling.none, 25),
    ]);

    // Partial: two receipts, each with damaged goods returned to the
    // supplier — the second line has no cost price on the invoice.
    final part = await _po(ctx, s1, [(p[4], 20, 110), (p[6], 20, null)]);
    final partLines = ctx.poItems[part.poId]!;
    ctx.damagedGrns.add(await _grn(ctx, part, [
      (partLines[0], 6, 1, DamagedHandling.returnToSupplier, 110),
    ]));
    ctx.damagedGrns.add(await _grn(ctx, part, [
      (partLines[1], 5, 2, DamagedHandling.returnToSupplier, null),
    ]));
    return '3 POs (pending, partial, completed), 3 GRNs, 2 with damaged '
        'goods (1 unpriced line)';
  }

  Future<String> _purchaseReturns(_Ctx ctx) async {
    await damagedGoodsStore.loadAll();
    final ids = ctx.damagedGrns.map((g) => g.grnId).toSet();
    final returns = damagedGoodsStore.purchaseReturns
        .where((r) => ids.contains(r.grnId))
        .toList();
    if (returns.length < 2) {
      return 'Found ${returns.length} purchase return(s) from the damaged '
          'GRNs — credit note / cancel not applied';
    }
    // Credit the priced return at its own value (the store refuses a note
    // above the return value); cancel the other one.
    returns.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final credited = await damagedGoodsStore.recordCreditNote(
      returnId: returns[0].returnId,
      creditNoteNumber: '${ctx.prefix}-CN-1',
      date: DateTime.now().toIso8601String(),
    );
    final cancelled =
        await damagedGoodsStore.cancelPurchaseReturn(returns[1].returnId);
    if (!credited || !cancelled) {
      throw StateError('Credit note: $credited, cancel: $cancelled');
    }
    return '1 purchase return credited, 1 cancelled';
  }

  // ── Stock and cash ─────────────────────────────────────────────────────

  Future<String> _adjustments(_Ctx ctx) async {
    if (!StockAdjustmentService.canAdjust) {
      throw StateError('This login cannot adjust stock');
    }
    Future<void> adjust(_Item item, double delta,
        StockAdjustmentReason reason) async {
      final v = await productStore.getVariantById(item.variant.varianteId);
      final r = await StockAdjustmentService.adjust(
        variant: v!,
        newStock: v.stockQty + delta,
        reason: reason,
        note: '${ctx.prefix} adjustment',
        expectedStock: v.stockQty,
      );
      if (!r.success) throw StateError('Adjustment: ${r.errorMessage}');
    }

    await adjust(ctx.products[7], -2, StockAdjustmentReason.damaged);
    await adjust(ctx.products[8], 1, StockAdjustmentReason.foundExtra);
    return '2 adjustments (1 loss, 1 found extra)';
  }

  Future<String> _cash(_Ctx ctx) async {
    final added = await cashMovementStore.addMovement(
      type: 'in',
      amount: 500,
      reason: 'Float top-up',
      note: '${ctx.prefix} cash in',
    );
    final taken = await cashMovementStore.addMovement(
      type: 'out',
      amount: 200,
      reason: 'Petty cash',
      note: '${ctx.prefix} cash out',
    );
    if (!added || !taken) throw StateError('Cash movement refused');
    return 'Cash in ₹500, cash out ₹200';
  }

  // ── Attendance (past days through the "Add shift" path) ────────────────

  Future<String> _attendance(_Ctx ctx) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // From the 26th of last month: a range that crosses months.
    final start = DateTime(now.year, now.month - 1, 26);
    final asha = '${ctx.prefix} Asha';
    final ravi = '${ctx.prefix} Ravi';
    final meena = '${ctx.prefix} Meena';
    var count = 0;

    Future<void> add(String name, DateTime inAt, DateTime outAt,
        {int breakMins = 0}) async {
      await attendanceStore.addRecord(AttendanceModel(
        id: _uuid.v4(),
        staffName: name,
        staffRole: 'Cashier',
        clockIn: inAt,
        clockOut: outAt,
        totalMinutes: outAt.difference(inAt).inMinutes - breakMins,
        breakTotalMinutes: breakMins > 0 ? breakMins : null,
        date: AttendanceReportCalc.dayKey(inAt),
      ));
      count++;
    }

    for (var d = start; d.isBefore(today); d = d.add(const Duration(days: 1))) {
      final day = DateTime(d.year, d.month, d.day);
      // Asha: day shift with a break; off on Sundays (absent days).
      if (day.weekday != DateTime.sunday) {
        await add(asha, day.add(const Duration(hours: 9)),
            day.add(const Duration(hours: 17)),
            breakMins: 30);
      }
      // Ravi: split shift (two on one day) every 3rd day, an overnight
      // shift every 4th, otherwise absent.
      final n = day.difference(start).inDays;
      if (n % 3 == 0) {
        await add(ravi, day.add(const Duration(hours: 8)),
            day.add(const Duration(hours: 12)));
        await add(ravi, day.add(const Duration(hours: 16)),
            day.add(const Duration(hours: 20)));
      } else if (n % 4 == 1 && day.add(const Duration(hours: 30)).isBefore(now)) {
        await add(ravi, day.add(const Duration(hours: 22)),
            day.add(const Duration(hours: 30)));
      }
    }
    // Meena: clocked in now and left open (status Open).
    await attendanceStore.clockIn(staffName: meena, staffRole: 'Cashier');
    count++;
    return '$count records from ${AttendanceReportCalc.dayKey(start)} '
        '(breaks, split and overnight shifts, absent days, 1 open)';
  }

  // ── End of Day (optional) ──────────────────────────────────────────────

  Future<String> _endOfDay(_Ctx ctx) async {
    if (!ctx.openedDay) {
      throw StateError('Skipped: the day was already open before this run, '
          'so it may hold real sales — End of Day was NOT run');
    }
    await shiftStore.loadShifts();
    if (shiftStore.shifts.any((s) => s.isOpen)) {
      throw StateError('Skipped: a shift is open — End of Day was NOT run');
    }
    await attendanceStore.loadTodayRecords();
    // Any TEST-n run's staff are test data; anyone else is a real person.
    final openReal = attendanceStore.todayRecords
        .where((r) => r.isOpen && !_prefixPattern.hasMatch(r.staffName));
    if (openReal.isNotEmpty) {
      throw StateError('Skipped: real staff are clocked in — End of Day was '
          'NOT run');
    }

    // The same steps as the Retail EOD screen, without dialogs or printing.
    final session = await DayManagementService.getCurrentSession();
    final opening = await DayManagementService.getOpeningBalance();
    final preview = await EODService.generateRetailEODReport(
      date: session!.startTime,
      openingBalance: opening,
      actualCash: 0,
    );
    final expected = preview.closingBalance;
    final counted = expected - 50;
    final report = await EODService.generateRetailEODReport(
      date: session.startTime,
      openingBalance: opening,
      actualCash: counted,
      remarks: '${ctx.prefix} End of Day (₹50 short)',
      cashWithdrawn: 0,
    );
    await EODService.saveEODReport(report);
    await cashMovementStore.addAdjustment(
      signedAmount: -50,
      reason: 'EOD Shortage',
      note: '${ctx.prefix}: expected ${expected.toStringAsFixed(2)}, '
          'counted ${counted.toStringAsFixed(2)}',
      staffName: RestaurantSession.staffName ?? 'Admin',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'retail_last_eod_date', DateTime.now().toIso8601String());
    for (final r in attendanceStore.todayRecords.where((r) => r.isOpen)) {
      await attendanceStore.clockOut(r.id);
    }
    await RestaurantSession.clearShiftSession();
    await DayManagementService.markDayEnded(closingBalance: counted);
    return 'Day closed: expected ${expected.toStringAsFixed(2)}, counted '
        '${counted.toStringAsFixed(2)} (−50). The open test shift was '
        'clocked out.';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Item {
  final ProductModel product;
  final VarianteModel variant;
  _Item(this.product, this.variant);
}

class _Ctx {
  final String prefix;
  _Ctx(this.prefix);
  final products = <_Item>[];
  final customers = <Customer>[];
  final suppliers = <SupplierModel>[];
  final paid = <SaleModel>[];
  SaleModel? creditA;
  SaleModel? creditB;
  final poItems = <String, List<PurchaseOrderItemModel>>{};
  final damagedGrns = <GRNModel>[];
  int grnCount = 0;
  bool openedDay = false;
}

class _StepFailure implements Exception {
  final String step;
  final String error;
  _StepFailure(this.step, this.error);
}
