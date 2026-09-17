import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/util/color.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../util/restaurant_print_helper.dart';
import 'orderDetails.dart';
import 'past_order_list_index.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

class Pastorder extends StatefulWidget {
  const Pastorder({super.key});

  @override
  State<Pastorder> createState() => _PastorderState();
}

class _PastorderState extends State<Pastorder> {
  // Filters
  String _orderType = 'All';
  final List<String> _orderTypeOptions = const [
    'All',
    'Take Away',
    'Delivery',
    'Dine In',
  ];
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;

  /// Sorted orders + search text, rebuilt only when the orders list changes.
  PastOrderListIndex? _index;
  late final void Function() _disposeOrdersObserver;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {})); // live filter
    _disposeOrdersObserver =
        pastOrderStore.pastOrders.observe((_) => _index = null);
    pastOrderStore.loadPastOrders(); // Load past orders from store
  }

  @override
  void dispose() {
    _disposeOrdersObserver();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _money(num? v) =>
      '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount((v ?? 0).toDouble())}';

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year;
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy • $hh:%02d'.replaceFirst('%02d', min);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
      builder: (ctx, child) {
        // color theming to match your primary color
        final scheme = Theme.of(ctx).colorScheme.copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        );
        return Theme(
          data: Theme.of(ctx).copyWith(colorScheme: scheme),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔽 Filter header — matches Active Orders style (search-forward + compact dropdown)
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.largeSpacing(context),
            vertical: AppResponsive.smallSpacing(context),
          ),
          color: AppColors.white,
          child: Column(
            children: [
              // Row 1: search + compact order-type dropdown
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _searchCtrl,
                      hint: 'Search name / KOT / bill no',
                      icon: Icons.search_rounded,
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppColors.textSecondary,
                                size: AppResponsive.smallIconSize(context),
                              ),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(width: AppResponsive.smallSpacing(context)),
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
                      value: _orderType,
                      isDense: true,
                      underline: const SizedBox(),
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
                      items: _orderTypeOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _orderType = val ?? 'All'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppResponsive.smallSpacing(context)),
              // Row 2: date range + Today shortcut
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.mediumSpacing(context),
                          vertical: AppResponsive.mediumSpacing(context),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                          color: AppColors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: AppResponsive.smallIconSize(context),
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(
                              width: AppResponsive.smallSpacing(context),
                            ),
                            Expanded(
                              child: Text(
                                _dateRange == null
                                    ? 'Date range'
                                    : '${_fmtDate(_dateRange!.start)} — ${_fmtDate(_dateRange!.end)}',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_dateRange != null)
                              InkWell(
                                onTap: () => setState(() => _dateRange = null),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: AppResponsive.smallSpacing(context),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: AppResponsive.smallIconSize(context),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppResponsive.smallSpacing(context)),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final now = DateTime.now();
                        final start = DateTime(now.year, now.month, now.day);
                        final end = DateTime(now.year, now.month, now.day);
                        setState(
                          () => _dateRange = DateTimeRange(
                            start: start,
                            end: end,
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.today_outlined,
                        size: AppResponsive.smallIconSize(context),
                      ),
                      label: Text(
                        'Today',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.divider),
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 🔽 Orders list
        Expanded(
          child: Observer(
            builder: (_) {
              final all = pastOrderStore.pastOrders;

              if (pastOrderStore.isLoading && all.isEmpty) {
                return Center(child: CircularProgressIndicator());
              }

              if (all.isEmpty) {
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
                        'No past orders found',
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

              final filtered = (_index ??= PastOrderListIndex(all)).filter(
                orderType: _orderType,
                dateRange: _dateRange,
                rawQuery: _searchCtrl.text,
              );

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
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
                        'No matching orders for selected filters',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: AppResponsive.subheadingFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final o = filtered[index];
                  final isRefunded = o.isRefunded == true;
                  final isVoided = (o.orderStatus ?? '').contains('VOID');
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Orderdetails(Order: o),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                    child: Container(
                      margin: EdgeInsets.only(
                        bottom: AppResponsive.mediumSpacing(context),
                      ),
                      padding: EdgeInsets.all(
                        AppResponsive.mediumSpacing(context),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: isVoided
                              ? AppColors.textSecondary
                              : const Color(0xFFDEE1E6),
                        ),
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row — KOT chips + bill number + date
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      'KOT:',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: AppResponsive.smallFontSize(
                                          context,
                                        ),
                                      ),
                                    ),
                                    ...o.getKotNumbers().map(
                                      (kotNum) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppResponsive.smallBorderRadius(
                                              context,
                                            ),
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          '#$kotNum',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                AppResponsive.captionFontSize(
                                                  context,
                                                ),
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (o.billNumber != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            AppResponsive.smallBorderRadius(
                                              context,
                                            ),
                                          ),
                                          border: Border.all(
                                            color: Colors.green.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          'INV${o.billNumber}',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                AppResponsive.captionFontSize(
                                                  context,
                                                ),
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                _fmtDateTime(o.orderAt),
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.captionFontSize(
                                    context,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Name + total + reprint button
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (o.customerName?.isNotEmpty == true)
                                      ? o.customerName!
                                      : 'Guest',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: AppResponsive.smallSpacing(context),
                              ),
                              Text(
                                _money(o.totalPrice),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(
                                width: AppResponsive.smallSpacing(context),
                              ),
                              // Reprint button
                              if (!isVoided)
                                InkWell(
                                  onTap: () async {
                                    try {
                                      await RestaurantPrintHelper.printPastOrder(
                                        context: context,
                                        pastOrder: o,
                                      );
                                    } catch (e) {
                                      // handled inside helper
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppResponsive.smallSpacing(
                                        context,
                                      ),
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.print_outlined,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Print',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                AppResponsive.captionFontSize(
                                                  context,
                                                ),
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Type + table + payment + status badges
                          Row(
                            children: [
                              Text(
                                o.orderType ?? '',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
                                ),
                              ),
                              if ((o.tableNo ?? '').isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• Table ${o.tableNo}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                    fontSize: AppResponsive.smallFontSize(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if ((o.paymentmode ?? '').isNotEmpty)
                                Flexible(
                                  child: Text(
                                    o.paymentDisplay,
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.black54,
                                      fontSize: AppResponsive.smallFontSize(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              if (isVoided) ...[
                                SizedBox(
                                  width: AppResponsive.smallSpacing(context),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppResponsive.smallSpacing(
                                      context,
                                    ),
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.divider,
                                    borderRadius: BorderRadius.circular(
                                      AppResponsive.smallBorderRadius(context),
                                    ),
                                  ),
                                  child: Text(
                                    'Voided',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.captionFontSize(
                                        context,
                                      ),
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ] else if (isRefunded) ...[
                                SizedBox(
                                  width: AppResponsive.smallSpacing(context),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppResponsive.smallSpacing(
                                      context,
                                    ),
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(
                                      AppResponsive.smallBorderRadius(context),
                                    ),
                                  ),
                                  child: Text(
                                    'Refunded',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.captionFontSize(
                                        context,
                                      ),
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
