import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/screens/retail/add_product_screen.dart';
import 'package:billberrylite/presentation/screens/retail/category_management_screen.dart';
import 'package:billberrylite/presentation/screens/retail/inventory_screen.dart';
import 'package:billberrylite/presentation/screens/retail/stock_take_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../core/di/service_locator.dart';

/// The retail product catalog in one place — products and the categories that
/// group them.
///
/// Mirrors the restaurant's Menu Management hub: the tabs are the existing
/// screens hosted with `embedded: true`, so each still works standalone (routes,
/// Add Product → Manage Categories) while the hub owns the single AppBar and
/// its one contextual "+". Attributes stay in Settings — they configure how
/// products are built rather than being catalog entries themselves.
class ProductManagementScreen extends StatefulWidget {
  /// Tab to open on: 0 Products, 1 Categories.
  final int initialTab;

  const ProductManagementScreen({super.key, this.initialTab = 0});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Ticks once per settled tab change. Each tab listens and clears its own
  /// search box — the controllers stay owned by the tab that built them, so the
  /// hub never reaches into another widget's State.
  final ValueNotifier<int> _searchResetSignal = ValueNotifier(0);
  int _lastTabIndex = 0;

  static const _titles = ['Products', 'Categories'];
  static const _addLabels = ['Add Product', 'Add Category'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _lastTabIndex = _tabController.index;
    // Fires repeatedly while a tab animates, so compare the index rather than
    // signalling on every notification.
    _tabController.addListener(() {
      if (_tabController.index == _lastTabIndex) return;
      _lastTabIndex = _tabController.index;
      _searchResetSignal.value++;
    });

    // The pill counts must be right before the user visits a tab, so the hub
    // warms both stores rather than waiting for each tab's initState.
    productStore.loadProducts();
    categoryStore.loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchResetSignal.dispose();
    super.dispose();
  }

  /// Live item count behind each pill — read inside an Observer.
  int _countFor(int index) => switch (index) {
    0 => productStore.products.length,
    _ => categoryStore.categories.length,
  };

  void _addForCurrentTab() {
    if (_tabController.index == 0) {
      openAddProductScreen(context);
    } else {
      showAddCategoryDialog(context);
    }
  }

  /// Bulk counting belongs to the Products tab, and the hub owns the only
  /// AppBar — the embedded InventoryScreen has none, so this action cannot live
  /// there.
  void _openStockTakes() {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.inventoryStockTake,
      featureName: 'Stock Take',
    )) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockTakeListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final isDesktop = AppResponsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Products',
        titleFontSize: isTablet ? 22 : 20,
        actions: [
          // Products tab only, admin only. Shares the tab-tracking builder
          // below because its visibility depends on the same animation value.
          AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (_, child) {
              final index = _tabController.animation!.value.round();
              if (index != 0 || !StockAdjustmentService.canAdjust) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.fact_check_outlined),
                tooltip: 'Stock Takes',
                onPressed: _openStockTakes,
              );
            },
          ),
          // Both the icon's action and its visibility depend on the active tab,
          // so it tracks the tab animation as well as the stores.
          AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (_, child) => Observer(
              builder: (_) {
                final index = _tabController.animation!.value.round();
                // Empty tabs put the call-to-action in their empty state
                // instead, matching the rest of the app.
                if (_countFor(index) == 0) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: _addLabels[index],
                  onPressed: _addForCurrentTab,
                );
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabBar(isTablet, isDesktop),
            Expanded(
              child: isDesktop
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: _buildTabViews(),
                      ),
                    )
                  : _buildTabViews(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabViews() {
    return TabBarView(
      controller: _tabController,
      children: [
        InventoryScreen(embedded: true, clearSearchSignal: _searchResetSignal),
        CategoryManagementScreen(
          embedded: true,
          clearSearchSignal: _searchResetSignal,
        ),
      ],
    );
  }

  // ==================== TAB BAR ====================
  Widget _buildTabBar(bool isTablet, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      // AnimatedBuilder scopes the highlight rebuild to the pills only and
      // follows the swipe instead of snapping when it settles. The Observer
      // must sit INSIDE it: the counts are read in the Observer's own builder,
      // which is what registers the MobX dependency.
      child: AnimatedBuilder(
        animation: _tabController.animation!,
        builder: (_, child) => Observer(
          builder: (_) {
            // Two tabs split the width evenly — nothing to scroll or centre.
            final row = Row(
              children: [
                for (var i = 0; i < _titles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _buildTabButton(i, _titles[i], _countFor(i))),
                ],
              ],
            );

            // Desktop keeps the same 1400 cap as the content below, so the
            // pills don't stretch across an ultrawide monitor.
            if (!isDesktop) return row;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          count > 0 ? '$label · $count' : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
