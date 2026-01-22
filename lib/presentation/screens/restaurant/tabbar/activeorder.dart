
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/util/color.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/OrderCard.dart';
import '../start order/cart/cart.dart';
import '../../../../services/websocket_client_service.dart';
import '../../../../server/websocket.dart' as ws;


class Activeorder extends StatefulWidget {
  const Activeorder({super.key});

  @override
  State<Activeorder> createState() => _ActiveorderState();
}

class _ActiveorderState extends State<Activeorder> {
  String dropDownValue = 'All';
  StreamSubscription? _wsSubscription;
  final _wsService = WebSocketClientService();

  List<String> dropdownItems = [
    'All',
    'Take Away', // Note: Make sure this matches the string in your OrderModel exactly
    'Delivery',
    'Dine In',
  ];

  @override
  void initState() {
    super.initState();
    orderStore.loadOrders();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    // Start WebSocket client service
    await _wsService.start();

    // Listen for real-time updates from KDS
    _wsSubscription = _wsService.messageStream.listen((message) {
      final type = message['type'] as String?;

      if (type == 'STATUS_UPDATE') {
        final orderId = message['orderId'] as String?;
        final status = message['status'] as String?;
        final tableNo = message['tableNo'] as String?;
        final kotNumber = message['kotNumber'];

        print('🔔 UniPOS: Order status updated - KOT #$kotNumber (Table $tableNo) → $status');

        // Show notification to user
        if (mounted && status != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.update, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'KOT #$kotNumber: Status updated to $status',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // UI will automatically refresh via ValueListenableBuilder
        // because server already updated Hive database
      } else if (type == 'ORDER_UPDATED' || type == 'NEW_ITEMS_ADDED') {
        final kotNumber = message['kotNumber'];
        final newItemCount = message['newItemCount'];
        final tableNo = message['tableNo'];

        print('🔔 UniPOS: Order updated - KOT #$kotNumber with $newItemCount new items');

        // Show notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'New KOT #$kotNumber: $newItemCount items added to Table $tableNo',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (type == 'NEW_ORDER') {
        final kotNumber = message['kotNumber'];
        final tableNo = message['tableNo'];

        print('🔔 UniPOS: New order received - KOT #$kotNumber (Table $tableNo)');

        // Show notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.restaurant_menu, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'New Order: KOT #$kotNumber - Table $tableNo',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _deleteOrder(String orderId) async {
    // Show a confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Order'),
        content: Text('Are you sure you want to delete this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // Only delete if the user confirmed
    if (shouldDelete == true) {
      await orderStore.deleteOrder(orderId);
    }
  }



  // In _ActiveorderState class
  Color _getColorForStatus(String? status) {
    switch (status) {
      case 'Processing':
        return Colors.red.shade500; // Red for Processing (new orders)
      case 'Cooking':
        return Colors.red.shade500; // Red for Cooking
      case 'Ready':
        return Colors.orange.shade300; // Orange for Ready
      case 'Served':
        return Colors.green.shade300; // Green for Served (awaiting payment)
      default:
        return Colors.grey.shade400; // Default color for unknown status
    }
  }

  // In _ActiveorderState class

// This function shows the main dialog with KOT-level status updates
  void _showStatusUpdateDialog(OrderModel order, bool istakeaway,) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Get current KOT statuses
            final kotStatuses = Map<int, String>.from(order.kotStatuses ?? {});

            // Initialize missing KOT statuses
            for (var kotNum in order.kotNumbers) {
              if (!kotStatuses.containsKey(kotNum)) {
                kotStatuses[kotNum] = order.status;
              }
            }

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Update Order Status',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.cancel, color: Colors.grey),
                  )
                ],
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Info
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (order.tableNo != null && order.tableNo!.isNotEmpty)
                                  ? 'Table ${order.tableNo}'
                                  : order.orderType,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Overall Status: ${order.status}',
                              style: GoogleFonts.poppins(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),

                      // KOT Status Updates
                      Text(
                        'Update KOT Status:',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 12),

                      // List all KOTs with status buttons
                      ...order.kotNumbers.map((kotNum) {
                        final currentStatus = kotStatuses[kotNum] ?? order.status;
                        final kotIndex = order.kotNumbers.indexOf(kotNum);
                        final startIndex = kotIndex == 0 ? 0 : order.kotBoundaries[kotIndex - 1];
                        final endIndex = order.kotBoundaries[kotIndex];
                        final itemCount = endIndex - startIndex;

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: _getColorForStatus(currentStatus)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'KOT #$kotNum',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '$itemCount item${itemCount > 1 ? 's' : ''}',
                                    style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Status: $currentStatus',
                                style: GoogleFonts.poppins(
                                  color: _getColorForStatus(currentStatus),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (currentStatus != 'Cooking')
                                    _buildStatusButton('Cooking', Colors.orange, () {
                                      _updateKotStatus(order, kotNum, 'Cooking');
                                      Navigator.pop(context);
                                    }),
                                  if (currentStatus != 'Ready')
                                    _buildStatusButton('Ready', Colors.blue, () {
                                      _updateKotStatus(order, kotNum, 'Ready');
                                      Navigator.pop(context);
                                    }),
                                  if (currentStatus != 'Served')
                                    _buildStatusButton('Served', Colors.green, () {
                                      if (order.paymentStatus == 'Paid') {
                                        // Check if all KOTs are served
                                        final allServed = order.kotNumbers.every((k) =>
                                          (k == kotNum) || (kotStatuses[k] == 'Served')
                                        );
                                        if (allServed) {
                                          _moveOrderToPast(order);
                                        } else {
                                          _updateKotStatus(order, kotNum, 'Served');
                                        }
                                      } else {
                                        _updateKotStatus(order, kotNum, 'Served');
                                      }
                                      Navigator.pop(context);
                                    }),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper to build status button
  Widget _buildStatusButton(String status, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
      ),
    );
  }

// ACTION 1: Updates KOT status and syncs with KDS
  Future<void> _updateKotStatus(OrderModel order, int kotNumber, String newStatus) async {
    try {
      print('🔄 Updating KOT #$kotNumber to $newStatus');

      // Update KOT status map
      Map<int, String> updatedKotStatuses = Map<int, String>.from(order.kotStatuses ?? {});
      updatedKotStatuses[kotNumber] = newStatus;

      // Calculate overall order status
      String overallStatus = _calculateOverallStatus(updatedKotStatuses, order.kotNumbers);

      // Update the order in database
      final updatedOrder = order.copyWith(
        kotStatuses: updatedKotStatuses,
        status: overallStatus,
      );
      await orderStore.updateOrder(updatedOrder);

      // Update table status to match order status
      if (order.tableNo != null && order.tableNo!.isNotEmpty) {
        await tableStore.updateTableStatus(
          order.tableNo!,
          overallStatus,
          total: order.totalPrice,
          orderId: order.id,
          orderTime: order.timeStamp,
        );
        print('📍 Table ${order.tableNo} status updated to $overallStatus');
      }

      print('✅ KOT #$kotNumber updated to $newStatus (Overall: $overallStatus)');

      // Broadcast to KDS via WebSocket
      try {
        // Convert integer keys to strings for JSON encoding
        final kotStatusesJson = updatedKotStatuses.map((key, value) => MapEntry(key.toString(), value));

        ws.broadcastEvent({
          'type': 'KOT_STATUS_UPDATE',
          'orderId': order.id,
          'kotNumber': kotNumber,
          'kotStatus': newStatus,
          'overallStatus': overallStatus,
          'tableNo': order.tableNo,
          'allKotNumbers': order.kotNumbers,
          'kotStatuses': kotStatusesJson,
        });
        print('📡 Status update broadcast to KDS');
      } catch (e) {
        print('⚠️ Failed to broadcast to KDS: $e');
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KOT #$kotNumber updated to $newStatus'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating KOT status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  // Legacy: Updates the overall order status (kept for backward compatibility)
  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    // Create an updated version of the order
    final updatedOrder = order.copyWith(status: newStatus);
    // Save the change to the store
    await orderStore.updateOrder(updatedOrder);
    print("Order ${order.kotNumbers.isNotEmpty ? order.kotNumbers.first : order.id} status updated to $newStatus.");
  }

// ACTION 2: Moves the order to the past orders box
  Future<void> _moveOrderToPast(OrderModel order) async {
    // Create a past order record from the active order
    final pastOrder = pastOrderModel(
      id: order.id,
      customerName: order.customerName,
      totalPrice: order.totalPrice,
      items: order.items,
      orderAt: order.timeStamp,
      orderType: order.orderType,
      paymentmode: order.paymentMethod ?? 'N/A',
      subTotal: order.subTotal,
      gstAmount: order.gstAmount,
      Discount: order.discount,
      remark: order.remark,
      // ✅ KOT tracking - REQUIRED
      kotNumbers: order.kotNumbers,
      kotBoundaries: order.kotBoundaries, // KOT boundaries for grouping items
    );

    // Add to past orders and delete from active orders
    await pastOrderStore.addOrder(pastOrder);
    await orderStore.deleteOrder(order.id);
    if (order.tableNo != null && order.tableNo!.isNotEmpty) {
      await tableStore.updateTableStatus(order.tableNo!, 'Available');
    }

    print("Order ${order.kotNumbers.isNotEmpty ? order.kotNumbers.first : order.id} moved to past orders.");
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Order Type Filter Row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: AppColors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Type',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider, width: 1.5),
                  ),
                  child: DropdownButton<String>(
                    value: dropDownValue,
                    underline: SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    items: dropdownItems.map((String item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        dropDownValue = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: Observer(
              builder: (_) {
                if (orderStore.isLoading && orderStore.orders.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }

                // Show all orders except 'Served' orders that are already paid
                final activeOrders = orderStore.orders
                    .where((order) =>
                        order.status != 'Served' ||
                        (order.status == 'Served' && order.paymentStatus != 'Paid'))
                    .toList();

                activeOrders.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));

                if (activeOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: AppColors.divider,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No active orders',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filterOrderList = dropDownValue == 'All'
                    ? activeOrders
                    : activeOrders
                        .where((order) => order.orderType == dropDownValue)
                        .toList();

                if (filterOrderList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: AppColors.divider,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No orders of type "$dropDownValue"',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: filterOrderList.length,
                  itemBuilder: (context, index) {
                    final order = filterOrderList[index];
                    return OrderCard(
                      color: _getColorForStatus(order.status),
                      order: order,
                      onDelete: _deleteOrder,
                      ontapcooking: () async {
                        if (order.status == 'Processing' ||
                            order.status == 'Cooking' ||
                            order.status == 'Ready' ||
                            order.status == 'Served') {
                          _showStatusUpdateDialog(
                              order, order.orderType == 'Take Away' ? true : false);
                        }
                      },
                      ontap: () async {
                        if (order.isPaid != true) {
                          print(
                              'Card with Kot ${order.kotNumbers.isNotEmpty ? order.kotNumbers.first : order.id}');

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CartScreen(
                                existingOrder: order,
                                selectedTableNo: order.tableNo,
                              ),
                            ),
                          );
                        } else {
                          print("Order is in status: ${order.status}");
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// Future Builder
/*  FutureBuilder<List<OrderModel>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'No Active Orders',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 28,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    );
                  }

                  final allOrders = snapshot.data!;

                  allOrders.sort((a,b)=> b.timeStamp.compareTo(a.timeStamp!));

                  // Filter the orders based on the dropdown value
                  // final filteredOrders = dropDownValue == 'All'
                  //     ? allOrders
                  //     : allOrders
                  //     .where((order) => order.orderType == dropDownValue)
                  //     .toList();
                  //
                  // if (filteredOrders.isEmpty) {
                  //   return Center(child: Text('No orders of type "$dropDownValue" found.'));
                  // }




                  // The ListView provides its own scrolling
                  // Inside your build method's FutureBuilder

                },
              ),*/