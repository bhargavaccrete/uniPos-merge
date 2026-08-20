import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/presentation/screens/retail/sale_return_screen.dart';
import 'package:billberrylite/domain/services/retail/print_service.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

class SaleDetailScreen extends StatefulWidget {
  final String saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  SaleModel? _sale;
  List<SaleItemModel> _saleItems = [];
  Customer? _customer;
  bool _isLoading = true;
  bool _hasBeenRefunded = false;

  @override
  void initState() {
    super.initState();
    _loadSaleData();
  }

  Future<void> _loadSaleData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load sale header
      final sale = await saleStore.getSaleById(widget.saleId);

      // Load sale items
      final items = await saleStore.getItemsForSale(widget.saleId);

      // Load customer if exists
      Customer? customer;
      if (sale?.customerId != null) {
        customer = await customerStore.getCustomerById(sale!.customerId!);
      }

      // Check if this sale has been refunded (look for return transactions)
      bool hasRefund = false;
      if (sale != null) {
        final allSales = await saleStore.getAllSales();
        hasRefund = allSales.any(
          (s) => (s.isReturn ?? false) && s.originalSaleId == widget.saleId,
        );
      }

      setState(() {
        _sale = sale;
        _saleItems = items;
        _customer = customer;
        _hasBeenRefunded = hasRefund;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NotificationService.instance.showError('Error loading sale: $e');
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  Future<void> _printBill() async {
    if (_sale == null || _saleItems.isEmpty) return;

    try {
      // Get store details
      final storeSettingsService = StoreSettingsService();
      final storeName = await storeSettingsService.getStoreName();
      final storeAddress = await storeSettingsService.getFormattedAddress();
      final storePhone = await storeSettingsService.getStorePhone();
      final storeEmail = await storeSettingsService.getStoreEmail();
      final gstNumber = await storeSettingsService.getGSTNumber();

      // Five awaits happened above, so the screen may be gone by now.
      if (!mounted) return;

      // Show print options dialog
      final printService = PrintService();
      await printService.showPrintOptionsDialog(
        context: context,
        sale: _sale!,
        items: _saleItems,
        customer: _customer,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeEmail: storeEmail,
        gstNumber: gstNumber,
        // Same four the checkout screen passes, read off the STORED sale.
        // Omitting them printed a reprint that differed from the original: the
        // "Points Redeemed" and round-off lines vanished, so Sub Total,
        // Discount and Tax no longer added up to the Grand Total.
        itemTotal: _sale!.subtotal,
        loyaltyPointsDiscount: _sale!.loyaltyPointsUsed,
        roundOff: _sale!.roundOff,
        isTaxInclusive: _sale!.isTaxInclusive,
      );
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error printing: $e');
      }
    }
  }

  String _getPaymentIcon(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return '💵';
      case 'card':
        return '💳';
      case 'upi':
        return '📱';
      default:
        return '💰';
    }
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'card':
        return AppColors.info;
      case 'upi':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Sale Details',
        titleFontSize: AppResponsive.subheadingFontSize(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: Implement share functionality
              NotificationService.instance.showSuccess(
                'Share feature coming soon',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _isLoading || _sale == null ? null : _printBill,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
          ? _buildErrorView()
          : _buildSaleDetail(),

      bottomNavigationBar:
          _sale != null &&
              !(_sale!.isReturn ?? false) &&
              !_hasBeenRefunded &&
              !_isLoading
          ? _buildReturnButton()
          : null,
    );
  }

  Widget _buildReturnButton() {
    return Container(
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _capped(
        context,
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SaleReturnScreen(saleId: widget.saleId),
              ),
            );

            if (result == true && mounted) {
              Navigator.pop(context, true); // Go back to sales history
            }
          },
          icon: Icon(
            Icons.keyboard_return,
            size: AppResponsive.iconSize(context),
          ),
          label: Text(
            'Process Return/Refund',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppResponsive.subheadingFontSize(context),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: AppResponsive.largeSpacing(context),
            ),
            minimumSize: Size(
              double.infinity,
              AppResponsive.buttonHeight(context) + 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: AppResponsive.padding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
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
              'Sale not found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppResponsive.subheadingFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            SizedBox(
              height: AppResponsive.buttonHeight(context),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Caps content width on large screens so a stack of detail cards doesn't
  /// stretch across a laptop. Applied once here, which covers the header,
  /// items and summary cards below.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxCardWidth(context);
    if (maxWidth == double.infinity) return child;
    return Align(
      // topCenter + heightFactor: without both, Align fills its constraints —
      // which made this eat the whole screen when used as a bottom bar.
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  Widget _buildSaleDetail() {
    return SingleChildScrollView(
      child: _capped(
        context,
        Column(
          children: [
            // Sale Header Card
            _buildSaleHeaderCard(),

            // Sale Items List
            _buildSaleItemsList(),

            // Summary Card
            _buildSummaryCard(),

            SizedBox(height: AppResponsive.extraLargeSpacing(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleHeaderCard() {
    return Container(
      margin: AppResponsive.padding(context),
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPaymentColor(_sale!.paymentType),
            _getPaymentColor(_sale!.paymentType).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getPaymentColor(_sale!.paymentType).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Refund Status Banner
          if (_hasBeenRefunded) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.keyboard_return,
                    color: Colors.white,
                    size: AppResponsive.iconSize(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'REFUNDED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Full Return',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale ID',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shortRef(_sale!.saleId, length: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.largeSpacing(context),
                  vertical: AppResponsive.smallSpacing(context),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getPaymentIcon(_sale!.paymentType),
                      style: TextStyle(
                        fontSize: AppResponsive.iconSize(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _sale!.paymentType.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.extraLargeSpacing(context)),
          _headerMetaRow(Icons.calendar_today, _formatDate(_sale!.date)),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          _headerMetaRow(
            Icons.shopping_bag_outlined,
            '${_sale!.totalItems} items',
          ),
          if (_customer != null) ...[
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _headerMetaRow(
              Icons.person_outline,
              '${_customer!.name} (${_customer!.phone})',
            ),
          ],
        ],
      ),
    );
  }

  /// One icon+text line of the coloured header card.
  Widget _headerMetaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: AppResponsive.smallIconSize(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: AppResponsive.bodyFontSize(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleItemsList() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.padding(context).left,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppResponsive.padding(context),
            child: Row(
              children: [
                Text(
                  'Items Sold',
                  style: TextStyle(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_saleItems.length} products',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _saleItems.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 0.5,
              color: AppColors.divider,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final item = _saleItems[index];
              return _buildSaleItemTile(item, index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaleItemTile(SaleItemModel item, int itemNumber) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Number Badge
              Container(
                width: AppResponsive.smallAvatarSize(context),
                height: AppResponsive.smallAvatarSize(context),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$itemNumber',
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName ?? 'Unknown Product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ...attributeStore
                            .describeAttributes(
                              item.attributes,
                              size: item.size,
                              color: item.color,
                            )
                            .split(' · ')
                            .where((p) => p.isNotEmpty)
                            .map(_buildPropertyChip),
                        if (item.barcode != null)
                          _buildPropertyChip('📦 ${item.barcode}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Price Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildPriceRow(
                  '${item.qty} × ${formatMoney(item.price)}',
                  formatMoney((item.qty * item.price)),
                  isBold: false,
                ),
                if (item.discountAmount != null &&
                    item.discountAmount! > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Discount',
                    '- ${formatMoney(item.discountAmount!)}',
                    color: Colors.red,
                    isBold: false,
                  ),
                ],
                if (item.taxAmount != null && item.taxAmount! > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Tax',
                    '+ ${formatMoney(item.taxAmount!)}',
                    color: AppColors.success,
                    isBold: false,
                  ),
                ],
                const Divider(height: 16, thickness: 0.5),
                _buildPriceRow(
                  'Item Total',
                  formatMoney(item.total),
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: AppResponsive.captionFontSize(context),
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: AppResponsive.padding(context),
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          _buildPriceRow(
            'Subtotal',
            formatMoney(_sale!.subtotal),
            isBold: false,
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Discount',
            '- ${formatMoney(_sale!.discountAmount)}',
            color: Colors.red,
            isBold: false,
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Tax',
            '+ ${formatMoney(_sale!.taxAmount)}',
            color: AppColors.success,
            isBold: false,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5, color: AppColors.divider),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: _buildPriceRow(
              'Grand Total',
              formatMoney(_sale!.totalAmount),
              isBold: true,
              fontSize: AppResponsive.headingFontSize(context),
            ),
          ),
          // Split Payment Breakdown
          _buildSplitPaymentBreakdown(),
        ],
      ),
    );
  }

  Widget _buildSplitPaymentBreakdown() {
    final paymentList = _sale!.paymentList;

    // Only show if there are multiple payment methods or it's marked as split payment
    if (paymentList.length <= 1 && _sale!.isSplitPayment != true) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: AppResponsive.smallIconSize(context),
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Split Payment Breakdown',
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...paymentList.map((payment) {
                final method =
                    (payment['method'] as String?)?.toUpperCase() ?? 'OTHER';
                final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
                final ref = payment['ref'] as String?;
                final received = (payment['received'] as num?)?.toDouble();
                final change = (payment['change'] as num?)?.toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: AppResponsive.smallAvatarSize(context),
                            height: AppResponsive.smallAvatarSize(context),
                            decoration: BoxDecoration(
                              color: _getPaymentMethodColor(
                                method,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                _getPaymentMethodIcon(method),
                                style: TextStyle(
                                  fontSize: AppResponsive.subheadingFontSize(
                                    context,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppResponsive.mediumSpacing(context)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  method,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppResponsive.smallFontSize(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (ref != null && ref.isNotEmpty)
                                  Text(
                                    'Ref: $ref',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: AppResponsive.captionFontSize(
                                        context,
                                      ),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatMoney(amount),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      // Show cash received and change for cash payments
                      if (method == 'CASH' &&
                          received != null &&
                          received > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          margin: const EdgeInsets.only(left: 44),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMedium,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Cash Received',
                                    style: TextStyle(
                                      fontSize: AppResponsive.smallFontSize(
                                        context,
                                      ),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    formatMoney(received),
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: AppResponsive.smallFontSize(
                                        context,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (change != null && change > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Change Given',
                                      style: TextStyle(
                                        fontSize: AppResponsive.smallFontSize(
                                          context,
                                        ),
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      formatMoney(change),
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: AppResponsive.smallFontSize(
                                          context,
                                        ),
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              // Show total paid and change if any
              if (_sale!.totalPaid != null &&
                  _sale!.totalPaid! > _sale!.totalAmount) ...[
                const Divider(height: 16, thickness: 0.5),
                _buildPriceRow(
                  'Total Paid',
                  formatMoney(_sale!.totalPaid!),
                  isBold: true,
                ),
              ],
              if (_sale!.changeReturn != null && _sale!.changeReturn! > 0) ...[
                const SizedBox(height: 8),
                _buildPriceRow(
                  'Change Returned',
                  formatMoney(_sale!.changeReturn!),
                  color: Colors.orange,
                  isBold: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return '💵';
      case 'card':
        return '💳';
      case 'upi':
        return '📱';
      case 'wallet':
        return '👛';
      case 'credit':
        return '📝';
      default:
        return '💰';
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'card':
        return AppColors.info;
      case 'upi':
        return AppColors.secondary;
      case 'wallet':
        return AppColors.warning;
      case 'credit':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildPriceRow(
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
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: color ?? AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
