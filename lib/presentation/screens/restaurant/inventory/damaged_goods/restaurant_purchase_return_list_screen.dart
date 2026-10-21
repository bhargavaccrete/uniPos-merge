import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_model.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/damaged_goods/restaurant_purchase_return_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Colour for a return status — shared with the detail screen so both agree.
Color restaurantPurchaseReturnStatusColor(
  RestaurantPurchaseReturnStatus status,
) {
  switch (status) {
    case RestaurantPurchaseReturnStatus.pending:
      return AppColors.warning;
    case RestaurantPurchaseReturnStatus.creditReceived:
      return AppColors.success;
    case RestaurantPurchaseReturnStatus.cancelled:
      return AppColors.textSecondary;
  }
}

/// Raw material sent back to suppliers because it arrived damaged. Mirrors
/// retail's `PurchaseReturnListScreen`, scoped to restaurant's Items/Supplier
/// models.
///
/// Hosted standalone or inside the Damaged Goods hub with [embedded] — the hub
/// owns the AppBar in that case.
class RestaurantPurchaseReturnListScreen extends StatefulWidget {
  final bool embedded;

  const RestaurantPurchaseReturnListScreen({super.key, this.embedded = false});

  @override
  State<RestaurantPurchaseReturnListScreen> createState() =>
      _RestaurantPurchaseReturnListScreenState();
}

class _RestaurantPurchaseReturnListScreenState
    extends State<RestaurantPurchaseReturnListScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// null = All.
  RestaurantPurchaseReturnStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy').format(date);
  }

  /// Filtering is a plain list operation over the store's observable — no
  /// repository round-trip, so an update shows up immediately.
  List<RestaurantPurchaseReturnModel> get _visibleReturns {
    final query = _searchController.text.trim().toLowerCase();

    return restaurantDamagedGoodsStore.purchaseReturns.where((item) {
      if (_statusFilter != null && item.statusEnum != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.returnNumber.toLowerCase().contains(query) ||
          item.grnNumber.toLowerCase().contains(query) ||
          item.poNumber.toLowerCase().contains(query) ||
          (item.supplierName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _openDetail(RestaurantPurchaseReturnModel model) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RestaurantPurchaseReturnDetailScreen(purchaseReturn: model),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final body = MoneyScope(child: _buildBody(context));

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Purchase Returns'),
      body: body,
    );
  }

  /// Caps content width on large screens. Backgrounds still span edge to edge —
  /// only what you read is constrained.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxContentWidth(context);
    // Mobile is uncapped — returning early keeps two widgets out of the tree.
    if (maxWidth == double.infinity) return child;
    return AppResponsive.constrainedContent(
      context: context,
      maxWidth: maxWidth,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  Widget _buildBody(BuildContext context) {
    final side = AppResponsive.padding(context).left;

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: EdgeInsets.fromLTRB(
            side,
            AppResponsive.mediumSpacing(context),
            side,
            12,
          ),
          child: _capped(
            context,
            Column(
              children: [
                AppTextField(
                  controller: _searchController,
                  hint: 'Search by PR, GRN, PO or supplier...',
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
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildStatusFilter(),
              ],
            ),
          ),
        ),
        Expanded(
          child: Observer(
            builder: (context) {
              if (restaurantDamagedGoodsStore.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final returns = _visibleReturns;
              if (returns.isEmpty) return _buildEmptyState();

              return _capped(
                context,
                ListView.builder(
                  padding: AppResponsive.padding(context),
                  itemCount: returns.length,
                  itemBuilder: (context, index) => _buildCard(returns[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    const options = <(String, RestaurantPurchaseReturnStatus?)>[
      ('All', null),
      ('Pending', RestaurantPurchaseReturnStatus.pending),
      ('Credit Received', RestaurantPurchaseReturnStatus.creditReceived),
      ('Cancelled', RestaurantPurchaseReturnStatus.cancelled),
    ];

    final height = AppResponsive.getValue(
      context,
      mobile: 34.0,
      tablet: 40.0,
      desktop: 44.0,
    );
    final gap = AppResponsive.smallSpacing(context);

    if (!AppResponsive.isMobile(context)) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: _statusChip(options[i].$1, options[i].$2)),
            ],
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, index) =>
            _statusChip(options[index].$1, options[index].$2),
      ),
    );
  }

  Widget _statusChip(String label, RestaurantPurchaseReturnStatus? status) {
    final selected = _statusFilter == status;

    return GestureDetector(
      onTap: () => setState(() => _statusFilter = status),
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final filtering =
        _statusFilter != null || _searchController.text.trim().isNotEmpty;

    return AppEmptyState(
      icon: filtering
          ? Icons.search_off_rounded
          : Icons.assignment_return_outlined,
      title: filtering ? 'No returns match' : 'No purchase returns yet',
      message: filtering
          ? 'Try a different search or status filter.'
          : 'Returns are raised automatically when goods are marked "Return to Supplier" while receiving a purchase order.',
    );
  }

  Widget _buildCard(RestaurantPurchaseReturnModel model) {
    final color = restaurantPurchaseReturnStatusColor(model.statusEnum);

    final radius = AppResponsive.smallBorderRadius(context);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => _openDetail(model),
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      model.returnNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AppStatusPill(label: model.statusDisplay, color: color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                model.supplierName ?? 'Unknown supplier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppResponsive.smallSpacing(context)),
              Wrap(
                spacing: AppResponsive.smallSpacing(context),
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: AppResponsive.smallIconSize(context),
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${model.grnNumber}  •  ${model.poNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${model.totalQty} pcs  •  ${formatMoney(model.totalAmount)}',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(model.returnDate),
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
