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
import 'package:billberrylite/domain/services/retail/receipt_pdf_service.dart'
    show receiptLineDiscount, receiptLineDiscountTotal, receiptBillDiscountRemainder;
import 'package:billberrylite/presentation/screens/retail/sale_return_screen.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/util/retail/payment_mode_summary.dart';
import 'package:billberrylite/presentation/screens/retail/exchange_screen.dart';
import 'package:billberrylite/domain/services/retail/print_service.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

class SaleDetailScreen extends StatefulWidget {
  final String saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  final ReturnService _returnService = ReturnService();
  final ExchangeService _exchangeService = ExchangeService();

  SaleModel? _sale;
  List<SaleItemModel> _saleItems = [];
  Customer? _customer;
  bool _isLoading = true;

  /// Every sold unit has come back. Only then is the sale closed to returns.
  bool _isFullyReturned = false;

  /// Some, but not all, has come back — the rest is still returnable.
  bool _isPartiallyReturned = false;

  bool get _hasBeenRefunded => _isFullyReturned || _isPartiallyReturned;

  /// Money still owed on this bill — a partial payment or a pay-later sale.
  /// A return's header is negative, so it is never "outstanding".
  bool get _hasOutstanding =>
      _sale != null && !(_sale!.isReturn ?? false) && _sale!.dueAmount > 0.009;

  /// This sale's exchange lost its replacement half — surfaced rather than
  /// auto-repaired, because a repair that guesses wrong about money is worse
  /// than a visible flag.
  bool _exchangeIncomplete = false;

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

      // How much has come back, by QUANTITY. "Any return exists" used to close
      // the sale outright, so returning 1 of 3 units made the other 2
      // permanently unreturnable.
      var fullyReturned = false;
      var partiallyReturned = false;
      if (sale != null && !(sale.isReturn ?? false)) {
        fullyReturned = await _returnService.isFullyReturned(widget.saleId);
        partiallyReturned =
            !fullyReturned && await _returnService.isPartiallyReturned(widget.saleId);
      }

      // A return stamped with an exchange group whose replacement never landed.
      var exchangeIncomplete = false;
      if (sale?.exchangeGroupId != null) {
        final orphans = await _exchangeService.findIncomplete();
        exchangeIncomplete =
            orphans.any((o) => o.exchangeGroupId == sale!.exchangeGroupId);
      }

      setState(() {
        _sale = sale;
        _saleItems = items;
        _customer = customer;
        _isFullyReturned = fullyReturned;
        _isPartiallyReturned = partiallyReturned;
        _exchangeIncomplete = exchangeIncomplete;
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

      // Only a FULLY returned sale closes the action. A partial return leaves
      // the remaining units returnable — gating on "any return exists" stranded
      // them permanently.
      bottomNavigationBar:
          _sale != null &&
              !(_sale!.isReturn ?? false) &&
              !_isFullyReturned &&
              !_isLoading &&
              (AppSettings.refundsEnabled || _exchangeService.canExchange)
          ? _buildActionBar()
          : null,
    );
  }

  bool get _isRefundWindowExpired {
    if (_sale == null) return false;
    final windowMinutes = AppSettings.refundWindowMinutes;
    if (windowMinutes == 0) return false; // 0 = No Limit
    final saleDate = DateTime.tryParse(_sale!.date);
    if (saleDate == null) return false;
    return DateTime.now().difference(saleDate).inMinutes > windowMinutes;
  }

  /// Return, plus Exchange when the user is allowed to run one.
  ///
  /// Exchange is HIDDEN rather than shown-and-refused for a non-admin — the
  /// pattern every money-sensitive retail action follows.
  Widget _buildActionBar() {
    final canReturn = AppSettings.refundsEnabled;
    final canExchange = _exchangeService.canExchange;

    if (!canExchange && canReturn) return _buildReturnButton();
    if (!canReturn && canExchange) {
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
        child: _capped(context, _exchangeButton()),
      );
    }

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
        Row(
          children: [
            Expanded(child: _exchangeButton()),
            const SizedBox(width: 10),
            Expanded(child: _returnAction(compact: true)),
          ],
        ),
      ),
    );
  }

  Widget _exchangeButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExchangeScreen(saleId: widget.saleId),
          ),
        );
        if (result == true && mounted) Navigator.pop(context, true);
      },
      icon: Icon(Icons.swap_horiz_rounded,
          size: AppResponsive.iconSize(context)),
      label: Text(
        'Exchange',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: AppResponsive.bodyFontSize(context)),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(
          vertical: AppResponsive.largeSpacing(context),
        ),
        minimumSize: Size(0, AppResponsive.buttonHeight(context) + 2),
      ),
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
      child: _capped(context, _returnAction()),
    );
  }

  /// The Return action itself. [compact] shortens the label and drops the
  /// full-width minimum so it can sit beside Exchange in a Row.
  Widget _returnAction({bool compact = false}) {
    final windowExpired = _isRefundWindowExpired;
    final isEnabled = AppSettings.refundsEnabled && !windowExpired;

    final windowMinutes = AppSettings.refundWindowMinutes;
    final windowLabel = windowMinutes < 60
        ? '$windowMinutes min'
        : '${windowMinutes ~/ 60} hr';

    final tooltipMsg = !AppSettings.refundsEnabled
        ? 'Refunds are disabled in Settings'
        : windowExpired
            ? 'Refund window has passed ($windowLabel limit)'
            : '';

    return Tooltip(
      message: tooltipMsg,
      child: ElevatedButton.icon(
        onPressed: isEnabled
            ? () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SaleReturnScreen(saleId: widget.saleId),
                  ),
                );

                if (result == true && mounted) {
                  Navigator.pop(context, true); // Go back to sales history
                }
              }
            : null,
        icon: Icon(
          Icons.keyboard_return,
          size: AppResponsive.iconSize(context),
        ),
        label: Text(
          !AppSettings.refundsEnabled
              ? 'Refunds Disabled'
              : windowExpired
                  ? (compact ? 'Window Expired' : 'Refund Window Expired')
                  : (compact ? 'Return' : 'Process Return/Refund'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact
                ? AppResponsive.bodyFontSize(context)
                : AppResponsive.subheadingFontSize(context),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? Colors.red : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(
            vertical: AppResponsive.largeSpacing(context),
          ),
          minimumSize: Size(
            compact ? 0 : double.infinity,
            AppResponsive.buttonHeight(context) + 2,
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
          // An exchange whose replacement half never landed. Shown, not
          // auto-repaired: the return itself is correct and complete, and
          // guessing at the missing sale would invent money.
          if (_exchangeIncomplete) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: AppResponsive.iconSize(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exchange incomplete — the replacement was never created',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
          ],

          // Unsettled bill. Sat only in `dueAmount`/`status` before, so a
          // ₹200 bill with ₹50 collected read here as an ordinary paid sale.
          if (_hasOutstanding) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: AppResponsive.iconSize(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sale!.statusDisplayText.toUpperCase(),
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
                      'Balance ${formatMoney(_sale!.dueAmount)}',
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
            SizedBox(height: AppResponsive.mediumSpacing(context)),
          ],

          // Refund Status Banner
          if (_hasBeenRefunded) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                // Amber for a partial return: the sale is not closed and more
                // can still come back, so it must not read as final.
                color: _isFullyReturned
                    ? Colors.red.shade600
                    : AppColors.warning,
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
                      _isFullyReturned ? 'REFUNDED' : 'PARTIALLY RETURNED',
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
                      _isFullyReturned ? 'Full Return' : 'Items still returnable',
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
                      saleRef(_sale!.saleId),
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
                      // Via the shared label so an exchange reads "Exchange"
                      // or "Exchange + UPI" rather than a bare payment method
                      // the customer never actually tendered.
                      RetailPaymentModeSummary.methodLabel(_sale!)
                          .toUpperCase(),
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
                // The line's OWN discount only. `discountAmount` also carries
                // this line's share of the order-level discount, which the
                // totals block below subtracts once as "Bill Discount" — showing
                // it here too would read as a double deduction. Same rule the
                // receipt follows.
                if (receiptLineDiscount(item) > 0.009) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Discount',
                    '- ${formatMoney(receiptLineDiscount(item))}',
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
          // Split exactly as the receipt and the checkout screen do, from the
          // same items, so all three views group the numbers identically.
          if (receiptLineDiscountTotal(_saleItems) > 0.009) ...[
            _buildPriceRow(
              'Item Discounts',
              '- ${formatMoney(receiptLineDiscountTotal(_saleItems))}',
              color: Colors.red,
              isBold: false,
            ),
            const SizedBox(height: 12),
          ],
          if (receiptBillDiscountRemainder(_sale!, _saleItems) > 0.009) ...[
            _buildPriceRow(
              receiptLineDiscountTotal(_saleItems) > 0.009
                  ? 'Bill Discount'
                  : 'Discount',
              '- ${formatMoney(receiptBillDiscountRemainder(_sale!, _saleItems))}',
              color: Colors.red,
              isBold: false,
            ),
            const SizedBox(height: 12),
          ],
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
          // What was actually collected against that total. Shown only when
          // they differ — on a settled bill the Grand Total says it all.
          if (_hasOutstanding) ...[
            SizedBox(height: AppResponsive.largeSpacing(context)),
            _buildPriceRow(
              'Paid',
              formatMoney(_sale!.paidAmount),
              color: AppColors.success,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: _buildPriceRow(
                'Balance Due',
                formatMoney(_sale!.dueAmount),
                isBold: true,
                fontSize: AppResponsive.subheadingFontSize(context),
                color: AppColors.warning,
              ),
            ),
            if (_customer != null) ...[
              const SizedBox(height: 8),
              Text(
                "On ${_customer!.name}'s account — collect from Receive Payment.",
                style: TextStyle(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],

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
