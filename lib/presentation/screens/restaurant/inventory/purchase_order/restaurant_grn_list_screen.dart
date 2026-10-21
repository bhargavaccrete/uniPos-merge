import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Register of goods actually received — the read-only counterpart to the
/// Purchase Orders list.
///
/// Receipts were previously visible only through Reports › Purchase › GRN
/// Report, a different hub behind the server-manifest entitlement contract,
/// while Suppliers, POs, Returns, Claims and Losses each had a register here.
/// This closes that gap. It is deliberately **read-only**: a GRN is raised by
/// confirming a receipt against a PO, which is the one place raw-material
/// stock moves, so there is no create/edit/delete path.
class RestaurantGRNListScreen extends StatefulWidget {
  const RestaurantGRNListScreen({super.key});

  @override
  State<RestaurantGRNListScreen> createState() =>
      _RestaurantGRNListScreenState();
}

Color grnStatusColor(RestaurantGRNStatus status) {
  switch (status) {
    case RestaurantGRNStatus.draft:
      return AppColors.textSecondary;
    case RestaurantGRNStatus.confirmed:
      return AppColors.success;
    case RestaurantGRNStatus.cancelled:
      return AppColors.danger;
  }
}

String grnStatusLabel(RestaurantGRNStatus status) {
  switch (status) {
    case RestaurantGRNStatus.draft:
      return 'Draft';
    case RestaurantGRNStatus.confirmed:
      return 'Confirmed';
    case RestaurantGRNStatus.cancelled:
      return 'Cancelled';
  }
}

class _RestaurantGRNListScreenState extends State<RestaurantGRNListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The store loads GRNs in its constructor, but that may have run long
    // before this screen opened — and confirmGRN reloads too. Cheap: a read
    // off an already-open box.
    restaurantPurchaseOrderStore.loadGRNs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy').format(date);
  }

  void _showDetail(RestaurantGRNModel grn) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GRNDetailSheet(grn: grn),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MoneyScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(title: 'Goods Received'),
        body: Observer(
          builder: (context) {
            // Newest first. The box returns insertion order, same reason
            // loadPurchaseOrders sorts.
            final grns = restaurantPurchaseOrderStore.grns.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            // One pass for both hero stats.
            var billedValue = 0.0;
            var receivedQty = 0.0;
            for (final g in grns) {
              billedValue += g.totalAmount ?? 0;
              receivedQty += g.totalReceivedQty;
            }

            final query = _searchController.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? grns
                : grns.where((g) {
                    return g.grnNumber.toLowerCase().contains(query) ||
                        g.poNumber.toLowerCase().contains(query) ||
                        (g.supplierName?.toLowerCase().contains(query) ??
                            false) ||
                        (g.invoiceNumber?.toLowerCase().contains(query) ??
                            false);
                  }).toList();

            return Column(
              children: [
                GradientHeroHeader(
                  title: 'Goods Received',
                  subtitle:
                      'Every receipt confirmed against a purchase order',
                  icon: Icons.inventory_rounded,
                  accent: AppColors.success,
                  stats: [
                    HeroStat(
                      icon: Icons.receipt_long_rounded,
                      value: '${grns.length}',
                      label: 'Receipts',
                    ),
                    HeroStat(
                      icon: Icons.inventory_2_rounded,
                      value: formatQty(receivedQty),
                      label: 'Qty Received',
                    ),
                    HeroStat(
                      icon: Icons.currency_rupee_rounded,
                      value: formatMoney(billedValue),
                      label: 'Billed Value',
                    ),
                  ],
                ),
                if (grns.isNotEmpty)
                  Container(
                    color: AppColors.white,
                    padding: EdgeInsets.fromLTRB(
                      AppResponsive.padding(context).left,
                      AppResponsive.mediumSpacing(context),
                      AppResponsive.padding(context).right,
                      AppResponsive.mediumSpacing(context),
                    ),
                    child: AppResponsive.constrainedContent(
                      context: context,
                      maxWidth: AppResponsive.maxContentWidth(context),
                      alignment: Alignment.topCenter,
                      // No status pills: confirmGRN always writes `confirmed`,
                      // so draft and cancelled are unreachable and four of the
                      // five chips would sit permanently at zero.
                      child: AppTextField(
                        controller: _searchController,
                        hint: 'Search by GRN, PO, invoice or supplier...',
                        icon: Icons.search_rounded,
                        onChanged: (_) => setState(() {}),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  size: AppResponsive.smallIconSize(context),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                Expanded(
                  child: AppResponsive.constrainedContent(
                    context: context,
                    maxWidth: AppResponsive.maxContentWidth(context),
                    alignment: Alignment.topCenter,
                    child: visible.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: AppResponsive.padding(context),
                            itemCount: visible.length,
                            itemBuilder: (context, index) =>
                                _buildGRNCard(visible[index]),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final searching = _searchController.text.trim().isNotEmpty;

    return AppEmptyState(
      icon: searching ? Icons.search_off_rounded : Icons.inventory_outlined,
      title: searching ? 'No receipts match' : 'No goods received yet',
      message: searching
          ? 'Try a different search.'
          : 'Receipts appear here once you receive against a purchase order.',
    );
  }

  Widget _buildGRNCard(RestaurantGRNModel grn) {
    const radius = 16.0;
    final status = grn.statusEnum;
    final statusColor = grnStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: statusColor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetail(grn),
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: AppResponsive.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      grn.grnNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      grnStatusLabel(status),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppResponsive.smallSpacing(context)),
              Text(
                grn.supplierName ?? 'Unknown Supplier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Wrap(
                spacing: AppResponsive.mediumSpacing(context),
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _metaItem(
                    Icons.calendar_today,
                    _formatDate(grn.receivedDate),
                    AppColors.textSecondary,
                  ),
                  _metaItem(
                    Icons.local_shipping_outlined,
                    grn.poNumber,
                    AppColors.info,
                  ),
                  _metaItem(
                    Icons.inventory_2,
                    'Qty ${formatQty(grn.totalReceivedQty)}',
                    AppColors.textSecondary,
                  ),
                  if ((grn.totalAmount ?? 0) > 0)
                    Text(
                      formatMoney(grn.totalAmount!),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppResponsive.smallIconSize(context), color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Per-line breakdown of one receipt. Reads its own items — the store keeps
/// only GRN headers.
class _GRNDetailSheet extends StatelessWidget {
  final RestaurantGRNModel grn;

  const _GRNDetailSheet({required this.grn});

  /// The three money figures, fixed once in the purchase-report service and
  /// used verbatim everywhere: Billed is what the supplier invoiced (damage
  /// included), Accepted is what reached the shelf, Damaged is the difference.
  static String _handlingLabel(String? handling) {
    switch (handling) {
      case 'returnToSupplier':
        return 'Returned to supplier';
      case 'keepForClaim':
        return 'Kept — claim raised';
      case 'writeOff':
        return 'Written off';
      default:
        return 'Not handled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = restaurantGrnItemRepository.getItemsByGRNId(grn.grnId);
    final billed = grn.totalAmount ?? 0;
    final accepted =
        items.fold<double>(0, (sum, i) => sum + i.acceptedAmount);
    final damaged = items.fold<double>(0, (sum, i) => sum + i.damagedAmount);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.padding(context).left,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grn.grnNumber,
                            style: GoogleFonts.poppins(
                              fontSize:
                                  AppResponsive.subheadingFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${grn.supplierName ?? 'Unknown Supplier'} · ${grn.poNumber}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (grn.invoiceNumber != null &&
                              grn.invoiceNumber!.trim().isNotEmpty)
                            Text(
                              'Invoice ${grn.invoiceNumber}',
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
              ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              _buildMoneyStrip(context, billed, accepted, damaged),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: items.isEmpty
                    ? const AppEmptyState(
                        dense: true,
                        icon: Icons.inventory_2_outlined,
                        title: 'No line items',
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: AppResponsive.padding(context),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _buildItemRow(context, items[index]),
                      ),
              ),
              if (grn.notes != null && grn.notes!.trim().isNotEmpty)
                Padding(
                  padding: EdgeInsets.all(AppResponsive.padding(context).left),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: AppResponsive.smallIconSize(context),
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          grn.notes!,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoneyStrip(
    BuildContext context,
    double billed,
    double accepted,
    double damaged,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.padding(context).left,
        0,
        AppResponsive.padding(context).right,
        AppResponsive.mediumSpacing(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: _moneyCell(context, 'Billed', billed, AppColors.textPrimary),
          ),
          Expanded(
            child: _moneyCell(context, 'Accepted', accepted, AppColors.success),
          ),
          Expanded(
            child: _moneyCell(
              context,
              'Damaged',
              damaged,
              damaged > 0 ? AppColors.warning : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyCell(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatMoney(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(BuildContext context, RestaurantGRNItemModel item) {
    final damagedQty = item.damagedQty ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName ?? 'Unknown Item',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (item.totalAmount != null)
                Text(
                  formatMoney(item.totalAmount!),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ordered ${formatQty(item.orderedQty)} · '
            'Received ${formatQty(item.receivedQty)} · '
            'Accepted ${formatQty(item.acceptedQty)}'
            '${item.costPrice != null ? ' @ ${formatMoney(item.costPrice!)}' : ''}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          if (damagedQty > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.warning,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Damaged ${formatQty(damagedQty)} — '
                    '${_handlingLabel(item.damagedHandling)}',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
