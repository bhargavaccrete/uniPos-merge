import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/screens/retail/add_product_screen.dart';
import 'package:billberrylite/presentation/screens/retail/assemble_kit_screen.dart';
import 'package:billberrylite/presentation/screens/retail/bundles_screen.dart';
import 'package:billberrylite/presentation/screens/retail/category_management_screen.dart';
import 'package:billberrylite/presentation/screens/retail/import_product/bulk_import_screen.dart';
import 'package:billberrylite/presentation/screens/retail/inventory_screen.dart';
import 'package:billberrylite/presentation/screens/retail/stock_take_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_service.dart';
import 'package:billberrylite/domain/services/retail/catalog_permission.dart';
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
  /// The importer refreshes the product/category stores itself on Done, so the
  /// hub picks up whatever it created without any extra plumbing here.
  void _openBulkImport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BulkImportScreen()),
    );
  }

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

  /// Assembling writes stock, so it rides the stock-adjustment plan key.
  void _openAssembleKit() {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.inventory,
      featureName: 'Assemble Kit',
    )) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssembleKitScreen()),
    );
  }

  void _openBundles() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BundlesScreen()),
    );
  }

  /// A Products-tab, stock-adjuster-only app-bar action that appears only
  /// while the catalog has something for it to act on.
  Widget _productsTabAction({
    required bool Function() hasTarget,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (_, child) => Observer(
        builder: (_) {
          if (_tabController.animation!.value.round() != 0 ||
              !StockAdjustmentService.canAdjust ||
              !hasTarget()) {
            return const SizedBox.shrink();
          }
          return IconButton(
            icon: Icon(icon),
            tooltip: tooltip,
            onPressed: onPressed,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // True on desktop too — it means "not a phone", not "tablet".
    final isWide = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Products',
        titleFontSize: AppResponsive.headingFontSize(context),
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
          // Kits are built here; the embedded InventoryScreen has no AppBar,
          // so these can't live there.
          _productsTabAction(
            hasTarget: () => productStore.products.any((p) => p.isRepack),
            icon: Icons.inventory_rounded,
            tooltip: 'Assemble Kit',
            onPressed: _openAssembleKit,
          ),
          _productsTabAction(
            hasTarget: () =>
                productStore.products.any((p) => p.isBundle || p.isRepack),
            icon: Icons.widgets_outlined,
            tooltip: 'Bundles',
            onPressed: _openBundles,
          ),
          // Products tab only. Bulk import was previously reachable only from
          // the onboarding wizard, so an existing shop had no way back to it.
          AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (_, child) {
              if (_tabController.animation!.value.round() != 0 ||
                  !CatalogPermission.canEdit) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Bulk Import',
                onPressed: _openBulkImport,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabBar(isWide),
            // The shared ladder, not a local 1400. maxContentWidth is
            // double.infinity on mobile so the cap is a no-op there, which is
            // why the old `isDesktop ?` branch is gone — it also meant tablet
            // went UNCAPPED while every other retail page capped at 1000.
            // The hub owns the cap; the embedded tab children cap nothing.
            Expanded(
              child: AppResponsive.constrainedContent(
                context: context,
                maxWidth: AppResponsive.maxContentWidth(context),
                alignment: Alignment.topCenter,
                child: _buildTabViews(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: CatalogPermission.canEdit
          ? FloatingActionButton(
              onPressed: _addForCurrentTab,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
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
  Widget _buildTabBar(bool isWide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isWide
            ? AppResponsive.cardPadding(context).left
            : AppResponsive.mediumSpacing(context),
      ),
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
                  if (i > 0)
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                  Expanded(child: _buildTabButton(i, _titles[i], _countFor(i))),
                ],
              ],
            );

            // Same cap as the content below, from the shared ladder — so the
            // pills sit directly above the tab they switch to at every
            // breakpoint, not just desktop.
            return AppResponsive.constrainedContent(
              context: context,
              maxWidth: AppResponsive.maxContentWidth(context),
              heightFactor: 1,
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
          horizontal: AppResponsive.mediumSpacing(context),
          vertical: AppResponsive.smallSpacing(context),
        ),
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
