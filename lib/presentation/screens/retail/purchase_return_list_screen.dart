import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Colour for a return status — shared with the detail screen so both agree.
Color purchaseReturnStatusColor(PurchaseReturnStatus status) {
  switch (status) {
    case PurchaseReturnStatus.pending:
      return AppColors.warning;
    case PurchaseReturnStatus.creditReceived:
      return AppColors.success;
    case PurchaseReturnStatus.cancelled:
      return AppColors.textSecondary;
  }
}

/// Goods sent back to suppliers because they arrived damaged.
///
/// Hosted standalone or inside the Damaged Goods hub with [embedded] — the hub
/// owns the AppBar in that case, exactly like the product catalog hub.
class PurchaseReturnListScreen extends StatefulWidget {
  final bool embedded;

  const PurchaseReturnListScreen({super.key, this.embedded = false});

  @override
  State<PurchaseReturnListScreen> createState() =>
      _PurchaseReturnListScreenState();
}

class _PurchaseReturnListScreenState extends State<PurchaseReturnListScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// null = All.
  PurchaseReturnStatus? _statusFilter;

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
  List<PurchaseReturnModel> get _visibleReturns {
    final query = _searchController.text.trim().toLowerCase();

    return damagedGoodsStore.purchaseReturns.where((item) {
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

  void _openDetail(PurchaseReturnModel model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseReturnDetailScreen(purchaseReturn: model),
      ),
    );
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
    if (maxWidth == double.infinity) return child;
    return Align(
      // topCenter, not Center: Center aligns on BOTH axes, so a
      // shrink-wrapping child floats in the vertical middle.
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
              if (damagedGoodsStore.isLoading) {
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
    const options = <(String, PurchaseReturnStatus?)>[
      ('All', null),
      ('Pending', PurchaseReturnStatus.pending),
      ('Credit Received', PurchaseReturnStatus.creditReceived),
      ('Cancelled', PurchaseReturnStatus.cancelled),
    ];

    final height = AppResponsive.getValue(
      context,
      mobile: 34.0,
      tablet: 40.0,
      desktop: 44.0,
    );
    final gap = AppResponsive.smallSpacing(context);

    // Phones scroll — the labels can't all fit. From tablet up the row divides
    // the width evenly, matching the PO tab bar and removing the dead space a
    // left-packed scrolling row leaves on a wide screen.
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

  Widget _statusChip(String label, PurchaseReturnStatus? status) {
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
        // An equal slice of a small tablet is tight for the longest label;
        // scaleDown keeps it on one line instead of clipping to an ellipsis.
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

  Widget _buildCard(PurchaseReturnModel model) {
    final color = purchaseReturnStatusColor(model.statusEnum);

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
              // Wrap so the qty/amount drops below the document numbers on a
              // narrow card rather than squeezing them to an ellipsis.
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
