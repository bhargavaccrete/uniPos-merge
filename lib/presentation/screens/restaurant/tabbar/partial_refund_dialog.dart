import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../stores/payment_method_store.dart';
import '../../../../util/restaurant/payment_mode_summary.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../domain/services/restaurant/refund_restock_rule.dart';
import '../../../../domain/services/restaurant/refund_service.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

// Export PartialRefundResult so UI screens can use it
export '../../../../domain/services/restaurant/refund_service.dart'
    show PartialRefundResult;

class PartialRefundDialog extends StatefulWidget {
  final List<CartItem> orderItems; // Refundable items only
  final List<CartItem> allOrderItems; // ALL items for discount calculation
  final double orderGstRate;
  final double orderTotalPrice; // Still refundable: paid minus earlier refunds
  final double? orderPaidTotal; // What the order was paid in total (net payable)
  final double orderDiscount; // Order-level discount
  final double orderSubTotal; // Order subtotal
  final bool isTaxInclusive; // Whether tax was inclusive when order was placed

  /// The methods the order was paid by, largest first — the first one is the
  /// default way the refund is paid back.
  final List<String> paidMethods;

  const PartialRefundDialog({
    Key? key,
    required this.orderItems,
    required this.allOrderItems,
    required this.orderGstRate,
    required this.orderTotalPrice, // Add this parameter
    this.orderPaidTotal,
    this.orderDiscount = 0.0,
    this.orderSubTotal = 0.0,
    this.isTaxInclusive = false,
    this.paidMethods = const [],
  }) : super(key: key);

  @override
  _PartialRefundDialogState createState() => _PartialRefundDialogState();
}

class _PartialRefundDialogState extends State<PartialRefundDialog> {
  final _refundReasonController = TextEditingController();
  late Map<CartItem, int> _refundQuantities;
  double _totalRefundAmount = 0.0;
  // Created once: the cashier's ticks outlive every rebuild of the dialog.
  late final RefundRestockSelection _restock;
  bool _showReasonError = false;

  /// How the money goes back: one row per method. Refunds are recorded by
  /// method so the drawer and End of Day take each one off the right method.
  late final List<String> _methodChoices;
  final List<_RefundMethodRow> _methodRows = [];

  @override
  void initState() {
    super.initState();
    _refundQuantities = {for (var item in widget.orderItems) item: 0};
    _restock = RefundRestockSelection(
      widget.orderItems,
      (productId) => itemStore.getItemById(productId),
    );

    final choices = <String>[];
    void addChoice(String raw) {
      final label = PaymentModeSummary.normalizeMethod(raw);
      if (label != 'Unknown' && !choices.contains(label)) choices.add(label);
    }

    widget.paidMethods.forEach(addChoice);
    if (locator.isRegistered<PaymentMethodStore>()) {
      for (final m in locator<PaymentMethodStore>().enabledMethods) {
        addChoice(m.value);
      }
    }
    if (choices.isEmpty) choices.add('Cash');
    _methodChoices = choices;
    _methodRows.add(_RefundMethodRow(choices.first));
  }

  @override
  void dispose() {
    _refundReasonController.dispose();
    for (final r in _methodRows) {
      r.amount.dispose();
    }
    super.dispose();
  }

  /// With one method, its amount simply follows the refund total.
  void _syncSingleMethodRow() {
    if (_methodRows.length == 1) {
      _methodRows.single.amount.text = _totalRefundAmount.toStringAsFixed(2);
    }
  }

  void _addMethodRow() {
    final used = _methodRows.map((r) => r.method).toSet();
    final next = _methodChoices.firstWhere(
      (m) => !used.contains(m),
      orElse: () => _methodChoices.first,
    );
    setState(() => _methodRows.add(_RefundMethodRow(next)));
  }

  void _removeMethodRow(int index) {
    setState(() {
      _methodRows.removeAt(index).amount.dispose();
      _syncSingleMethodRow();
    });
  }

  double get _methodsTotal => _methodRows.fold(
      0.0, (s, r) => s + (double.tryParse(r.amount.text.trim()) ?? 0.0));

  double _calculateItemPriceWithTax(CartItem item) {
    // Calculate the actual item price with its specific tax rate and discount

    final itemDiscount = item.discount ?? 0.0; // Item-level discount
    final priceAfterItemDiscount = item.finalItemPrice; // price - item.discount
    final itemTaxRate = item.taxRate ?? 0.0;

    // Check if discount is on items (item.discount > 0) or on bill (order.Discount > 0)
    if (itemDiscount > 0) {
      // Discount is applied to individual items
      if (widget.isTaxInclusive) {
        // Price already includes tax — do not add again
        return priceAfterItemDiscount;
      }
      final taxAmount = priceAfterItemDiscount * itemTaxRate;
      return priceAfterItemDiscount + taxAmount;
    } else {
      // Discount is on total bill - distribute proportionally
      double totalItemsValue = 0.0;
      for (var orderItem in widget.allOrderItems) {
        totalItemsValue += orderItem.finalItemPrice * (orderItem.quantity ?? 0);
      }

      double itemDiscountShare = 0.0;
      if (totalItemsValue > 0 && widget.orderDiscount > 0) {
        final itemProportion = priceAfterItemDiscount / totalItemsValue;
        itemDiscountShare = widget.orderDiscount * itemProportion;
      }

      final priceAfterOrderDiscount =
          priceAfterItemDiscount - itemDiscountShare;

      if (widget.isTaxInclusive) {
        // Price already includes tax — only apply the discount share, no tax addition
        return priceAfterOrderDiscount;
      }
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
        _syncSingleMethodRow();
      });
    } else {
      // Partial refund - calculate based on individual items
      double total = 0.0;
      _refundQuantities.forEach((item, quantity) {
        if (quantity > 0) {
          total += _calculateItemPriceWithTax(item) * quantity;
        }
      });
      // Scaled to what was actually paid (loyalty points, tax off, rounding)
      // and never more than is still refundable (BLK-06).
      double allItemsValue = 0.0;
      for (final item in widget.allOrderItems) {
        allItemsValue += _calculateItemPriceWithTax(item) * item.quantity;
      }
      final capped = RefundService.partialRefundAmount(
        selectedValue: total,
        allItemsValue: allItemsValue,
        paidTotal: widget.orderPaidTotal ?? widget.orderTotalPrice,
        remaining: widget.orderTotalPrice,
      );
      setState(() {
        _totalRefundAmount = capped;
        _syncSingleMethodRow();
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
      bool isFullRefund =
          _refundQuantities.values.every((qty) => qty > 0) &&
          _refundQuantities.entries.every(
            (entry) => entry.value == _maxRefundableQuantity(entry.key),
          );

      if (isFullRefund) {
        _totalRefundAmount = widget.orderTotalPrice;
        _syncSingleMethodRow();
      } else {
        _updateRefundTotal();
      }

      // Suggest a default reason if empty
      if (_refundReasonController.text.trim().isEmpty) {
        _refundReasonController.text =
            'Full order refund requested by customer';
      }

      // Clear error state if shown
      _showReasonError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: 'Select Items to Refund',
      accent: Colors.orange,
      icon: Icons.assignment_return_rounded,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                Icons.receipt_long,
                size: AppResponsive.smallIconSize(context),
              ),
              label: Text(
                'Refund Entire Bill',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _selectAllForFullRefund,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
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

              if (maxQty == 0) return const SizedBox.shrink();

              return Card(
                // Explicit white + no surface tint. Material 3 tints a Card's
                // default surface by elevation, and main.dart sets no
                // colorScheme, so an untinted Card picks up M3's default
                // lavender while every neighbouring surface stays white.
                color: AppColors.white,
                surfaceTintColor: Colors.transparent,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
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
                        'Ordered: $maxQty | Price: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_calculateItemPriceWithTax(item))}/item',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: currentRefundQty > 0
                                ? () {
                                    setState(() {
                                      _refundQuantities[item] =
                                          currentRefundQty - 1;
                                      _updateRefundTotal();
                                    });
                                  }
                                : null,
                          ),
                          Text(
                            '$currentRefundQty',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: currentRefundQty < maxQty
                                ? () {
                                    setState(() {
                                      _refundQuantities[item] =
                                          currentRefundQty + 1;
                                      _updateRefundTotal();
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                      // Every line being refunded gets its own choice;
                      // cooked food starts unchecked (RefundRestockRule).
                      if (currentRefundQty > 0 && !_restock.canRestock(item))
                        Padding(
                          padding: EdgeInsets.only(
                            top: AppResponsive.smallSpacing(context),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: AppResponsive.smallIconSize(context),
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Already back in stock',
                                  style: GoogleFonts.poppins(
                                    fontSize:
                                        AppResponsive.smallFontSize(context),
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (currentRefundQty > 0)
                        CheckboxListTile(
                          title: Text(
                            RefundRestockRule.restorable(item) < item.quantity
                                ? 'Add back to stock (up to ${RefundRestockRule.restorable(item)})'
                                : 'Add back to stock',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: _restock.isSelected(item),
                          onChanged: (v) =>
                              setState(() => _restock.select(item, v ?? false)),
                          activeColor: AppColors.primary,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          // Required indicator
          Row(
            children: [
              Text(
                'Reason for Refund',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                ' *',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          AppTextField(
            controller: _refundReasonController,
            hint: 'e.g., Customer complaint, wrong order, quality issue...',
            icon: Icons.note_alt_outlined,
            maxLines: 3,
            minLines: 2,
            onChanged: (value) {
              if (_showReasonError && value.trim().isNotEmpty) {
                setState(() => _showReasonError = false);
              }
            },
            validator: (_) =>
                _showReasonError ? 'This field is required' : null,
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          _buildRefundMethods(context),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          Text(
            'Total Refund: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRefundAmount)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        appDialogCancelButton(context),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        appDialogPrimaryButton(
          label: 'Confirm Refund',
          color: Colors.orange,
          onPressed: () {
            if (_totalRefundAmount <= 0) {
              NotificationService.instance.showError(
                'Please select at least one item to refund',
              );
              return;
            }
            if (_refundReasonController.text.trim().isEmpty) {
              setState(() => _showReasonError = true);
              NotificationService.instance.showError(
                'Reason is required! Please enter a reason for this refund.',
              );
              return;
            }

            final itemsToRefund = Map.of(_refundQuantities)
              ..removeWhere((key, value) => value == 0);

            final itemsToRestock = _restock.restockFor(itemsToRefund);

            // How the money went back must add up to the refund.
            final legs = <RefundLeg>[
              for (final r in _methodRows)
                (
                  method: r.method,
                  amount: double.tryParse(r.amount.text.trim()) ?? 0.0,
                ),
            ];
            if (legs.any((l) => l.amount <= 0)) {
              NotificationService.instance.showError(
                'Enter an amount for each refund method, or remove it.',
              );
              return;
            }
            final legsTotal = legs.fold(0.0, (s, l) => s + l.amount);
            if ((legsTotal - _totalRefundAmount).abs() > 0.01) {
              NotificationService.instance.showError(
                'Refund methods add up to '
                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(legsTotal)}, '
                'but the refund is '
                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRefundAmount)}.',
              );
              return;
            }

            final result = PartialRefundResult(
              itemsToRefund: itemsToRefund,
              reason: _refundReasonController.text.trim(),
              totalRefundAmount: _totalRefundAmount,
              itemsToRestock: itemsToRestock,
              refundLegs: legs,
            );

            // Reset error state on successful submission
            setState(() => _showReasonError = false);

            Navigator.pop(context, result);
          },
        ),
      ],
    );
  }

  /// "Refund paid by": one row per method, each with its amount.
  Widget _buildRefundMethods(BuildContext context) {
    final labelStyle = GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
    final remaining = _totalRefundAmount - _methodsTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Refund paid by', style: labelStyle),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        for (var i = 0; i < _methodRows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _methodRows[i].method,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      color: AppColors.textPrimary,
                    ),
                    items: [
                      for (final m in _methodChoices)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (m) {
                      if (m != null) setState(() => _methodRows[i].method = m);
                    },
                  ),
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: _methodRows[i].amount,
                    hint: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    readOnly: _methodRows.length == 1,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_methodRows.length > 1)
                  IconButton(
                    tooltip: 'Remove method',
                    icon: Icon(
                      Icons.remove_circle_outline,
                      size: AppResponsive.iconSize(context),
                      color: AppColors.danger,
                    ),
                    onPressed: () => _removeMethodRow(i),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            if (_methodChoices.length > 1)
              TextButton.icon(
                onPressed: _addMethodRow,
                icon: Icon(Icons.add, size: AppResponsive.smallIconSize(context)),
                label: Text(
                  'Add method',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const Spacer(),
            if (_methodRows.length > 1 && remaining.abs() > 0.009)
              Flexible(
                child: Text(
                  remaining > 0
                      ? 'Left to assign: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(remaining)}'
                      : 'Over by ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(-remaining)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.danger,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One "Refund paid by" row.
class _RefundMethodRow {
  _RefundMethodRow(this.method);
  String method;
  final TextEditingController amount = TextEditingController();
}
