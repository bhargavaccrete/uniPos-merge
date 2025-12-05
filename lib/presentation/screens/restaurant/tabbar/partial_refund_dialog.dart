
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../domain/services/restaurant/notification_service.dart';


// A helper class to hold the result from the dialog
class PartialRefundResult {
  final Map<CartItem, int> itemsToRefund;
  final String reason;
  final double totalRefundAmount;
  final Map<CartItem, int> itemsToRestock;

  PartialRefundResult({
    required this.itemsToRefund,
    required this.reason,
    required this.totalRefundAmount,
    required this.itemsToRestock, // <-- FIX 1: Corrected comma
  });
}

class PartialRefundDialog extends StatefulWidget {
  final List<CartItem> orderItems; // Refundable items only
  final List<CartItem> allOrderItems; // ALL items for discount calculation
  final double orderGstRate;
  final double orderTotalPrice; // Add the actual order total that was paid
  final double orderDiscount; // Order-level discount
  final double orderSubTotal; // Order subtotal

  const PartialRefundDialog({
    Key? key,
    required this.orderItems,
    required this.allOrderItems,
    required this.orderGstRate,
    required this.orderTotalPrice, // Add this parameter
    this.orderDiscount = 0.0,
    this.orderSubTotal = 0.0,
  }) : super(key: key);

  @override
  _PartialRefundDialogState createState() => _PartialRefundDialogState();
}

class _PartialRefundDialogState extends State<PartialRefundDialog> {
  final _refundReasonController = TextEditingController();
  late Map<CartItem, int> _refundQuantities;
  double _totalRefundAmount = 0.0;
  late Map<CartItem, bool> _restockStatus;

  @override
  void initState() {
    super.initState();
    _refundQuantities = {for (var item in widget.orderItems) item: 0};
    _restockStatus = {for (var item in widget.orderItems) item: true};
  }

  @override
  void dispose() {
    _refundReasonController.dispose();
    super.dispose();
  }

  double _calculateItemPriceWithTax(CartItem item) {
    // Calculate the actual item price with its specific tax rate and discount

    final itemDiscount = item.discount ?? 0.0; // Item-level discount
    final priceAfterItemDiscount = item.finalItemPrice; // price - item.discount
    final itemTaxRate = item.taxRate ?? 0.0;

    // Check if discount is on items (item.discount > 0) or on bill (order.Discount > 0)
    if (itemDiscount > 0) {
      // Discount is applied to individual items
      // Tax is calculated on discounted price
      final taxAmount = priceAfterItemDiscount * itemTaxRate;
      return priceAfterItemDiscount + taxAmount;
    } else {
      // Discount is on total bill - distribute proportionally
      // Calculate total value of ALL ORIGINAL items (for proportional discount distribution)
      double totalItemsValue = 0.0;
      for (var orderItem in widget.allOrderItems) {
        totalItemsValue += orderItem.finalItemPrice * (orderItem.quantity ?? 0);
      }

      // Calculate this item's proportional share of the order-level discount
      double itemDiscountShare = 0.0;
      if (totalItemsValue > 0 && widget.orderDiscount > 0) {
        final itemProportion = priceAfterItemDiscount / totalItemsValue;
        itemDiscountShare = widget.orderDiscount * itemProportion;
      }

      // Apply order-level discount and tax
      final priceAfterOrderDiscount = priceAfterItemDiscount - itemDiscountShare;
      final taxAmount = priceAfterOrderDiscount * itemTaxRate;
      return priceAfterOrderDiscount + taxAmount;
    }
  }



  void _updateRefundTotal() {
    // Check if all remaining items are selected for full refund
    bool isFullRefund = true;
    for (var item in widget.orderItems) {
      final maxRefundable = _maxRefundableQuantity(item);
      final selectedQty = _refundQuantities[item] ?? 0;
      if (maxRefundable > 0 && selectedQty != maxRefundable) {
        isFullRefund = false;
        break;
      }
    }

    if (isFullRefund) {
      // All remaining items selected - use exact remaining total to avoid rounding errors
      setState(() {
        _totalRefundAmount = widget.orderTotalPrice;
      });
    } else {
      // Partial refund - calculate based on individual items
      double total = 0.0;
      _refundQuantities.forEach((item, quantity) {
        if (quantity > 0) {
          total += _calculateItemPriceWithTax(item) * quantity;
        }
      });
      setState(() {
        _totalRefundAmount = total;
      });
    }
  }

  int _maxRefundableQuantity(CartItem item) {
    final originalQty = item.quantity ?? 0;
    final alreadyRefunded = item.refundedQuantity ?? 0;
    return originalQty - alreadyRefunded; // Only return remaining quantity
  }

  void _selectAllForFullRefund() {
    setState(() {
      _refundQuantities.forEach((item, currentQty) {
        _refundQuantities[item] = _maxRefundableQuantity(item);
      });
      // For full refund, use the exact order total that was paid
      // Check if all items are selected for refund
      bool isFullRefund = _refundQuantities.values.every((qty) => qty > 0) &&
          _refundQuantities.entries.every((entry) => entry.value == _maxRefundableQuantity(entry.key));

      if (isFullRefund) {
        _totalRefundAmount = widget.orderTotalPrice;
      } else {
        _updateRefundTotal();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Items to Refund', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Refund Entire Bill'),
                  onPressed: _selectAllForFullRefund,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const Divider(height: 24),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.orderItems.length,
                itemBuilder: (context, index) {
                  final item = widget.orderItems[index];
                  final maxQty = _maxRefundableQuantity(item);
                  final currentRefundQty = _refundQuantities[item]!;
                  final bool isStockManaged = item.isStockManaged ?? false;

                  if (maxQty == 0) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.variantName != null && item.variantName!.isNotEmpty
                                ? '${item.title} (${item.variantName})'
                                : item.title,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Ordered: $maxQty | Price: ₹${_calculateItemPriceWithTax(item).toStringAsFixed(2)}/item',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: currentRefundQty > 0
                                    ? () {
                                  setState(() {
                                    _refundQuantities[item] = currentRefundQty - 1;
                                    _updateRefundTotal();
                                  });
                                }
                                    : null,
                              ),
                              Text(
                                '$currentRefundQty',
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: currentRefundQty < maxQty
                                    ? () {
                                  setState(() {
                                    _refundQuantities[item] = currentRefundQty + 1;
                                    _updateRefundTotal();
                                  });
                                }
                                    : null,
                              ),
                            ],
                          ),
                          if (isStockManaged && currentRefundQty > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: SwitchListTile(
                                title: Text("Add to Stock?", style: GoogleFonts.poppins(fontSize: 14)),
                                value: _restockStatus[item]!,
                                onChanged: (newValue) {
                                  setState(() {
                                    _restockStatus[item] = newValue;
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _refundReasonController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Enter reason for refund...',
                  hintStyle: GoogleFonts.poppins(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Total Refund: ₹${_totalRefundAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () {
            if (_totalRefundAmount <= 0) {
              NotificationService.instance.showInfo('Please select at least one item to refund.');
              return;
            }
            if (_refundReasonController.text.trim().isEmpty) {
              NotificationService.instance.showInfo('Please enter a reason for refund.');
              return;
            }

            final itemsToRefund = Map.of(_refundQuantities)..removeWhere((key, value) => value == 0);

            final Map<CartItem, int> itemsToRestock = {};
            itemsToRefund.forEach((item, quantity) {
              if (_restockStatus[item] == true) {
                itemsToRestock[item] = quantity;
              }
            });

            final result = PartialRefundResult(
              itemsToRefund: itemsToRefund,
              reason: _refundReasonController.text.trim(),
              totalRefundAmount: _totalRefundAmount,
              itemsToRestock: itemsToRestock, // <-- FIX 2: Corrected parenthesis
            );
            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: Text('Confirm Refund', style: GoogleFonts.poppins(color: Colors.white)),
        )
      ],
    );
  }
}