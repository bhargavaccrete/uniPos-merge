import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/customer_model_208.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';
import 'package:unipos/domain/services/retail/gst_service.dart';
import 'package:unipos/domain/services/retail/store_settings_service.dart';
import 'package:unipos/presentation/screens/retail/customer_selection_screen.dart';
import 'package:unipos/presentation/widget/retail/split_payment_widget.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

import 'package:uuid/uuid.dart';

import '../../../data/models/retail/hive_model/sale_item_model_204.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _discountController = TextEditingController(text: '0');
  bool _isProcessing = false;

  // Split payment state
  List<PaymentEntry> _paymentEntries = [];
  double _totalPaid = 0;
  double _changeReturn = 0;
  bool _isPaymentValid = false;

  // Credit/Pay Later state
  bool _isCreditSale = false;

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  void _onPaymentChanged(List<PaymentEntry> payments, double totalPaid, double change) {
    setState(() {
      _paymentEntries = payments;
      _totalPaid = totalPaid;
      _changeReturn = change;
    });
  }

  void _onValidationChanged(bool isValid) {
    setState(() {
      _isPaymentValid = isValid;
    });
  }

  double get _discountAmount {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  // GST is auto-calculated from cart items
  double get _totalTaxableAmount => cartStore.totalTaxableAmount;
  double get _totalGstAmount => cartStore.totalGstAmount;
  double get _totalCgstAmount => cartStore.totalCgstAmount;
  double get _totalSgstAmount => cartStore.totalSgstAmount;

  double get _subtotal {
    // Subtotal is now the sum of (price * qty) before GST
    double total = 0;
    for (var item in cartStore.items) {
      total += item.price * item.qty;
    }
    return total;
  }

  double get _grandTotal {
    // Grand total = taxable amount - discount + GST
    return _totalTaxableAmount - _discountAmount + _totalGstAmount;
  }

  /// Process a Credit/Pay Later sale
  Future<void> _processCreditSale() async {
    // Require customer for credit sales
    if (customerStoreRestail.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer is required for Pay Later sales'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check credit limit
    final customerId = customerStoreRestail.selectedCustomer!.customerId;
    final canCredit = await customerStoreRestail.canMakeCreditPurchase(customerId, _grandTotal);
    if (!canCredit) {
      final availableCredit = await customerStoreRestail.getAvailableCredit(customerId);
      if (mounted) {
        final symbol = CurrencyHelper.currentSymbol;
        final precision = DecimalSettings.precision;
        final formattedCredit = availableCredit.toStringAsFixed(precision);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Credit limit exceeded. Available credit: $symbol$formattedCredit'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Confirm credit sale
    final symbol = CurrencyHelper.currentSymbol;
    final precision = DecimalSettings.precision;
    final formattedTotal = _grandTotal.toStringAsFixed(precision);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Pay Later'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${customerStoreRestail.selectedCustomer!.name}'),
            const SizedBox(height: 8),
            Text('Amount: $symbol$formattedTotal'),
            const SizedBox(height: 8),
            const Text(
              'This will create a credit sale. The amount will be added to the customer\'s outstanding balance.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
            ),
            child: const Text('Confirm Pay Later'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _isCreditSale = true;
    });

    try {
      final saleId = const Uuid().v4();

      // Create credit sale record
      final sale = SaleModel.createCreditSale(
        saleId: saleId,
        customerId: customerId,
        totalItems: cartStore.totalItems,
        subtotal: _subtotal,
        discountAmount: _discountAmount,
        totalTaxableAmount: _totalTaxableAmount,
        totalGstAmount: _totalGstAmount,
        grandTotal: _grandTotal,
      );

      // Update customer credit balance
      await customerStoreRestail.updateAfterCreditSale(customerId, _grandTotal);

      // Save sale and items
      await saleStore.addSale(sale);
      await _saveSaleItems(saleId);
      await _deductStock();

      // Store customer before clearing
      final customer = customerStoreRestail.selectedCustomer;

      // Clear the cart
      await cartStore.clearCart();

      // Refresh credit store
      creditStore.loadData();

      if (mounted) {
        await _showCreditSuccessDialog(
          sale: sale,
          customer: customer!,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing credit sale: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCreditSale = false;
        });
      }
    }
  }

  /// Save sale items to database
  Future<List<SaleItemModel>> _saveSaleItems(String saleId) async {
    final saleItems = <SaleItemModel>[];

    for (var cartItem in cartStore.items) {
      final itemSubtotal = cartItem.price * cartItem.qty;
      final itemDiscountRatio = _subtotal > 0 ? (itemSubtotal / _subtotal) : 0.0;
      final itemDiscountAmount = _discountAmount * itemDiscountRatio;

      final saleItem = SaleItemModel.fromCalculated(
        saleId: saleId,
        varianteId: cartItem.variantId,
        productId: cartItem.productId,
        productName: cartItem.productName,
        size: cartItem.size,
        color: cartItem.color,
        weight: cartItem.weight,
        price: cartItem.price,
        qty: cartItem.qty,
        discountAmount: itemDiscountAmount,
        gstRate: cartItem.gstRate ?? 0,
        taxableAmount: cartItem.taxableAmount ?? (itemSubtotal - itemDiscountAmount),
        gstAmount: cartItem.gstAmount ?? 0,
        total: cartItem.total,
        barcode: cartItem.barcode,
        hsnCode: cartItem.hsnCode,
      );

      saleItems.add(saleItem);
    }

    await saleItemRepository.addSaleItems(saleItems);
    return saleItems;
  }

  /// Deduct stock for sold items
  Future<void> _deductStock() async {
    for (var item in cartStore.items) {
      final variant = await productStore.getVariantById(item.variantId);
      if (variant != null) {
        final newStock = variant.stockQty - item.qty;
        final finalStock = (newStock < 0 ? 0 : newStock).toInt();
        await productStore.updateVariantStock(item.variantId, finalStock);
      }
    }
  }

  Future<void> _processCheckout() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Generate unique sale ID
      final saleId = const Uuid().v4();

      // Convert payment entries to list of maps for storage
      final paymentList = _paymentEntries.map((e) => e.toMap()).toList();

      // Create sale record with GST totals and split payment
      final sale = SaleModel.createWithSplitPayment(
        saleId: saleId,
        customerId: customerStoreRestail.selectedCustomer?.customerId,
        totalItems: cartStore.totalItems,
        subtotal: _subtotal,
        discountAmount: _discountAmount,
        totalTaxableAmount: _totalTaxableAmount,
        totalGstAmount: _totalGstAmount,
        grandTotal: _grandTotal,
        paymentList: paymentList,
        totalPaid: _totalPaid,
        changeReturn: _changeReturn,
      );

      // Update customer purchase data if customer is selected
      if (customerStoreRestail.selectedCustomer != null) {
        final points = (_grandTotal / 10).floor(); // 1 point per Rs.10
        await customerStoreRestail.updateAfterPurchase(
          customerStoreRestail.selectedCustomer!.customerId,
          _grandTotal,
          points,
        );
      }

      // Save sale to database through SaleStore
      await saleStore.addSale(sale);

      // Create and save sale items with GST data from cart
      final saleItems = <SaleItemModel>[];

      for (var cartItem in cartStore.items) {
        // Calculate proportional discount if any
        final itemSubtotal = cartItem.price * cartItem.qty;
        final itemDiscountRatio = _subtotal > 0 ? (itemSubtotal / _subtotal) : 0.0;
        final itemDiscountAmount = _discountAmount * itemDiscountRatio;

        // Create sale item with GST data
        final saleItem = SaleItemModel.fromCalculated(
          saleId: saleId,
          varianteId: cartItem.variantId,
          productId: cartItem.productId,
          productName: cartItem.productName,
          size: cartItem.size,
          color: cartItem.color,
          weight: cartItem.weight,
          price: cartItem.price,
          qty: cartItem.qty,
          discountAmount: itemDiscountAmount,
          gstRate: cartItem.gstRate ?? 0,
          taxableAmount: cartItem.taxableAmount ?? (itemSubtotal - itemDiscountAmount),
          gstAmount: cartItem.gstAmount ?? 0,
          total: cartItem.total,
          barcode: cartItem.barcode,
          hsnCode: cartItem.hsnCode,
        );

        saleItems.add(saleItem);
      }

      // Save all sale items to database
      await saleItemRepository.addSaleItems(saleItems);

      // Decrease stock quantities for sold items
      for (var item in cartStore.items) {
        final variant = await productStore.getVariantById(item.variantId);
        if (variant != null) {
          final newStock = variant.stockQty - item.qty;
          // Ensure stock doesn't go negative
          final finalStock = (newStock < 0 ? 0 : newStock).toInt();
          await productStore.updateVariantStock(
            item.variantId,
            finalStock,
          );
        }
      }

      // Store customer before clearing
      final customer = customerStoreRestail.selectedCustomer;

      // Clear the cart
      await cartStore.clearCart();

      if (mounted) {
        // Show success dialog with print options
        await _showSuccessDialog(
          sale: sale,
          saleItems: saleItems,
          customer: customer,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing checkout: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Observer(
        builder: (context) {
          if (cartStore.itemCount == 0) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFFD0D0D0)),
                  SizedBox(height: 16),
                  Text(
                    'Cart is empty',
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Section
                _buildSectionTitle('Customer'),
                const SizedBox(height: 12),
                _buildCustomerCard(),
                const SizedBox(height: 24),

                // Order Summary Section
                _buildSectionTitle('Order Summary'),
                const SizedBox(height: 12),
                _buildOrderSummaryCard(),
                const SizedBox(height: 24),

                // Billing Details Section
                _buildSectionTitle('Billing Details'),
                const SizedBox(height: 12),
                _buildBillingDetailsCard(),
                const SizedBox(height: 24),

                // Total Summary Section
                _buildTotalSummaryCard(),
                const SizedBox(height: 24),

                // Split Payment Section
                _buildSectionTitle('Payment'),
                const SizedBox(height: 12),
                SplitPaymentWidget(
                  billTotal: _grandTotal,
                  onPaymentChanged: _onPaymentChanged,
                  onValidationChanged: _onValidationChanged,
                ),
                const SizedBox(height: 24),

                // Payment Action Buttons
                Row(
                  children: [
                    // Pay Later Button
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _processCreditSale,
                          icon: const Icon(Icons.schedule, size: 20),
                          label: const Text(
                            'Pay Later',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: const Color(0xFFB0B0B0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Complete Payment Button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (_isProcessing || !_isPaymentValid) ? null : _processCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: const Color(0xFFB0B0B0),
                          ),
                          child: _isProcessing && !_isCreditSale
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : ValueListenableBuilder<String>(
                                  valueListenable: CurrencyHelper.currencyNotifier,
                                  builder: (context, currencyCode, child) {
                                    return ValueListenableBuilder<int>(
                                      valueListenable: DecimalSettings.precisionNotifier,
                                      builder: (context, precision, child) {
                                        final symbol = CurrencyHelper.currentSymbol;
                                        final formattedChange = _changeReturn.toStringAsFixed(precision);
                                        return Text(
                                          _changeReturn > 0
                                            ? 'Pay ($symbol$formattedChange change)'
                                            : 'Complete Payment',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Total Items', '${cartStore.totalItems}', isBold: false),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: CurrencyHelper.currencyNotifier,
            builder: (context, currencyCode, child) {
              return ValueListenableBuilder<int>(
                valueListenable: DecimalSettings.precisionNotifier,
                builder: (context, precision, child) {
                  final symbol = CurrencyHelper.currentSymbol;
                  final formattedSubtotal = _subtotal.toStringAsFixed(precision);
                  return _buildSummaryRow('Subtotal', '$symbol$formattedSubtotal', isBold: false);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBillingDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        children: [
          // Discount Field
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Discount',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    prefixText: '${CurrencyHelper.currentSymbol} ',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGstBreakdownCard() {
    final breakdown = cartStore.gstBreakdown;
    if (breakdown.isEmpty || _totalGstAmount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GST Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          ...breakdown.entries.map((entry) {
            final rate = entry.key;
            final data = entry.value;
            if (data.totalGstAmount == 0) return const SizedBox.shrink();
            return ValueListenableBuilder<String>(
              valueListenable: CurrencyHelper.currencyNotifier,
              builder: (context, currencyCode, child) {
                return ValueListenableBuilder<int>(
                  valueListenable: DecimalSettings.precisionNotifier,
                  builder: (context, precision, child) {
                    final symbol = CurrencyHelper.currentSymbol;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GST ${GstService.formatGstRate(rate)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                              Text(
                                '$symbol${data.totalGstAmount.toStringAsFixed(precision)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '  CGST ${GstService.formatGstRate(rate / 2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                              Text(
                                '$symbol${data.cgstAmount.toStringAsFixed(precision)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '  SGST ${GstService.formatGstRate(rate / 2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                              Text(
                                '$symbol${data.sgstAmount.toStringAsFixed(precision)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard() {
    return ValueListenableBuilder<String>(
      valueListenable: CurrencyHelper.currencyNotifier,
      builder: (context, currencyCode, child) {
        return ValueListenableBuilder<int>(
          valueListenable: DecimalSettings.precisionNotifier,
          builder: (context, precision, child) {
            final symbol = CurrencyHelper.currentSymbol;
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2), width: 1),
              ),
              child: Column(
                children: [
                  if (_discountAmount > 0) ...[
                    _buildSummaryRow('Subtotal', '$symbol${_subtotal.toStringAsFixed(precision)}', isBold: false),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Discount', '- $symbol${_discountAmount.toStringAsFixed(precision)}', isBold: false, color: Colors.red),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Taxable Amount', '$symbol${_totalTaxableAmount.toStringAsFixed(precision)}', isBold: false),
                    const SizedBox(height: 8),
                  ],
                  if (_totalGstAmount > 0) ...[
                    _buildSummaryRow('CGST', '+ $symbol${_totalCgstAmount.toStringAsFixed(precision)}', isBold: false, color: const Color(0xFF4CAF50)),
                    const SizedBox(height: 4),
                    _buildSummaryRow('SGST', '+ $symbol${_totalSgstAmount.toStringAsFixed(precision)}', isBold: false, color: const Color(0xFF4CAF50)),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Total GST', '+ $symbol${_totalGstAmount.toStringAsFixed(precision)}', isBold: false, color: const Color(0xFF4CAF50)),
                    const Divider(height: 20, thickness: 0.5, color: Color(0xFFE8E8E8)),
                  ],
                  _buildSummaryRow('Grand Total', '$symbol${_grandTotal.toStringAsFixed(precision)}', isBold: true, fontSize: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = true, double? fontSize, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: color ?? const Color(0xFF1A1A1A),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Future<void> _showSuccessDialog({
    required SaleModel sale,
    required List<SaleItemModel> saleItems,
    CustomerModel? customer,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 16),

              // Success Message
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),

              // Sale ID
              Text(
                'Receipt #${sale.saleId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: CurrencyHelper.currencyNotifier,
                  builder: (context, currencyCode, child) {
                    return ValueListenableBuilder<int>(
                      valueListenable: DecimalSettings.precisionNotifier,
                      builder: (context, precision, child) {
                        final symbol = CurrencyHelper.currentSymbol;
                        final formattedAmount = sale.totalAmount.toStringAsFixed(precision);
                        return Text(
                          '$symbol$formattedAmount',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4CAF50),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Print Receipt Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Fetch store settings
                    final storeSettings = StoreSettingsService();
                    final storeName = await storeSettings.getStoreName();
                    final storeAddress = await storeSettings.getFormattedAddress();
                    final storePhone = await storeSettings.getStorePhone();
                    final storeEmail = await storeSettings.getStoreEmail();
                    final gstNumber = await storeSettings.getGSTNumber();

                    if (mounted) {
                      await printService.showPrintOptionsDialog(
                        context: this.context,
                        sale: sale,
                        items: saleItems,
                        customer: customer,
                        storeName: storeName,
                        storeAddress: storeAddress,
                        storePhone: storePhone,
                        storeEmail: storeEmail,
                        gstNumber: gstNumber,
                      );
                      // Navigate back after printing
                      if (mounted) {
                        Navigator.of(context).pop(true);
                      }
                    }
                  },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Done Button (Skip printing)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Skip & Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show success dialog for credit/pay later sale
  Future<void> _showCreditSuccessDialog({
    required SaleModel sale,
    required CustomerModel customer,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Credit Sale Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  size: 48,
                  color: Color(0xFFFF9800),
                ),
              ),
              const SizedBox(height: 16),

              // Success Message
              const Text(
                'Credit Sale Recorded!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),

              // Invoice ID
              Text(
                'Invoice #${sale.saleId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 16),

              // Amount Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: CurrencyHelper.currencyNotifier,
                  builder: (context, currencyCode, child) {
                    return ValueListenableBuilder<int>(
                      valueListenable: DecimalSettings.precisionNotifier,
                      builder: (context, precision, child) {
                        final symbol = CurrencyHelper.currentSymbol;
                        final formattedTotal = sale.totalAmount.toStringAsFixed(precision);
                        final formattedBalance = (customer.creditBalance + sale.totalAmount).toStringAsFixed(precision);
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                                ),
                                Text(
                                  '$symbol$formattedTotal',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF9800),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Customer',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                                ),
                                Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'New Balance',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                                ),
                                Text(
                                  '$symbol$formattedBalance',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Payment is pending. Stock has been deducted.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Print Receipt Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final saleItems = await saleItemRepository.getItemsBySaleId(sale.saleId);

                    // Fetch store settings
                    final storeSettings = StoreSettingsService();
                    final storeName = await storeSettings.getStoreName();
                    final storeAddress = await storeSettings.getFormattedAddress();
                    final storePhone = await storeSettings.getStorePhone();
                    final storeEmail = await storeSettings.getStoreEmail();
                    final gstNumber = await storeSettings.getGSTNumber();

                    if (mounted) {
                      await printService.showPrintOptionsDialog(
                        context: this.context,
                        sale: sale,
                        items: saleItems,
                        customer: customer,
                        storeName: storeName,
                        storeAddress: storeAddress,
                        storePhone: storePhone,
                        storeEmail: storeEmail,
                        gstNumber: gstNumber,
                      );
                      // Navigate back after printing
                      if (mounted) {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(); // Return to POS screen
                      }
                    }
                  },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Done Button (Skip printing)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Return to POS screen
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Skip & Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Observer(
      builder: (context) {
        final customer = customerStoreRestail.selectedCustomer;

        return InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomerSelectionScreen(),
              ),
            );

            if (result != null) {
              setState(() {});
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: customer != null
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    customer != null ? Icons.person : Icons.person_add_outlined,
                    color: customer != null ? const Color(0xFF4CAF50) : const Color(0xFF6B6B6B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: customer != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              customer.phone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Customer',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Optional - Tap to select',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB0B0B0),
                              ),
                            ),
                          ],
                        ),
                ),
                Icon(
                  customer != null ? Icons.edit_outlined : Icons.arrow_forward_ios,
                  size: 18,
                  color: const Color(0xFFB0B0B0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}