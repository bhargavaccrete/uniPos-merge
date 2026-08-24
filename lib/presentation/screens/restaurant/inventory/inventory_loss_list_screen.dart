import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Friendly label for [RestaurantInventoryLossModel.source].
String _sourceLabel(String source) {
  switch (source) {
    case RestaurantInventoryLossSource.grnDamage:
      return 'GRN Damage';
    case RestaurantInventoryLossSource.claimRejected:
      return 'Claim Rejected';
    case RestaurantInventoryLossSource.stockAdjustment:
      return 'Stock Adjustment';
    default:
      return source;
  }
}

/// Every raw-material/stock cost the business absorbed — from damaged GRN
/// receipts, rejected supplier claims, and loss-bearing manual removals
/// (wastage, theft, samples) or stock-take shortages. Read-only by design:
/// a loss is a historical fact, corrected by a new event, not an edit.
/// Mirrors retail's `InventoryLossListScreen`.
class RestaurantInventoryLossListScreen extends StatefulWidget {
  const RestaurantInventoryLossListScreen({super.key});

  @override
  State<RestaurantInventoryLossListScreen> createState() =>
      _RestaurantInventoryLossListScreenState();
}

class _RestaurantInventoryLossListScreenState
    extends State<RestaurantInventoryLossListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _sourceFilter;

  @override
  void initState() {
    super.initState();
    if (restaurantDamagedGoodsStore.inventoryLosses.isEmpty) {
      restaurantDamagedGoodsStore.loadAll();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  List<RestaurantInventoryLossModel> get _visibleLosses {
    final query = _searchController.text.trim().toLowerCase();
    return restaurantDamagedGoodsStore.inventoryLosses.where((loss) {
      if (_sourceFilter != null && loss.source != _sourceFilter) return false;
      if (query.isEmpty) return true;
      return loss.lossNumber.toLowerCase().contains(query) ||
          (loss.itemName?.toLowerCase().contains(query) ?? false) ||
          (loss.supplierName?.toLowerCase().contains(query) ?? false) ||
          (loss.grnNumber?.toLowerCase().contains(query) ?? false) ||
          loss.reason.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Inventory Losses'),
      body: SafeArea(child: MoneyScope(child: _buildBody(context))),
    );
  }

  Widget _buildBody(BuildContext context) {
    final side = AppResponsive.padding(context).left;

    return Column(
      children: [
        _buildHero(context),
        Container(
          color: AppColors.white,
          padding: EdgeInsets.fromLTRB(
            side,
            AppResponsive.mediumSpacing(context),
            side,
            12,
          ),
          child: AppTextField(
            controller: _searchController,
            hint: 'Search by item, supplier, GRN or reason...',
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
        _buildSourceFilter(context),
        Expanded(
          child: Observer(
            builder: (context) {
              if (restaurantDamagedGoodsStore.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final losses = _visibleLosses;
              if (losses.isEmpty) {
                final filtering = _searchController.text.trim().isNotEmpty ||
                    _sourceFilter != null;
                return AppEmptyState(
                  icon: filtering
                      ? Icons.search_off_rounded
                      : Icons.money_off_rounded,
                  title: filtering ? 'No losses match' : 'No inventory losses',
                  message: filtering
                      ? 'Try a different search or filter.'
                      : 'Losses are recorded automatically when goods are '
                          'written off on receipt, a supplier claim is '
                          'rejected, or stock is manually removed for '
                          'wastage, theft or samples.',
                );
              }

              return ListView.builder(
                padding: AppResponsive.padding(context),
                itemCount: losses.length,
                itemBuilder: (context, index) => _buildCard(losses[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSourceFilter(BuildContext context) {
    const sources = [
      RestaurantInventoryLossSource.grnDamage,
      RestaurantInventoryLossSource.claimRejected,
      RestaurantInventoryLossSource.stockAdjustment,
    ];

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
        AppResponsive.padding(context).left,
        0,
        AppResponsive.padding(context).left,
        12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(context, 'All', _sourceFilter == null,
                () => setState(() => _sourceFilter = null)),
            for (final s in sources) ...[
              const SizedBox(width: 8),
              _filterChip(context, _sourceLabel(s), _sourceFilter == s,
                  () => setState(() => _sourceFilter = s)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Observer(
      builder: (context) {
        final lossCount = restaurantDamagedGoodsStore.inventoryLosses.length;
        final totalQty = restaurantDamagedGoodsStore.totalLossQty;
        final totalValue = restaurantDamagedGoodsStore.totalLossValue;

        return GradientHeroHeader(
          title: 'Inventory Losses',
          subtitle:
              'Every cost absorbed from damage, rejected claims & write-offs',
          icon: Icons.money_off_rounded,
          accent: AppColors.danger,
          stats: [
            HeroStat(
              icon: Icons.receipt_long_rounded,
              value: '$lossCount',
              label: 'Loss Events',
            ),
            HeroStat(
              icon: Icons.trending_down_rounded,
              value: '${totalQty % 1 == 0 ? totalQty.toInt() : totalQty}',
              label: 'Units Written Off',
            ),
            HeroStat(
              icon: Icons.payments_rounded,
              value: formatMoney(totalValue),
              label: 'Total Loss Value',
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(RestaurantInventoryLossModel loss) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loss.itemName ?? 'Unknown item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _sourceLabel(loss.source),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${loss.quantity}',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  Text(
                    formatMoney(loss.lossValue),
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          const Divider(height: 1, color: AppColors.divider),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Wrap(
            spacing: AppResponsive.mediumSpacing(context),
            runSpacing: 4,
            children: [
              _meta(Icons.tag_rounded, loss.lossNumber),
              _meta(Icons.description_outlined, loss.reason),
              if (loss.supplierName?.isNotEmpty ?? false)
                _meta(Icons.storefront_outlined, loss.supplierName!),
              if (loss.grnNumber?.isNotEmpty ?? false)
                _meta(Icons.receipt_long_outlined, loss.grnNumber!),
            ],
          ),
          if (loss.note?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              loss.note!,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _formatDate(loss.recordedAt),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
