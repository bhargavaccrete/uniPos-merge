import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/kds_order_dto.dart';
import '../models/order_status.dart';
import '../../data/models/restaurant/db/database/hive_order.dart';
import '../../data/models/restaurant/db/ordermodel_309.dart';
import '../websocket.dart';

Future<Response> getKdsOrdersHandler(Request request) async {
  try {
    // Fetch all orders from Hive
    final orders = await HiveOrders.getAllOrder();

    // Filter for active orders (not completed/cancelled)
    final activeOrders = orders.where((order) =>
      order.status != 'Completed' &&
      order.status != 'Cancelled'
    ).toList();

    // Convert to KDS DTOs - ONE CARD PER KOT
    List<KdsOrderDto> kdsOrders = [];

    for (var order in activeOrders) {
      final kotNumbers = order.kotNumbers;
      final kotBoundaries = order.kotBoundaries;
      final allItems = order.items;

      // Create separate KOT cards for each KOT
      int startIndex = 0;
      for (int i = 0; i < kotNumbers.length; i++) {
        final kotNum = kotNumbers[i];
        final endIndex = kotBoundaries[i];

        // Get items for this specific KOT
        if (startIndex < allItems.length) {
          final actualEndIndex = endIndex > allItems.length ? allItems.length : endIndex;
          final kotItems = allItems.sublist(startIndex, actualEndIndex);

          if (kotItems.isNotEmpty) {
            // Get KOT-specific status
            String kotStatusString = order.getKotStatus(kotNum);

            // Map KOT status to KDS status
            OrderStatus kdsStatus;
            switch (kotStatusString) {
              case 'Processing':
                kdsStatus = OrderStatus.newOrder;
                break;
              case 'Cooking':
                kdsStatus = OrderStatus.preparing;
                break;
              case 'Ready':
                kdsStatus = OrderStatus.ready;
                break;
              case 'Served':
                kdsStatus = OrderStatus.served;
                break;
              default:
                kdsStatus = OrderStatus.newOrder;
            }

            // Convert cart items to KDS items
            final kdsItems = kotItems.map((item) {
              return KdsItemDto(
                name: item.title,
                qty: item.quantity,
                note: item.instruction,
                variant: item.variantName,
                choices: item.choiceNames,
                extras: item.extras,
                category: item.categoryName,
                weightDisplay: item.weightDisplay,
              );
            }).toList();

            // Create KOT card
            kdsOrders.add(KdsOrderDto(
              orderId: order.id,
              orderNumber: order.orderNumber, // Daily order number
              tableNo: order.tableNo ?? 'N/A',
              orderType: order.orderType,
              status: kdsStatus,
              createdAt: order.timeStamp,
              items: kdsItems,
              kotNumber: kotNum,
              allKotNumbers: kotNumbers,
              isPartialOrder: kotNumbers.length > 1,
            ));
          }

          startIndex = endIndex;
        }
      }
    }

    return Response.ok(
      jsonEncode(kdsOrders.map((e) => e.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('❌ Error in getKdsOrdersHandler: $e');
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// Legacy handler - updates whole order status (kept for backward compatibility)
Future<Response> updateKdsStatusHandler(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Get the new status from request
    final newStatus = data['status'] as String?;
    if (newStatus == null) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': 'Status is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Fetch all orders to find the one to update
    final orders = await HiveOrders.getAllOrder();
    final orderToUpdate = orders.firstWhere(
      (order) => order.id == id,
      orElse: () => throw Exception('Order not found'),
    );

    // Map KDS status to order status
    String orderStatus;
    switch (newStatus) {
      case 'newOrder':
        orderStatus = 'Processing';
        break;
      case 'accepted':
      case 'preparing':
        orderStatus = 'Cooking';
        break;
      case 'ready':
        orderStatus = 'Ready';
        break;
      case 'served':
        orderStatus = 'Served';
        break;
      default:
        orderStatus = newStatus;
    }

    // Update the order
    final updatedOrder = orderToUpdate.copyWith(status: orderStatus);
    await HiveOrders.updateOrder(updatedOrder);

    print('✅ Order $id status updated to: $orderStatus');

    // Broadcast status change to all connected clients (UniPOS + other KDS apps)
    // Convert integer keys to strings for JSON encoding
    final kotStatusesJson = orderToUpdate.kotStatuses?.map((key, value) => MapEntry(key.toString(), value));

    broadcastEvent({
      'type': 'STATUS_UPDATE',
      'orderId': id,
      'status': orderStatus,
      'tableNo': orderToUpdate.tableNo,
      'kotNumber': orderToUpdate.kotNumbers.isNotEmpty ? orderToUpdate.kotNumbers.first : null,
      'allKotNumbers': orderToUpdate.kotNumbers,
      'kotBoundaries': orderToUpdate.kotBoundaries,
      'kotStatuses': kotStatusesJson,
    });

    return Response.ok(
      jsonEncode({'success': true, 'orderId': id, 'newStatus': orderStatus}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// New handler - updates specific KOT status
Future<Response> updateKotStatusHandler(Request request, String id, String kotNumberStr) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Parse KOT number
    final int? kotNumber = int.tryParse(kotNumberStr);
    if (kotNumber == null) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': 'Invalid KOT number'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get the new status from request
    final newStatus = data['status'] as String?;
    if (newStatus == null) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': 'Status is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Fetch all orders to find the one to update
    final orders = await HiveOrders.getAllOrder();
    final orderToUpdate = orders.firstWhere(
      (order) => order.id == id,
      orElse: () => throw Exception('Order not found'),
    );

    // Verify KOT belongs to this order
    if (!orderToUpdate.kotNumbers.contains(kotNumber)) {
      return Response.badRequest(
        body: jsonEncode({'success': false, 'error': 'KOT $kotNumber not found in order $id'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Map KDS status to order status
    String kotStatus;
    switch (newStatus) {
      case 'newOrder':
        kotStatus = 'Processing';
        break;
      case 'accepted':
      case 'preparing':
        kotStatus = 'Cooking';
        break;
      case 'ready':
        kotStatus = 'Ready';
        break;
      case 'served':
        kotStatus = 'Served';
        break;
      default:
        kotStatus = newStatus;
    }

    // Update KOT status
    Map<int, String> updatedKotStatuses = Map<int, String>.from(orderToUpdate.kotStatuses ?? {});
    updatedKotStatuses[kotNumber] = kotStatus;

    // Calculate overall order status based on all KOT statuses
    String overallStatus = _calculateOverallStatus(updatedKotStatuses, orderToUpdate.kotNumbers);

    // Update the order with new KOT statuses and overall status
    final updatedOrder = orderToUpdate.copyWith(
      kotStatuses: updatedKotStatuses,
      status: overallStatus,
    );
    await HiveOrders.updateOrder(updatedOrder);

    print('✅ KOT #$kotNumber status updated to: $kotStatus');
    print('📊 Overall order status: $overallStatus');

    // Broadcast KOT status change to all connected clients
    // Convert integer keys to strings for JSON encoding
    final kotStatusesJson = updatedKotStatuses.map((key, value) => MapEntry(key.toString(), value));

    broadcastEvent({
      'type': 'KOT_STATUS_UPDATE',
      'orderId': id,
      'kotNumber': kotNumber,
      'kotStatus': kotStatus,
      'overallStatus': overallStatus,
      'tableNo': orderToUpdate.tableNo,
      'allKotNumbers': orderToUpdate.kotNumbers,
      'kotStatuses': kotStatusesJson,
    });

    return Response.ok(
      jsonEncode({
        'success': true,
        'orderId': id,
        'kotNumber': kotNumber,
        'newKotStatus': kotStatus,
        'overallStatus': overallStatus,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('❌ Error in updateKotStatusHandler: $e');
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

// Helper function to calculate overall order status from KOT statuses
String _calculateOverallStatus(Map<int, String> kotStatuses, List<int> kotNumbers) {
  if (kotStatuses.isEmpty) return 'Processing';

  // Get all statuses
  final statuses = kotNumbers.map((kot) => kotStatuses[kot] ?? 'Processing').toList();

  // If all KOTs are Served, order is Served
  if (statuses.every((s) => s == 'Served')) return 'Served';

  // If all KOTs are Ready or Served, order is Ready
  if (statuses.every((s) => s == 'Ready' || s == 'Served')) return 'Ready';

  // If any KOT is Cooking, order is Cooking
  if (statuses.any((s) => s == 'Cooking')) return 'Cooking';

  // Otherwise, order is Processing
  return 'Processing';
}
