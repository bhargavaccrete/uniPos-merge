import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/presentation/screens/retail/inventory_loss_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_claim_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Everything that happens to goods that arrived damaged, in one place.
///
/// Mirrors the product catalog hub: the tabs are the real screens hosted with
/// `embedded: true`, so each still works standalone while the hub owns the
/// single AppBar. Three outcomes, one destination — the shopkeeper doesn't have
/// to remember which of three dashboard cards holds what they're after.
class DamagedGoodsHubScreen extends StatefulWidget {
  /// 0 Returns, 1 Claims, 2 Losses.
  final int initialTab;

  const DamagedGoodsHubScreen({super.key, this.initialTab = 0});

  @override
  State<DamagedGoodsHubScreen> createState() => _DamagedGoodsHubScreenState();
}

class _DamagedGoodsHubScreenState extends State<DamagedGoodsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _titles = ['Returns', 'Claims', 'Losses'];

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

  /// Badge counts: open work for returns/claims, total rows for losses.
  int _countFor(int index) {
    switch (index) {
      case 0:
        return damagedGoodsStore.openReturnCount;
      case 1:
        return damagedGoodsStore.openClaimCount;
      default:
        return damagedGoodsStore.inventoryLosses.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Returns & Claims'),
      body: Column(
        children: [
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                PurchaseReturnListScreen(embedded: true),
                SupplierClaimListScreen(embedded: true),
                InventoryLossListScreen(embedded: true),
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

            // Same cap the content below uses, so three pills don't stretch
            // across an ultrawide monitor.
            final maxWidth = AppResponsive.maxContentWidth(context);
            if (maxWidth == double.infinity) return row;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: row,
              ),
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
