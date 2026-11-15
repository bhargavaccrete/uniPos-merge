import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/restaurant/db/cartmodel_308.dart';
import '../../data/models/restaurant/db/database/hive_order.dart';
import '../../data/models/restaurant/db/item_cancellation_model_134.dart';
import '../../data/models/restaurant/db/ordermodel_309.dart';
import '../../data/repositories/restaurant/item_cancellation_repository.dart';
import '../../domain/services/restaurant/cart_calculation_service.dart';
import '../../domain/services/restaurant/day_management_service.dart';
import '../../util/restaurant/staticswitch.dart';
import '../../domain/services/restaurant/inventory_service.dart';
import '../../domain/services/restaurant/kot_layout.dart';
import '../../domain/services/restaurant/order_line_cancel.dart';
import '../../domain/services/restaurant/saved_service_charge.dart';
import '../../domain/services/restaurant/stock_gate.dart';
import '../../domain/services/restaurant/stock_journal.dart';
import '../../domain/services/common/local_notification_service.dart';
import '../../data/models/common/notification_presenter.dart';
import '../../core/routes/routes_name.dart';
import '../../util/restaurant/restaurant_auth_helper.dart';
import '../websocket.dart';

/// Human label for an order's location used in captain notifications.
String _orderLocationLabel(String? tableNo) =>
    (tableNo != null && tableNo.isNotEmpty) ? 'Table $tableNo' : 'Take Away';

// ── Idempotency Cache ─────────────────────────────────────────────────────────
// Prevents duplicate orders if captain taps Send twice (network retry / double-tap).
// Cache entry: requestId → {response data, request fingerprint, expiresAt}
// TTL: 30 minutes. Entries older than that are eligible to be pruned.
// In memory only: a POS restart forgets every entry (P7, deferred).

final Map<String, _IdempotencyEntry> _orderRequestCache = {};

class _IdempotencyEntry {
  final Map<String, dynamic> response;

  /// [_requestFingerprint] of the request that produced [response].
  final String fingerprint;
  final DateTime expiresAt;
  _IdempotencyEntry(this.response, this.fingerprint)
      : expiresAt = DateTime.now().add(const Duration(minutes: 30));
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// The request minus its `requestId`, as JSON with every map's keys sorted:
/// a retry of the same request matches whatever its key order. Each line's
/// own `id` is left out — a label the client makes up, not what was ordered
/// (product, variant, options, price, quantity, table, target order all
/// count).
String _requestFingerprint(Map<String, dynamic> data) {
  Object? canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: canonical(v[k])};
    }
    if (v is List) return [for (final e in v) canonical(e)];
    return v;
  }

  final items = data['items'];
  return jsonEncode(canonical({
    ...data,
    if (items is List)
      'items': [
        for (final l in items) l is Map ? ({...l}..remove('id')) : l,
      ],
  }..remove('requestId')));
}

/// Answer to a `requestId` that already produced an order for a DIFFERENT
/// request. `requestIdReused` tells Captain this is not a plain refusal: the
/// earlier request was saved.
const String _requestIdReusedError =
    'This request ID was already used for a different order on the POS. '
    'Nothing new was saved. Check Active Orders.';

void _pruneExpiredRequests() {
  _orderRequestCache.removeWhere((_, entry) => entry.isExpired);
}

// ── Auth ──────────────────────────────────────────────────────────────────────

/// POST /captain/auth
/// Body: { "pin": "..." }
/// Returns: { "success": true, "staffId": "...", "name": "...", "role": "cashier|waiter" }
Future<Response> captainAuthHandler(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final pin = (data['pin'] as String?)?.trim() ?? '';

    if (pin.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': 'PIN is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    await staffStore.loadStaff();

    final match = staffStore.staff.where((s) =>
      s.isActive &&
      RestaurantAuthHelper.verifyPassword(pin, s.pinNo.trim()),
    ).firstOrNull;

    if (match == null) {
      return Response(
        401,
        body: jsonEncode({'success': false, 'error': 'Invalid PIN'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({
        'success': true,
        'staffId': match.id,
        'name': '${match.firstName} ${match.lastName}'.trim(),
        'username': match.userName,
        'role': match.isCashier,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// ── Menu ──────────────────────────────────────────────────────────────────────

/// GET /captain/menu
/// Returns all categories, items, variants, choices, extras
Future<Response> getCaptainMenuHandler(Request request) async {
  try {
    await Future.wait([
      categoryStore.loadCategories(),
      itemStore.loadItems(),
      variantStore.loadVariants(),
      choiceStore.loadChoices(),
      extraStore.loadExtras(),
    ]);

    final menu = {
      'categories': categoryStore.categories.map((c) => c.toMap()).toList(),
      'items': itemStore.items.map((i) => i.toMap()).toList(),
      'variants': variantStore.variants.map((v) => v.toMap()).toList(),
      'choices': choiceStore.choices.map((c) => c.toMap()).toList(),
      'extras': extraStore.extras.map((e) => e.toMap()).toList(),
    };

    return Response.ok(
      jsonEncode(menu),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// ── Tables ────────────────────────────────────────────────────────────────────

/// GET /captain/tables
/// Returns all tables with current status
Future<Response> getCaptainTablesHandler(Request request) async {
  try {
    await tableStore.loadTables();

    final tables = tableStore.tables.map((t) => t.toMap()).toList();

    return Response.ok(
      jsonEncode(tables),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// ── Send Order (smart: adds to existing table order or creates new) ───────────

/// POST /captain/send-order
/// Body: { "items": [...], "orderType": "Dine In|Take Away", "tableNo": "...", "totalPrice": 0.0 }
/// If table already has an active order → adds items as new KOT
/// If no active order → creates new order
///
/// S-04: refused with 409 when stock cannot cover the items (see
/// [InventoryService.stockShortfalls]) — before any order, KOT number or
/// stock write. The whole check-to-deduction runs inside the app-wide
/// [StockGate] (S-04A), so a Captain order and a POS order — or two Captain
/// orders — cannot both pass the check against the same stock.
///
/// SEC-20: the body is read BEFORE the gate — a slow or stalled client must
/// never hold every sale on the POS behind it.
///
/// WF-7: refused with 409 when the POS day has ended (End of Day overdue) or
/// was never started — the order would fall outside every End of Day.
///
/// INVX-4 (POS side): the reply is cached under `requestId` the moment the
/// order is saved, and the table status, KDS broadcast and notification run
/// after the gate as best effort — a failure there never turns a saved order
/// into an error, and a retry with the SAME `requestId` gets the saved reply
/// instead of a second order. A stock-write failure after the save answers
/// 500 with `orderSaved: true` and says not to resend. Captain keeps one
/// `requestId` and its exact request on disk until a clear answer (Batch
/// 3.2c). The same `requestId` with a DIFFERENT request answers 409 with
/// `requestIdReused: true`, nothing written. The cache is in memory for 30
/// minutes: a retry after a POS restart or later is not recognised (P7).
Future<Response> captainSendOrderHandler(Request request) async {
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  } catch (e) {
    return _jsonResponse(400, {'success': false, 'error': 'Invalid request body'});
  }
  final outcome = await StockGate.run(() => _captainSendOrder(data));
  await _runAfterCommit(outcome.afterCommit);
  return outcome.response;
}

/// What a gated Captain operation answers, plus the display-only follow-up
/// (table status, KDS broadcast, notification) to run once the gate is
/// released. The follow-up never changes the answer.
typedef _GatedReply = ({Response response, Future<void> Function()? afterCommit});

Future<void> _runAfterCommit(Future<void> Function()? afterCommit) async {
  if (afterCommit == null) return;
  try {
    await afterCommit();
  } catch (e) {
    debugPrint('Captain follow-up failed (the order is saved): $e');
  }
}

Response _jsonResponse(int status, Map<String, dynamic> body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

/// WF-7: the POS day refuses Captain orders, with the reason, or null.
Future<String?> _dayBlock() async {
  if (await DayManagementService.isEodStrictlyPending()) {
    return 'Day has ended. Complete End of Day on the POS.';
  }
  if (!await DayManagementService.isSessionOpen()) {
    return 'Start the day on the POS first.';
  }
  return null;
}

Future<_GatedReply> _captainSendOrder(Map<String, dynamic> data) async {
  try {
    final requestId = data['requestId'] as String?;
    final staffId   = data['staffId']   as String?;

    final fingerprint = _requestFingerprint(data);

    // ── Duplicate check ──────────────────────────────────────────────────────
    // Same ID + same request → the saved reply. Same ID + a different
    // request → 409, nothing written (never the old reply for new items).
    if (requestId != null && requestId.isNotEmpty) {
      _pruneExpiredRequests();
      final cached = _orderRequestCache[requestId];
      if (cached != null && !cached.isExpired) {
        if (cached.fingerprint != fingerprint) {
          return (
            response: _jsonResponse(409, {
              'success': false,
              'requestIdReused': true,
              'error': _requestIdReusedError,
            }),
            afterCommit: null,
          );
        }
        return (
          response: _jsonResponse(200, {...cached.response, 'duplicate': true}),
          afterCommit: null,
        );
      }
    }

    // WF-7: after the duplicate check — a retry of an order already taken
    // still gets its saved reply.
    final dayBlock = await _dayBlock();
    if (dayBlock != null) {
      return (
        response: _jsonResponse(409, {'success': false, 'error': dayBlock}),
        afterCommit: null,
      );
    }

    final tableNo = data['tableNo'] as String?;
    final orderType = data['orderType'] as String? ?? 'Take Away';
    // P2: the request's `totalPrice` is accepted but never trusted — the POS
    // prices every Captain order itself (below).

    final newItems = (data['items'] as List<dynamic>? ?? [])
        .map((i) => CartItem.fromMap(i as Map<String, dynamic>))
        .toList();

    if (newItems.isEmpty) {
      return (
        response: _jsonResponse(
            400, {'success': false, 'error': 'No items provided'}),
        afterCommit: null,
      );
    }

    // S-04: stock is checked HERE, against the POS's own item records, before
    // anything is written — no order, no KOT number, no deduction. Not cached
    // under the requestId, so a retry after restocking is checked afresh.
    final shortfalls = await InventoryService.stockShortfalls(newItems);
    if (shortfalls.isNotEmpty) {
      return (
        response: _jsonResponse(409, {
          'success': false,
          'error':
              'Insufficient stock: ${shortfalls.map((s) => s.message).join('; ')}',
          'shortfalls': [
            for (final s in shortfalls)
              {
                'itemId': s.itemId,
                'name': s.name,
                'available': s.available,
                'requested': s.requested,
                'unit': s.unit,
              },
          ],
        }),
        afterCommit: null,
      );
    }

    // Resolve the order to append to: an explicit orderId (from "Add Items")
    // wins — this is the only way to append to a Take Away order, which has no
    // table to match on. Otherwise fall back to the table's active order.
    final explicitOrderId = data['orderId'] as String?;
    OrderModel? existing;
    if (explicitOrderId != null && explicitOrderId.isNotEmpty) {
      existing = await HiveOrders.getOrderById(explicitOrderId);
    } else if (tableNo != null) {
      existing = await HiveOrders.getActiveOrderByTableId(tableNo);
    }

    // Stamped lines (LineStock): restores read what each sale took.
    final salePlan = await InventoryService.planSale(newItems);

    if (existing != null) {
      // Journal first: the deduction, persisted before the lines it covers.
      final entry = await _openSaleJournal(existing.id, salePlan);
      // Add items to the existing order as a new KOT.
      // A write that throws may still have landed: the entry stays and the
      // journal's recovery decides from the saved lines (next Settle or start).
      final updated = await HiveOrders.updateOrderWithNewItems(
        existingOrder: existing,
        newItems: salePlan.lines,
        // P1: totals and payment state re-derived in the same save.
        finalize: (combined) => _repricedAfterAddItems(existing!, combined),
      );
      await StockJournal.markOrderSaved(entry);
      // The POS's in-memory orders do not see HiveOrders writes.
      await _bestEffort(() async => orderStore.readSaved(updated.id));
      final addedResponse = {
        'success': true,
        'orderId': updated.id,
        'kotNumber': updated.kotNumbers.last,
        'addedToExisting': true,
      };
      // INVX-4: saved → cached NOW, before anything else can fail.
      _cacheReply(requestId, fingerprint, addedResponse);
      Future<void> announce() async {
        // Update table total (dine-in only — Take Away has no table).
        if (updated.tableNo != null && updated.tableNo!.isNotEmpty) {
          await _bestEffort(() => tableStore.updateTableStatus(
                updated.tableNo!,
                'Cooking',
                total: updated.totalPrice,
                orderId: updated.id,
                orderTime: updated.timeStamp,
              ));
        }
        await _bestEffort(() async => broadcastEvent({
              'type': 'NEW_ITEMS_ADDED',
              'orderId': updated.id,
              'kotNumber': updated.kotNumbers.last,
              'newItemCount': newItems.length,
              'tableNo': updated.tableNo,
            }));
        await _bestEffort(() => LocalNotificationService.instance.showNow(
              idSeed: 'kot_${updated.id}_${updated.kotNumbers.last}',
              title: 'New KOT #${updated.kotNumbers.last}',
              body: '${newItems.length} item${newItems.length == 1 ? '' : 's'} added · ${_orderLocationLabel(updated.tableNo)}',
              channelId: NotificationChannels.orders,
              payload: RouteNames.restaurantActiveOrders,
            ));
      }

      final stockFailure = await _deductAfterSave(entry, updated.kotNumbers.last);
      return (
        response: stockFailure ?? _jsonResponse(200, addedResponse),
        afterCommit: announce,
      );
    }

    // Get current session ID
    final currentSessionId = await DayManagementService.getCurrentSessionId();

    // No active order — create new one
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final kotNumber = await orderStore.getNextKotNumber();
    // Daily order number — without this the KDS/bill fall back to showing the
    // raw epoch orderId instead of a clean "Order #N".
    final orderNumber = await orderStore.getNextOrderNumber();

    // P2: priced exactly as the POS prices its own new order (takeaway.dart):
    // no discount or service charge yet, the current tax mode — stored on the
    // order so every later recalculation uses the same mode.
    final bool taxInclusive = AppSettings.isTaxInclusive;
    final calc = CartCalculationService(
      items: salePlan.lines,
      discountType: DiscountType.amount,
      discountValue: 0.0,
      isDeliveryOrder: orderType.toLowerCase().contains('delivery'),
      isTaxInclusive: taxInclusive,
    );
    final totalPrice = calc.grandTotal;

    final order = OrderModel(
      id: orderId,
      customerName: 'Captain Order',
      customerNumber: '',
      customerEmail: '',
      items: salePlan.lines,
      status: 'Processing',
      timeStamp: DateTime.now(),
      orderType: orderType,
      tableNo: tableNo,
      totalPrice: totalPrice,
      // Already the pre-tax base in both tax modes (M5).
      subTotal: calc.subtotal,
      gstAmount: calc.totalGST,
      gstRate: 0,
      isTaxInclusive: taxInclusive,
      kotNumbers: [kotNumber],
      itemCountAtLastKot: newItems.length,
      kotBoundaries: [newItems.length],
      orderNumber: orderNumber,
      sessionId: currentSessionId, // Link to POS session
    );

    // Journal first: the deduction, persisted before the order it covers.
    final entry = await _openSaleJournal(orderId, salePlan);
    // The store reports a failed save as `false`: stop before any stock,
    // table, KOT broadcast or success reply (SALE-3).
    if (!await orderStore.addOrder(order)) {
      if (await HiveOrders.getOrderById(orderId) == null) {
        await StockJournal.delete(entry.id);
      }
      throw StateError(
          orderStore.errorMessage ?? 'The order could not be saved.');
    }
    await StockJournal.markOrderSaved(entry);
    final newOrderResponse = {
      'success': true,
      'orderId': orderId,
      'kotNumber': kotNumber,
      'addedToExisting': false,
    };
    // INVX-4: saved → cached NOW, before anything else can fail.
    _cacheReply(requestId, fingerprint, newOrderResponse);

    Future<void> announce() async {
      if (tableNo != null) {
        await _bestEffort(() => tableStore.updateTableStatus(
              tableNo,
              'Cooking',
              total: totalPrice,
              orderId: orderId,
              orderTime: order.timeStamp,
            ));
      }
      await _bestEffort(() async => broadcastEvent({
            'type': 'NEW_ORDER',
            'orderId': orderId,
            'kotNumber': kotNumber,
            'tableNo': tableNo ?? 'Take Away',
            'orderType': orderType,
          }));
      await _bestEffort(() => LocalNotificationService.instance.showNow(
            idSeed: 'order_$orderId',
            title: 'New Order',
            body: '${_orderLocationLabel(tableNo)} · KOT #$kotNumber',
            channelId: NotificationChannels.orders,
            payload: RouteNames.restaurantActiveOrders,
          ));
    }

    final stockFailure = await _deductAfterSave(entry, kotNumber);
    return (
      response: stockFailure ?? _jsonResponse(200, newOrderResponse),
      afterCommit: announce,
    );
  } catch (e) {
    return (
      response: _jsonResponse(500, {'success': false, 'error': e.toString()}),
      afterCommit: null,
    );
  }
}

void _cacheReply(
    String? requestId, String fingerprint, Map<String, dynamic> reply) {
  if (requestId != null && requestId.isNotEmpty) {
    _orderRequestCache[requestId] = _IdempotencyEntry(reply, fingerprint);
  }
}

/// One display-only step of a follow-up: a failure is logged, never stops the
/// steps after it.
Future<void> _bestEffort(Future<void> Function() step) async {
  try {
    await step();
  } catch (e) {
    debugPrint('Captain follow-up step failed: $e');
  }
}

/// P1: [combined] ([saved] with Captain's lines appended) priced the way the
/// POS's own Place Order prices an existing order — saved discount amount,
/// service charge at the % [saved]'s amount was taken at, stored tax mode
/// ([SavedServiceCharge]) — and its payment flags re-derived from the new
/// balance, so a paid order that gets new items is payable again. Payments
/// themselves are untouched.
OrderModel _repricedAfterAddItems(OrderModel saved, OrderModel combined) {
  // The % comes from the order as saved: its amount over ITS lines.
  final calc = SavedServiceCharge.calculate(saved, combined.items,
      isDelivery: combined.orderType.toLowerCase().contains('delivery'));
  final paid = combined.totalPaid ?? 0;
  final fullyPaid = (calc.grandTotal - paid) < 0.01;
  return combined.copyWith(
    totalPrice: calc.grandTotal,
    // Already the pre-tax base in both tax modes (M5).
    subTotal: calc.subtotal,
    gstAmount: calc.totalGST,
    // The new amount (when there is one), so a later recalculation finds the
    // same %; a delivery order's flat charge comes back unchanged.
    serviceCharge:
        (combined.serviceCharge ?? 0) > 0 ? calc.serviceChargeAmount : null,
    isPaid: fullyPaid,
    paymentStatus:
        fullyPaid ? 'Paid' : (paid > 0 ? 'Partially Paid' : 'Unpaid'),
  );
}

/// The Settle journal's entry for a Captain sale: [plan]'s units, with the
/// new lines as the proof of the order write ([StockJournal.recoverAll]).
Future<JournalEntry> _openSaleJournal(String orderId,
        ({List<CartItem> lines, List<SaleStockUnit> units}) plan) =>
    StockJournal.open(
      orderId: orderId,
      target: {for (final l in plan.lines) l.id: l.quantity},
      units: plan.units,
    );

/// The deduction for an order that is ALREADY saved (and its reply cached),
/// through its journal [entry]. A failure keeps the entry — it resumes at the
/// next Settle or start, never repeats — and is answered with an error that
/// says the order exists, so the waiter does not send it again; null when the
/// stock was written.
Future<Response?> _deductAfterSave(JournalEntry entry, int kotNumber) async {
  try {
    await StockJournal.complete(entry);
    return null;
  } catch (e) {
    return _jsonResponse(500, {
      'success': false,
      'orderSaved': true,
      'error': 'Order saved (KOT #$kotNumber) but its stock update did not '
          'finish: $e. It will finish automatically on the POS. Do not send '
          'it again.',
    });
  }
}

// ── Modify Order (edit qty / remove items → Cancel KOT) ──────────────────────

/// PUT /captain/orders/:id/modify
/// Body: {
///   "updatedItems": [...CartItem maps with new quantities (qty > 0 only)],
///   "cancelledItems": [...CartItem maps with the CANCELLED quantities]
/// }
///
/// The request only says WHICH saved lines to keep and how many; everything
/// else comes from the saved order, the same rules as the POS's own cancel
/// (INVX-2 / INVX-3):
///
/// * SEC-2: an empty `updatedItems` is refused — cancelling a whole order is
///   a void on the POS, which records the payment and the reason.
/// * Read and parsed before the [StockGate]; validated and written inside it,
///   so it cannot interleave with a POS edit, settle or another Captain call.
/// * Every kept line must be a saved line at no more than its saved quantity,
///   and `cancelledItems` must name exactly what that removes — otherwise
///   the order changed since Captain loaded it: 409, nothing written. A
///   repeat of an applied request is refused the same way, so stock is never
///   restored twice.
/// * A line on a cooked KOT is refused ([OrderLineCancel.isCooked]).
/// * Lines, KOT boundaries and statuses via [KotLayout.removeQuantity];
///   totals via [SavedServiceCharge] at saved prices; stock restored from the
///   saved lines' stamps for the server-computed quantities; one
///   ItemCancellationModel per cancelled line for the report.
/// * The order is saved before any stock moves; a failed save restores
///   nothing.
Future<Response> captainModifyOrderHandler(
    Request request, String orderId) async {
  final List<CartItem> updatedItems;
  final List<CartItem> cancelledItems;
  final String reason;
  try {
    final data =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    updatedItems = (data['updatedItems'] as List<dynamic>? ?? [])
        .map((i) => CartItem.fromMap(i as Map<String, dynamic>))
        .toList();
    cancelledItems = (data['cancelledItems'] as List<dynamic>? ?? [])
        .map((i) => CartItem.fromMap(i as Map<String, dynamic>))
        .toList();
    reason = (data['reason'] as String?)?.trim().isNotEmpty == true
        ? (data['reason'] as String).trim()
        : 'Cancelled from Captain';
  } catch (e) {
    return _jsonResponse(400, {'success': false, 'error': 'Invalid request body'});
  }

  // SEC-2: never delete an order from a modify request.
  if (updatedItems.isEmpty) {
    return _jsonResponse(409, {
      'success': false,
      'error': 'To cancel the whole order, void it on the POS.',
    });
  }

  final outcome = await StockGate.run(() => _captainModifyOrder(
        orderId: orderId,
        updatedItems: updatedItems,
        cancelledItems: cancelledItems,
        reason: reason,
      ));
  await _runAfterCommit(outcome.afterCommit);
  return outcome.response;
}

const _orderChangedOnPos =
    'This order was changed on the POS since you opened it. Refresh and try '
    'again.';

/// Quantity to cancel per saved line id, worked out from the SAVED order and
/// the lines Captain keeps — or null when the request does not describe the
/// saved order (a line that does not exist, a quantity above the saved one,
/// a repeated line, or `cancelled` disagreeing with what keeping removes).
Map<String, int>? _cancelQuantities({
  required List<CartItem> saved,
  required List<CartItem> kept,
  required List<CartItem> cancelled,
}) {
  final savedQty = {for (final s in saved) s.id: s.quantity};
  final keepQty = <String, int>{};
  for (final k in kept) {
    final have = savedQty[k.id];
    if (have == null || keepQty.containsKey(k.id)) return null;
    if (k.quantity < 1 || k.quantity > have) return null;
    keepQty[k.id] = k.quantity;
  }
  final cancel = <String, int>{
    for (final s in saved)
      if (s.quantity - (keepQty[s.id] ?? 0) > 0)
        s.id: s.quantity - (keepQty[s.id] ?? 0),
  };
  final claimed = <String, int>{};
  for (final c in cancelled) {
    claimed[c.id] = (claimed[c.id] ?? 0) + c.quantity;
  }
  if (claimed.length != cancel.length) return null;
  for (final e in cancel.entries) {
    if (claimed[e.key] != e.value) return null;
  }
  return cancel;
}

/// The KOT number owning [lineId] in [order], or null.
int? _kotOf(OrderModel order, String lineId) {
  final idx = order.items.indexWhere((i) => i.id == lineId);
  if (idx == -1) return null;
  final kotIndex = order.kotBoundaries.indexWhere((b) => idx < b);
  if (kotIndex == -1 || kotIndex >= order.kotNumbers.length) return null;
  return order.kotNumbers[kotIndex];
}

Future<_GatedReply> _captainModifyOrder({
  required String orderId,
  required List<CartItem> updatedItems,
  required List<CartItem> cancelledItems,
  required String reason,
}) async {
  try {
    // Earlier cancels a stop left part-way first, so the read below sees
    // their stock settled.
    await StockJournal.recoverCancels();
    final order = await HiveOrders.getOrderById(orderId);
    if (order == null) {
      return (
        response: _jsonResponse(
            404, {'success': false, 'error': 'Order not found'}),
        afterCommit: null,
      );
    }

    final cancelQty = _cancelQuantities(
      saved: order.items,
      kept: updatedItems,
      cancelled: cancelledItems,
    );
    if (cancelQty == null) {
      return (
        response: _jsonResponse(
            409, {'success': false, 'error': _orderChangedOnPos}),
        afterCommit: null,
      );
    }

    final savedById = {for (final s in order.items) s.id: s};
    final cooked = [
      for (final id in cancelQty.keys)
        if (OrderLineCancel.isCooked(order, id)) savedById[id]!.title,
    ];
    if (cooked.isNotEmpty) {
      return (
        response: _jsonResponse(409, {
          'success': false,
          'error': 'Cannot cancel cooked items: ${cooked.join(', ')}',
        }),
        afterCommit: null,
      );
    }

    // Saved lines, KOT boundaries and statuses with each cancellation taken
    // out; stamps shrink with the quantity (LineStock.reduced).
    var items = order.items;
    var kotNumbers = order.kotNumbers;
    var kotBoundaries = order.kotBoundaries;
    var kotStatuses = order.kotStatuses ?? <int, String>{};
    var itemCountAtLastKot = order.itemCountAtLastKot;
    for (final e in cancelQty.entries) {
      final layout = KotLayout.removeQuantity(
        items: items,
        kotNumbers: kotNumbers,
        kotBoundaries: kotBoundaries,
        kotStatuses: kotStatuses,
        lineId: e.key,
        qty: e.value,
      );
      items = layout.items;
      kotNumbers = layout.kotNumbers;
      kotBoundaries = layout.kotBoundaries;
      kotStatuses = layout.kotStatuses;
      itemCountAtLastKot = layout.itemCountAtLastKot;
    }

    final bool isDelivery = order.orderType.toLowerCase().contains('delivery');
    final calc = SavedServiceCharge.calculate(order, items, isDelivery: isDelivery);
    final updatedOrder = order.copyWith(
      items: items,
      kotNumbers: kotNumbers,
      kotBoundaries: kotBoundaries,
      kotStatuses: kotStatuses,
      itemCountAtLastKot: itemCountAtLastKot,
      totalPrice: calc.grandTotal,
      // Already the pre-tax base in both tax modes (M5).
      subTotal: calc.subtotal,
      gstAmount: calc.totalGST,
      // The new amount, so a later recalculation finds the same %.
      serviceCharge: calc.serviceChargeAmount,
    );

    // Generate a Cancel KOT number (only once the request is accepted).
    final cancelKotNumber = await orderStore.getNextKotNumber();

    // Stock — exactly the server-computed quantities, from the lines as
    // SAVED before this change (their stamps say what each sale took).
    final cancelled = [
      for (final e in cancelQty.entries)
        (line: savedById[e.key]!, qty: e.value),
    ];

    // 1. Journal: the return, persisted before the order write; each line's
    // quantity after the write (0 = removed) proves whether it happened.
    final entry = await StockJournal.openCancel(
      orderId: orderId,
      target: {
        for (final e in cancelQty.entries)
          e.key: savedById[e.key]!.quantity - e.value,
      },
      units: await InventoryService.planRestoreUnits(cancelled),
      tableNo: order.tableNo,
      staffName: 'Captain',
    );

    // 2. The order. A save that throws may still have landed: the entry
    // stays and StockJournal.recoverCancels decides from the saved order.
    await HiveOrders.updateOrder(updatedOrder);
    await StockJournal.markOrderSaved(entry);
    // The POS's in-memory orders do not see HiveOrders writes.
    await _bestEffort(() async => orderStore.readSaved(orderId));

    // 3. The return. A failure keeps the entry; it resumes, never repeats.
    String? stockWarning;
    try {
      await StockJournal.complete(entry);
    } catch (e) {
      stockWarning = 'Items cancelled, but returning their stock did not '
          'finish ($e). It will finish automatically on the POS.';
    }

    // 3. The Item Cancellation Report, as the POS's own cancel writes it.
    final sessionId = await DayManagementService.getCurrentSessionId();
    final now = DateTime.now();
    final repo = ItemCancellationRepository();
    for (final c in cancelled) {
      await _bestEffort(() => repo.add(ItemCancellationModel(
            id: const Uuid().v4(),
            itemName: c.line.title,
            variantName: c.line.variantName,
            quantity: c.qty,
            amount: c.line.price * c.qty,
            reason: reason,
            orderId: orderId,
            kotNumber: _kotOf(order, c.line.id),
            staffName: 'Captain',
            timestamp: now,
            sessionId: sessionId,
            orderType: order.orderType,
            tableNo: order.tableNo,
          )));
    }

    final modifiedKots = {
      for (final c in cancelled) ?_kotOf(order, c.line.id),
    }.toList();

    Future<void> announce() async {
      if (order.tableNo != null && order.tableNo!.isNotEmpty) {
        await _bestEffort(() => tableStore.updateTableStatus(
              order.tableNo!,
              order.status,
              total: updatedOrder.totalPrice,
              orderId: orderId,
              orderTime: order.timeStamp,
            ));
      }

      // The KDS flashes its cancellation warning on ORDER_MODIFIED (the POS's
      // own correction event). Emit ONLY this (matching the POS's own cancel
      // flow) so the kitchen gets exactly one warning with the real KOT number.
      await _bestEffort(() async => broadcastEvent({
            'type': 'ORDER_MODIFIED',
            'orderId': orderId,
            'orderNumber': order.orderNumber,
            'kotNumbers':
                modifiedKots.isNotEmpty ? modifiedKots : order.kotNumbers,
            'tableNo': order.tableNo,
            'removedItems': [
              for (final c in cancelled)
                {'id': c.line.id, 'title': c.line.title, 'quantity': c.qty},
            ],
            'reducedItems': [],
          }));

      // Also trigger ORDER_UPDATED so activeorder.dart reloads MobX store
      await _bestEffort(() async => broadcastEvent({
            'type': 'ORDER_UPDATED',
            'orderId': orderId,
            'tableNo': order.tableNo,
            'kotNumber': cancelKotNumber,
            'newItemCount': 0,
          }));

      final hasCancellations = cancelled.isNotEmpty;
      await _bestEffort(() => LocalNotificationService.instance.showNow(
            idSeed: 'cancel_${orderId}_$cancelKotNumber',
            title: hasCancellations ? 'Items Cancelled' : 'Order Modified',
            body: hasCancellations
                ? '${cancelled.length} item${cancelled.length == 1 ? '' : 's'} cancelled · ${_orderLocationLabel(order.tableNo)}'
                : 'Order updated · ${_orderLocationLabel(order.tableNo)}',
            channelId: NotificationChannels.orders,
            payload: RouteNames.restaurantActiveOrders,
          ));
    }

    return (
      response: _jsonResponse(200, {
        'success': true,
        'cancelKotNumber': cancelKotNumber,
        'warning': ?stockWarning,
      }),
      afterCommit: announce,
    );
  } catch (e) {
    return (
      response: _jsonResponse(500, {'success': false, 'error': e.toString()}),
      afterCommit: null,
    );
  }
}

// ── Active Orders ─────────────────────────────────────────────────────────────

/// GET /captain/active-orders
/// Returns all active orders with table name, status, items, total, time
Future<Response> getCaptainActiveOrdersHandler(Request request) async {
  try {
    await tableStore.loadTables();
    final allOrders = await HiveOrders.getAllActiveOrders();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final orders = allOrders
        .where((o) => o.timeStamp == null || o.timeStamp!.isAfter(cutoff))
        .toList();

    final result = orders.map((o) {
      final table = tableStore.tables.cast<dynamic>().firstWhere(
        (t) => t.id == o.tableNo,
        orElse: () => null,
      );
      return {
        'orderId': o.id,
        'tableNo': o.tableNo,
        'tableName': table != null ? (table.id as String?) : o.tableNo,
        'status': o.status,
        'orderType': o.orderType,
        'total': o.totalPrice,
        'timeStamp': o.timeStamp?.toIso8601String(),
        'kotNumbers': o.kotNumbers,
        'items': o.items.map((i) => i.toMap()).toList(),
      };
    }).toList();

    return Response.ok(
      jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// ── Update Order Status ───────────────────────────────────────────────────────

/// PUT /captain/orders/:id/status
/// Body: { "status": "Served" | "Running" | "Bill Requested" }
Future<Response> captainUpdateOrderStatusHandler(Request request, String orderId) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final newStatus = data['status'] as String?;

    if (newStatus == null) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': 'status is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final order = await HiveOrders.getOrderById(orderId);
    if (order == null) {
      return Response(404,
        body: jsonEncode({'success': false, 'error': 'Order not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final updated = order.copyWith(status: newStatus);
    await HiveOrders.updateOrder(updated);

    // Update table status to match order status
    if (order.tableNo != null) {
      final tableStatus = newStatus == 'Served' ? 'Running' : newStatus;
      await tableStore.updateTableStatus(
        order.tableNo!,
        tableStatus,
        total: order.totalPrice,
        orderId: orderId,
        orderTime: order.timeStamp,
      );
    }

    broadcastEvent({
      'type': 'ORDER_STATUS_UPDATED',
      'orderId': orderId,
      'status': newStatus,
      'tableNo': order.tableNo,
      'updatedBy': 'captain',
    });

    return Response.ok(
      jsonEncode({'success': true, 'orderId': orderId, 'status': newStatus}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}