import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/damaged_goods/restaurant_purchase_return_list_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/damaged_goods/restaurant_supplier_claim_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Everything that happens to raw material that arrived damaged, in one
/// place. Mirrors retail's `DamagedGoodsHubScreen`, scoped to restaurant's
/// Items/Supplier models — Purchase Returns and Supplier Claims only (write-
/// offs surface through Inventory Loss elsewhere).
///
/// The tabs are the real screens hosted with `embedded: true`, so each still
/// works standalone while the hub owns the single AppBar.
class RestaurantDamagedGoodsHubScreen extends StatefulWidget {
  /// 0 Returns, 1 Claims.
  final int initialTab;

  const RestaurantDamagedGoodsHubScreen({super.key, this.initialTab = 0});

  @override
  State<RestaurantDamagedGoodsHubScreen> createState() =>
      _RestaurantDamagedGoodsHubScreenState();
}

class _RestaurantDamagedGoodsHubScreenState
    extends State<RestaurantDamagedGoodsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _titles = ['Returns', 'Claims'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _titles.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _titles.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Badge counts: open work for returns/claims.
  int _countFor(int index) {
    switch (index) {
      case 0:
        return restaurantDamagedGoodsStore.openReturnCount;
      default:
        return restaurantDamagedGoodsStore.openClaimCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Returns & Claims'),
      body: Column(
        children: [
          Observer(
            builder: (_) {
              return GradientHeroHeader(
                title: 'Returns & Claims',
                subtitle:
                    'Handle raw material that arrived damaged — return it or claim it',
                icon: Icons.assignment_return_rounded,
                accent: AppColors.orange,
                stats: [
                  HeroStat(
                    icon: Icons.keyboard_return_rounded,
                    value: '${restaurantDamagedGoodsStore.openReturnCount}',
                    label: 'Open Returns',
                  ),
                  HeroStat(
                    icon: Icons.gavel_rounded,
                    value: '${restaurantDamagedGoodsStore.openClaimCount}',
                    label: 'Open Claims',
                  ),
                ],
              );
            },
          ),
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                RestaurantPurchaseReturnListScreen(embedded: true),
                RestaurantSupplierClaimListScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      // AnimatedBuilder follows the swipe instead of snapping when it settles;
      // the Observer sits inside it so the counts register their MobX
      // dependency in the builder that actually reads them.
      child: AnimatedBuilder(
        animation: _tabController.animation!,
        builder: (_, _) => Observer(
          builder: (_) {
            final row = Row(
              children: [
                for (var i = 0; i < _titles.length; i++) ...[
                  if (i > 0)
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                  Expanded(child: _buildTabButton(i, _titles[i], _countFor(i))),
                ],
              ],
            );

            final maxWidth = AppResponsive.maxContentWidth(context);
            // Mobile is uncapped — returning early keeps two widgets out of
            // the tree. Centred on both axes, as the tab row was before.
            if (maxWidth == double.infinity) return row;
            return AppResponsive.constrainedContent(
              context: context,
              maxWidth: maxWidth,
              child: row,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, int count) {
    final isSelected = _tabController.animation!.value.round() == index;

    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.smallSpacing(context),
          vertical: AppResponsive.getValue(
            context,
            mobile: 11.0,
            tablet: 13.0,
            desktop: 15.0,
          ),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.smallBorderRadius(context),
          ),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          count > 0 ? '$label · $count' : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
