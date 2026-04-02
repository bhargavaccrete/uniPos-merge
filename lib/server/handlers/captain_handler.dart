import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/restaurant/db/cartmodel_308.dart';
import '../../data/models/restaurant/db/database/hive_order.dart';
import '../../data/models/restaurant/db/ordermodel_309.dart';
import '../../domain/services/restaurant/inventory_service.dart';
import '../../util/restaurant/restaurant_auth_helper.dart';
import '../websocket.dart';

// ── Auth ──────────────────────────────────────────────────────────────────────

/// POST /captain/auth
/// Body: { "username": "...", "pin": "..." }
/// Returns: { "success": true, "staffId": "...", "name": "...", "role": "cashier|waiter" }
Future<Response> captainAuthHandler(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final username = (data['username'] as String?)?.trim() ?? '';
    final pin = (data['pin'] as String?)?.trim() ?? '';

    if (username.isEmpty || pin.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': 'Username and PIN are required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    await staffStore.loadStaff();

    final match = staffStore.staff.where((s) =>
      s.isActive &&
      s.userName.trim() == username &&
      RestaurantAuthHelper.verifyPassword(pin, s.pinNo.trim()),
    ).firstOrNull;

    if (match == null) {
      return Response(
        401,
        body: jsonEncode({'success': false, 'error': 'Invalid username or PIN'}),
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
    print('❌ Error in captainAuthHandler: $e');
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
    print('❌ Error in getCaptainMenuHandler: $e');
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
    print('❌ Error in getCaptainTablesHandler: $e');
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
Future<Response> captainSendOrderHandler(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final tableNo = data['tableNo'] as String?;
    final orderType = data['orderType'] as String? ?? 'Take Away';
    final totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;

    final newItems = (data['items'] as List<dynamic>? ?? [])
        .map((i) => CartItem.fromMap(i as Map<String, dynamic>))
        .toList();

    if (newItems.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': 'No items provided'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Check for existing active order on this table
    if (tableNo != null) {
      final existing = await HiveOrders.getActiveOrderByTableId(tableNo);
      if (existing != null) {
        // Add items to existing order as new KOT
        final updated = await HiveOrders.updateOrderWithNewItems(
          existingOrder: existing,
          newItems: newItems,
        );
        await InventoryService.deductStockForOrder(newItems);
        // Update table total
        await tableStore.updateTableStatus(
          tableNo,
          'Cooking',
          total: updated.totalPrice,
          orderId: updated.id,
          orderTime: updated.timeStamp,
        );
        return Response.ok(
          jsonEncode({
            'success': true,
            'orderId': updated.id,
            'kotNumber': updated.kotNumbers.last,
            'addedToExisting': true,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    // No active order — create new one
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final kotNumber = await orderStore.getNextKotNumber();

    final order = OrderModel(
      id: orderId,
      customerName: 'Captain Order',
      customerNumber: '',
      customerEmail: '',
      items: newItems,
      status: 'Processing',
      timeStamp: DateTime.now(),
      orderType: orderType,
      tableNo: tableNo,
      totalPrice: totalPrice,
      kotNumbers: [kotNumber],
      itemCountAtLastKot: newItems.length,
      kotBoundaries: [newItems.length],
    );

    await orderStore.addOrder(order);
    await InventoryService.deductStockForOrder(newItems);

    if (tableNo != null) {
      await tableStore.updateTableStatus(
        tableNo,
        'Cooking',
        total: totalPrice,
        orderId: orderId,
        orderTime: order.timeStamp,
      );
    }

    broadcastEvent({
      'type': 'NEW_ORDER',
      'orderId': orderId,
      'kotNumber': kotNumber,
      'tableNo': tableNo,
      'orderType': orderType,
    });

    return Response.ok(
      jsonEncode({
        'success': true,
        'orderId': orderId,
        'kotNumber': kotNumber,
        'addedToExisting': false,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('❌ Error in captainSendOrderHandler: $e');
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// ── Active Orders ─────────────────────────────────────────────────────────────

/// GET /captain/active-orders
/// Returns all active orders with table name, status, items, total, time
Future<Response> getCaptainActiveOrdersHandler(Request request) async {
  try {
    await tableStore.loadTables();
    final orders = await HiveOrders.getAllActiveOrders();

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
    print('❌ Error in getCaptainActiveOrdersHandler: $e');
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
    print('❌ Error in captainUpdateOrderStatusHandler: $e');
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}