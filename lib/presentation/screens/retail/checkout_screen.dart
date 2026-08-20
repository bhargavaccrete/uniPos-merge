import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/services/retail/retail_billing_service.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/presentation/screens/retail/customer_selection_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/split_payment_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/loyalty_points.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';

import 'package:uuid/uuid.dart';

import '../../../data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );
  bool _isProcessing = false;

  // Split payment state
  List<PaymentEntry> _paymentEntries = [];
  double _totalPaid = 0;
  double _changeReturn = 0;
  bool _isPaymentValid = false;

  // Credit/Pay Later state
  bool _isCreditSale = false;

  /// Why a discount was given. Retail-specific wording — restaurant's list is
  /// about customer relationships, which doesn't fit a counter sale.
  static const List<String> _discountReasons = [
    'Customer Discount',
    'Promotion',
    'Price Match',
    'Damaged Product',
    'Manual Adjustment',
    'Other',
  ];

  String _selectedDiscountReason = _discountReasons.first;
  final TextEditingController _otherReasonController = TextEditingController();

  /// Resolved reason, only meaningful when a discount was actually applied.
  String? get _discountReason {
    if (_bill.discountAmount <= 0) return null;
    return _selectedDiscountReason == 'Other'
        ? _otherReasonController.text.trim()
        : _selectedDiscountReason;
  }

  /// Loyalty points the customer is redeeming on this bill (1 point = 1 unit).
  int _pointsRedeemed = 0;

  /// Collect less than the bill now and put the balance on the customer's
  /// account. Requires a customer, same as a full Pay Later.
  bool _allowPartialPayment = false;

  /// Balance that would remain unpaid, given what has been tendered.
  double get _balanceDue {
    final due = _grandTotal - _totalPaid;
    return due > 0.009 ? double.parse(due.toStringAsFixed(2)) : 0;
  }

  /// Whether "Complete Payment" should be enabled.
  ///
  /// Normally the split-payment widget must cover the bill. In partial mode we
  /// only require that something was actually collected and a customer is
  /// attached to carry the balance.
  bool get _canSubmitPayment {
    if (_isProcessing) return false;
    if (!_allowPartialPayment) return _isPaymentValid;
    return _totalPaid > 0 && customerStore.selectedCustomer != null;
  }

  @override
  void initState() {
    super.initState();
    // Seed the field FROM the store, not the other way round. Leaving checkout
    // without paying and coming back would otherwise show an empty field while
    // the store still held the discount — the bill and the input disagreeing.
    final existing = retailCartStore.discountValue;
    _discountController.text = existing > 0 ? _trimZeros(existing) : '0';
    _pointsRedeemed = retailCartStore.loyaltyRedemption.round();

    // From here on, keep the store in step with the field.
    _discountController.addListener(_syncDiscountToStore);
  }

  /// "10.0" reads badly in a discount box; show "10".
  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _syncDiscountToStore() {
    retailCartStore.setDiscount(
      value: double.tryParse(_discountController.text) ?? 0,
    );
  }

  @override
  void dispose() {
    _discountController.removeListener(_syncDiscountToStore);
    _discountController.dispose();
    _otherReasonController.dispose();
    super.dispose();
  }

  void _onPaymentChanged(
    List<PaymentEntry> payments,
    double totalPaid,
    double change,
  ) {
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

  /// The single source of truth for every figure on this screen: totals, tax,
  /// round-off, and each line's share of the discount.
  ///
  /// Derived in the store (a MobX `@computed`, so it is memoised and shared
  /// with the POS screen) — this screen only renders it.
  RetailBill get _bill => retailCartStore.bill;

  double get _subtotal => _bill.itemTotal;
  double get _discountAmount => _bill.discountAmount;
  double get _totalTaxableAmount => _bill.taxableAmount;
  double get _totalGstAmount => _bill.totalGst;
  double get _totalCgstAmount => _bill.cgstAmount;
  double get _totalSgstAmount => _bill.sgstAmount;
  double get _grandTotal => _bill.grandTotal;

  /// Process a Credit/Pay Later sale
  /// Plan gate — blocks a NEW bill once the per-day cap is reached. Counts
  /// today's completed sales. No-op until a retail manifest is present, and
  /// `0/absent = unlimited` (see PlanEnforce). Mirrors restaurant's per-day cap
  /// enforced at the order entrance (customerdetails.dart).
  Future<bool> _withinDailyBillCap() async {
    final billsToday = (await saleStore.getTodaySales()).length;
    if (PlanEnforce.withinLimit(RetailEntKeys.billingPerDayMax, billsToday)) {
      return true;
    }
    final max = PlanEnforce.limit(RetailEntKeys.billingPerDayMax);
    if (mounted) {
      NotificationService.instance.showError(
        'Daily bill limit reached${max != null ? ' (max $max)' : ''}. Upgrade your plan to bill more today.',
      );
    }
    return false;
  }

  Future<void> _processCreditSale() async {
    // Plan gate — daily bill cap (a credit sale is still a bill).
    if (!await _withinDailyBillCap()) return;

    // Require customer for credit sales
    if (customerStore.selectedCustomer == null) {
      NotificationService.instance.showError(
        'Customer is required for Pay Later sales',
      );
      return;
    }

    // Check credit limit
    final customerId = customerStore.selectedCustomer!.customerId;
    final canCredit = await customerStore.canMakeCreditPurchase(
      customerId,
      _grandTotal,
    );
    if (!canCredit) {
      final availableCredit = await customerStore.getAvailableCredit(
        customerId,
      );
      if (mounted) {
        final symbol = CurrencyHelper.currentSymbol;
        final precision = DecimalSettings.precision;
        final formattedCredit = availableCredit.toStringAsFixed(precision);
        NotificationService.instance.showError(
          'Credit limit exceeded. Available credit: $symbol$formattedCredit',
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
      builder: (dialogContext) => AppDialogShell(
        title: 'Confirm Pay Later',
        subtitle: 'Settle this bill against the customer\'s account',
        icon: Icons.schedule_rounded,
        accent: AppColors.warning,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _payLaterRow(
              dialogContext,
              'Customer',
              customerStore.selectedCustomer!.name ?? 'Unnamed',
            ),
            _payLaterRow(
              dialogContext,
              'Amount',
              '$symbol$formattedTotal',
              emphasise: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This creates a credit sale. The amount is added to the '
                      'customer\'s outstanding balance.',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(dialogContext),
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          appDialogCancelButton(dialogContext),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Pay Later',
            color: AppColors.warning,
            onPressed: () => Navigator.pop(dialogContext, true),
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

      // Same rule as the paid path: one bill snapshot drives the record, the
      // lines and the credit balance.
      final bill = _bill;

      // Create credit sale record
      final sale = SaleModel.createCreditSale(
        saleId: saleId,
        customerId: customerId,
        totalItems: bill.totalItems,
        subtotal: bill.itemTotal,
        discountAmount: bill.discountAmount,
        totalTaxableAmount: bill.taxableAmount,
        totalGstAmount: bill.totalGst,
        grandTotal: bill.grandTotal,
        discountType: retailCartStore.discountType.name,
        discountValue: retailCartStore.discountValue,
        discountReason: _discountReason,
        loyaltyPointsUsed: _pointsRedeemed,
        roundOff: bill.roundOff,
        isTaxInclusive: bill.isTaxInclusive,
      );

      // Update customer credit balance
      await customerStore.updateAfterCreditSale(customerId, bill.grandTotal);
      if (_pointsRedeemed > 0) {
        await customerStore.redeemCustomerPoints(customerId, _pointsRedeemed);
      }

      // Save sale and items through the store, then adjust stock
      await saleStore.addSaleWithItems(
        sale,
        await _buildSaleItems(saleId, bill),
      );
      await _deductStock();

      // Store customer before clearing
      final customer = customerStore.selectedCustomer;

      // Clear the cart
      await cartStore.clearCart();

      // Refresh credit store
      creditStore.loadData();

      if (mounted) {
        await _showCreditSuccessDialog(sale: sale, customer: customer!);
      }

      // Closing the dialog only closed the DIALOG — the cart was cleared
      // above, so the user was left staring at an empty Checkout and had to
      // press back again to reach billing. Hand control back to the POS, which
      // already awaits `true` to toast the success.
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError(
          'Error processing credit sale: $e',
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

  /// One label/value line of the Pay Later confirmation — same shape the
  /// Settings day-info dialog uses, so confirmations read alike.
  Widget _payLaterRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasise = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: emphasise
                    ? AppResponsive.subheadingFontSize(context)
                    : AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: emphasise ? AppColors.warning : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Persist the sale lines exactly as the engine computed them.
  ///
  /// The per-item taxable amount and discount share must come from [bill],
  /// not from the cart row: a cart row's taxable amount is computed at add-time
  /// and knows nothing about an order-level discount applied later. Reading it
  /// back here is what used to store an inflated tax base on every invoice.
  ///
  /// The variant's cost is read here and frozen onto the line. Profit reports
  /// used to look up the variant's live `costPrice` instead, so a supplier
  /// price change re-wrote the profit on sales that had already been settled.
  Future<List<SaleItemModel>> _buildSaleItems(
    String saleId,
    RetailBill bill,
  ) async {
    // One lookup per distinct variant in the basket, not per report row.
    final costByVariantId = <String, double?>{};
    for (final line in bill.lines) {
      final variantId = line.item.variantId;
      if (costByVariantId.containsKey(variantId)) continue;
      final variant = await productStore.getVariantById(variantId);
      costByVariantId[variantId] = variant?.costPrice;
    }

    return bill.lines.map((line) {
      final cartItem = line.item;
      return SaleItemModel.fromCalculated(
        saleId: saleId,
        varianteId: cartItem.variantId,
        productId: cartItem.productId,
        productName: cartItem.productName,
        attributes: cartItem.attributes,
        price: cartItem.price,
        qty: cartItem.qty,
        discountAmount: line.discountAmount,
        gstRate: line.gstRatePercent,
        taxableAmount: line.taxableAmount,
        gstAmount: line.gstAmount,
        total: line.total,
        barcode: cartItem.barcode,
        hsnCode: cartItem.hsnCode,
        costPrice: costByVariantId[cartItem.variantId],
      );
    }).toList();
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

    // Plan gate — daily bill cap, checked before we start processing.
    if (!await _withinDailyBillCap()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Generate unique sale ID
      final saleId = const Uuid().v4();

      // Snapshot the bill ONCE. Everything below — the sale record, the line
      // items and the receipt — must come from this same instance, or the
      // stored figures can disagree with what the customer was shown.
      final bill = _bill;

      // Convert payment entries to list of maps for storage
      final paymentList = _paymentEntries.map((e) => e.toMap()).toList();

      // Create sale record with GST totals and split payment
      final sale = SaleModel.createWithSplitPayment(
        saleId: saleId,
        customerId: customerStore.selectedCustomer?.customerId,
        totalItems: bill.totalItems,
        subtotal: bill.itemTotal,
        discountAmount: bill.discountAmount,
        totalTaxableAmount: bill.taxableAmount,
        totalGstAmount: bill.totalGst,
        grandTotal: bill.grandTotal,
        paymentList: paymentList,
        totalPaid: _totalPaid,
        changeReturn: _changeReturn,
        discountType: retailCartStore.discountType.name,
        discountValue: retailCartStore.discountValue,
        discountReason: _discountReason,
        loyaltyPointsUsed: _pointsRedeemed,
        roundOff: bill.roundOff,
        isTaxInclusive: bill.isTaxInclusive,
        // In partial mode record what was actually collected; the factory
        // derives dueAmount and flips the status to partially_paid.
        amountCollected: _allowPartialPayment ? _totalPaid : null,
      );

      // Update customer purchase data if customer is selected
      if (customerStore.selectedCustomer != null) {
        final customerId = customerStore.selectedCustomer!.customerId;
        if (_pointsRedeemed > 0) {
          await customerStore.redeemCustomerPoints(customerId, _pointsRedeemed);
        }
        // An unpaid balance is credit — put it on the customer's account so it
        // shows up in credit reports and can be collected later.
        if (sale.dueAmount > 0) {
          await customerStore.updateAfterCreditSale(customerId, sale.dueAmount);
        }
        final points = LoyaltyPoints.earnedFor(bill.grandTotal);
        await customerStore.updateAfterPurchase(
          customerId,
          bill.grandTotal,
          points,
        );
      }

      // Persist the header and its lines through the store, in one action.
      final saleItems = await _buildSaleItems(saleId, bill);
      await saleStore.addSaleWithItems(sale, saleItems);

      await _deductStock();

      // Store customer before clearing
      final customer = customerStore.selectedCustomer;

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

      // See the credit path above — the dialog's buttons pop the dialog, not
      // this screen, so printing and pressing back landed on a blank Checkout.
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error processing checkout: $e');
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
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Checkout',
        centerTitle: true,
        titleFontSize: AppResponsive.subheadingFontSize(context),
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        // maxCardWidth, not maxFormWidth: this is mostly summary rows with the
        // label left and the amount right, which read fine wider — 600 left a
        // dead gap either side on a tablet.
        maxWidth: AppResponsive.maxCardWidth(context),
        child: Observer(
          builder: (context) {
            if (cartStore.itemCount == 0) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: Color(0xFFD0D0D0),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Cart is empty',
                      style: TextStyle(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        color: Color(0xFF6B6B6B),
                      ),
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
                  const SizedBox(height: 12),
                  _buildLoyaltyCard(),
                  const SizedBox(height: 12),

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

                  // Per-rate GST slabs (hidden when tax is off or zero)
                  _buildGstBreakdownCard(),

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
                  const SizedBox(height: 12),
                  _buildPartialPaymentCard(),
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
                            onPressed: _isProcessing
                                ? null
                                : _processCreditSale,
                            icon: const Icon(Icons.schedule, size: 20),
                            label: Text(
                              'Pay Later',
                              style: TextStyle(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                              ),
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
                            onPressed: _canSubmitPayment
                                ? _processCheckout
                                : null,
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
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : ValueListenableBuilder<String>(
                                    valueListenable:
                                        CurrencyHelper.currencyNotifier,
                                    builder: (context, currencyCode, child) {
                                      return ValueListenableBuilder<int>(
                                        valueListenable:
                                            DecimalSettings.precisionNotifier,
                                        builder: (context, precision, child) {
                                          final symbol =
                                              CurrencyHelper.currentSymbol;
                                          final formattedChange = _changeReturn
                                              .toStringAsFixed(precision);
                                          return Text(
                                            _changeReturn > 0
                                                ? 'Pay ($symbol$formattedChange change)'
                                                : 'Complete Payment',
                                            style: TextStyle(
                                              fontSize:
                                                  AppResponsive.bodyFontSize(
                                                    context,
                                                  ),
                                              fontWeight: FontWeight.w600,
                                            ),
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: AppResponsive.subheadingFontSize(context),
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
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
          _buildSummaryRow(
            'Total Items',
            '${cartStore.totalItems}',
            isBold: false,
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: CurrencyHelper.currencyNotifier,
            builder: (context, currencyCode, child) {
              return ValueListenableBuilder<int>(
                valueListenable: DecimalSettings.precisionNotifier,
                builder: (context, precision, child) {
                  final symbol = CurrencyHelper.currentSymbol;
                  final formattedSubtotal = _subtotal.toStringAsFixed(
                    precision,
                  );
                  return _buildSummaryRow(
                    'Subtotal',
                    '$symbol$formattedSubtotal',
                    isBold: false,
                  );
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
          // Discount type — flat amount or percentage of the item total
          Row(
            children: [
              Expanded(
                child: Text(
                  'Discount',
                  style: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ),
              _buildDiscountTypeToggle(),
            ],
          ),
          const SizedBox(height: 12),

          // Preset percentages — only meaningful in percentage mode
          if (retailCartStore.discountType == DiscountType.percentage) ...[
            Row(
              children: [
                5,
                10,
                15,
                20,
                25,
              ].map((p) => Expanded(child: _buildPercentPreset(p))).toList(),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: Text(
                  retailCartStore.discountType == DiscountType.percentage
                      ? 'Percentage off'
                      : 'Amount off',
                  style: TextStyle(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ),
              SizedBox(
                width: AppResponsive.getValue(
                  context,
                  mobile: 120.0,
                  tablet: 140.0,
                  desktop: 160.0,
                ),
                child: AppTextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // keyboardType alone is a hint, not a constraint — a hardware
                  // keyboard or paste can still enter '-50'. The engine clamps
                  // the value too; this just stops it being typed.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  textAlign: TextAlign.right,
                  prefixWidget: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Text(CurrencyHelper.currentSymbol),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),

          // Reason — only asked for once a discount actually applies
          if (_bill.discountAmount > 0) ...[
            const Divider(height: 24, thickness: 0.5, color: Color(0xFFE8E8E8)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reason',
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedDiscountReason,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                  items: _discountReasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedDiscountReason = v);
                  },
                ),
              ],
            ),
            if (_selectedDiscountReason == 'Other') ...[
              const SizedBox(height: 8),
              AppTextField(
                controller: _otherReasonController,
                hint: 'Enter reason',
                icon: Icons.notes_rounded,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Collect part of the bill now, balance to the customer's account.
  ///
  /// Deliberately requires a customer: an unpaid balance with nobody attached
  /// is money that can never be collected.
  Widget _buildPartialPaymentCard() {
    return Observer(
      builder: (context) {
        final hasCustomer = customerStore.selectedCustomer != null;
        final symbol = CurrencyHelper.currentSymbol;
        final precision = DecimalSettings.precision;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Partial Payment',
                          style: TextStyle(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasCustomer
                              ? 'Collect part now, balance on account'
                              : 'Select a customer to enable',
                          style: TextStyle(
                            fontSize: AppResponsive.smallFontSize(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _allowPartialPayment,
                    activeColor: const Color(0xFFFF9800),
                    // Stays tappable without a customer so we can explain why
                    // it won't turn on, rather than greying out silently.
                    onChanged: (on) {
                      if (on && !hasCustomer) {
                        NotificationService.instance.showError(
                          'Select a customer to use partial payment',
                        );
                        return;
                      }
                      setState(() => _allowPartialPayment = on);
                    },
                  ),
                ],
              ),
              // The customer can be cleared after switching this on — say so,
              // instead of just disabling the pay button with no reason.
              if (_allowPartialPayment && !hasCustomer) ...[
                const Divider(
                  height: 20,
                  thickness: 0.5,
                  color: Color(0xFFE8E8E8),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFFFF9800),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select a customer — the balance is recorded on their account.',
                        style: TextStyle(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: Color(0xFFFF9800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_allowPartialPayment && hasCustomer && _balanceDue > 0) ...[
                const Divider(
                  height: 20,
                  thickness: 0.5,
                  color: Color(0xFFE8E8E8),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Balance Due',
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    Text(
                      '$symbol${_balanceDue.toStringAsFixed(precision)}',
                      style: TextStyle(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Loyalty redemption. Hidden unless a customer with points is attached.
  ///
  /// Redemption is all-or-nothing and capped at the bill; the engine folds it
  /// into the taxable base BEFORE tax, so redeeming also reduces the GST.
  Widget _buildLoyaltyCard() {
    return Observer(
      builder: (context) {
        final customer = customerStore.selectedCustomer;
        final available = customer?.loyaltyPoints ?? 0;
        if (customer == null || available <= 0) return const SizedBox.shrink();

        final symbol = CurrencyHelper.currentSymbol;
        // Cap against the bill computed WITHOUT redemption, so toggling on and
        // off can't ratchet the cap downwards.
        final billBefore = RetailBillingService.compute(
          items: retailCartStore.items,
          isTaxInclusive: retailCartStore.isTaxInclusive,
          discountType: retailCartStore.discountType,
          discountValue: retailCartStore.discountValue,
        ).grandTotal;
        final redeemable = available.clamp(0, billBefore.floor()).toInt();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFF9800).withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.card_giftcard,
                color: Color(0xFFFF9800),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Redeem Loyalty Points',
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      redeemable > 0
                          ? '$available pts available · redeem $redeemable = $symbol$redeemable'
                          : '$available pts available',
                      style: TextStyle(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _pointsRedeemed > 0,
                activeColor: const Color(0xFFFF9800),
                onChanged: redeemable <= 0
                    ? null
                    : (on) {
                        // Show-and-block, not hide: the card stays visible and
                        // the upgrade sheet explains why. Gating the toggle
                        // (the entrance) rather than the commit at settle keeps
                        // a redemption already in the cart from breaking.
                        if (on &&
                            !PlanGuard.allowedOr(
                              context,
                              RetailEntKeys.loyalty,
                              featureName: 'Loyalty Points',
                            )) {
                          return;
                        }
                        setState(() => _pointsRedeemed = on ? redeemable : 0);
                        retailCartStore.setLoyaltyRedemption(
                          _pointsRedeemed.toDouble(),
                        );
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Flat-amount vs percentage selector. Writes to the store so the bill (and
  /// every screen reading it) recomputes.
  Widget _buildDiscountTypeToggle() {
    Widget option(DiscountType type, String label) {
      final selected = retailCartStore.discountType == type;
      return GestureDetector(
        onTap: () {
          // Value means something different per mode — clear it on switch so
          // "50" doesn't silently become "50%".
          _discountController.clear();
          retailCartStore.setDiscount(type: type, value: 0);
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4CAF50) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF6B6B6B),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        option(DiscountType.amount, CurrencyHelper.currentSymbol),
        const SizedBox(width: 6),
        option(DiscountType.percentage, '%'),
      ],
    );
  }

  Widget _buildPercentPreset(int percent) {
    final selected = retailCartStore.discountValue == percent.toDouble();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          _discountController.text = percent.toString();
          setState(() {});
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF4CAF50).withOpacity(0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFE8E8E8),
            ),
          ),
          child: Text(
            '$percent%',
            style: TextStyle(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF6B6B6B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGstBreakdownCard() {
    if (!TaxFeature.enabled) {
      return const SizedBox.shrink();
    }
    // Per-rate slabs come from the engine, not from the cart store, so they
    // reflect the discounted taxable base rather than the pre-discount one.
    final breakdown = _bill.gstBreakdown;
    if (breakdown.isEmpty || _totalGstAmount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GST Breakdown',
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
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
                                style: TextStyle(
                                  color: Color(0xFF6B6B6B),
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
                                ),
                              ),
                              Text(
                                '$symbol${data.totalGstAmount.toStringAsFixed(precision)}',
                                style: TextStyle(
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
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
                                style: TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
                                ),
                              ),
                              Text(
                                '$symbol${data.cgstAmount.toStringAsFixed(precision)}',
                                style: TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '  SGST ${GstService.formatGstRate(rate / 2)}',
                                style: TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
                                ),
                              ),
                              Text(
                                '$symbol${data.sgstAmount.toStringAsFixed(precision)}',
                                style: TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
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
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Gross before any discount — always shown so the customer
                  // can see what the discount came off.
                  _buildSummaryRow(
                    _bill.isTaxInclusive
                        ? 'Item Total (incl. tax)'
                        : 'Item Total',
                    '$symbol${_subtotal.toStringAsFixed(precision)}',
                    isBold: false,
                  ),
                  const SizedBox(height: 8),
                  if (_discountAmount > 0) ...[
                    _buildSummaryRow(
                      'Discount',
                      '- $symbol${_discountAmount.toStringAsFixed(precision)}',
                      isBold: false,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Taxable Amount',
                      '$symbol${_totalTaxableAmount.toStringAsFixed(precision)}',
                      isBold: false,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_totalGstAmount > 0) ...[
                    _buildSummaryRow(
                      'CGST',
                      '+ $symbol${_totalCgstAmount.toStringAsFixed(precision)}',
                      isBold: false,
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 4),
                    _buildSummaryRow(
                      'SGST',
                      '+ $symbol${_totalSgstAmount.toStringAsFixed(precision)}',
                      isBold: false,
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Total GST',
                      '+ $symbol${_totalGstAmount.toStringAsFixed(precision)}',
                      isBold: false,
                      color: const Color(0xFF4CAF50),
                    ),
                    const Divider(
                      height: 20,
                      thickness: 0.5,
                      color: Color(0xFFE8E8E8),
                    ),
                  ],
                  if (_bill.loyaltyRedemption > 0) ...[
                    _buildSummaryRow(
                      'Points Redeemed',
                      '- $symbol${_bill.loyaltyRedemption.toStringAsFixed(precision)}',
                      isBold: false,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Rounding adjustment baked into the grand total; signed so a
                  // downward rounding reads as a deduction.
                  if (_bill.roundOff.abs() > 0.009) ...[
                    _buildSummaryRow(
                      'Round Off',
                      '${_bill.roundOff >= 0 ? '+ ' : '- '}$symbol${_bill.roundOff.abs().toStringAsFixed(precision)}',
                      isBold: false,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildSummaryRow(
                    _bill.loyaltyRedemption > 0 ? 'Net Payable' : 'Grand Total',
                    '$symbol${_grandTotal.toStringAsFixed(precision)}',
                    isBold: true,
                    fontSize: AppResponsive.headingFontSize(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = true,
    double? fontSize,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            color: color ?? const Color(0xFF1A1A1A),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            color: color ?? const Color(0xFF1A1A1A),
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _showSuccessDialog({
    required SaleModel sale,
    required List<SaleItemModel> saleItems,
    Customer? customer,
  }) async {
    final isPartial = sale.dueAmount > 0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppDialogShell(
        // A partly-settled bill is not "paid" — title and accent both say so.
        title: isPartial ? 'Partial Payment Received' : 'Payment Successful!',
        subtitle: 'Receipt #${shortRef(sale.saleId)}',
        accent: isPartial ? AppColors.warning : AppColors.success,
        icon: isPartial ? Icons.schedule_rounded : Icons.check_circle,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          // stretch, not the default centre: AppDialogShell's outer Column is
          // start-aligned, so a shrink-wrapping body sizes to its widest child
          // and hugs the left edge of the dialog.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount
            Container(
              alignment: Alignment.center,
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
                      // Show what was COLLECTED, not the bill total — on a
                      // partial payment those differ, and showing the bill
                      // reads as though the customer paid in full.
                      final formattedAmount = sale.paidAmount.toStringAsFixed(
                        precision,
                      );
                      return Text(
                        '$symbol$formattedAmount',
                        style: TextStyle(
                          fontSize: AppResponsive.getValue(
                            context,
                            mobile: 28.0,
                            tablet: 32.0,
                            desktop: 36.0,
                          ),
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Partial payment: spell out the bill and what is still owed,
            // so a big green number can't be mistaken for a settled sale.
            if (isPartial) ...[
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: DecimalSettings.precisionNotifier,
                builder: (context, precision, child) {
                  final symbol = CurrencyHelper.currentSymbol;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bill Total',
                              style: TextStyle(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                            Text(
                              '$symbol${sale.totalAmount.toStringAsFixed(precision)}',
                              style: TextStyle(
                                fontSize: AppResponsive.smallFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Balance Due',
                              style: TextStyle(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                            Text(
                              '$symbol${sale.dueAmount.toStringAsFixed(precision)}',
                              style: TextStyle(
                                fontSize: AppResponsive.subheadingFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF9800),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          appDialogCancelButton(dialogContext, label: 'Skip & Close'),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Print Receipt',
            color: AppColors.success,
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
                  // Bill composition read from the STORED sale, so a
                  // reprint always matches the original receipt even if
                  // settings changed since.
                  itemTotal: sale.subtotal,
                  loyaltyPointsDiscount: sale.loyaltyPointsUsed,
                  roundOff: sale.roundOff,
                  isTaxInclusive: sale.isTaxInclusive,
                );
                // Close the success dialog once printing is done. Guarded on
                // the DIALOG's context — the print sheet is an await, so the
                // dialog may already be gone by the time we get back.
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Show success dialog for credit/pay later sale
  Future<void> _showCreditSuccessDialog({
    required SaleModel sale,
    required Customer customer,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppDialogShell(
        title: 'Credit Sale Recorded!',
        subtitle: 'Invoice #${shortRef(sale.saleId)}',
        accent: AppColors.warning,
        icon: Icons.schedule,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          // See _showSuccessDialog — the shell is start-aligned, so the body
          // must stretch or it hugs the left edge.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF9800).withOpacity(0.3),
                ),
              ),
              child: ValueListenableBuilder<String>(
                valueListenable: CurrencyHelper.currencyNotifier,
                builder: (context, currencyCode, child) {
                  return ValueListenableBuilder<int>(
                    valueListenable: DecimalSettings.precisionNotifier,
                    builder: (context, precision, child) {
                      final symbol = CurrencyHelper.currentSymbol;
                      final formattedTotal = sale.totalAmount.toStringAsFixed(
                        precision,
                      );
                      final formattedBalance =
                          (customer.creditBalance + sale.totalAmount)
                              .toStringAsFixed(precision);
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                              Text(
                                '$symbol$formattedTotal',
                                style: TextStyle(
                                  fontSize: AppResponsive.subheadingFontSize(
                                    context,
                                  ),
                                  color: Color(0xFFFF9800),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Customer',
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                              Text(
                                customer.name ?? '',
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  color: Color(0xFF1A1A1A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'New Balance',
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                              Text(
                                '$symbol$formattedBalance',
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
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
            Text(
              'Payment is pending. Stock has been deducted.',
              style: TextStyle(
                fontSize: AppResponsive.smallFontSize(context),
                color: Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        // Both buttons pop the DIALOG only. `_processCreditSale` pops the
        // Checkout screen itself once this future returns — the old code
        // popped twice here as well, which only avoided over-popping because
        // `mounted` had already gone false.
        actions: [
          appDialogCancelButton(dialogContext, label: 'Skip & Close'),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Print Invoice',
            color: AppColors.warning,
            onPressed: () async {
              final saleItems = await saleStore.getItemsForSale(sale.saleId);

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
                  // Bill composition read from the STORED sale, so a
                  // reprint always matches the original receipt even if
                  // settings changed since.
                  itemTotal: sale.subtotal,
                  loyaltyPointsDiscount: sale.loyaltyPointsUsed,
                  roundOff: sale.roundOff,
                  isTaxInclusive: sale.isTaxInclusive,
                );
                // The print sheet is an await, so the dialog may already be
                // gone by the time we get back.
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Observer(
      builder: (context) {
        final customer = customerStore.selectedCustomer;

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
                    color: customer != null
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF6B6B6B),
                    size: 24,
                    customer != null ? Icons.person : Icons.person_add_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: customer != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name ?? '',
                              style: TextStyle(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              customer.phone ?? '',
                              style: TextStyle(
                                color: Color(0xFF6B6B6B),
                                fontSize: AppResponsive.smallFontSize(context),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Customer',
                              style: TextStyle(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: Color(0xFF6B6B6B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Optional - Tap to select',
                              style: TextStyle(
                                color: Color(0xFFB0B0B0),
                                fontSize: AppResponsive.smallFontSize(context),
                              ),
                            ),
                          ],
                        ),
                ),
                Icon(
                  size: 18,
                  color: const Color(0xFFB0B0B0),
                  customer != null
                      ? Icons.edit_outlined
                      : Icons.arrow_forward_ios,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
