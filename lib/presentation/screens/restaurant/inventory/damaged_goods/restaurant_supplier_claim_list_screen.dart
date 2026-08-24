import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/damaged_goods/restaurant_supplier_claim_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Colour for a claim status — shared with the detail screen.
Color restaurantSupplierClaimStatusColor(RestaurantSupplierClaimStatus status) {
  switch (status) {
    case RestaurantSupplierClaimStatus.pending:
      return AppColors.warning;
    case RestaurantSupplierClaimStatus.approved:
      return AppColors.info;
    case RestaurantSupplierClaimStatus.rejected:
      return AppColors.danger;
    case RestaurantSupplierClaimStatus.settled:
      return AppColors.success;
  }
}

/// Damaged raw material kept on site while compensation is pursued with the
/// supplier. Mirrors retail's `SupplierClaimListScreen`, scoped to
/// restaurant's Items/Supplier models.
class RestaurantSupplierClaimListScreen extends StatefulWidget {
  final bool embedded;

  const RestaurantSupplierClaimListScreen({super.key, this.embedded = false});

  @override
  State<RestaurantSupplierClaimListScreen> createState() =>
      _RestaurantSupplierClaimListScreenState();
}

class _RestaurantSupplierClaimListScreenState
    extends State<RestaurantSupplierClaimListScreen> {
  final TextEditingController _searchController = TextEditingController();
  RestaurantSupplierClaimStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy').format(date);
  }

  List<RestaurantSupplierClaimModel> get _visibleClaims {
    final query = _searchController.text.trim().toLowerCase();

    return restaurantDamagedGoodsStore.supplierClaims.where((item) {
      if (_statusFilter != null && item.statusEnum != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.claimNumber.toLowerCase().contains(query) ||
          item.grnNumber.toLowerCase().contains(query) ||
          item.poNumber.toLowerCase().contains(query) ||
          (item.supplierName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = MoneyScope(child: _buildBody(context));

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Supplier Claims'),
      body: body,
    );
  }

  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxContentWidth(context);
    if (maxWidth == double.infinity) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
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
                  hint: 'Search by claim, GRN, PO or supplier...',
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
        _buildOpenSummary(context),
        Expanded(
          child: Observer(
            builder: (context) {
              if (restaurantDamagedGoodsStore.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final claims = _visibleClaims;
              if (claims.isEmpty) return _buildEmptyState();

              return _capped(
                context,
                ListView.builder(
                  padding: AppResponsive.padding(context),
                  itemCount: claims.length,
                  itemBuilder: (context, index) => _buildCard(claims[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Open claims are money still in dispute — worth surfacing above the list.
  Widget _buildOpenSummary(BuildContext context) {
    return Observer(
      builder: (context) {
        final count = restaurantDamagedGoodsStore.openClaimCount;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: AppColors.warning.withValues(alpha: 0.08),
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.padding(context).left,
            vertical: AppResponsive.smallSpacing(context),
          ),
          child: _capped(
            context,
            Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count open claim${count == 1 ? '' : 's'} • ${formatMoney(restaurantDamagedGoodsStore.openClaimValue)} awaiting supplier decision',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusFilter() {
    const options = <(String, RestaurantSupplierClaimStatus?)>[
      ('All', null),
      ('Pending', RestaurantSupplierClaimStatus.pending),
      ('Approved', RestaurantSupplierClaimStatus.approved),
      ('Settled', RestaurantSupplierClaimStatus.settled),
      ('Rejected', RestaurantSupplierClaimStatus.rejected),
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

  Widget _statusChip(String label, RestaurantSupplierClaimStatus? status) {
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
      icon: filtering ? Icons.search_off_rounded : Icons.gavel_rounded,
      title: filtering ? 'No claims match' : 'No supplier claims yet',
      message: filtering
          ? 'Try a different search or status filter.'
          : 'Claims are raised automatically when goods are marked "Keep for Claim" while receiving a purchase order.',
    );
  }

  Widget _buildCard(RestaurantSupplierClaimModel model) {
    final color = restaurantSupplierClaimStatusColor(model.statusEnum);

    final radius = AppResponsive.smallBorderRadius(context);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: model.isOpen
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantSupplierClaimDetailScreen(claim: model),
            ),
          );
          if (mounted) setState(() {});
        },
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
                      model.claimNumber,
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
                    '${model.totalQty} units  •  ${formatMoney(model.totalAmount)}',
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
                _formatDate(model.claimDate),
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
