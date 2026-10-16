import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/common/document_number_service.dart';
import 'package:billberrylite/domain/services/retail/inventory_service.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:billberrylite/domain/services/retail/retail_billing_service.dart';
import 'package:billberrylite/domain/services/retail/return_math.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:uuid/uuid.dart';

/// A priced exchange, computed but NOT yet written.
///
/// Both halves are known before anything touches the database, which is what
/// makes "validate everything, then write" possible.
class ExchangeQuote {
  /// What the returned goods were originally charged. Always positive.
  final double returnValue;

  /// What the replacement costs today, at its own tax rate.
  final double replacementValue;

  /// The returned line, prorated from the original sale.
  final ReturnFigures returnFigures;

  /// The replacement priced through the ordinary retail engine.
  final RetailBill replacementBill;

  final SaleModel originalSale;
  final SaleItemModel returnedLine;
  final double returnQty;
  final VarianteModel replacementVariant;
  final double replacementQty;

  const ExchangeQuote({
    required this.returnValue,
    required this.replacementValue,
    required this.returnFigures,
    required this.replacementBill,
    required this.originalSale,
    required this.returnedLine,
    required this.returnQty,
    required this.replacementVariant,
    required this.replacementQty,
  });

  /// Positive → the customer pays. Negative → the customer is owed.
  double get difference =>
      double.parse((replacementValue - returnValue).toStringAsFixed(2));

  bool get customerPays => difference > 0.009;
  bool get customerRefunded => difference < -0.009;
  bool get isEven => !customerPays && !customerRefunded;

  /// Magnitude of [difference], for display and for collecting/refunding.
  double get differenceAmount => difference.abs();

  /// Value carried across by the returned goods — the part of the replacement
  /// the customer paid for with the item they brought back.
  ///
  /// `min(returnValue, replacementValue)`: whichever side is smaller is fully
  /// covered, and only the remainder is real money.
  double get exchangeCredit =>
      returnValue < replacementValue ? returnValue : replacementValue;

  /// Legs for the REPLACEMENT document. Sums to [replacementValue].
  ///
  /// The customer only ever tenders money here when the replacement is the
  /// dearer side; otherwise the returned goods cover it entirely.
  ///
  /// Amounts are forced to `double`: `SaleModel.createWithSplitPayment` sorts
  /// legs with `as double`, and a whole-rupee `int` crashes there.
  List<Map<String, dynamic>> replacementLegs(String method) => [
        {
          'method': ExchangeService.exchangeCreditMethod,
          'amount': exchangeCredit.toDouble(),
        },
        if (customerPays)
          {'method': method, 'amount': differenceAmount.toDouble()},
      ];

  /// Legs for the RETURN document, stored NEGATIVE to match its negated header.
  ///
  /// The invariant: a document's legs sum to its own `totalAmount`. That is
  /// what lets payment buckets sum legs across documents and land on the real
  /// money movement without any special-casing.
  List<Map<String, dynamic>> returnLegs(String method) => [
        {
          'method': ExchangeService.exchangeCreditMethod,
          'amount': -exchangeCredit.toDouble(),
        },
        if (customerRefunded)
          {'method': method, 'amount': -differenceAmount.toDouble()},
      ];

  /// Real money actually handed back on this exchange, 0 when none was.
  double get refundedInMoney => customerRefunded ? differenceAmount : 0;

  /// Of the return value, how much offsets an unpaid invoice rather than
  /// coming back as money.
  double get appliedToDue {
    final due = originalSale.dueAmount;
    if (due <= 0) return 0;
    return returnValue < due ? returnValue : due;
  }
}

/// The outcome of a committed exchange.
class ExchangeResult {
  final bool success;
  final String? error;
  final String? exchangeGroupId;
  final String? returnSaleId;
  final String? replacementSaleId;
  final double difference;

  const ExchangeResult._({
    required this.success,
    this.error,
    this.exchangeGroupId,
    this.returnSaleId,
    this.replacementSaleId,
    this.difference = 0,
  });

  factory ExchangeResult.failure(String message) =>
      ExchangeResult._(success: false, error: message);

  factory ExchangeResult.ok({
    required String exchangeGroupId,
    required String returnSaleId,
    required String replacementSaleId,
    required double difference,
  }) =>
      ExchangeResult._(
        success: true,
        exchangeGroupId: exchangeGroupId,
        returnSaleId: returnSaleId,
        replacementSaleId: replacementSaleId,
        difference: difference,
      );
}

/// Retail EXCHANGE — take one item back from a settled sale and give a
/// different one out, settling the price difference.
///
/// **An exchange is not its own accounting document.** It is an ordinary
/// RETURN plus an ordinary SALE, linked by [SaleModel.exchangeGroupId]. Every
/// report, EOD aggregate, tax summary and ledger already understands both
/// halves, so nothing downstream has to be taught about exchanges.
///
/// **Both halves settle through the SAME payment method** — the one chosen for
/// the difference, which is independent of how the original sale was paid. The
/// legs then cancel down to exactly the difference in that method's bucket:
/// a 900 return and a 1200 replacement both on UPI net to +300 UPI and leave
/// the cash drawer untouched. This is why no new payment concept is needed.
///
/// **The original sale's payment identity is never rewritten.** 900 paid by
/// CASH stays 900 CASH forever, whatever settles the difference. Only an
/// outstanding receivable moves — see [ReturnService].
///
/// V1 is deliberately one returned line and one replacement variant. No store
/// credit, no wallet, no split payment, no multi-line.
class ExchangeService {
  static const _uuid = Uuid();

  /// Document prefix — `EXC-20260824-001`.
  static const String exchangePrefix = 'EXC';

  /// Stock-movement reason for both exchange legs, so they are identifiable in
  /// Stock History.
  static const String stockReason = 'Exchange';

  /// Settlement leg representing value carried across by the returned goods.
  ///
  /// **This is an accounting leg, not money.** No cash, card or UPI moved for
  /// it — the customer paid with the item they handed back. It exists so each
  /// document's legs sum to its own `totalAmount`, and it is deliberately
  /// SUPPRESSED from payment-method totals: a day's Cash/UPI/Card buckets must
  /// show real monetary movement only, or an exchange would inflate them by the
  /// whole value of the goods swapped.
  ///
  /// Suppressed in `RetailPaymentModeSummary.summarize` and ignored by
  /// `CashDrawerLedger`.
  static const String exchangeCreditMethod = 'exchange_credit';

  /// True when [method] is the internal exchange-credit leg rather than money.
  static bool isExchangeCredit(String? method) =>
      (method ?? '').trim().toLowerCase() == exchangeCreditMethod;

  final ReturnService _returnService;
  final DocumentNumberService _numbers;

  ExchangeService({
    ReturnService? returnService,
    DocumentNumberService? numberService,
  })  : _returnService = returnService ?? ReturnService(),
        _numbers = numberService ?? DocumentNumberService();

  /// Guards against a double-tap producing two exchange groups.
  bool _inFlight = false;

  /// Admin and Manager may process an exchange; a Cashier may not.
  ///
  /// Note the deliberate asymmetry: a Cashier CAN process a plain return
  /// (`sale_return_screen`), but not an exchange — an exchange writes a new
  /// sale at a possibly different price, so it carries the same manager-level
  /// gate as price override and line discount.
  ///
  /// Callers must HIDE the action when this is false rather than showing it and
  /// refusing.
  bool get canExchange => RestaurantSession.canAccess('billingExchange');

  // ==========================================================================
  // Validation + pricing — NOTHING is written here
  // ==========================================================================

  /// Price an exchange without committing it.
  ///
  /// Returns a [ExchangeQuote] or throws with a reason. Every rule that could
  /// reject the exchange is checked here, so [processExchange] can commit
  /// knowing the work is sound.
  Future<ExchangeQuote> quote({
    required String originalSaleId,
    required String returnedVariantId,
    required double returnQty,
    required String replacementVariantId,
    double replacementQty = 1,
  }) async {
    // ---- the sale being exchanged against ---------------------------------
    final originalSale = await saleStore.getSaleById(originalSaleId);
    if (originalSale == null) {
      throw Exception('Original sale not found');
    }
    if (originalSale.isReturn ?? false) {
      throw Exception('A return document cannot be exchanged');
    }

    final soldLines = await saleItemRepository.getItemsBySaleId(originalSaleId);
    if (soldLines.isEmpty) {
      throw Exception('No items found in the original sale');
    }

    final returnedLine = soldLines
        .where((l) => l.varianteId == returnedVariantId)
        .cast<SaleItemModel?>()
        .firstWhere((l) => l != null, orElse: () => null);
    if (returnedLine == null) {
      throw Exception('That item is not part of this sale');
    }

    if (returnQty <= 0) {
      throw Exception('Select at least one unit to exchange');
    }

    // ---- the repeat-return guard, shared with the plain return flow -------
    final remaining = await _returnService.remainingReturnable(originalSaleId);
    final left = remaining[returnedVariantId] ?? 0;
    if (returnQty > left) {
      throw Exception(
        left == 0
            ? 'That item has already been fully returned'
            : 'Only $left of that item can still be exchanged',
      );
    }

    // ---- the replacement --------------------------------------------------
    if (replacementQty <= 0) {
      throw Exception('Replacement quantity must be at least one');
    }

    final replacement = await productStore.getVariantById(replacementVariantId);
    if (replacement == null) {
      throw Exception('Replacement item not found');
    }
    if (replacement.status.toLowerCase().trim() != 'active') {
      throw Exception('That replacement is not active and cannot be sold');
    }
    // Same stock rule as the cart: a bundle's availability is what its
    // components support (its own figure means nothing), a component-less
    // bundle can't be handed over, and allow-when-out lifts the limit.
    final replacementProduct =
        productStore.getProductById(replacement.productId);
    if (replacementProduct != null &&
        RetailInventoryService.isUnconfiguredBundle(
            replacementProduct, replacement)) {
      throw Exception('That bundle has no components set up');
    }
    final available = replacementProduct == null
        ? replacement.stockQty
        : RetailInventoryService.calculateAvailableToSell(
            replacementProduct, replacement);
    final sellsWhenOut = replacementProduct?.sellsWhenOutOfStock ?? false;
    if (!sellsWhenOut && available < replacementQty) {
      throw Exception(
        available <= 0
            ? 'The replacement is out of stock'
            : 'Only ${formatQty(available)} of the replacement in stock',
      );
    }
    if (replacement.effectivePrice <= 0) {
      throw Exception('The replacement has no selling price set');
    }

    // ---- price both halves ------------------------------------------------
    // The returned side is PRORATED from what was charged; the replacement is
    // priced by the live engine at its own rate. They are separate documents
    // and each keeps its own correct tax.
    final returnFigures = RetailReturnMath.compute(
      sale: originalSale,
      soldLines: soldLines,
      returnQtyByVariantId: {returnedVariantId: returnQty},
    );
    if (returnFigures.isEmpty || returnFigures.totalAmount <= 0) {
      throw Exception('Nothing to return for the selected item');
    }

    final replacementBill = await _priceReplacement(
      variant: replacement,
      qty: replacementQty,
    );
    if (replacementBill.grandTotal <= 0) {
      throw Exception('The replacement priced to zero');
    }

    return ExchangeQuote(
      returnValue: returnFigures.totalAmount,
      replacementValue: replacementBill.grandTotal,
      returnFigures: returnFigures,
      replacementBill: replacementBill,
      originalSale: originalSale,
      returnedLine: returnedLine,
      returnQty: returnQty,
      replacementVariant: replacement,
      replacementQty: replacementQty,
    );
  }

  /// Price the replacement through the ordinary retail engine — one cart line,
  /// no discounts, no loyalty. Reusing [RetailBillingService] is what keeps a
  /// second tax engine from existing.
  Future<RetailBill> _priceReplacement({
    required VarianteModel variant,
    required double qty,
  }) async {
    final product = productStore.getProductById(variant.productId);
    final gstRate = await gstService.getEffectiveGstRate(
      variant: variant,
      product: product,
    );
    final isTaxInclusive = await RetailBillingService.loadTaxInclusive();

    final line = CartItemModel.create(
      cartItemId: _uuid.v4(),
      variantId: variant.varianteId,
      productId: variant.productId,
      productName: product?.productName ?? 'Item',
      price: variant.effectivePrice,
      qty: qty,
      barcode: variant.barcode,
      gstRate: gstRate,
      hsnCode: variant.hsnCode,
      taxInclusive: isTaxInclusive,
    );

    return RetailBillingService.compute(
      items: [line],
      isTaxInclusive: isTaxInclusive,
    );
  }

  // ==========================================================================
  // Commit
  // ==========================================================================

  /// Commit an exchange.
  ///
  /// **Write order matters and is deliberate.** Everything is validated first,
  /// so a failure before the first write leaves no return, no sale, no stock
  /// movement and no payment. After that the customer's side is completed
  /// before the shop's: if the replacement fails to write, the shop still holds
  /// the goods and the customer holds a valid credit note — the same state an
  /// ordinary return would leave, and recoverable. The reverse order would hand
  /// over new goods with nothing backing them.
  ///
  /// Hive has no transactions, so this ordering IS the safety mechanism.
  Future<ExchangeResult> processExchange({
    required String originalSaleId,
    required String returnedVariantId,
    required double returnQty,
    required String replacementVariantId,
    double replacementQty = 1,
    required String paymentMethod,
    String? note,
  }) async {
    if (_inFlight) {
      return ExchangeResult.failure('An exchange is already being processed');
    }
    if (!canExchange) {
      return ExchangeResult.failure(
          'Only an admin or manager can process an exchange');
    }

    _inFlight = true;
    try {
      // ---- 0. validate + price; still zero writes -------------------------
      final ExchangeQuote q;
      try {
        q = await quote(
          originalSaleId: originalSaleId,
          returnedVariantId: returnedVariantId,
          returnQty: returnQty,
          replacementVariantId: replacementVariantId,
          replacementQty: replacementQty,
        );
      } catch (e) {
        return ExchangeResult.failure(_message(e));
      }

      // ---- 1. the link both halves will carry -----------------------------
      final groupId = await _numbers.next(exchangePrefix);

      // ---- 2. the RETURN half ---------------------------------------------
      // Built through ReturnService so the credit settlement, loyalty reversal
      // and refund audit are identical to an ordinary return — there is no
      // second implementation of any of it.
      final String returnSaleId;
      try {
        returnSaleId = await _returnService.processPartialReturn(
          originalSaleId: originalSaleId,
          itemsToReturn: {returnedVariantId: returnQty},
          refundMethod: paymentMethod,
          // Only the difference ever leaves the till on an exchange; the rest
          // of the return value crosses to the replacement as goods.
          cashRefundOverride: q.refundedInMoney,
          // ReturnService logs the restock itself (per component for a
          // bundle); tagging it here makes both legs identifiable in Stock
          // History without a second, duplicate row.
          stockReason: stockReason,
          stockNotePrefix: groupId,
        );
      } catch (e) {
        return ExchangeResult.failure(_message(e));
      }

      await _stamp(returnSaleId, groupId, q.returnLegs(paymentMethod));

      // ---- 4. the REPLACEMENT half ----------------------------------------
      // An ordinary sale, so it takes the next number in the ordinary invoice
      // series. Its key stays a UUID like every other sale's.
      final replacementSaleId = _uuid.v4();
      final replacementNumber = await saleStore.nextInvoiceNumber();
      try {
        await _writeReplacement(
          saleId: replacementSaleId,
          invoiceNumber: replacementNumber,
          groupId: groupId,
          quote: q,
          paymentMethod: paymentMethod,
        );
      } catch (e) {
        // The return stands on its own and is correct. Surface the failure
        // rather than trying to unwind it — `findIncomplete` will show this
        // pair as needing attention.
        debugPrint('Exchange replacement failed for $groupId: $e');
        return ExchangeResult.failure(
          'The return was recorded but the replacement could not be created. '
          'Exchange $groupId is incomplete.',
        );
      }

      // ---- 5. move and audit the replacement stock ------------------------
      // A bundle replacement deducts its COMPONENTS — it used to take its
      // own meaningless figure, so the goods handed over never left stock.
      await RetailInventoryService.deductStock(
        productId: q.replacementVariant.productId,
        variantId: q.replacementVariant.varianteId,
        qty: replacementQty,
        reason: stockReason,
        note: '$groupId · $replacementSaleId',
      );

      return ExchangeResult.ok(
        exchangeGroupId: groupId,
        returnSaleId: returnSaleId,
        replacementSaleId: replacementSaleId,
        difference: q.difference,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Stamp the freshly-written return with its exchange group and its real
  /// settlement.
  ///
  /// `ReturnService` writes an ordinary return, which records the whole refund
  /// against the chosen method. On an exchange that is not what happened: most
  /// of the value went across to the replacement as goods, and only the
  /// difference (if any) was money. Rewriting the legs here keeps
  /// `ReturnService` untouched for plain returns.
  Future<void> _stamp(
    String saleId,
    String groupId,
    List<Map<String, dynamic>> legs,
  ) async {
    final sale = await saleStore.getSaleById(saleId);
    if (sale == null) return;

    // The document's own primary method: the money leg if there is one,
    // otherwise the credit leg. Never a method that saw no money.
    final moneyLeg = legs
        .where((l) => !isExchangeCredit(l['method'] as String?))
        .cast<Map<String, dynamic>?>()
        .firstWhere((l) => l != null, orElse: () => null);

    await saleStore.updateSale(
      sale.copyWith(
        exchangeGroupId: groupId,
        paymentType:
            (moneyLeg?['method'] as String?) ?? exchangeCreditMethod,
        paymentListJson: jsonEncode(legs),
        isSplitPayment: legs.length > 1,
      ),
    );
  }

  /// The replacement is an ORDINARY sale — same factory and same line builder
  /// checkout uses, so it lands in every report exactly like a walk-in sale.
  Future<void> _writeReplacement({
    required String saleId,
    required String invoiceNumber,
    required String groupId,
    required ExchangeQuote quote,
    required String paymentMethod,
  }) async {
    final bill = quote.replacementBill;
    final line = bill.lines.first;
    final variant = quote.replacementVariant;

    final sale = SaleModel.createWithSplitPayment(
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      customerId: quote.originalSale.customerId,
      totalItems: bill.totalItems,
      subtotal: bill.itemTotal,
      discountAmount: bill.discountAmount,
      totalTaxableAmount: bill.taxableAmount,
      totalGstAmount: bill.totalGst,
      grandTotal: bill.grandTotal,
      // Settled partly (or wholly) by the returned goods. Recording the
      // refund method here as though the customer tendered the full
      // replacement value was the bug: an 800 replacement against a 1000
      // return showed as "UPI 800" when 200 went the OTHER way.
      paymentList: quote.replacementLegs(paymentMethod),
      totalPaid: bill.grandTotal,
      changeReturn: 0,
      roundOff: bill.roundOff,
      isTaxInclusive: bill.isTaxInclusive,
      taxEnabled: TaxFeature.enabled,
      storeGstNumber: await StoreSettingsService().gstNumberSnapshot(),
      lineDiscountTotal: bill.lineDiscountTotal,
      exchangeGroupId: groupId,
      // Both legs of an exchange belong to the shift that processed it —
      // return_service stamps the return leg with the same value.
      shiftId: RestaurantSession.currentShiftId,
    );

    final item = SaleItemModel.fromCalculated(
      saleId: saleId,
      varianteId: variant.varianteId,
      productId: variant.productId,
      productName: line.item.productName,
      attributes: line.item.attributes,
      price: line.item.price,
      qty: line.item.qty,
      discountAmount: line.discountAmount,
      gstRate: line.gstRatePercent,
      taxableAmount: line.taxableAmount,
      gstAmount: line.gstAmount,
      total: line.total,
      barcode: line.item.barcode,
      hsnCode: line.item.hsnCode,
      // Cost frozen at sale time, exactly as checkout does — profit is a
      // historical fact.
      costPrice: variant.costPrice,
    );

    await saleStore.addSaleWithItems(sale, [item]);
  }


  // ==========================================================================
  // Reconciliation
  // ==========================================================================

  /// Both halves of an exchange, by its group id.
  Future<List<SaleModel>> salesInGroup(String exchangeGroupId) async {
    final all = await saleStore.getAllSales();
    return all.where((s) => s.exchangeGroupId == exchangeGroupId).toList();
  }

  /// The counterpart document of one half of an exchange.
  Future<SaleModel?> counterpartOf(SaleModel sale) async {
    final groupId = sale.exchangeGroupId;
    if (groupId == null) return null;
    final group = await salesInGroup(groupId);
    for (final other in group) {
      if (other.saleId != sale.saleId) return other;
    }
    return null;
  }

  /// Exchange groups whose replacement never landed.
  ///
  /// V1 DETECTS and displays these rather than auto-repairing: a repair that
  /// guesses wrong about money is worse than a visible flag.
  Future<List<SaleModel>> findIncomplete() async {
    final all = await saleStore.getAllSales();
    final byGroup = <String, List<SaleModel>>{};
    for (final sale in all) {
      final groupId = sale.exchangeGroupId;
      if (groupId == null) continue;
      byGroup.putIfAbsent(groupId, () => []).add(sale);
    }

    final orphans = <SaleModel>[];
    for (final group in byGroup.values) {
      final hasReplacement = group.any((s) => !(s.isReturn ?? false));
      if (!hasReplacement) {
        orphans.addAll(group.where((s) => s.isReturn ?? false));
      }
    }
    return orphans;
  }

  /// Exceptions carry their reason in `toString()` as "Exception: message";
  /// the prefix is noise in a snackbar.
  static String _message(Object e) =>
      e.toString().replaceFirst('Exception: ', '');
}
