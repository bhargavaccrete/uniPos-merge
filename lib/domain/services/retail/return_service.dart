import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:flutter/foundation.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/return_math.dart';
import 'package:billberrylite/util/common/loyalty_points.dart';
import 'package:uuid/uuid.dart';

/// What a completed return actually did with the money.
class ReturnOutcome {
  final String returnSaleId;

  /// Value of the goods that came back.
  final double returnValue;

  /// Offset against the original invoice's outstanding due. Never leaves the
  /// till.
  final double appliedToDue;

  /// Actually handed back through [refundMethod].
  final double refunded;

  final String refundMethod;

  const ReturnOutcome({
    required this.returnSaleId,
    required this.returnValue,
    required this.appliedToDue,
    required this.refunded,
    required this.refundMethod,
  });
}

/// Sale returns and refunds: the return document, stock restoration, the
/// customer's credit position, and the refund audit trail.
///
/// **MONEY RULE — a refund returns what was CHARGED.** Every figure is prorated
/// from the original sale's stored values by [RetailReturnMath]; nothing is
/// recomputed through `RetailBillingService`. Recomputing would refund a
/// different amount than was taken if a tax rate, the tax mode or the round-off
/// setting changed after the sale — and, in tax-inclusive mode, would add GST on
/// top of a price that already contained it.
///
/// **QUANTITY RULE — you can only give back what you still hold.** How much of a
/// line has already been returned is DERIVED from the return documents
/// ([RetailReturnMath.remainingByVariant]), not stored on the sale line. There
/// is no counter to keep in sync, and the guard cannot be bypassed by reaching
/// the service from a different screen.
class ReturnService {
  static const _uuid = Uuid();

  /// Cash refund method — the one that physically empties the drawer.
  /// Everything else (card, UPI, anything added later) settles outside the till.
  static const String cashRefundMethod = 'cash';

  /// Movement type used ONLY for refund audit rows.
  ///
  /// Deliberately not 'out': every existing consumer filters movements by exact
  /// type equality (`m.type == 'in' / 'out' / 'opening' / 'adjustment'`), so a
  /// distinct type is invisible to all of them. The drawer and EOD derive their
  /// refund figure from the return SALES instead, and skip these rows — that is
  /// what stops a refund being counted twice.
  static const String refundMovementType = 'refund';

  /// `CreditPaymentModel.paymentMode` for a return offset against an unpaid
  /// invoice.
  ///
  /// Aliases the model's own constant — one canonical definition, so a report
  /// asking "is this a collection?" and the service writing the row can never
  /// drift apart. Use `CreditPaymentModel.isCollection` to filter.
  static const String returnAdjustmentMode =
      CreditPaymentModel.returnAdjustmentMode;

  // ==========================================================================
  // Queries
  // ==========================================================================

  /// Every return document raised against [originalSaleId].
  Future<List<SaleModel>> getReturnsForSale(String originalSaleId) async {
    final allSales = await saleStore.getAllSales();
    return allSales
        .where((sale) =>
            (sale.isReturn ?? false) && sale.originalSaleId == originalSaleId)
        .toList();
  }

  /// Every LINE across every return raised against [originalSaleId].
  Future<List<SaleItemModel>> _returnedLines(String originalSaleId) async {
    final returns = await getReturnsForSale(originalSaleId);
    final lines = <SaleItemModel>[];
    for (final r in returns) {
      lines.addAll(await saleItemRepository.getItemsBySaleId(r.saleId));
    }
    return lines;
  }

  /// Units of each variant that may still be returned, keyed by variant id.
  ///
  /// This is the single source of truth for the Return and Exchange screens —
  /// cap every quantity picker with it.
  Future<Map<String, double>> remainingReturnable(String originalSaleId) async {
    final soldLines = await saleItemRepository.getItemsBySaleId(originalSaleId);
    if (soldLines.isEmpty) return {};
    return RetailReturnMath.remainingByVariant(
      soldLines: soldLines,
      returnedLines: await _returnedLines(originalSaleId),
    );
  }

  /// Whether a sale can be returned at all: it exists, it is not itself a
  /// return, and something is still outstanding.
  Future<bool> canReturnSale(String saleId) async {
    final sale = await saleStore.getSaleById(saleId);
    if (sale == null) return false;
    if (sale.isReturn ?? false) return false;

    final remaining = await remainingReturnable(saleId);
    return remaining.values.any((qty) => qty > 0);
  }

  /// True once every sold unit has come back.
  ///
  /// Quantity-based, not amount-based. The old amount comparison could mark a
  /// sale "fully returned" off a single inflated partial refund.
  Future<bool> isFullyReturned(String originalSaleId) async {
    final remaining = await remainingReturnable(originalSaleId);
    if (remaining.isEmpty) return false;
    return remaining.values.every((qty) => qty <= 0);
  }

  /// True when some but not all of the sale has come back.
  Future<bool> isPartiallyReturned(String originalSaleId) async {
    final remaining = await remainingReturnable(originalSaleId);
    if (remaining.isEmpty) return false;
    final anyLeft = remaining.values.any((qty) => qty > 0);
    if (!anyLeft) return false;
    return (await _returnedLines(originalSaleId)).isNotEmpty;
  }

  Future<double> getTotalReturnedAmount(String originalSaleId) async {
    final returns = await getReturnsForSale(originalSaleId);
    return returns.fold<double>(0.0, (sum, r) => sum + r.totalAmount.abs());
  }

  /// Price a return WITHOUT writing anything — for the confirmation screen.
  ///
  /// The UI must display this rather than repeating the arithmetic, or the
  /// figure shown to the cashier can drift from the figure actually refunded.
  Future<ReturnFigures> quote({
    required String originalSaleId,
    required Map<String, double> itemsToReturn,
  }) async {
    final sale = await saleStore.getSaleById(originalSaleId);
    if (sale == null) return ReturnFigures.empty;
    final soldLines = await saleItemRepository.getItemsBySaleId(originalSaleId);
    if (soldLines.isEmpty) return ReturnFigures.empty;

    return RetailReturnMath.compute(
      sale: sale,
      soldLines: soldLines,
      returnQtyByVariantId: itemsToReturn,
    );
  }

  // ==========================================================================
  // Commands
  // ==========================================================================

  /// Return everything still outstanding on the sale.
  ///
  /// "Full" means every unit NOT already returned — so it stays correct after a
  /// partial return instead of refunding the original quantities a second time.
  Future<String> processFullReturn({
    required String originalSaleId,
    required String refundMethod,
    String? returnReason,
    String? returnNote,
  }) async {
    final remaining = await remainingReturnable(originalSaleId);
    final toReturn = <String, double>{
      for (final e in remaining.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (toReturn.isEmpty) {
      throw Exception('This sale has already been fully returned');
    }

    final outcome = await _process(
      originalSaleId: originalSaleId,
      itemsToReturn: toReturn,
      refundMethod: refundMethod,
      returnReason: returnReason,
      returnNote: returnNote,
    );
    return outcome.returnSaleId;
  }

  /// Return selected quantities: `variantId -> qty`.
  Future<String> processPartialReturn({
    required String originalSaleId,
    required Map<String, double> itemsToReturn,
    required String refundMethod,
    String? returnReason,
    String? returnNote,
    /// Cash that actually left the till, when the caller knows better than the
    /// return value does.
    ///
    /// Only an EXCHANGE needs this: most of its return value crosses to the
    /// replacement as goods, so the audit row must record the difference, not
    /// the whole refund. `null` — every plain return — behaves exactly as
    /// before.
    double? cashRefundOverride,
  }) async {
    final outcome = await _process(
      originalSaleId: originalSaleId,
      itemsToReturn: itemsToReturn,
      refundMethod: refundMethod,
      returnReason: returnReason,
      returnNote: returnNote,
      cashRefundOverride: cashRefundOverride,
    );
    return outcome.returnSaleId;
  }

  /// The one implementation behind both entry points.
  ///
  /// Validates completely BEFORE the first write, then writes in an order where
  /// a mid-way failure leaves a state that is safe and visible: the return
  /// document exists before any money position moves, so a failure can never
  /// hand goods back without a record of it.
  Future<ReturnOutcome> _process({
    required String originalSaleId,
    required Map<String, double> itemsToReturn,
    required String refundMethod,
    String? returnReason,
    String? returnNote,
    double? cashRefundOverride,
  }) async {
    // ---- validate: nothing is written until every check passes -------------
    final originalSale = await saleStore.getSaleById(originalSaleId);
    if (originalSale == null) {
      throw Exception('Original sale not found');
    }
    if (originalSale.isReturn ?? false) {
      throw Exception('Cannot return a return transaction');
    }

    final soldLines = await saleItemRepository.getItemsBySaleId(originalSaleId);
    if (soldLines.isEmpty) {
      throw Exception('No items found in original sale');
    }

    final requested = <String, double>{
      for (final e in itemsToReturn.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (requested.isEmpty) {
      throw Exception('Select at least one item to return');
    }

    // The repeat-refund guard. Checked against what is STILL returnable, not
    // against the originally sold quantity.
    final remaining = RetailReturnMath.remainingByVariant(
      soldLines: soldLines,
      returnedLines: await _returnedLines(originalSaleId),
    );
    for (final entry in requested.entries) {
      final left = remaining[entry.key];
      if (left == null) {
        throw Exception('Item ${entry.key} is not part of this sale');
      }
      if (entry.value > left) {
        throw Exception(
          left == 0
              ? 'That item has already been fully returned'
              : 'Only $left of that item can still be returned',
        );
      }
    }

    final figures = RetailReturnMath.compute(
      sale: originalSale,
      soldLines: soldLines,
      returnQtyByVariantId: requested,
    );
    if (figures.isEmpty || figures.totalAmount <= 0) {
      throw Exception('Nothing to refund for the selected items');
    }

    // ---- write -------------------------------------------------------------
    final returnSaleId = 'RTN_${_uuid.v4()}';

    // 1. The return document. Header amounts are NEGATED; lines stay positive.
    //    Built through the constructor rather than `SaleModel.create` so the
    //    tax mode and bill composition carry across — without them a reprinted
    //    credit note renders under whatever settings are current today.
    await saleStore.addSaleWithItems(
      _buildReturnHeader(
        returnSaleId: returnSaleId,
        original: originalSale,
        figures: figures,
        refundMethod: refundMethod,
        returnReason: returnReason,
        returnNote: returnNote,
      ),
      _buildReturnLines(returnSaleId: returnSaleId, figures: figures),
    );

    // 2. Put the goods back on the shelf.
    for (final line in figures.lines) {
      final variant = await productStore.getVariantById(line.source.varianteId);
      if (variant == null) continue;
      await productStore.updateVariantStock(
        line.source.varianteId,
        variant.stockQty + line.qty,
      );
    }

    // 3. Settle the customer's money position.
    final settlement = await _settle(
      original: originalSale,
      returnSaleId: returnSaleId,
      returnValue: figures.totalAmount,
    );

    // 4. Reverse the purchase stats and the points this sale granted.
    if (originalSale.customerId != null) {
      await customerStore.updateAfterReturn(
        originalSale.customerId!,
        -figures.totalAmount,
        -LoyaltyPoints.earnedFor(figures.totalAmount),
      );
    }

    // 5. Audit only — never blocks, see below.
    await _recordCashRefundMovement(
      refundMethod: refundMethod,
      amount: cashRefundOverride ?? settlement.refunded,
      returnSaleId: returnSaleId,
    );

    return ReturnOutcome(
      returnSaleId: returnSaleId,
      returnValue: figures.totalAmount,
      appliedToDue: settlement.appliedToDue,
      refunded: settlement.refunded,
      refundMethod: refundMethod,
    );
  }

  // ==========================================================================
  // Building the return document
  // ==========================================================================

  SaleModel _buildReturnHeader({
    required String returnSaleId,
    required SaleModel original,
    required ReturnFigures figures,
    required String refundMethod,
    required String? returnReason,
    required String? returnNote,
  }) {
    final now = DateTime.now().toIso8601String();
    final gst = figures.taxAmount;

    return SaleModel(
      saleId: returnSaleId,
      customerId: original.customerId,
      totalItems: figures.totalItems,
      // Negated, per the retail convention: headers net by themselves when
      // summed, lines stay positive for stock restoration.
      subtotal: -figures.subtotal,
      discountAmount: -figures.discountAmount,
      taxAmount: -gst,
      totalAmount: -figures.totalAmount,
      paymentType: refundMethod,
      date: now,
      createdAt: now,
      updatedAt: now,
      isReturn: true,
      originalSaleId: original.saleId,
      totalTaxableAmount: -figures.totalTaxableAmount,
      totalGstAmount: -gst,
      totalCgstAmount: -_half(gst),
      totalSgstAmount: -_half(gst),
      grandTotal: -figures.totalAmount,
      // Carried from the sale being reversed so a reprint renders under the
      // rules it was charged under, not today's settings.
      isTaxInclusive: original.isTaxInclusive,
      // A return settles immediately; there is no receivable on a credit note.
      paidAmount: -figures.totalAmount,
      dueAmount: 0,
      status: SaleStatus.paid,
      // The refund belongs to the shift that processed it, not the one that
      // made the original sale.
      shiftId: RestaurantSession.currentShiftId,
      // Why the goods came back. Stored on the return document, never on the
      // sale being reversed — the original's identity is immutable.
      returnReason: returnReason,
      returnNote: returnNote,
    );
  }

  List<SaleItemModel> _buildReturnLines({
    required String returnSaleId,
    required ReturnFigures figures,
  }) {
    return figures.lines.map((line) {
      final src = line.source;
      // `fromCalculated`, NOT `create`. `create` re-derives tax from price and
      // rate down a branch that is hard-wired tax-EXCLUSIVE for retail, which
      // stored an exclusive-shaped tax base on every inclusive-mode return.
      // These figures are already prorated from the original.
      return SaleItemModel.fromCalculated(
        saleId: returnSaleId,
        varianteId: src.varianteId,
        productId: src.productId,
        productName: src.productName ?? '',
        size: src.size,
        color: src.color,
        weight: src.weight,
        attributes: src.attributes,
        // The CHARGED price, override included — a refund returns what was
        // taken, never today's catalogue price.
        price: line.price,
        qty: line.qty,
        discountAmount: line.discountAmount,
        gstRate: src.gstRate ?? 0,
        taxableAmount: line.taxableAmount,
        gstAmount: line.gstAmount,
        total: line.total,
        barcode: src.barcode,
        hsnCode: src.hsnCode,
        // The original line's cost, never today's. A return can only cancel out
        // against the sale it reverses if both sides are costed identically.
        costPrice: src.costPrice,
        // Override and line-discount audit mirrored, so a credit note can print
        // the same explanation as the sale it reverses.
        originalPrice: src.originalPrice,
        overrideReason: src.overrideReason,
        overrideNote: src.overrideNote,
        lineDiscountType: src.lineDiscountType,
        lineDiscountValue: src.lineDiscountValue,
        lineDiscountAmount: line.lineDiscountAmount,
        lineDiscountReason: src.lineDiscountReason,
        lineDiscountNote: src.lineDiscountNote,
      );
    }).toList();
  }

  // ==========================================================================
  // Settlement
  // ==========================================================================

  /// Where the money goes: against the outstanding due first, and only the
  /// excess back through the refund method.
  ///
  /// Refunding cash on an invoice the customer never paid took money out of the
  /// till AND left the debt standing.
  ///
  /// **The original sale's payment identity is never rewritten** — `paymentType`
  /// and `paymentListJson` are untouched. Only the receivable moves, and
  /// `paidAmount` stays put: a credit note cancels a debt without any money
  /// arriving, so raising it would record a payment that never happened.
  Future<_Settlement> _settle({
    required SaleModel original,
    required String returnSaleId,
    required double returnValue,
  }) async {
    final due = original.dueAmount;
    final customerId = original.customerId;

    if (due <= 0 || customerId == null) {
      return _Settlement(appliedToDue: 0, refunded: returnValue);
    }

    final appliedToDue = returnValue < due ? returnValue : due;
    final refunded = _r2(returnValue - appliedToDue);

    final customer = await customerStore.getCustomerById(customerId);
    final balanceBefore = customer?.creditBalance ?? 0;

    await customerStore.reduceCredit(customerId, appliedToDue);

    // The audit row, same shape a credit collection writes — which is also what
    // makes the return visible in the customer ledger.
    await creditPaymentRepository.addPayment(
      CreditPaymentModel.create(
        paymentId: _uuid.v4(),
        customerId: customerId,
        saleId: original.saleId,
        amount: appliedToDue,
        paymentMode: returnAdjustmentMode,
        referenceId: returnSaleId,
        note: 'Return $returnSaleId',
        balanceBefore: balanceBefore,
        balanceAfter: _r2(balanceBefore - appliedToDue),
      ),
    );

    final newDue = _r2(due - appliedToDue);
    await saleStore.updateSale(
      original.copyWith(
        dueAmount: newDue,
        // paidAmount deliberately unchanged — nothing was paid.
        status: SaleModel.calculateStatus(original.paidAmount, newDue),
      ),
    );

    return _Settlement(appliedToDue: appliedToDue, refunded: refunded);
  }

  /// Audit-only trail for a cash refund. Never blocks the return: the money has
  /// already been handed back and the totals are derived from the return sale,
  /// so a failure here loses the audit row, not the figure.
  Future<void> _recordCashRefundMovement({
    required String refundMethod,
    required double amount,
    required String returnSaleId,
  }) async {
    if (refundMethod.toLowerCase().trim() != cashRefundMethod) return;
    if (amount <= 0) return;

    try {
      await cashMovementStore.addMovement(
        type: refundMovementType,
        amount: amount,
        reason: 'Sale Refund',
        note: 'Return $returnSaleId',
      );
    } catch (e) {
      debugPrint('Cash refund movement not recorded: $e');
    }
  }

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));
  static double _half(double v) => _r2(v / 2);
}

class _Settlement {
  final double appliedToDue;
  final double refunded;
  const _Settlement({required this.appliedToDue, required this.refunded});
}
