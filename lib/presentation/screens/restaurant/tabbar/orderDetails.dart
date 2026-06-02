
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../domain/services/restaurant/cart_calculation_service.dart';
import '../../../../core/di/service_locator.dart';
import '../util/restaurant_print_helper.dart';
import '../start order/cart/customerdetails.dart';
import 'partial_refund_dialog.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../../util/common/app_responsive.dart';
class Orderdetails extends StatefulWidget {
  final PastOrderModel? Order;
  const Orderdetails({super.key, this.Order});

  @override
  State<Orderdetails> createState() => _OrderdetailsState();
}

class _OrderdetailsState extends State<Orderdetails> {
  late PastOrderModel currentOrder;

  @override
  void initState() {
    super.initState();
    if (widget.Order == null) return;
    currentOrder = widget.Order!;
  }

  String _money(num? v) => '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((v ?? 0).toDouble())}';

  @override
  Widget build(BuildContext context) {
    if (widget.Order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Order Not Found')),
      );
    }

    final items = currentOrder.items ?? <CartItem>[];
    final String status = currentOrder.orderStatus?.toUpperCase() ?? 'COMPLETED';
    final bool isVoid = status == 'VOID' || status == 'VOIDED';
    final bool isFullyRefunded = status == 'FULLY_REFUNDED';
    final bool isPartiallyRefunded = status == 'PARTIALLY_REFUNDED';

    bool isRefundEligible = false;
    if (!isFullyRefunded && currentOrder.orderAt != null) {
      final window = AppSettings.refundWindowMinutes;
      if (window == 0) {
        isRefundEligible = true; // No limit
      } else {
        final minuteSinceOrder = DateTime.now().difference(currentOrder.orderAt!).inMinutes;
        if (minuteSinceOrder <= window) {
          isRefundEligible = true;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Order Details',
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Print',
                outlined: true,
                onTap: () => _printBill(context),
              ),
            ),
            const SizedBox(width: 12),
            if (!isFullyRefunded && !isVoid)
              Expanded(
                child: Tooltip(
                  message: isRefundEligible ? '' : AppSettings.refundWindowMinutes == 0 ? '' : 'Refund window has passed',
                  child: _ActionBtn(
                    label: 'Refund',
                    color: isRefundEligible ? Colors.orange : AppColors.textSecondary,
                    onTap: isRefundEligible ? () => _showRefundDialog(context) : () {
                      final w = AppSettings.refundWindowMinutes;
                      final label = w < 60 ? '$w min' : w == 60 ? '1 hour' : '${(w / 60).toStringAsFixed(w % 60 == 0 ? 0 : 1)} hours';
                      NotificationService.instance.showError(
                        'Refund window has passed (must be within $label of order).',
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // VOID Status Banner
          if (isVoid)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: AppResponsive.getValue(context, mobile: 20.0, tablet: 22.0, desktop: 24.0)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This order was voided (deleted before payment). No refund is applicable.',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                              fontWeight: FontWeight.w500,
                              color: Colors.red.shade700,
                            ),
                          ),
                          if ((currentOrder.voidedBy ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Voided by: ${currentOrder.voidedBy}',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // KOT Numbers Display Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: AppColors.primary, size: AppResponsive.getValue(context, mobile: 20.0, tablet: 22.0, desktop: 24.0)),
                      SizedBox(width: 8),
                      Text(
                        'Kitchen Order Tickets (KOT)',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
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
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppResponsive.largeBorderRadius(context)),
                        ),
                        child: Text(
                          'KOT #$kotNum',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
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
                          fontSize: AppResponsive.getValue(context, mobile: 11.0, tablet: 12.0, desktop: 13.0),
                          color: AppColors.textSecondary,
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
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.replaceAll('_', ' '),
                      style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0), fontWeight: FontWeight.w700, color: Colors.orange.shade800),
                    ),
                    const SizedBox(height: 4),
                    _kv('Total Refunded', _money(currentOrder.refundAmount)),
                    if ((currentOrder.refundReason ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Reason(s): ${currentOrder.refundReason}',
                            style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0), color: AppColors.textSecondary)),
                      ),
                    if (currentOrder.refundedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Last Refund At: ${_fmtDate(currentOrder.refundedAt!)}',
                          style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0), color: AppColors.textSecondary),
                        ),
                      ),
                    if ((currentOrder.refundedBy ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Refunded by: ${currentOrder.refundedBy}',
                          style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0), color: AppColors.textSecondary),
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
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
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
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.white, size: AppResponsive.getValue(context, mobile: 20.0, tablet: 22.0, desktop: 24.0)),
                        SizedBox(width: 8),
                        Text(
                          'KOT #$kotNum',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                          ),
                          child: Text(
                            '${kotItems.length} item${kotItems.length > 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
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

                      // Line total = item unit price × qty (same as bill).
                      // item.price is the base price as entered on the menu.
                      // Tax and order-level discount are shown only in the totals section.
                      final lineTotal = it.finalItemPrice * remainingQty;

                      return Card(
                        elevation: 0,
                        color: itemIsFullyRefunded ? AppColors.surfaceMedium : AppColors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context))),
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
                                      style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(it.title?.toString() ?? '—',
                                            style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0), fontWeight: FontWeight.w600)),
                                        // This is where _metaChip was missing
                                        if (it.variantName != null) _metaChip(it.variantName!),
                                        // Display extras with quantities
                                        if (it.extras != null && it.extras!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Builder(
                                              builder: (context) {
                                                // Group extras by name and count them
                                                Map<String, Map<String, dynamic>> groupedExtras = {};

                                                for (var extra in it.extras!) {
                                                  final displayName = extra['displayName'] ?? extra['name'] ?? 'Unknown';
                                                  final price = extra['price']?.toDouble() ?? 0.0;
                                                  final quantity = extra['quantity']?.toInt() ?? 1;

                                                  String key = '$displayName-${price.toStringAsFixed(2)}';

                                                  if (groupedExtras.containsKey(key)) {
                                                    groupedExtras[key]!['quantity'] = (groupedExtras[key]!['quantity'] as int) + quantity;
                                                  } else {
                                                    groupedExtras[key] = {
                                                      'displayName': displayName,
                                                      'price': price,
                                                      'quantity': quantity,
                                                    };
                                                  }
                                                }

                                                // Build display string
                                                final extrasDisplay = groupedExtras.entries.map((entry) {
                                                  final data = entry.value;
                                                  final int qty = data['quantity'] as int;
                                                  final String name = data['displayName'] as String;
                                                  final double price = data['price'] as double;

                                                  if (qty > 1) {
                                                    return '${qty}x $name(${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(price)})';
                                                  } else {
                                                    return '$name(${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(price)})';
                                                  }
                                                }).join(', ');

                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                                    border: Border.all(color: Colors.orange.shade200, width: 0.5),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.add_circle_outline, size: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0), color: Colors.orange.shade700),
                                                      SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          'Extras: $extrasDisplay',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: AppResponsive.getValue(context, mobile: 11.0, tablet: 12.0, desktop: 13.0),
                                                            color: Colors.orange.shade900,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        // Display choices/add-ons
                                        if (it.choiceNames != null && it.choiceNames!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 0.5),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.restaurant_menu, size: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0), color: AppColors.primary),
                                                  SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Choices: ${it.choiceNames!.join(", ")}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: AppResponsive.getValue(context, mobile: 11.0, tablet: 12.0, desktop: 13.0),
                                                        color: AppColors.primary,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // Tax rate badge (info only — GST total shown at bottom)
                                        if (it.taxRate != null && it.taxRate! > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.receipt, size: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0), color: AppColors.textSecondary),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Tax: ${(it.taxRate! * 100).toStringAsFixed(0)}%',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: AppResponsive.getValue(context, mobile: 11.0, tablet: 12.0, desktop: 13.0),
                                                    color: AppColors.textSecondary,
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
                                        style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0), fontWeight: FontWeight.w700),
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
                                      fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  children: [
                    // Pre-discount subtotal = taxable (post-discount) + discount
                    _totalRow('Sub Total', _money((currentOrder.subTotal ?? 0) + (currentOrder.Discount ?? 0))),
                    if ((currentOrder.Discount ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _totalRow('Discount', '-${_money(currentOrder.Discount)}', color: Colors.green.shade700),
                      if ((currentOrder.discountAppliedBy ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'by ${currentOrder.discountAppliedBy}',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                    ],
                    if ((currentOrder.loyaltyPointsUsed ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _totalRow('Points Redeemed', '-${CurrencyHelper.currentSymbol}${currentOrder.loyaltyPointsUsed}'),
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

                    // Payment method / Split payment breakdown
                    const Divider(height: 20),
                    if (currentOrder.isSplitPayment == true) ...[
                      // Split payment — show each method with cash detail
                      ...currentOrder.paymentList.expand((p) {
                        final method = (p['method'] as String? ?? 'Unknown').toUpperCase();
                        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                        final received = (p['received'] as num?)?.toDouble() ?? 0.0;
                        final change = (p['change'] as num?)?.toDouble() ?? 0.0;
                        return [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _totalRow(method, _money(amount), color: AppColors.primary),
                          ),
                          if (received > amount)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2, left: 12),
                              child: _totalRow('  Received', _money(received), color: AppColors.textSecondary),
                            ),
                          if (change > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4, left: 12),
                              child: _totalRow('  Change', _money(change), color: Colors.orange.shade700),
                            ),
                        ];
                      }),
                    ] else ...[
                      // Single payment
                      _totalRow(
                        'Paid by',
                        (currentOrder.paymentmode ?? 'Cash').toUpperCase(),
                        color: AppColors.primary,
                      ),
                    ],
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

  Future<void> _printBill(BuildContext context) async {
    try {
      // Convert pastOrderModel to OrderModel for printing
      final orderForPrint = OrderModel(
        id: currentOrder.id,
        customerName: currentOrder.customerName ?? '',
        customerNumber: '', // pastOrderModel doesn't store customer number
        customerEmail: '', // pastOrderModel doesn't store customer email
        items: currentOrder.items ?? [],
        status: 'COMPLETED',
        timeStamp: currentOrder.orderAt ?? DateTime.now(),
        orderType: currentOrder.orderType ?? 'Take Away',
        tableNo: currentOrder.tableNo, // Preserved from original order
        totalPrice: currentOrder.totalPrice ?? 0,
        discount: currentOrder.Discount,
        serviceCharge: currentOrder.serviceCharge,
        paymentMethod: currentOrder.paymentmode,
        paymentStatus: 'PAID',
        isPaid: true,
        isSplitPayment: currentOrder.isSplitPayment,
        paymentListJson: currentOrder.paymentListJson,
        completedAt: currentOrder.orderAt,
        subTotal: currentOrder.subTotal,
        gstAmount: currentOrder.gstAmount,
        kotNumbers: currentOrder.kotNumbers,
        itemCountAtLastKot: currentOrder.items?.length ?? 0,
        kotBoundaries: currentOrder.kotBoundaries,
      );

      // Create calculations with saved values from the order
      final calculations = CartCalculationService(
        items: currentOrder.items ?? [],
        discountType: DiscountType.amount,
        discountValue: currentOrder.Discount ?? 0,
        isDeliveryOrder: true,
        deliveryCharge: currentOrder.serviceCharge ?? 0,
        isTaxInclusive: currentOrder.isTaxInclusive, // Use stored tax mode from order
      );

      // Print using RestaurantPrintHelper
      await RestaurantPrintHelper.printOrderReceipt(
        context: context,
        order: orderForPrint,
        calculations: calculations,
        billNumber: currentOrder.billNumber,
        loyaltyPointsDiscount: currentOrder.loyaltyPointsUsed ?? 0,
      );
    } catch (e) {
      NotificationService.instance.showError('Failed to print: $e');
    }
  }

  Widget _headCell(String text, {int flex = 1, bool alignEnd = false}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 11.0, tablet: 12.0, desktop: 13.0), color: AppColors.textSecondary),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isStrong = false, Color? color}) {
    final style = GoogleFonts.poppins(
      fontSize: isStrong ? AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0) : AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
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
        Text(k, style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0), color: AppColors.textPrimary)),
        Text(v, style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _showRefundDialog(BuildContext context) async {

    // Validate refund eligibility using store
    final eligibilityError = pastOrderStore.validateRefundEligibility(currentOrder);
    if (eligibilityError != null) {
      NotificationService.instance.showInfo(eligibilityError);
      return;
    }

    // Get refundable items and remaining amount using store
    final refundableItems = pastOrderStore.getRefundableItems(currentOrder);
    final remainingTotal = pastOrderStore.getRemainingRefundableAmount(currentOrder);


    // Calculate GST rate for dialog
    final subTotal = currentOrder.subTotal ?? 0;
    final gstAmount = currentOrder.gstAmount ?? 0;
    final gstRate = (subTotal > 0) ? (gstAmount / subTotal) : 0.0;

    final result = await showDialog<PartialRefundResult>(
      context: context,
      builder: (ctx) => PartialRefundDialog(
        orderItems: refundableItems,
        allOrderItems: currentOrder.items ?? [],
        orderGstRate: gstRate,
        orderTotalPrice: remainingTotal,
        orderDiscount: currentOrder.Discount ?? 0.0,
        orderSubTotal: currentOrder.subTotal ?? 0.0,
        isTaxInclusive: currentOrder.isTaxInclusive ?? false,
      ),
    );

    if (result != null) {
      await _processPartialRefund(result);
    } else {
    }
  }

  Future<void> _processPartialRefund(PartialRefundResult result) async {
    // Use PastOrderStore to handle all business logic
    final updatedOrder = await pastOrderStore.processRefund(
      order: currentOrder,
      refundResult: result,
    );

    if (updatedOrder != null) {
      // Update UI state
      setState(() => currentOrder = updatedOrder);

      // Show success message
      NotificationService.instance.showSuccess(
        'Refund processed: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(result.totalRefundAmount)}'
      );
    } else {
      // Error message already set by store
      NotificationService.instance.showError(
        pastOrderStore.errorMessage ?? 'Failed to process refund'
      );
    }
  }

  // Business logic has been moved to RefundService and InventoryService
  // UI should only handle user interactions and display

  Future<void> _deleteOrder(BuildContext context) async {
    // Show dialog to get void reason
    final TextEditingController reasonController = TextEditingController();

    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context))),
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: AppResponsive.getValue(context, mobile: 28.0, tablet: 30.0, desktop: 32.0)),
            SizedBox(width: 12),
            Text(
              "Void Order",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to void this order?",
              style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0)),
            ),
            SizedBox(height: 16),
            Text(
              "Reason for voiding:",
              style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0), fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            AppTextField(
              controller: reasonController,
              maxLines: 3,
              hint: "Enter reason (optional)",
              icon: Icons.note_alt_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text("Void Order", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) {
      reasonController.dispose();
      return;
    }

    // Use PastOrderStore to void the order
    final voidedOrder = await pastOrderStore.voidOrder(
      order: currentOrder,
      reason: reasonController.text,
    );

    reasonController.dispose();

    if (voidedOrder != null) {
      setState(() => currentOrder = voidedOrder);

      NotificationService.instance.showSuccess('Order voided successfully');
      if (mounted) Navigator.pop(context, true); // Return true to refresh parent
    } else {
      NotificationService.instance.showError(
        pastOrderStore.errorMessage ?? 'Failed to void order'
      );
    }
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
    final bg = outlined ? Colors.transparent : (color ?? AppColors.primary);
    final fg = outlined ? Theme.of(context).textTheme.bodyMedium?.color : Colors.white;
    final border = outlined ? BorderSide(color: AppColors.divider) : BorderSide.none;

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
        child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0))),
      ),
    );
  }



}