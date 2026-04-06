
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/util/color.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/restaurant/componets/OrderCard.dart';
import '../start order/cart/cart.dart';
import '../../../../services/websocket_client_service.dart';
import '../../../../server/websocket.dart' as ws;
import '../util/restaurant_print_helper.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';


class Activeorder extends StatefulWidget {
  const Activeorder({super.key});

  @override
  State<Activeorder> createState() => _ActiveorderState();
}

class _ActiveorderState extends State<Activeorder> {
  String dropDownValue = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
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

  void _initializeWebSocket() {
    // Start WebSocket client service (fire and forget)
    _wsService.start();

    // Listen for real-time updates from KDS
    _wsSubscription = _wsService.messageStream.listen((message) async {
      final type = message['type'] as String?;

      if (type == 'STATUS_UPDATE') {
        final orderId = message['orderId'] as String?;
        final status = message['status'] as String?;
        final tableNo = message['tableNo'] as String?;
        final kotNumber = message['kotNumber'];

        print('🔔 UniPOS: Order status updated - KOT #$kotNumber (Table $tableNo) → $status');

        // Show notification to user
        if (mounted && status != null) {
          NotificationService.instance.showSuccess('KOT #$kotNumber: Status updated to $status');
        }

        // UI will automatically refresh via ValueListenableBuilder
        // because server already updated Hive database
      } else if (type == 'ORDER_UPDATED' || type == 'NEW_ITEMS_ADDED') {
        final kotNumber = message['kotNumber'];
        final newItemCount = message['newItemCount'];
        final tableNo = message['tableNo'];

        print('🔔 UniPOS: Order updated - KOT #$kotNumber with $newItemCount new items');

        // Reload MobX store — updateOrderWithNewItems writes Hive directly, bypassing MobX
        await orderStore.loadOrders();

        // Show notification
        if (mounted) {
          NotificationService.instance.showSuccess('New KOT #$kotNumber: $newItemCount items added to Table $tableNo');
        }
      } else if (type == 'CANCEL_KOT') {
        final cancelKotNumber = message['cancelKotNumber'];
        final tableNo = message['tableNo'];
        final cancelledItems = message['cancelledItems'] as List? ?? [];
        final itemSummary = cancelledItems.map((i) =>
            '${i['quantity']}× ${i['title']}${i['variantName'] != null ? ' (${i['variantName']})' : ''}')
            .join(', ');

        print('🔔 UniPOS: Cancel KOT #$cancelKotNumber for Table $tableNo: $itemSummary');

        // Reload MobX store so UI reflects removed items
        await orderStore.loadOrders();

        if (mounted) {
          NotificationService.instance.showError(
            'Cancel KOT #$cancelKotNumber - Table $tableNo\n$itemSummary',
          );
        }
      } else if (type == 'NEW_ORDER') {
        final kotNumber = message['kotNumber'];
        final tableNo = message['tableNo'];

        print('🔔 UniPOS: New order received - KOT #$kotNumber (Table $tableNo)');

        // Show notification
        if (mounted) {
          NotificationService.instance.showSuccess('New Order: KOT #$kotNumber - Table $tableNo');
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _searchController.dispose();
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
      final order = orderStore.orders.where((o) => o.id == orderId).firstOrNull;

      if (order != null) {
        // Save to past orders as VOID so it appears in the Void Order Report
        final voidRecord = PastOrderModel(

          id: order.id,
          customerName: order.customerName ?? '',
          totalPrice: order.totalPrice,
          items: order.items,
          orderAt: order.timeStamp ?? DateTime.now(),
          orderType: order.orderType,
          paymentmode: 'N/A',
          subTotal: order.subTotal,
          gstAmount: order.gstAmount,
          Discount: order.discount,
          remark: order.remark,
          tableNo: order.tableNo,
          orderStatus: 'VOID',
          billNumber: order.billNumber,
          kotNumbers: order.kotNumbers,
          kotBoundaries: order.kotBoundaries,
          sessionId: order.sessionId, // Preserve sessionId for voided order
        );
        await pastOrderStore.addOrder(voidRecord);
      }

      await orderStore.deleteOrder(orderId);

      // Reset the table to Available so it no longer shows as occupied
      if (order?.tableNo != null && order!.tableNo!.isNotEmpty) {
        await tableStore.updateTableStatus(order.tableNo!, 'Available');
      }
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

// Status flow order for stepper
  static const _statusFlow = ['Processing', 'Cooking', 'Ready', 'Served'];

  static const _statusColors = {
    'Processing': Colors.grey,
    'Cooking': Colors.orange,
    'Ready': Colors.blue,
    'Served': Colors.green,
  };

  static const _statusIcons = {
    'Processing': Icons.hourglass_empty_rounded,
    'Cooking': Icons.local_fire_department_rounded,
    'Ready': Icons.room_service_rounded,
    'Served': Icons.check_circle_rounded,
  };

  int _statusIndex(String status) => _statusFlow.indexOf(status).clamp(0, 3);

// This function shows the main dialog with KOT-level status updates
  void _showStatusUpdateDialog(OrderModel order, bool istakeaway) {
    // Local mutable copy of KOT statuses — updated optimistically inside the dialog
    final kotStatuses = Map<int, String>.from(order.kotStatuses ?? {});
    for (var kotNum in order.kotNumbers) {
      kotStatuses.putIfAbsent(kotNum, () => order.status);
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // ── helpers ────────────────────────────────────────────────
            Future<void> updateOne(int kotNum, String newStatus) async {
              setDialogState(() => kotStatuses[kotNum] = newStatus);
              final allServed = order.kotNumbers.every((k) => kotStatuses[k] == 'Served');
              if (newStatus == 'Served' && allServed) {
                final latestOrder = orderStore.orders.firstWhere(
                  (o) => o.id == order.id, orElse: () => order);
                if (latestOrder.paymentStatus == 'Paid') {
                  Navigator.pop(dialogContext);
                  await _moveOrderToPast(latestOrder);
                  return;
                }
              }
              await _updateKotStatus(order, kotNum, newStatus);
            }

            Future<void> updateAll(String newStatus) async {
              for (final k in order.kotNumbers) {
                setDialogState(() => kotStatuses[k] = newStatus);
              }
              await Future.wait(
                order.kotNumbers.map((k) => _updateKotStatus(order, k, newStatus)),
              );
              if (newStatus == 'Served') {
                final latestOrder = orderStore.orders.firstWhere(
                  (o) => o.id == order.id, orElse: () => order);
                if (latestOrder.paymentStatus == 'Paid') {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _moveOrderToPast(latestOrder);
                }
              }
            }

            // ── derived state ──────────────────────────────────────────
            final allServed = order.kotNumbers.every((k) => kotStatuses[k] == 'Served');
            final overallStatus = _calculateOverallStatus(kotStatuses, order.kotNumbers);
            final hasMultipleKots = order.kotNumbers.length > 1;

            // ── UI ─────────────────────────────────────────────────────
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (order.tableNo != null && order.tableNo!.isNotEmpty)
                                      ? 'Table ${order.tableNo}'
                                      : order.orderType,
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _statusColors[overallStatus] ?? Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      overallStatus,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: _statusColors[overallStatus] ?? Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '  •  ${order.kotNumbers.length} KOT${order.kotNumbers.length > 1 ? 's' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close_rounded, color: Colors.grey.shade500, size: 22),
                          ),
                        ],
                      ),
                    ),

                    // ── Content ───────────────────────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── All Served banner ──────────────────────
                            if (allServed)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.check_rounded, color: Colors.green.shade700, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'All KOTs Served',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                          Text(
                                            'Order is ready for settlement',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.green.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // ── Bulk actions (multi-KOT, not all served) ──
                            if (hasMultipleKots && !allServed) ...[
                              Text(
                                'Quick Actions',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildBulkChip('All Cooking', Colors.orange, Icons.local_fire_department_rounded, () => updateAll('Cooking')),
                                  const SizedBox(width: 8),
                                  _buildBulkChip('All Ready', Colors.blue, Icons.room_service_rounded, () => updateAll('Ready')),
                                  const SizedBox(width: 8),
                                  _buildBulkChip('All Served', Colors.green, Icons.check_circle_rounded, () => updateAll('Served')),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ── KOT cards ─────────────────────────────
                            ...order.kotNumbers.map((kotNum) {
                              final currentStatus = kotStatuses[kotNum] ?? order.status;
                              final currentIdx = _statusIndex(currentStatus);
                              final kotIndex = order.kotNumbers.indexOf(kotNum);
                              final startIndex = kotIndex == 0 ? 0 : order.kotBoundaries[kotIndex - 1];
                              final endIndex = order.kotBoundaries[kotIndex];
                              final itemCount = endIndex - startIndex;
                              final isServed = currentStatus == 'Served';
                              final statusColor = _statusColors[currentStatus] ?? Colors.grey;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isServed ? Colors.green.shade200 : Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // KOT header
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _statusIcons[currentStatus] ?? Icons.receipt,
                                              color: statusColor,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'KOT #$kotNum',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '$itemCount item${itemCount > 1 ? 's' : ''}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Status badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isServed) ...[
                                                  Icon(Icons.check_rounded, size: 13, color: statusColor),
                                                  const SizedBox(width: 4),
                                                ],
                                                Text(
                                                  currentStatus,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Progress dots + next action (only if not served)
                                    if (!isServed)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                        child: Row(
                                          children: [
                                            // Compact dot progress indicator
                                            ...List.generate(_statusFlow.length, (i) {
                                              final dotColor = _statusColors[_statusFlow[i]]!;
                                              final isPast = i < currentIdx;
                                              final isCurrent = i == currentIdx;
                                              final isLast = i == _statusFlow.length - 1;

                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: isCurrent ? 22 : 14,
                                                    height: 14,
                                                    decoration: BoxDecoration(
                                                      color: (isPast || isCurrent)
                                                          ? dotColor
                                                          : Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: (isPast || isCurrent)
                                                        ? Icon(
                                                            isPast ? Icons.check_rounded : _statusIcons[_statusFlow[i]]!,
                                                            size: 10,
                                                            color: Colors.white,
                                                          )
                                                        : null,
                                                  ),
                                                  if (!isLast)
                                                    Container(
                                                      width: 8,
                                                      height: 2,
                                                      color: isPast
                                                          ? dotColor.withValues(alpha: 0.5)
                                                          : Colors.grey.shade200,
                                                    ),
                                                ],
                                              );
                                            }),

                                            const Spacer(),

                                            // Next step button
                                            if (currentIdx < _statusFlow.length - 1)
                                              () {
                                                final nextStatus = _statusFlow[currentIdx + 1];
                                                final nextColor = _statusColors[nextStatus]!;
                                                return SizedBox(
                                                  height: 32,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () => updateOne(kotNum, nextStatus),
                                                    icon: Icon(_statusIcons[nextStatus]!, size: 14),
                                                    label: Text(
                                                      nextStatus,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: nextColor,
                                                      foregroundColor: Colors.white,
                                                      elevation: 0,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }(),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    // ── Close button ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Quick action chip for bulk updates
  Widget _buildBulkChip(String label, Color color, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
        NotificationService.instance.showSuccess('KOT #$kotNumber updated to $newStatus');
      }
    } catch (e) {
      print('❌ Error updating KOT status: $e');
      if (mounted) {
        NotificationService.instance.showError('Failed to update status: $e');
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
    // Always use the latest version of the order from the store
    // (payment details may have been updated after the dialog was opened)
    final latestOrder = orderStore.orders.firstWhere(
      (o) => o.id == order.id,
      orElse: () => order,
    );

    // Reuse the stored bill number if payment was recorded earlier (Dine In paid-but-not-served flow),
    // otherwise generate a fresh one now.
    final int billNumber = latestOrder.billNumber ?? await orderStore.getNextBillNumber();

    final pastOrder = PastOrderModel(
      id: latestOrder.id,
      customerName: latestOrder.customerName,
      totalPrice: latestOrder.totalPrice,
      items: latestOrder.items,
      orderAt: latestOrder.timeStamp,
      orderType: latestOrder.orderType,
      paymentmode: latestOrder.paymentMethod ?? 'N/A',
      subTotal: latestOrder.subTotal,
      gstAmount: latestOrder.gstAmount,
      Discount: latestOrder.discount,
      remark: latestOrder.remark,
      kotNumbers: latestOrder.kotNumbers,
      kotBoundaries: latestOrder.kotBoundaries,
      billNumber: billNumber,
      isSplitPayment: latestOrder.isSplitPayment,
      paymentListJson: latestOrder.paymentListJson,
      totalPaid: latestOrder.totalPaid,
      changeReturn: latestOrder.changeReturn,
      tableNo: latestOrder.tableNo,
      sessionId: latestOrder.sessionId, // Preserve sessionId
    );

    await pastOrderStore.addOrder(pastOrder);
    await orderStore.deleteOrder(latestOrder.id);
    if (latestOrder.tableNo != null && latestOrder.tableNo!.isNotEmpty) {
      await tableStore.updateTableStatus(latestOrder.tableNo!, 'Available');
    }

    print("Order ${latestOrder.kotNumbers.isNotEmpty ? latestOrder.kotNumbers.first : latestOrder.id} moved to past orders (Bill #$billNumber).");
  }



  // Show dialog to select KOT for reprinting
  void _showKotPrintSelectionDialog(OrderModel order) {
    if (order.kotNumbers.isEmpty) {
      NotificationService.instance.showError('No KOTs found for this order');
      return;
    }

    // If only one KOT, print it directly
    if (order.kotNumbers.length == 1) {
      RestaurantPrintHelper.printKOT(
        context: context,
        order: order,
        kotNumber: order.kotNumbers.first,
        autoPrint: true,
      );
      return;
    }

    // If multiple KOTs, show selection dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select KOT to Reprint', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: order.kotNumbers.length,
              itemBuilder: (context, index) {
                final kotNum = order.kotNumbers[index];
                // Calculate item count for this KOT
                final startIndex = index == 0 ? 0 : order.kotBoundaries[index - 1];
                final endIndex = order.kotBoundaries[index];
                final itemCount = endIndex - startIndex;

                return ListTile(
                  leading: Icon(Icons.receipt_long, color: Colors.blue),
                  title: Text('KOT #$kotNum', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text('$itemCount items', style: GoogleFonts.poppins(fontSize: 12)),
                  trailing: Icon(Icons.print, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    RestaurantPrintHelper.printKOT(
                      context: context,
                      order: order,
                      kotNumber: kotNum,
                      autoPrint: true,
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Order Type Filter + Search Row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.white,
            child: Row(
              children: [
                // Search field takes available space
                Expanded(
                  child: AppTextField(
                    controller: _searchController,
                    hint: 'Search customer, table, KOT…',
                    icon: Icons.search_rounded,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  ),
                ),
                SizedBox(width: 10),
                // Compact dropdown
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider, width: 1.5),
                  ),
                  child: DropdownButton<String>(
                    value: dropDownValue,
                    isDense: true,
                    underline: SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textPrimary),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
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

                var filterOrderList = dropDownValue == 'All'
                    ? activeOrders
                    : activeOrders
                        .where((order) => order.orderType == dropDownValue)
                        .toList();

                // Apply search query: match customer name, table, or KOT number
                if (_searchQuery.isNotEmpty) {
                  filterOrderList = filterOrderList.where((order) {
                    final nameMatch = order.customerName.toLowerCase().contains(_searchQuery);
                    final tableMatch = (order.tableNo ?? '').toLowerCase().contains(_searchQuery);
                    final kotMatch = order.kotNumbers.any((k) => k.toString().contains(_searchQuery));
                    return nameMatch || tableMatch || kotMatch;
                  }).toList();
                }

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
                      onPrintKot: () => _showKotPrintSelectionDialog(order),
                      onPrintBill: () => RestaurantPrintHelper.printBillForActiveOrder(
                        context: context,
                        order: order,
                        currentItems: order.items,
                      ),
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