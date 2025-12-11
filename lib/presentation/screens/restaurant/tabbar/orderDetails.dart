import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/database/hive_db.dart';
import '../../../../data/models/restaurant/db/database/hive_pastorder.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import 'partial_refund_dialog.dart';

class Orderdetails extends StatefulWidget {
  final pastOrderModel? Order;
  const Orderdetails({super.key, this.Order});

  @override
  State<Orderdetails> createState() => _OrderdetailsState();
}

class _OrderdetailsState extends State<Orderdetails> {
  late pastOrderModel currentOrder;

  @override
  void initState() {
    super.initState();
    if (widget.Order == null) return;
    currentOrder = widget.Order!;
  }

  String _money(num? v) => '₹${(v ?? 0).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (widget.Order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Order Not Found')),
      );
    }

    final items = currentOrder.items ?? <CartItem>[];
    final String status = currentOrder.orderStatus ?? 'COMPLETED';
    final bool isFullyRefunded = status == 'FULLY_REFUNDED';
    final bool isPartiallyRefunded = status == 'PARTIALLY_REFUNDED';

    bool isRefundEligible = false;
    if (!isFullyRefunded && currentOrder.orderAt != null) {
      final minuteSinceOrder = DateTime.now().difference(currentOrder.orderAt!).inMinutes;
      if (minuteSinceOrder <= 60) {
        isRefundEligible = true;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading:
        IconButton(onPressed: (){
          Navigator.pop(context);

        }, icon: Icon(Icons.arrow_back,color: Colors.white,)),

        backgroundColor: primarycolor,
        title: Text('Order Details', style: GoogleFonts.poppins(color: Colors.white)),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Void',
                color: Colors.red,
                onTap: () => _deleteOrder(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                label: 'Print',
                outlined: true,
                onTap: () {
                  // TODO: print flow
                },
              ),
            ),
            const SizedBox(width: 12),
            if (!isFullyRefunded)
              Expanded(
                child: _ActionBtn(
                  label: 'Refund',
                  color: isRefundEligible ? Colors.orange : Colors.grey,
                  onTap: () => _showRefundDialog(context),
                ),
              ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // KOT Numbers Display Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.blue.shade700, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Kitchen Order Tickets (KOT)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentOrder.getKotNumbers().map((kotNum) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'KOT #$kotNum',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if ((currentOrder.kotNumbers?.length ?? 1) > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${(currentOrder.kotNumbers?.length ?? 1)} KOT(s) generated for this order',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isFullyRefunded || isPartiallyRefunded)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.replaceAll('_', ' '),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orange.shade800),
                    ),
                    const SizedBox(height: 4),
                    _kv('Total Refunded', _money(currentOrder.refundAmount)),
                    if ((currentOrder.refundReason ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Reason(s): ${currentOrder.refundReason}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                      ),
                    if (currentOrder.refundedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Last Refund At: ${_fmtDate(currentOrder.refundedAt!)}',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _headCell('QTY', flex: 2),
                  _headCell('Item', flex: 7),
                  _headCell('Amount', flex: 3, alignEnd: true),
                ],
              ),
            ),
          ),
          // === DISPLAY ITEMS GROUPED BY KOT ===
          ...(() {
            // Get items grouped by KOT number
            final Map<int, List<CartItem>> itemsByKot = currentOrder.getItemsByKot();

            List<Widget> kotSections = [];

            itemsByKot.forEach((kotNum, kotItems) {
              // KOT Header
              kotSections.add(
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade500],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'KOT #$kotNum',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${kotItems.length} item${kotItems.length > 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              // Items in this KOT
              kotSections.add(
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: kotItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final it = kotItems[index];
                      final originalQty = it.quantity ?? 0;
                      final refundedQty = it.refundedQuantity ?? 0;
                      final remainingQty = originalQty - refundedQty;
                      final bool itemIsFullyRefunded = refundedQty > 0 && refundedQty >= originalQty;

                      // Calculate line total with proper discount and tax handling
                      final basePrice = it.price; // Original price
                      final itemDiscount = it.discount ?? 0.0; // Item-level discount
                      final priceAfterItemDiscount = it.finalItemPrice; // price - item.discount

                      double finalPricePerItem;

                      // Check if discount is on items (item.discount > 0) or on bill (order.Discount > 0)
                      if (itemDiscount > 0) {
                        // Discount is applied to individual items
                        // Tax is calculated on discounted price
                        final taxAmount = priceAfterItemDiscount * (it.taxRate ?? 0.0);
                        finalPricePerItem = priceAfterItemDiscount + taxAmount;
                      } else {
                        // Discount is on total bill - distribute proportionally
                        // Calculate total value of ALL items for proportional discount
                        double totalItemsValue = 0.0;
                        for (var orderItem in items) {
                          totalItemsValue += orderItem.finalItemPrice * (orderItem.quantity ?? 0);
                        }

                        // Calculate this item's proportional share of order discount
                        double itemDiscountShare = 0.0;
                        final orderDiscount = currentOrder.Discount ?? 0.0;
                        if (totalItemsValue > 0 && orderDiscount > 0) {
                          final itemProportion = priceAfterItemDiscount / totalItemsValue;
                          itemDiscountShare = orderDiscount * itemProportion;
                        }

                        // Apply order discount and tax
                        final priceAfterOrderDiscount = priceAfterItemDiscount - itemDiscountShare;
                        final taxAmount = priceAfterOrderDiscount * (it.taxRate ?? 0.0);
                        finalPricePerItem = priceAfterOrderDiscount + taxAmount;
                      }

                      final lineTotal = finalPricePerItem * remainingQty;

                      return Card(
                        elevation: 0,
                        color: itemIsFullyRefunded ? Colors.grey.shade200 : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '$remainingQty',
                                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(it.title?.toString() ?? '—',
                                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                                        // This is where _metaChip was missing
                                        if (it.variantName != null) _metaChip(it.variantName!),
                                        // Display tax information
                                        if (it.taxRate != null && it.taxRate! > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.receipt, size: 12, color: Colors.grey.shade600),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Tax: ${(it.taxRate! * 100).toStringAsFixed(0)}% (₹${(priceAfterItemDiscount * it.taxRate!).toStringAsFixed(2)})',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        _money(lineTotal),
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (refundedQty > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                                  child: Text(
                                    'Refunded: $refundedQty of $originalQty',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: itemIsFullyRefunded ? Colors.red.shade700 : Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            });

            return kotSections;
          })(),
          // CORRECTED AND IMPROVED TOTALS SECTION
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  children: [
                    _totalRow('Sub Total', _money(currentOrder.subTotal)),
                    if ((currentOrder.Discount ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _totalRow('Discount', _money(currentOrder.Discount)),
                    ],
                    if ((currentOrder.gstAmount ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _totalRow('Total GST', _money(currentOrder.gstAmount)),
                    ],

                    // Display the original total before refunds
                    _totalRow('Grand Total', _money(currentOrder.totalPrice)),

                    // --- FIX: Show the refunded amount as a deduction ---
                    if ((currentOrder.refundAmount ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _totalRow(
                        'Refunded Amount',
                        '-${_money(currentOrder.refundAmount)}',
                        color: Colors.orange.shade800,
                      ),
                    ],
                    const Divider(height: 20),

                    // --- FIX: Calculate and display the final payable amount ---
                    _totalRow(
                      'Net Payable',
                      _money((currentOrder.totalPrice ?? 0) - (currentOrder.refundAmount ?? 0)),
                      isStrong: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS AND FUNCTIONS (ADD ALL OF THESE) ---

  Widget _headCell(String text, {int flex = 1, bool alignEnd = false}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isStrong = false, Color? color}) {
    final style = GoogleFonts.poppins(
      fontSize: isStrong ? 16 : 14,
      fontWeight: isStrong ? FontWeight.w700 : FontWeight.w600,
      color: color, // Use the color if provided
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade800)),
        Text(v, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _showRefundDialog(BuildContext context) async {
    if (currentOrder.orderAt == null) {
      NotificationService.instance.showInfo('Order time is missing. Cannot process refund.');
      return;
    }
    final minutePassed = DateTime.now().difference(currentOrder.orderAt!).inMinutes;
    if (minutePassed > 60) {
      NotificationService.instance.showInfo('Refund window (60 minutes) has passed.');
      return;
    }

    final subTotal = currentOrder.subTotal ?? 0;
    final gstAmount = currentOrder.gstAmount ?? 0;
    final gstRate = (subTotal > 0) ? (gstAmount / subTotal) : 0.0;

    final refundableItems = currentOrder.items?.where((item) {
      final originalQty = item.quantity ?? 0;
      final alreadyRefunded = item.refundedQuantity ?? 0;
      return originalQty > alreadyRefunded;
    }).toList() ?? [];

    if (refundableItems.isEmpty) {
      NotificationService.instance.showError('All items in this order have already been refunded.');
      return;
    }

    // Calculate remaining order total (original - already refunded)
    final originalTotal = currentOrder.totalPrice ?? 0.0;
    final alreadyRefunded = currentOrder.refundAmount ?? 0.0;
    final remainingTotal = originalTotal - alreadyRefunded;

    final result = await showDialog<PartialRefundResult>(
      context: context,
      builder: (ctx) => PartialRefundDialog(
        orderItems: refundableItems,
        allOrderItems: currentOrder.items ?? [], // Pass ALL items for discount calculation
        orderGstRate: gstRate,
        orderTotalPrice: remainingTotal, // Pass remaining amount that can be refunded
        orderDiscount: currentOrder.Discount ?? 0.0, // Pass the order-level discount
        orderSubTotal: currentOrder.subTotal ?? 0.0, // Pass the subtotal
      ),
    );

    if (result != null) {
      await _processPartialRefund(result);
    }
  }

  Future<void> _processPartialRefund(PartialRefundResult result) async {
    try {
      final List<CartItem> updatedItems = List<CartItem>.from(currentOrder.items ?? []);

      result.itemsToRefund.forEach((itemToRefund, quantityToRefund) {
        final index = updatedItems.indexWhere((item) =>
        item.id == itemToRefund.id &&
            item.productId == itemToRefund.productId &&
            item.variantName == itemToRefund.variantName);
        if (index != -1) {
          final currentItem = updatedItems[index];
          final newRefundedQuantity = (currentItem.refundedQuantity ?? 0) + quantityToRefund;
          updatedItems[index] = currentItem.copyWith(refundedQuantity: newRefundedQuantity);
        }
      });

      bool allItemsRefunded = updatedItems.every((item) {
        final originalQty = item.quantity ?? 0;
        final refundedQty = item.refundedQuantity ?? 0;
        return refundedQty >= originalQty;
      });

      final newStatus = allItemsRefunded ? 'FULLY_REFUNDED' : 'PARTIALLY_REFUNDED';

      final updatedOrder = currentOrder.copyWith(
        items: updatedItems,
        orderStatus: newStatus,
        refundAmount: (currentOrder.refundAmount ?? 0) + result.totalRefundAmount,
        refundReason: (currentOrder.refundReason ?? '') + '\n[${DateTime.now().toLocal().toString().substring(0, 16)}] ${result.reason}',
        refundedAt: DateTime.now(),
      );

      await HivePastOrder.updateOrder(updatedOrder);

      // Process stock restoration for items marked for restocking
      await _restoreItemStock(result.itemsToRestock);

      setState(() => currentOrder = updatedOrder);
      NotificationService.instance.showSuccess('Partial refund processed successfully');
    } catch (e) {
      NotificationService.instance.showError('Failed to process refund: $e');
    }
  }

  Future<void> _restoreItemStock(Map<CartItem, int> itemsToRestock) async {
    try {
      for (final entry in itemsToRestock.entries) {
        final cartItem = entry.key;
        final restockQuantity = entry.value;

        if (cartItem.productId.isEmpty || restockQuantity <= 0) continue;

        // Get the current item from the database
        final itemBox = await itemsBoxes.getItemBox();
        final existingItem = itemBox.get(cartItem.productId);

        if (existingItem != null && existingItem.trackInventory) {
          // Update the stock quantity
          final updatedItem = existingItem.copyWith(
            stockQuantity: existingItem.stockQuantity + restockQuantity,
          );

          // Save the updated item back to the database
          await itemsBoxes.updateItem(updatedItem);

          print('Stock restored: $restockQuantity units added to ${existingItem.name}. New stock: ${updatedItem.stockQuantity}');
        }
      }
    } catch (e) {
      print('Error restoring stock: $e');
      NotificationService.instance.showError('Failed to restore some item stock: $e');
    }
  }

  Future<void> _deleteOrder(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Order"),
        content: const Text("Are you sure you want to delete this order?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );
    if (confirm != true) return;

    await HivePastOrder.deleteOrder(widget.Order!.id);
    NotificationService.instance.showSuccess('Order deleted successfully');
    if (mounted) Navigator.pop(context);
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool outlined;
  const _ActionBtn({
    required this.label,
    required this.onTap,
    this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = outlined ? Colors.transparent : (color ?? Theme.of(context).primaryColor);
    final fg = outlined ? Theme.of(context).textTheme.bodyMedium?.color : Colors.white;
    final border = outlined ? BorderSide(color: Colors.black12) : BorderSide.none;

    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: border),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }



}