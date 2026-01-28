import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:unipos/core/di/service_locator.dart';
import '../websocket.dart';
import '../../data/models/restaurant/db/database/hive_order.dart';
import '../../data/models/restaurant/db/ordermodel_309.dart';
import '../../data/models/restaurant/db/cartmodel_308.dart';

Future<Response> createOrderHandler(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Generate unique order ID
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();

    // Get next KOT number
    final kotNumber = await orderStore.getNextKotNumber();

    // Parse cart items from request
    final items = (data['items'] as List<dynamic>?)
        ?.map((item) => CartItem.fromMap(item as Map<String, dynamic>))
        .toList() ?? [];

    // Create order model
    final order = OrderModel(
      id: orderId,
      customerName: data['customerName'] as String? ?? 'Walk-in',
      customerNumber: data['customerNumber'] as String? ?? '',
      customerEmail: data['customerEmail'] as String? ?? '',
      items: items,
      status: 'Processing', // Initial status
      timeStamp: DateTime.now(),
      orderType: data['orderType'] as String? ?? 'Dine In',
      tableNo: data['tableNo'] as String?,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      kotNumbers: [kotNumber],
      itemCountAtLastKot: items.length,
      kotBoundaries: [items.length],
    );

    // Save order to Hive
    await orderStore.addOrder(order);

    // Notify kitchen via WebSocket
    broadcastEvent({
      'type': 'NEW_ORDER',
      'orderId': orderId,
      'kotNumber': kotNumber,
      'tableNo': order.tableNo,
      'orderType': order.orderType,
    });

    return Response.ok(
      jsonEncode({'success': true, 'orderId': orderId, 'kotNumber': kotNumber}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
