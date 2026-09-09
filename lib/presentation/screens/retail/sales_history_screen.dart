import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/presentation/screens/retail/sale_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<SaleModel> _sales = [];

  /// Everything matching the current filters, **including return rows** — the
  /// revenue total needs them because a return is stored with a negative
  /// amount and nets itself out.
  List<SaleModel> _filteredSales = [];

  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, today, dateRange, cash, card, upi

  final ReturnService _returnService = ReturnService();
  final Map<String, bool> _returnedSalesCache = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Rows actually listed. Returns are excluded — they're shown as a RETURNED
  /// badge on the original sale instead. Previously the list rendered them as
  /// zero-height placeholders, so the "Total Sales" count included rows nobody
  /// could see.
  List<SaleModel> get _visibleSales =>
      _filteredSales.where((s) => !(s.isReturn ?? false)).toList();

  double get _totalRevenue =>
      _filteredSales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);

  /// Value returned in this filter window. Stored negative, shown positive.
  double get _returnedValue => _filteredSales
      .where((s) => s.isReturn ?? false)
      .fold<double>(0, (sum, s) => sum + s.totalAmount.abs());

  int get _returnCount =>
      _filteredSales.where((s) => s.isReturn ?? false).length;

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _returnedSalesCache.clear();
    });

    try {
      final sales = await saleStore.getAllSales();
      sales.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _sales = sales;
        _filteredSales = sales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      NotificationService.instance.showError('Error loading sales: $e');
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyAllFilters();
    });
  }

  void _applyAllFilters() {
    List<SaleModel> result = _sales;

    switch (_selectedFilter) {
      case 'today':
        final today = DateTime.now();
        result = result.where((sale) {
          final saleDate = DateTime.tryParse(sale.date);
          if (saleDate == null) return false;
          return saleDate.year == today.year &&
              saleDate.month == today.month &&
              saleDate.day == today.day;
        }).toList();
        break;
      case 'dateRange':
        if (_startDate != null && _endDate != null) {
          result = result.where((sale) {
            final saleDate = DateTime.tryParse(sale.date);
            if (saleDate == null) return false;
            // Compared on calendar days, so both ends are inclusive.
            final day = DateTime(saleDate.year, saleDate.month, saleDate.day);
            final start = DateTime(
              _startDate!.year,
              _startDate!.month,
              _startDate!.day,
            );
            final end = DateTime(
              _endDate!.year,
              _endDate!.month,
              _endDate!.day,
            );
            return !day.isBefore(start) && !day.isAfter(end);
          }).toList();
        }
        break;
      case 'cash':
      case 'card':
      case 'upi':
        result = result
            .where((sale) => sale.paymentType.toLowerCase() == _selectedFilter)
            .toList();
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((sale) {
        return sale.saleId.toLowerCase().contains(query) ||
            sale.totalAmount.toStringAsFixed(2).contains(query);
      }).toList();
    }

    _filteredSales = result;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyAllFilters();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
      _selectedFilter = 'dateRange';
      _applyAllFilters();
    });
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedFilter = 'all';
      _applyAllFilters();
    });
  }

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final saleDate = DateTime(date.year, date.month, date.day);

    if (saleDate == today)
      return 'Today, ${DateFormat('hh:mm a').format(date)}';
    if (saleDate == yesterday) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(date)}';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'card':
        return AppColors.info;
      case 'upi':
        return AppColors.secondary;
      case 'credit':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getPaymentIcon(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return Icons.payments_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'upi':
        return Icons.qr_code_2_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Future<bool> _checkIfReturned(String saleId) async {
    if (_returnedSalesCache.containsKey(saleId)) {
      return _returnedSalesCache[saleId]!;
    }
    final isReturned = await _returnService.isFullyReturned(saleId);
    _returnedSalesCache[saleId] = isReturned;
    return isReturned;
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Sales History',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: _loadSales,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: MoneyScope(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Column(
                children: [
                  Container(
                    color: AppColors.white,
                    padding: EdgeInsets.fromLTRB(
                      AppResponsive.padding(context).left,
                      AppResponsive.mediumSpacing(context),
                      AppResponsive.padding(context).left,
                      12,
                    ),
                    child: AppResponsive.constrainedContent(
                      context: context,
                      alignment: Alignment.topCenter,
                      maxWidth: AppResponsive.maxContentWidth(context),
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _searchController,
                            hint: 'Search by Sale ID or amount...',
                            icon: Icons.search_rounded,
                            onChanged: _onSearchChanged,
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      size: AppResponsive.smallIconSize(
                                        context,
                                      ),
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                          ),
                          SizedBox(
                            height: AppResponsive.mediumSpacing(context),
                          ),
                          _buildFilterChips(),
                        ],
                      ),
                    ),
                  ),
                  _buildSummaryCard(context),
                  if (_selectedFilter == 'dateRange' &&
                      _startDate != null &&
                      _endDate != null)
                    _buildDateRangeBar(),
                  Expanded(
                    child: _visibleSales.isEmpty
                        ? _buildEmptyState()
                        : AppResponsive.constrainedContent(
                            context: context,
                            alignment: Alignment.topCenter,
                            maxWidth: AppResponsive.maxContentWidth(context),
                            child: ListView.builder(
                              padding: AppResponsive.padding(context),
                              itemCount: _visibleSales.length,
                              itemBuilder: (context, index) =>
                                  _buildSaleCard(_visibleSales[index]),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final hasReturns = _returnCount > 0;
    final side = AppResponsive.padding(context).left;

    return Container(
      margin: EdgeInsets.fromLTRB(side, 12, side, 4),
      child: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxContentWidth(context),
        child: Container(
          padding: AppResponsive.cardPadding(context),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
          ),
          child: Row(
            children: [
              _summaryStat('Sales', '${_visibleSales.length}'),
              _summaryDivider(),
              _summaryStat('Net Revenue', formatMoney(_totalRevenue)),
              // Only shown when there is something to show — otherwise the
              // returns column is dead space on every screen.
              if (hasReturns) ...[
                _summaryDivider(),
                _summaryStat(
                  'Returned',
                  formatMoney(_returnedValue),
                  caption:
                      '$_returnCount refund${_returnCount == 1 ? '' : 's'}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryDivider() => Container(
    height: AppResponsive.getValue(
      context,
      mobile: 40.0,
      tablet: 46.0,
      desktop: 52.0,
    ),
    width: 1,
    margin: EdgeInsets.symmetric(
      horizontal: AppResponsive.mediumSpacing(context),
    ),
    color: AppColors.white.withValues(alpha: 0.25),
  );

  Widget _summaryStat(String label, String value, {String? caption}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
          if (caption != null)
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.white.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeBar() {
    final side = AppResponsive.padding(context).left;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        side,
        AppResponsive.smallSpacing(context),
        side,
        0,
      ),
      child: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxContentWidth(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.mediumSpacing(context),
            vertical: AppResponsive.smallSpacing(context),
          ),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.date_range_rounded,
                size: AppResponsive.smallIconSize(context),
                color: AppColors.info,
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                child: Text(
                  '${DateFormat('dd MMM yyyy').format(_startDate!)} — ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w500,
                    color: AppColors.info,
                  ),
                ),
              ),
              InkWell(
                onTap: _clearDateRange,
                child: Icon(
                  Icons.close_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = <(String, String)>[
      ('All Sales', 'all'),
      ('Today', 'today'),
      ('Cash', 'cash'),
      ('Card', 'card'),
      ('UPI', 'upi'),
    ];

    return SizedBox(
      height: AppResponsive.getValue(
        context,
        mobile: 34.0,
        tablet: 40.0,
        desktop: 44.0,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (label, value) in filters) ...[
            _filterPill(
              label: label,
              selected: _selectedFilter == value,
              onTap: () => _applyFilter(value),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
          ],
          _filterPill(
            label: 'Date Range',
            icon: Icons.date_range_rounded,
            selected: _selectedFilter == 'dateRange',
            onTap: _selectDateRange,
          ),
        ],
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.smallBorderRadius(context),
          ),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppResponsive.smallIconSize(context),
                color: selected ? AppColors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final filtering = _selectedFilter != 'all' || _searchQuery.isNotEmpty;

    return AppEmptyState(
      icon: filtering ? Icons.search_off_rounded : Icons.receipt_long_outlined,
      title: filtering ? 'No sales match' : 'No sales yet',
      message: filtering
          ? 'Try a different filter or search term.'
          : 'Sales will appear here after checkout.',
    );
  }

  /// One icon+label pair of the sale card's footer. Sized to its content so it
  /// can sit in a Wrap and drop to the next line instead of overflowing.
  Widget _saleMeta(
    IconData icon,
    String label,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppResponsive.smallIconSize(context), color: color),
        const SizedBox(width: 5),
        Text(
          label,
          maxLines: 1,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSaleCard(SaleModel sale) {
    final paymentColor = _getPaymentColor(sale.paymentType);

    return FutureBuilder<bool>(
      future: _checkIfReturned(sale.saleId),
      builder: (context, snapshot) {
        final isReturned = snapshot.data ?? false;

        final radius = AppResponsive.smallBorderRadius(context);

        return Container(
          margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isReturned
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : AppColors.divider,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SaleDetailScreen(saleId: sale.saleId),
                ),
              );
              // A refund made on the detail screen changes this row's badge.
              if (mounted) _loadSales();
            },
            child: Padding(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppResponsive.smallAvatarSize(context),
                        height: AppResponsive.smallAvatarSize(context),
                        decoration: BoxDecoration(
                          color: paymentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppResponsive.smallBorderRadius(context),
                          ),
                        ),
                        child: Icon(
                          _getPaymentIcon(sale.paymentType),
                          size: AppResponsive.iconSize(context),
                          color: paymentColor,
                        ),
                      ),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sale.displayNumber,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.bodyFontSize(
                                        context,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isReturned) ...[
                                  SizedBox(
                                    width: AppResponsive.smallSpacing(context),
                                  ),
                                  const AppStatusPill(
                                    dense: true,
                                    label: 'RETURNED',
                                    color: AppColors.danger,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(sale.date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.captionFontSize(
                                  context,
                                ),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(sale.totalAmount),
                            maxLines: 1,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AppStatusPill(
                            dense: true,
                            label: sale.paymentType.toUpperCase(),
                            color: paymentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  const Divider(height: 1, color: AppColors.divider),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  Row(
                    children: [
                      // Wrap inside the Expanded so a long discount amount
                      // drops to a second line instead of pushing the chevron
                      // off the card — a Spacer gives back nothing when the
                      // fixed content already exceeds the width.
                      Expanded(
                        child: Wrap(
                          spacing: AppResponsive.mediumSpacing(context),
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _saleMeta(
                              Icons.shopping_bag_outlined,
                              '${sale.totalItems} items',
                              AppColors.textSecondary,
                            ),
                            if (sale.discountAmount > 0)
                              _saleMeta(
                                Icons.local_offer_outlined,
                                '${formatMoney(sale.discountAmount)} off',
                                AppColors.danger,
                                bold: true,
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: AppResponsive.smallIconSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
