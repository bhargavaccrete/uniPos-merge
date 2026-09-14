import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/plan/plan_guard.dart';
import '../../../../core/plan/entitlement_keys.dart';
import '../../../../util/restaurant/restaurant_session.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/restaurant/componets/OrderCard.dart';
import '../start order/cart/cart.dart';
import '../../../../services/websocket_client_service.dart';
import '../../../../server/websocket.dart' as ws;
import '../util/restaurant_print_helper.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import '../../../../domain/services/restaurant/inventory_service.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../util/common/app_responsive.dart';

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

        // Show notification to user
        if (mounted && status != null) {
          NotificationService.instance.showSuccess(
            'KOT #$kotNumber: Status updated to $status',
          );
        }

        // UI will automatically refresh via ValueListenableBuilder
        // because server already updated Hive database
      } else if (type == 'ORDER_UPDATED' || type == 'NEW_ITEMS_ADDED') {
        final kotNumber = message['kotNumber'];
        final newItemCount = message['newItemCount'];
        final tableNo = message['tableNo'];

        // Reload MobX store — updateOrderWithNewItems writes Hive directly, bypassing MobX
        await orderStore.loadOrders();

        // Show notification
        if (mounted) {
          NotificationService.instance.showSuccess(
            'New KOT #$kotNumber: $newItemCount items added to Table $tableNo',
          );
        }
      } else if (type == 'CANCEL_KOT') {
        final cancelKotNumber = message['cancelKotNumber'];
        final tableNo = message['tableNo'];
        final cancelledItems = message['cancelledItems'] as List? ?? [];
        final itemSummary = cancelledItems
            .map(
              (i) =>
                  '${i['quantity']}× ${i['title']}${i['variantName'] != null ? ' (${i['variantName']})' : ''}',
            )
            .join(', ');

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

        // Show notification
        if (mounted) {
          NotificationService.instance.showSuccess(
            'New Order: KOT #$kotNumber - Table $tableNo',
          );
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
    // Plan gate — voiding a bill is billing.invoice.void. This path writes the
    // VOID record directly (not via RefundService), so it needs its own check.
    if (!PlanGuard.allowedOr(
      context,
      EntKeys.billingInvoiceVoid,
      featureName: 'Void Order',
    )) {
      return;
    }
    final String? voidReason = await _showVoidReasonDialog();
    if (voidReason == null) return;

    final order = orderStore.orders.where((o) => o.id == orderId).firstOrNull;

    if (order != null) {
      // A settled dine-in order stays in the active list until served, so it
      // can still be voided here. If it was already PAID, preserve the real
      // payment (method + amount + split) and mark it 'VOIDED' — so the Void
      // report shows it as paid (not "Unpaid") and a refund can be issued.
      // An unpaid order deleted before payment stays 'VOID' with 'N/A'.
      final bool wasPaid =
          order.isPaid == true ||
          (order.paymentStatus?.toLowerCase() == 'paid');
      // Save to past orders as VOID/VOIDED so it appears in the Void Order Report
      final voidRecord = PastOrderModel(
        id: order.id,
        customerName: order.customerName ?? '',
        totalPrice: order.totalPrice,
        items: order.items,
        orderAt: order.timeStamp ?? DateTime.now(),
        orderType: order.orderType,
        paymentmode: wasPaid ? (order.paymentMethod ?? 'N/A') : 'N/A',
        paymentListJson: wasPaid ? order.paymentListJson : null,
        isSplitPayment: wasPaid ? order.isSplitPayment : null,
        totalPaid: wasPaid ? order.totalPaid : null,
        subTotal: order.subTotal,
        gstAmount: order.gstAmount,
        Discount: order.discount,
        remark: order.remark,
        tableNo: order.tableNo,
        orderStatus: wasPaid ? 'VOIDED' : 'VOID',
        billNumber: order.billNumber,
        kotNumbers: order.kotNumbers,
        kotBoundaries: order.kotBoundaries,
        sessionId: order.sessionId,
        voidedBy: RestaurantSession.isAdmin
            ? 'Admin'
            : '${RestaurantSession.staffName ?? 'Staff'} (${RestaurantSession.effectiveRole})',
        voidReason: voidReason.isNotEmpty ? voidReason : null,
      );
      await pastOrderStore.addOrder(voidRecord);

      // Restore stock only for items in KOTs that have NOT been served yet.
      // Served KOT items were already consumed by the kitchen — don't restore.
      {
        final kotNums = order.kotNumbers;
        final kotBounds = order.kotBoundaries;
        final kotStatuses = Map<int, String>.from(order.kotStatuses ?? {});
        final itemsToRestock = <CartItem, int>{};

        int start = 0;
        for (int i = 0; i < kotNums.length; i++) {
          final kotNum = kotNums[i];
          final end = (i < kotBounds.length ? kotBounds[i] : order.items.length)
              .clamp(start, order.items.length);
          final kotStatus = kotStatuses[kotNum] ?? order.status;

          if (kotStatus != 'Served') {
            for (final item in order.items.sublist(start, end)) {
              if (item.quantity > 0) {
                itemsToRestock[item] =
                    (itemsToRestock[item] ?? 0) + item.quantity;
              }
            }
          }
          start = end;
        }

        if (itemsToRestock.isNotEmpty) {
          await InventoryService.restoreStockForRefund(itemsToRestock);
        }
      }
    }

    await orderStore.deleteOrder(orderId);

    // Reset the table to Available so it no longer shows as occupied
    if (order?.tableNo != null && order!.tableNo!.isNotEmpty) {
      await tableStore.updateTableStatus(order.tableNo!, 'Available');
    }
  }

  Future<String?> _showVoidReasonDialog() async {
    final reasonCtrl = TextEditingController();
    const quickReasons = [
      'Wrong order',
      'Customer cancelled',
      'Item unavailable',
      'Test order',
    ];

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogDisposeScope(
        disposables: [reasonCtrl],
        child: StatefulBuilder(
          builder: (ctx, setDialog) {
            return Dialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadius(context),
                ),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 40,
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  AppResponsive.extraLargeSpacing(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            AppResponsive.smallSpacing(context),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(
                              AppResponsive.smallBorderRadius(context),
                            ),
                          ),
                          child: Icon(
                            Icons.block,
                            size: AppResponsive.smallIconSize(context),
                            color: AppColors.danger,
                          ),
                        ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        Expanded(
                          child: Text(
                            'Void Order',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          icon: Icon(
                            Icons.close,
                            size: AppResponsive.smallIconSize(context),
                            color: AppColors.textSecondary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickReasons.map((r) {
                        final selected = reasonCtrl.text == r;
                        return GestureDetector(
                          onTap: () => setDialog(() {
                            reasonCtrl.text = r;
                            reasonCtrl.selection = TextSelection.collapsed(
                              offset: r.length,
                            );
                          }),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppResponsive.smallSpacing(context),
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.surfaceMedium,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.divider,
                              ),
                            ),
                            child: Text(
                              r,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    TextField(
                      controller: reasonCtrl,
                      autofocus: true,
                      onChanged: (_) => setDialog(() {}),
                      decoration: InputDecoration(
                        hintText: 'Or type a reason (optional)',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.mediumSpacing(context),
                          vertical: AppResponsive.smallSpacing(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppResponsive.smallBorderRadius(context),
                          ),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppResponsive.smallBorderRadius(context),
                          ),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppResponsive.smallBorderRadius(context),
                          ),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: AppResponsive.mediumSpacing(context),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: AppColors.divider),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(ctx, reasonCtrl.text.trim()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                vertical: AppResponsive.mediumSpacing(context),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Void Order',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    return result;
  }

  Color _getColorForStatus(String? status) {
    switch (status) {
      case 'Processing':
        return AppColors.danger; // New orders — needs attention
      case 'Cooking':
        return AppColors.danger; // Still in kitchen
      case 'Ready':
        return AppColors.warning; // Ready for pickup/serve
      case 'Served':
        return AppColors.success; // Served (awaiting payment)
      default:
        return AppColors.textSecondary; // Unknown status
    }
  }

  // In _ActiveorderState class

  // Status flow order for stepper
  static const _statusFlow = ['Processing', 'Cooking', 'Ready', 'Served'];

  static const _statusColors = {
    'Processing': AppColors.textSecondary,
    'Cooking': AppColors.warning,
    'Ready': AppColors.info,
    'Served': AppColors.success,
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
              final allServed = order.kotNumbers.every(
                (k) => kotStatuses[k] == 'Served',
              );
              if (newStatus == 'Served' && allServed) {
                final latestOrder = orderStore.orders.firstWhere(
                  (o) => o.id == order.id,
                  orElse: () => order,
                );
                if (latestOrder.isFullyPaid) {
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
              await _updateAllKotStatuses(order, order.kotNumbers, newStatus);
              if (newStatus == 'Served') {
                final latestOrder = orderStore.orders.firstWhere(
                  (o) => o.id == order.id,
                  orElse: () => order,
                );
                if (latestOrder.isFullyPaid) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _moveOrderToPast(latestOrder);
                }
              }
            }

            // ── derived state ──────────────────────────────────────────
            final allServed = order.kotNumbers.every(
              (k) => kotStatuses[k] == 'Served',
            );
            final overallStatus = _calculateOverallStatus(
              kotStatuses,
              order.kotNumbers,
            );
            final hasMultipleKots = order.kotNumbers.length > 1;

            // ── UI ─────────────────────────────────────────────────────
            return Dialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ────────────────────────────────────────
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        AppResponsive.largeSpacing(context),
                        AppResponsive.largeSpacing(context),
                        AppResponsive.mediumSpacing(context),
                        AppResponsive.largeSpacing(context),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              AppResponsive.smallSpacing(context),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppResponsive.borderRadius(context),
                              ),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              size: AppResponsive.iconSize(context),
                            ),
                          ),
                          SizedBox(width: AppResponsive.mediumSpacing(context)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (order.tableNo != null &&
                                          order.tableNo!.isNotEmpty)
                                      ? 'Table ${order.tableNo}'
                                      : order.orderType,
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.subheadingFontSize(
                                      context,
                                    ),
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
                                        color:
                                            _statusColors[overallStatus] ??
                                            AppColors.textSecondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      overallStatus,
                                      style: GoogleFonts.poppins(
                                        fontSize: AppResponsive.smallFontSize(
                                          context,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        color:
                                            _statusColors[overallStatus] ??
                                            AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '  •  ${order.kotNumbers.length} KOT${order.kotNumbers.length > 1 ? 's' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: AppResponsive.smallFontSize(
                                          context,
                                        ),
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.textSecondary,
                              size: AppResponsive.iconSize(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Content ───────────────────────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          AppResponsive.largeSpacing(context),
                          AppResponsive.largeSpacing(context),
                          AppResponsive.largeSpacing(context),
                          AppResponsive.largeSpacing(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── All Served banner ──────────────────────
                            if (allServed)
                              Container(
                                width: double.infinity,
                                padding: AppResponsive.padding(context),
                                margin: EdgeInsets.only(
                                  bottom: AppResponsive.largeSpacing(context),
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(
                                    AppResponsive.borderRadius(context),
                                  ),
                                  border: Border.all(
                                    color: AppColors.success.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                        AppResponsive.smallSpacing(context),
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(
                                          0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_rounded,
                                        color: AppColors.success,
                                        size: AppResponsive.iconSize(context),
                                      ),
                                    ),
                                    SizedBox(
                                      width: AppResponsive.mediumSpacing(
                                        context,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'All KOTs Served',
                                            style: GoogleFonts.poppins(
                                              fontSize:
                                                  AppResponsive.bodyFontSize(
                                                    context,
                                                  ),
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
                                            ),
                                          ),
                                          Text(
                                            'Order is ready for settlement',
                                            style: GoogleFonts.poppins(
                                              fontSize:
                                                  AppResponsive.smallFontSize(
                                                    context,
                                                  ),
                                              color: AppColors.success,
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
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(
                                height: AppResponsive.smallSpacing(context),
                              ),
                              Row(
                                children: [
                                  _buildBulkChip(
                                    'All Cooking',
                                    AppColors.warning,
                                    Icons.local_fire_department_rounded,
                                    () => updateAll('Cooking'),
                                  ),
                                  SizedBox(
                                    width: AppResponsive.smallSpacing(context),
                                  ),
                                  _buildBulkChip(
                                    'All Ready',
                                    AppColors.info,
                                    Icons.room_service_rounded,
                                    () => updateAll('Ready'),
                                  ),
                                  SizedBox(
                                    width: AppResponsive.smallSpacing(context),
                                  ),
                                  _buildBulkChip(
                                    'All Served',
                                    AppColors.success,
                                    Icons.check_circle_rounded,
                                    () => updateAll('Served'),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: AppResponsive.largeSpacing(context),
                              ),
                            ],

                            // ── KOT cards ─────────────────────────────
                            ...order.kotNumbers.map((kotNum) {
                              final currentStatus =
                                  kotStatuses[kotNum] ?? order.status;
                              final currentIdx = _statusIndex(currentStatus);
                              final kotIndex = order.kotNumbers.indexOf(kotNum);
                              // Defensive: KOT boundaries can drift past the item
                              // count (e.g. items removed) — clamp so sublist()
                              // never throws a RangeError while rendering.
                              final int itemLen = order.items.length;
                              final int endIndex =
                                  (kotIndex < order.kotBoundaries.length
                                          ? order.kotBoundaries[kotIndex]
                                          : itemLen)
                                      .clamp(0, itemLen);
                              final int startIndex =
                                  (kotIndex == 0
                                          ? 0
                                          : order.kotBoundaries[kotIndex - 1])
                                      .clamp(0, endIndex);
                              final itemCount = endIndex - startIndex;
                              final isServed = currentStatus == 'Served';
                              final statusColor =
                                  _statusColors[currentStatus] ??
                                  AppColors.textSecondary;

                              return Container(
                                margin: EdgeInsets.only(
                                  bottom: AppResponsive.mediumSpacing(context),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppResponsive.borderRadius(context),
                                  ),
                                  border: Border.all(
                                    color: isServed
                                        ? AppColors.success.withOpacity(0.4)
                                        : AppColors.divider,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // KOT header
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        AppResponsive.mediumSpacing(context),
                                        AppResponsive.mediumSpacing(context),
                                        AppResponsive.mediumSpacing(context),
                                        AppResponsive.smallSpacing(context),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(
                                              AppResponsive.smallSpacing(
                                                context,
                                              ),
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _statusIcons[currentStatus] ??
                                                  Icons.receipt,
                                              color: statusColor,
                                              size: AppResponsive.smallIconSize(
                                                context,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: AppResponsive.smallSpacing(
                                              context,
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'KOT #$kotNum',
                                                  style: GoogleFonts.poppins(
                                                    fontSize:
                                                        AppResponsive.bodyFontSize(
                                                          context,
                                                        ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '$itemCount item${itemCount > 1 ? 's' : ''}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize:
                                                        AppResponsive.smallFontSize(
                                                          context,
                                                        ),
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Status badge
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  AppResponsive.smallSpacing(
                                                    context,
                                                  ),
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: statusColor.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isServed) ...[
                                                  Icon(
                                                    Icons.check_rounded,
                                                    size: 13,
                                                    color: statusColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                Text(
                                                  currentStatus,
                                                  style: GoogleFonts.poppins(
                                                    fontSize:
                                                        AppResponsive.captionFontSize(
                                                          context,
                                                        ),
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
                                        padding: EdgeInsets.fromLTRB(
                                          AppResponsive.mediumSpacing(context),
                                          0,
                                          AppResponsive.mediumSpacing(context),
                                          AppResponsive.mediumSpacing(context),
                                        ),
                                        child: Row(
                                          children: [
                                            // Compact dot progress indicator
                                            ...List.generate(_statusFlow.length, (
                                              i,
                                            ) {
                                              final dotColor =
                                                  _statusColors[_statusFlow[i]]!;
                                              final isPast = i < currentIdx;
                                              final isCurrent = i == currentIdx;
                                              final isLast =
                                                  i == _statusFlow.length - 1;

                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: isCurrent ? 22 : 14,
                                                    height: 14,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          (isPast || isCurrent)
                                                          ? dotColor
                                                          : AppColors.divider,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            7,
                                                          ),
                                                    ),
                                                    child: (isPast || isCurrent)
                                                        ? Icon(
                                                            isPast
                                                                ? Icons
                                                                      .check_rounded
                                                                : _statusIcons[_statusFlow[i]]!,
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
                                                          ? dotColor.withValues(
                                                              alpha: 0.5,
                                                            )
                                                          : AppColors.divider,
                                                    ),
                                                ],
                                              );
                                            }),

                                            const Spacer(),

                                            // Next step button
                                            if (currentIdx <
                                                _statusFlow.length - 1)
                                              () {
                                                final nextStatus =
                                                    _statusFlow[currentIdx + 1];
                                                final nextColor =
                                                    _statusColors[nextStatus]!;
                                                return SizedBox(
                                                  height: 32,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () => updateOne(
                                                      kotNum,
                                                      nextStatus,
                                                    ),
                                                    icon: Icon(
                                                      _statusIcons[nextStatus]!,
                                                      size: 14,
                                                    ),
                                                    label: Text(
                                                      nextStatus,
                                                      style: GoogleFonts.poppins(
                                                        fontSize:
                                                            AppResponsive.smallFontSize(
                                                              context,
                                                            ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          nextColor,
                                                      foregroundColor:
                                                          Colors.white,
                                                      elevation: 0,
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal:
                                                            AppResponsive.mediumSpacing(
                                                              context,
                                                            ),
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppResponsive.smallBorderRadius(
                                                                context,
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }(),
                                          ],
                                        ),
                                      ),

                                    // Item list for this KOT — cancel buttons shown only for non-served KOTs
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        AppResponsive.mediumSpacing(context),
                                        0,
                                        AppResponsive.mediumSpacing(context),
                                        AppResponsive.smallSpacing(context),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Divider(
                                            height: 16,
                                            color: AppColors.divider,
                                          ),
                                          ...order.items.sublist(startIndex, endIndex).asMap().entries.map((
                                            e,
                                          ) {
                                            final item = e.value;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 3,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${item.quantity}×',
                                                      style: GoogleFonts.poppins(
                                                        fontSize:
                                                            AppResponsive.captionFontSize(
                                                              context,
                                                            ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width:
                                                        AppResponsive.smallSpacing(
                                                          context,
                                                        ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      '${item.title}${item.variantName != null ? ' (${item.variantName})' : ''}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize:
                                                            AppResponsive.smallFontSize(
                                                              context,
                                                            ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (!isServed)
                                                    InkWell(
                                                      onTap: () =>
                                                          _cancelKotItem(
                                                            order: order,
                                                            kotIndex: kotIndex,
                                                            itemIndexInOrder:
                                                                startIndex +
                                                                e.key,
                                                            dialogContext:
                                                                dialogContext,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppResponsive.borderRadius(
                                                              context,
                                                            ),
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4,
                                                            ),
                                                        child: Icon(
                                                          Icons.cancel_outlined,
                                                          size:
                                                              AppResponsive.smallIconSize(
                                                                context,
                                                              ),
                                                          color: AppColors
                                                              .danger
                                                              .withOpacity(0.6),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
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
                      padding: EdgeInsets.fromLTRB(
                        AppResponsive.largeSpacing(context),
                        0,
                        AppResponsive.largeSpacing(context),
                        AppResponsive.largeSpacing(context),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: AppResponsive.mediumSpacing(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppResponsive.borderRadius(context),
                              ),
                            ),
                            side: BorderSide(color: AppColors.divider),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
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
  Widget _buildBulkChip(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: AppResponsive.smallSpacing(context),
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppResponsive.smallIconSize(context),
                color: color,
              ),
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

  Future<void> _updateAllKotStatuses(
    OrderModel orderParam,
    List<int> kotNumbers,
    String newStatus,
  ) async {
    try {
      // Fetch the latest version from the store to prevent stale writes
      final order = orderStore.orders.firstWhere(
        (o) => o.id == orderParam.id,
        orElse: () => orderParam,
      );

      // Update KOT status map for all KOTs in one go
      Map<int, String> updatedKotStatuses = Map<int, String>.from(
        order.kotStatuses ?? {},
      );
      for (var kotNumber in kotNumbers) {
        updatedKotStatuses[kotNumber] = newStatus;
      }

      // Calculate overall order status
      String overallStatus = _calculateOverallStatus(
        updatedKotStatuses,
        order.kotNumbers,
      );

      // Update the order in database in a single atomic write
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
      }

      // Broadcast to KDS via WebSocket for each KOT to preserve compatibility
      try {
        final kotStatusesJson = updatedKotStatuses.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        for (var kotNumber in kotNumbers) {
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
        }
      } catch (e) {
        // Silently catch WS broadcast errors
      }

      // Show success message
      if (mounted) {
        NotificationService.instance.showSuccess(
          'All KOTs updated to $newStatus',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Failed to update status: $e');
      }
    }
  }

  // ACTION 1: Updates KOT status and syncs with KDS
  Future<void> _updateKotStatus(
    OrderModel orderParam,
    int kotNumber,
    String newStatus,
  ) async {
    try {
      // Fetch the latest version from the store to prevent stale writes
      final order = orderStore.orders.firstWhere(
        (o) => o.id == orderParam.id,
        orElse: () => orderParam,
      );

      // Update KOT status map
      Map<int, String> updatedKotStatuses = Map<int, String>.from(
        order.kotStatuses ?? {},
      );
      updatedKotStatuses[kotNumber] = newStatus;

      // Calculate overall order status
      String overallStatus = _calculateOverallStatus(
        updatedKotStatuses,
        order.kotNumbers,
      );

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
      }

      // Broadcast to KDS via WebSocket
      try {
        // Convert integer keys to strings for JSON encoding
        final kotStatusesJson = updatedKotStatuses.map(
          (key, value) => MapEntry(key.toString(), value),
        );

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
      } catch (e) {}

      // Show success message
      if (mounted) {
        NotificationService.instance.showSuccess(
          'KOT #$kotNumber updated to $newStatus',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Failed to update status: $e');
      }
    }
  }

  // Helper function to calculate overall order status from KOT statuses
  String _calculateOverallStatus(
    Map<int, String> kotStatuses,
    List<int> kotNumbers,
  ) {
    if (kotStatuses.isEmpty) return 'Processing';

    // Get all statuses
    final statuses = kotNumbers
        .map((kot) => kotStatuses[kot] ?? 'Processing')
        .toList();

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
    final int billNumber =
        latestOrder.billNumber ?? await orderStore.getNextBillNumber();

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
      sessionId: latestOrder.sessionId,
      serviceCharge: latestOrder.serviceCharge,
      isTaxInclusive: latestOrder.isTaxInclusive,
    );

    await pastOrderStore.addOrder(pastOrder);
    await orderStore.deleteOrder(latestOrder.id);
    if (latestOrder.tableNo != null && latestOrder.tableNo!.isNotEmpty) {
      await tableStore.updateTableStatus(latestOrder.tableNo!, 'Available');
    }
  }

  Future<void> _cancelKotItem({
    required OrderModel order,
    required int kotIndex,
    required int itemIndexInOrder,
    required BuildContext dialogContext,
  }) async {
    final item = order.items[itemIndexInOrder];
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Cancel Item?',
      message:
          'Remove ${item.quantity}× ${item.title}${item.variantName != null ? ' (${item.variantName})' : ''} from KOT #${order.kotNumbers[kotIndex]}?',
      confirmLabel: 'Cancel Item',
      cancelLabel: 'Keep',
      accent: AppColors.danger,
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmed) return;

    // 1. Remove item from the list
    final updatedItems = List<CartItem>.from(order.items)
      ..removeAt(itemIndexInOrder);

    // 2. Adjust boundaries: every boundary at index >= kotIndex decreases by 1
    final updatedBoundaries = List<int>.from(order.kotBoundaries);
    for (int i = kotIndex; i < updatedBoundaries.length; i++) {
      updatedBoundaries[i] = updatedBoundaries[i] - 1;
    }

    // 3. If this KOT is now empty, remove it from both lists
    final updatedNumbers = List<int>.from(order.kotNumbers);
    final updatedStatuses = Map<int, String>.from(order.kotStatuses ?? {});
    final prevBoundary = kotIndex == 0 ? 0 : updatedBoundaries[kotIndex - 1];
    if (updatedBoundaries[kotIndex] == prevBoundary) {
      final removedKotNumber = updatedNumbers[kotIndex];
      updatedNumbers.removeAt(kotIndex);
      updatedBoundaries.removeAt(kotIndex);
      updatedStatuses.remove(removedKotNumber);
    }

    // 4. Recalculate total
    final newTotal = order.totalPrice - (item.finalItemPrice * item.quantity);

    // 5. Persist the updated order
    final updatedOrder = order.copyWith(
      items: updatedItems,
      kotNumbers: updatedNumbers,
      kotBoundaries: updatedBoundaries,
      kotStatuses: updatedStatuses,
      totalPrice: newTotal.clamp(0, double.infinity),
      itemCountAtLastKot: updatedItems.length,
    );
    await orderStore.updateOrder(updatedOrder);

    // 6. Restore inventory stock
    await InventoryService.restoreStockForOrder([item]);

    // 7. Broadcast cancellation to KDS
    ws.broadcastEvent({
      'type': 'CANCEL_KOT_ITEM',
      'orderId': order.id,
      'orderNumber': order.orderNumber,
      'kotNumber': order.kotNumbers[kotIndex],
      'tableNo': order.tableNo,
      'cancelledItem': item.title,
    });

    // 8. Close the status dialog
    if (dialogContext.mounted) Navigator.pop(dialogContext);

    // 9. Notify user
    NotificationService.instance.showInfo(
      '${item.quantity}× ${item.title} removed from KOT',
    );
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
    final reprintHInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                      AppResponsive.dialogWidth(context)) /
                  2)
              .clamp(40.0, double.infinity)
        : 24.0;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: reprintHInset,
            vertical: AppResponsive.extraLargeSpacing(context),
          ),
          title: Text(
            'Select KOT to Reprint',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: order.kotNumbers.length,
              itemBuilder: (context, index) {
                final kotNum = order.kotNumbers[index];
                // Calculate item count for this KOT (clamp against item count so
                // a drifted boundary can't crash sublist/rendering).
                final int itemLen = order.items.length;
                final int endIndex =
                    (index < order.kotBoundaries.length
                            ? order.kotBoundaries[index]
                            : itemLen)
                        .clamp(0, itemLen);
                final int startIndex =
                    (index == 0 ? 0 : order.kotBoundaries[index - 1]).clamp(
                      0,
                      endIndex,
                    );
                final itemCount = endIndex - startIndex;

                return ListTile(
                  leading: Icon(Icons.receipt_long, color: AppColors.info),
                  title: Text(
                    'KOT #$kotNum',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '$itemCount items',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                    ),
                  ),
                  trailing: Icon(Icons.print, color: AppColors.textSecondary),
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
    final isTablet = !AppResponsive.isMobile(context);
    final hPad = isTablet ? 20.0 : 12.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Order Type Filter + Search Row
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: AppResponsive.smallSpacing(context),
            ),
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
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.textSecondary,
                              size: AppResponsive.smallIconSize(context),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                  ),
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                // Compact dropdown
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.smallSpacing(context),
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                    border: Border.all(color: AppColors.divider, width: 1.5),
                  ),
                  child: DropdownButton<String>(
                    value: dropDownValue,
                    isDense: true,
                    underline: SizedBox(),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      size: AppResponsive.iconSize(context),
                      color: AppColors.textPrimary,
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    items: dropdownItems.map((String item) {
                      return DropdownMenuItem(value: item, child: Text(item));
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
                    .where(
                      (order) =>
                          order.status != 'Served' ||
                          (order.status == 'Served' &&
                              order.paymentStatus != 'Paid'),
                    )
                    .toList();

                activeOrders.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));

                if (activeOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: AppResponsive.getValue(
                            context,
                            mobile: 64.0,
                            tablet: 76.0,
                            desktop: 88.0,
                          ),
                          color: AppColors.divider,
                        ),
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        Text(
                          'No active orders',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: AppResponsive.subheadingFontSize(context),
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
                    final nameMatch = order.customerName.toLowerCase().contains(
                      _searchQuery,
                    );
                    final tableMatch = (order.tableNo ?? '')
                        .toLowerCase()
                        .contains(_searchQuery);
                    final kotMatch = order.kotNumbers.any(
                      (k) => k.toString().contains(_searchQuery),
                    );
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
                          size: AppResponsive.getValue(
                            context,
                            mobile: 64.0,
                            tablet: 76.0,
                            desktop: 88.0,
                          ),
                          color: AppColors.divider,
                        ),
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        Text(
                          'No orders of type "$dropDownValue"',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: AppResponsive.subheadingFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Tablet: 2-column wrap layout (variable-height cards)
                if (isTablet) {
                  return LayoutBuilder(
                    builder: (ctx, constraints) {
                      final cols = AppResponsive.gridColumns(
                        context,
                        mobile: 1,
                        tablet: 1,
                        desktop: 2,
                      );
                      final spacing = AppResponsive.gridSpacing(context);
                      // Derive the inset from the SAME EdgeInsets the scroll
                      // view uses. This was a hardcoded `- 32` that matched the
                      // old `EdgeInsets.all(16)`; once the padding became
                      // responsive (16/20/24) the two drifted, each card came
                      // out too wide for the row, and the 2-column desktop
                      // layout silently collapsed to one card per row.
                      final pad = AppResponsive.padding(context);
                      final cardWidth =
                          (constraints.maxWidth -
                              pad.horizontal -
                              spacing * (cols - 1)) /
                          cols;
                      return SingleChildScrollView(
                        padding: pad,
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: filterOrderList
                              .map(
                                (order) => SizedBox(
                                  width: cardWidth,
                                  child: OrderCard(
                                    color: _getColorForStatus(order.status),
                                    order: order,
                                    onDelete: _deleteOrder,
                                    onPrintKot: () =>
                                        _showKotPrintSelectionDialog(order),
                                    onPrintBill: () =>
                                        RestaurantPrintHelper.printBillForActiveOrder(
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
                                          order,
                                          order.orderType == 'Take Away',
                                        );
                                      }
                                    },
                                    ontap: () async {
                                      if (!order.isFullyPaid) {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CartScreen(
                                              existingOrder: order,
                                              selectedTableNo: order.tableNo,
                                            ),
                                          ),
                                        );
                                      } else if (orderHasMoreToShow(order)) {
                                        // Paid orders can't be edited, so the
                                        // cart is the wrong destination — but
                                        // tapping used to do nothing at all.
                                        // Show the order read-only instead,
                                        // and only when the card isn't already
                                        // showing the whole thing.
                                        await showOrderItemsDialog(
                                          context,
                                          order,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  );
                }

                // Mobile: original single-column list (unchanged)
                return ListView.builder(
                  padding: AppResponsive.padding(context),
                  itemCount: filterOrderList.length,
                  itemBuilder: (context, index) {
                    final order = filterOrderList[index];
                    return OrderCard(
                      color: _getColorForStatus(order.status),
                      order: order,
                      onDelete: _deleteOrder,
                      onPrintKot: () => _showKotPrintSelectionDialog(order),
                      onPrintBill: () =>
                          RestaurantPrintHelper.printBillForActiveOrder(
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
                            order,
                            order.orderType == 'Take Away' ? true : false,
                          );
                        }
                      },
                      ontap: () async {
                        if (order.isPaid != true) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CartScreen(
                                existingOrder: order,
                                selectedTableNo: order.tableNo,
                              ),
                            ),
                          );
                        } else if (orderHasMoreToShow(order)) {
                          // Was an empty `else {}` — a paid order's tap did
                          // nothing. Show it read-only instead, but only when
                          // the card isn't already showing everything.
                          await showOrderItemsDialog(context, order);
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
                          fontSize: AppResponsive.getValue(context, mobile: 28.0, tablet: 32.0, desktop: 36.0),
                          color: AppColors.textPrimary,
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
