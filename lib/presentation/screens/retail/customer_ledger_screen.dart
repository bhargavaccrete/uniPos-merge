import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/domain/store/retail/credit_store.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Customer Ledger Screen - Timeline view of customer transactions
class CustomerLedgerScreen extends StatefulWidget {
  final Customer customer;

  const CustomerLedgerScreen({super.key, required this.customer});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  bool _isLoading = true;
  List<LedgerEntry> _entries = [];
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      final entries = await creditStore.getCustomerLedger(
        widget.customer.customerId,
      );
      if (mounted) setState(() => _entries = entries);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LedgerEntry> get _filteredEntries {
    if (_dateFilter == null) return _entries;

    return _entries.where((entry) {
      final entryDate = DateTime.tryParse(entry.date);
      if (entryDate == null) return true;
      return entryDate.isAfter(
            _dateFilter!.start.subtract(const Duration(days: 1)),
          ) &&
          entryDate.isBefore(_dateFilter!.end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() => _dateFilter = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final entries = _filteredEntries;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Customer Ledger',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            tooltip: 'Filter by date',
            onPressed: _selectDateRange,
          ),
          if (_dateFilter != null)
            IconButton(
              icon: Icon(Icons.filter_alt_off_outlined),
              tooltip: 'Clear filter',
              onPressed: () => setState(() => _dateFilter = null),
            ),
          SizedBox(width: 4),
        ],
      ),
      body: MoneyScope(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxContentWidth(context),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Column(
                  children: [
                    _buildCustomerSummary(),

                    if (_dateFilter != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: AppColors.info.withValues(alpha: 0.08),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: AppResponsive.smallIconSize(context),
                              color: AppColors.info,
                            ),
                            SizedBox(
                              width: AppResponsive.smallSpacing(context),
                            ),
                            Text(
                              '${DateFormat('dd/MM/yy').format(_dateFilter!.start)} — ${DateFormat('dd/MM/yy').format(_dateFilter!.end)}',
                              style: GoogleFonts.poppins(
                                color: AppColors.info,
                                fontSize: AppResponsive.smallFontSize(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: entries.isEmpty
                          ? AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions found',
                              message: _dateFilter != null
                                  ? 'Nothing recorded in the selected date range.'
                                  : 'Credit sales and payments will appear here.',
                            )
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: _loadLedger,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  16,
                                ),
                                itemCount: entries.length,
                                itemBuilder: (context, index) =>
                                    _buildLedgerEntry(
                                      entries[index],
                                      dateFormat,
                                      isLast: index == entries.length - 1,
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

  Widget _buildCustomerSummary() {
    final hasDue = widget.customer.creditBalance > 0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.cardPadding(context).left,
        vertical: AppResponsive.mediumSpacing(context),
      ),
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (widget.customer.name?.isNotEmpty ?? false)
                      ? widget.customer.name![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customer.name ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.customer.phone ?? '—',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          const Divider(height: 1, color: AppColors.divider),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Purchase',
                formatMoney(widget.customer.totalPurchaseAmount),
                AppColors.primary,
              ),
              _buildStatItem(
                'Outstanding',
                formatMoney(widget.customer.creditBalance),
                hasDue ? AppColors.danger : AppColors.success,
              ),
              _buildStatItem(
                'Visits',
                widget.customer.totalVisites.toString(),
                AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerEntry(
    LedgerEntry entry,
    DateFormat dateFormat, {
    required bool isLast,
  }) {
    final entryDate = DateTime.tryParse(entry.date);
    final dateStr = entryDate != null
        ? dateFormat.format(entryDate)
        : entry.date;

    // Semantic per entry type — a credit sale grows the debt (red, "+"),
    // a payment shrinks it (green), a write-off is neutral.
    late final Color iconColor;
    late final IconData icon;
    late final Color amountColor;
    late final String amountPrefix;

    switch (entry.type) {
      case LedgerEntryType.creditSale:
        iconColor = AppColors.warning;
        icon = Icons.receipt_long_rounded;
        amountColor = AppColors.danger;
        amountPrefix = '+';
        break;
      case LedgerEntryType.payment:
        iconColor = AppColors.success;
        icon = Icons.payments_rounded;
        amountColor = AppColors.success;
        amountPrefix = '';
        break;
      case LedgerEntryType.writeOff:
        iconColor = AppColors.textSecondary;
        icon = Icons.delete_outline_rounded;
        amountColor = AppColors.textSecondary;
        amountPrefix = '';
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail — the connector stops at the last entry so the line
          // never dangles below the final card.
          Column(
            children: [
              Container(
                width: AppResponsive.smallAvatarSize(context),
                height: AppResponsive.smallAvatarSize(context),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor, width: 2),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: AppResponsive.smallIconSize(context),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.divider)),
            ],
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),

          Expanded(
            child: Container(
              margin: EdgeInsets.only(
                bottom: AppResponsive.largeSpacing(context),
              ),
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    entry.description,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$amountPrefix${formatMoney(entry.amount.abs())}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: amountColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMedium,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Bal: ${formatMoney(entry.runningBalance)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
