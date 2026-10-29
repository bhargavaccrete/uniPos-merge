import 'dart:convert';

import '../../../core/di/service_locator.dart';
import '../../../core/plan/entitlement_keys.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../../../util/restaurant/staticswitch.dart';
import 'day_management_service.dart';
import 'inventory_service.dart';
import 'line_stock.dart';

/// One refund of a past order: how much, when, and in which session.
class RefundEvent {
  const RefundEvent({required this.amount, required this.at, this.sessionId});

  final double amount;
  final DateTime at;

  /// Null when no session was open, and for the synthetic entry of an order
  /// refunded before refund history was recorded.
  final String? sessionId;

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'at': at.toIso8601String(),
        'sessionId': sessionId,
      };

  factory RefundEvent.fromMap(Map<String, dynamic> map) => RefundEvent(
        amount: (map['amount'] as num).toDouble(),
        at: DateTime.parse(map['at'] as String),
        sessionId: map['sessionId'] as String?,
      );

  static String encodeAll(List<RefundEvent> events) =>
      jsonEncode([for (final e in events) e.toMap()]);
}

/// Result class for partial refund operations
class PartialRefundResult {
  final Map<CartItem, int> itemsToRefund;
  final String reason;
  final double totalRefundAmount;
  final Map<CartItem, int> itemsToRestock;

  PartialRefundResult({
    required this.itemsToRefund,
    required this.reason,
    required this.totalRefundAmount,
    required this.itemsToRestock,
  });
}

/// Service for handling refund business logic
/// Separates refund processing from UI layer
class RefundService {
  /// Shown when a refund is attempted with no open session (SB-2b-M8).
  static const String refundNeedsOpenSessionMessage =
      'Start the day before issuing a refund.';

  /// Process a partial or full refund for an order
  /// Returns the updated order after refund processing
  static Future<PastOrderModel> processRefund({
    required PastOrderModel order,
    required PartialRefundResult refundResult,
  }) async {
    // Plan gate — refunds are the Returns capability (billing.returns).
    if (!PlanEnforce.allows(EntKeys.billingReturns)) {
      throw Exception('Refunds aren’t available on your current plan.');
    }
    // SB-2b-M8: a refund needs an open session, as a sale does. Made after
    // End of Day and before the next Start Day it would belong to no session
    // and no EOD would ever count the cash it pays out. Read-only and before
    // any write, so a refused refund changes nothing.
    if (!await DayManagementService.isSessionOpen()) {
      throw Exception(refundNeedsOpenSessionMessage);
    }
    try {
      // BLK-06: checked before any write. A refund never pays back more than
      // is still refundable (what was paid minus earlier refunds), and never
      // more units than are left — previously extra units were dropped but
      // their money was still recorded.
      final remainingAmount = getRemainingRefundableAmount(order);
      var refundAmount = refundResult.totalRefundAmount;
      if (refundAmount < 0) {
        throw Exception('A refund amount cannot be negative.');
      }
      if (refundAmount > remainingAmount + _moneyTolerance) {
        throw Exception(
            'Refund of ${refundAmount.toStringAsFixed(2)} is more than the '
            '${remainingAmount.toStringAsFixed(2)} still refundable on this order.');
      }
      if (refundAmount > remainingAmount) refundAmount = remainingAmount;

      final unitsLeft = <String, int>{};
      for (final item in order.items) {
        final left = item.quantity - (item.refundedQuantity ?? 0);
        if (left > 0) {
          final key = _itemGroupKey(item);
          unitsLeft[key] = (unitsLeft[key] ?? 0) + left;
        }
      }
      final unitsAsked = <String, int>{};
      refundResult.itemsToRefund.forEach((item, qty) {
        if (qty < 0) {
          throw Exception('Refund quantity cannot be negative.');
        }
        final key = _itemGroupKey(item);
        unitsAsked[key] = (unitsAsked[key] ?? 0) + qty;
      });
      unitsAsked.forEach((key, qty) {
        if (qty > (unitsLeft[key] ?? 0)) {
          throw Exception(
              'Refund quantity is more than what is left to refund on this order.');
        }
      });

      // Update refunded quantities for each item.
      // Items may be grouped in the refund dialog (same product across KOTs),
      // so distribute refund quantity across all matching original items.
      final List<CartItem> updatedItems = List<CartItem>.from(order.items ?? []);

      refundResult.itemsToRefund.forEach((itemToRefund, quantityToRefund) {
        final groupKey = _itemGroupKey(itemToRefund);
        int remaining = quantityToRefund;

        for (int i = 0; i < updatedItems.length && remaining > 0; i++) {
          final item = updatedItems[i];
          if (_itemGroupKey(item) == groupKey) {
            final available = (item.quantity ?? 0) - (item.refundedQuantity ?? 0);
            if (available > 0) {
              final toRefund = available < remaining ? available : remaining;
              updatedItems[i] = item.copyWith(
                refundedQuantity: (item.refundedQuantity ?? 0) + toRefund,
              );
              remaining -= toRefund;
            }
          }
        }
        if (remaining > 0) {
        }
      });

      // Restock per line, never past what a line can still restore
      // (quantity − restockedQuantity): a line its void already put back
      // (KotLayout.voidPlan) restores nothing again — F2. Each line records
      // the return, so a second refund is capped too.
      final restores = <({CartItem line, int qty})>[];
      refundResult.itemsToRestock.forEach((itemToRestock, quantityToRestock) {
        final groupKey = _itemGroupKey(itemToRestock);
        int remaining = quantityToRestock;
        for (int i = 0; i < updatedItems.length && remaining > 0; i++) {
          final item = updatedItems[i];
          if (_itemGroupKey(item) != groupKey) continue;
          final available = item.quantity - (item.restockedQuantity ?? 0);
          if (available <= 0) continue;
          final take = available < remaining ? available : remaining;
          restores.add((line: item, qty: take));
          updatedItems[i] = LineStock.restocked(item, take);
          remaining -= take;
        }
      });

      // Determine new order status
      bool allItemsRefunded = updatedItems.every((item) {
        final originalQty = item.quantity ?? 0;
        final refundedQty = item.refundedQuantity ?? 0;
        return refundedQty >= originalQty;
      });

      final newStatus = order.orderStatus == 'VOIDED'
          ? 'VOIDED'
          : (allItemsRefunded ? 'FULLY_REFUNDED' : 'PARTIALLY_REFUNDED');

      final _staffLabel = RestaurantSession.isAdmin
          ? 'Admin'
          : '${RestaurantSession.staffName ?? RestaurantSession.effectiveRole} (${RestaurantSession.effectiveRole})';

      // SB-2b: this refund as its own history entry — the validated amount,
      // the same instant as `refundedAt`, and the session it happened in — so
      // EOD counts it in that session only. Saved in the same order write as
      // the running total, so the two can never disagree.
      final now = DateTime.now();
      final sessionId = await DayManagementService.getCurrentSessionId();
      final events = [
        ...refundEventsOf(order),
        RefundEvent(amount: refundAmount, at: now, sessionId: sessionId),
      ];

      // Create updated order
      final updatedOrder = order.copyWith(
        items: updatedItems,
        orderStatus: newStatus,
        refundAmount: (order.refundAmount ?? 0) + refundAmount,
        refundReason: (order.refundReason ?? '') +
            '\n[${now.toLocal().toString().substring(0, 16)}] $_staffLabel: ${refundResult.reason}',
        refundedAt: now,
        refundedBy: _staffLabel,
        refundEventsJson: RefundEvent.encodeAll(events),
      );

      await pastOrderStore.updateOrder(updatedOrder);

      // Restore stock for items marked for restocking — per line, from each
      // line's stamp (what its sale actually took).
      await InventoryService.restoreLines(restores);

      // Restore loyalty points proportional to refund amount
      final cid = order.customerId;
      final pointsUsed = order.loyaltyPointsUsed ?? 0;
      if (cid != null && pointsUsed > 0) {
        final refundRatio = order.totalPrice > 0
            ? refundAmount / order.totalPrice
            : 0.0;
        final pointsToRestore = (pointsUsed * refundRatio).round();
        if (pointsToRestore > 0) {
          await customerStore.addLoyaltyPoints(cid, pointsToRestore);
        }
      }

      return updatedOrder;
    } catch (e, stackTrace) {
      rethrow; // Rethrow so caller can handle and show error to user
    }
  }

  /// Validate if an order is eligible for refund
  /// Returns error message if not eligible, null if eligible
  static String? validateRefundEligibility(PastOrderModel order) {
    // Check if order time exists
    if (order.orderAt == null) {
      return 'Order time is missing. Cannot process refund.';
    }

    // Check if within refund window (configurable, 0 = no limit)
    final window = AppSettings.refundWindowMinutes;
    if (window > 0) {
      final minutePassed = DateTime.now().difference(order.orderAt!).inMinutes;
      if (minutePassed > window) {
        final label = window < 60
            ? '$window minutes'
            : window == 60
                ? '1 hour'
                : '${(window / 60).toStringAsFixed(window % 60 == 0 ? 0 : 1)} hours';
        return 'Refund window ($label) has passed.';
      }
    }

    // Check if there are refundable items
    final refundableItems = order.items?.where((item) {
      final originalQty = item.quantity ?? 0;
      final alreadyRefunded = item.refundedQuantity ?? 0;
      return originalQty > alreadyRefunded;
    }).toList() ?? [];

    if (refundableItems.isEmpty) {
      return 'All items in this order have already been refunded.';
    }

    return null; // Eligible for refund
  }

  /// Get list of items that can be refunded from an order.
  /// Groups identical items (same product, variant, extras, choices) that were
  /// split across different KOTs into a single entry with combined quantities.
  static List<CartItem> getRefundableItems(PastOrderModel order) {
    final items = order.items ?? [];
    if (items.isEmpty) return [];

    // Group identical items by product+variant+extras+choices
    final Map<String, CartItem> grouped = {};
    for (final item in items) {
      final key = _itemGroupKey(item);
      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;
        grouped[key] = existing.copyWith(
          quantity: existing.quantity + (item.quantity ?? 0),
          refundedQuantity: (existing.refundedQuantity ?? 0) + (item.refundedQuantity ?? 0),
          // So the dialog knows how much a void already put back.
          restockedQuantity: (existing.restockedQuantity ?? 0) +
              (item.restockedQuantity ?? 0),
        );
      } else {
        grouped[key] = item.copyWith(
          quantity: item.quantity ?? 0,
          refundedQuantity: item.refundedQuantity ?? 0,
        );
      }
    }

    // Filter to only items with remaining refundable quantity
    return grouped.values.where((item) {
      return item.quantity > (item.refundedQuantity ?? 0);
    }).toList();
  }

  /// Unique key for grouping identical items (same as print helper logic)
  static String _itemGroupKey(CartItem item) {
    final extrasKey = item.extras?.map((e) => '${e['name']}_${e['price']}_${e['quantity']}').join('|') ?? '';
    final choicesKey = item.choiceNames?.join('|') ?? '';
    return '${item.productId}_${item.variantName ?? ''}_${extrasKey}_${choicesKey}';
  }

  /// Calculate remaining refundable amount: what the customer actually paid
  /// (`totalPrice` is the net payable — after loyalty points, with or without
  /// tax) minus everything already refunded.
  static double getRemainingRefundableAmount(PastOrderModel order) {
    final originalTotal = order.totalPrice ?? 0.0;
    final alreadyRefunded = order.refundAmount ?? 0.0;
    return originalTotal - alreadyRefunded;
  }

  /// The order's refunds, one entry each.
  ///
  /// Orders refunded before refund history was recorded have only the running
  /// `refundAmount` and the time of their LAST refund (`refundedAt`), so they
  /// are read as a single refund of the whole amount at that time with no
  /// session — exactly what EOD did before. How such an order's earlier
  /// refunds were split across sessions was never stored and cannot be
  /// reconstructed: its old multi-session over-count stays as it was.
  static List<RefundEvent> refundEventsOf(PastOrderModel order) {
    final json = order.refundEventsJson;
    if (json != null && json.isNotEmpty) {
      return [
        for (final e in jsonDecode(json) as List)
          RefundEvent.fromMap(Map<String, dynamic>.from(e as Map)),
      ];
    }
    final amount = order.refundAmount ?? 0.0;
    final at = order.refundedAt;
    if (amount > 0 && at != null) {
      return [RefundEvent(amount: amount, at: at)];
    }
    return const [];
  }

  /// Sub-paisa rounding allowed when comparing a refund with what is left.
  static const double _moneyTolerance = 0.01;

  /// What a partial refund pays back for goods worth [selectedValue], when all
  /// the order's lines are worth [allItemsValue] by the same measure.
  ///
  /// The order may have been paid less than its lines are worth (loyalty
  /// points, tax switched off, rounding down); the value is then scaled down
  /// to what was paid — never up, so ordinary orders refund exactly as before
  /// and a service charge still comes back with the last items. Never more
  /// than [remaining].
  static double partialRefundAmount({
    required double selectedValue,
    required double allItemsValue,
    required double paidTotal,
    required double remaining,
  }) {
    if (selectedValue <= 0 || remaining <= 0) return 0;
    final scale = (allItemsValue > paidTotal && allItemsValue > 0)
        ? paidTotal / allItemsValue
        : 1.0;
    final amount = selectedValue * scale;
    return amount > remaining ? remaining : amount;
  }

  /// Process void order (mark as voided)
  static Future<PastOrderModel> voidOrder({
    required PastOrderModel order,
    required String reason,
  }) async {
    try {
      // Plan gate — voiding a completed order (billing.invoice.void).
      if (!PlanEnforce.allows(EntKeys.billingInvoiceVoid)) {
        throw Exception('Voiding orders isn’t available on your current plan.');
      }

      final _staffLabel = RestaurantSession.isAdmin
          ? 'Admin'
          : '${RestaurantSession.staffName ?? RestaurantSession.effectiveRole} (${RestaurantSession.effectiveRole})';

      final voidedOrder = order.copyWith(
        orderStatus: 'VOIDED',
        refundReason: reason.isNotEmpty ? 'VOIDED: $reason' : 'VOIDED: No reason provided',
        refundedAt: DateTime.now(),
        voidedBy: _staffLabel,
      );

      await pastOrderStore.updateOrder(voidedOrder);

      // Past orders (already served/paid) — stock was legitimately consumed, no restore.

      return voidedOrder;
    } catch (e, stackTrace) {
      rethrow;
    }
  }
}
