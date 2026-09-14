/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:billberrylite/util/color.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../domain/services/restaurant/day_management_service.dart';
import '../../../widget/restaurant/opening_balance_dialog.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../domain/services/restaurant/inventory_service.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/common/app_empty_state.dart';
import 'weight_item_dialog_restaurant.dart';
import 'item_options_dialog.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';

/// Opt-in GRID variant of the POS menu tab (flat "pick a category" model).
///
/// This is a SEPARATE screen from [MenuScreen] (the default list). It is chosen
/// at [Startorder] based on `AppSettings.menuGridView`, so the current list flow
/// is never touched. Cart behaviour reuses the SAME shared pieces the list uses
/// (`ItemOptionsDialog`, `restaurantCartStore.addToCart`, `showWeightItemDialog`)
/// — only the thin add-to-cart dispatch is duplicated for now; if grid is
/// adopted, extract that into a shared mixin used by both screens.
/// Absolute height of an item card on DESKTOP.
///
/// Desktop must NOT size these cells with `childAspectRatio`: the card's
/// content floor is constant (image, an up-to-two-line name, the price row)
/// while a ratio derives height from column width — so one ratio overflowed at
/// 1024 and left slack at 1440. `mainAxisExtent` pins the height so the card is
/// identical at every desktop width and only the columns get wider.
///
/// Mirrors `kMenuItemCardHeightDesktop` in menu.dart. This screen is
/// deliberately self-contained and doesn't import it — keep the two in step.
const double kMenuGridItemCardHeightDesktop = 240.0;

class MenuGridScreen extends StatefulWidget {
  final String? tableIdForNewOrder;
  final OrderModel? existingOrder;
  final bool isForAddingItem;

  const MenuGridScreen({
    super.key,
    this.existingOrder,
    this.isForAddingItem = false,
    this.tableIdForNewOrder,
  });

  @override
  State<MenuGridScreen> createState() => _MenuGridScreenState();
}

/// Local (private) copy of the list screen's stock enum, so this file stays
/// self-contained and can't clash with menu.dart's top-level `StockStatus`.
enum _StockStatus { inStock, orderAvailable, outOfStock, notTracked }

class _MenuGridScreenState extends State<MenuGridScreen> {
  static const String _kFavorites = '__favorites__';

  String query = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingData = false;

  // Category quick-nav (top chip strip → scroll to + expand that section).
  final ScrollController _scrollController = ScrollController();
  final Map<String, ExpansibleController> _expansionControllers = {};
  final Map<String, GlobalKey> _sectionKeys = {};
  String _lastExpandQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool force = false}) async {
    if (_isLoadingData && !force) return;
    if (!mounted) return;
    setState(() => _isLoadingData = true);
    try {
      await Future.wait([
        categoryStore.loadCategories(),
        itemStore.loadItems(),
        restaurantCartStore.loadCartItems(),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Data loading timed out after 10 seconds'),
      );
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error loading menu: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // ── Cart + favourite (reuse the shared dialog/store — same as the list) ─────

  void _toggleFavorite(Items item) {
    itemStore.updateItem(item.copyWith(isFavorite: !item.isFavorite));
  }

  Future<void> _handleItemTap(Items item) async {
    final strictlyPending = await DayManagementService.isEodStrictlyPending();
    if (strictlyPending) {
      NotificationService.instance
          .showError('Day has ended. Complete End of Day to unlock.');
      return;
    }

    if (item.isSoldByWeight) {
      final CartItem? weightCartItem = await showWeightItemDialog(context, item);
      if (weightCartItem != null) await _addItemToCart(weightCartItem);
      return;
    }

    final bool hasVariants = item.variant != null && item.variant!.isNotEmpty;
    final bool hasExtra = item.extraId != null && item.extraId!.isNotEmpty;
    final bool hasChoice = item.choiceIds != null && item.choiceIds!.isNotEmpty;
    String? categoryName;
    try {
      final category = categoryStore.categories
          .firstWhere((cat) => cat.id == item.categoryOfItem);
      categoryName = category.name;
    } catch (e) {
      categoryName = 'Uncategorized';
    }

    if (hasVariants || hasExtra || hasChoice) {
      CartItem? result;
      if (AppResponsive.isMobile(context)) {
        result = await showModalBottomSheet<CartItem>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85),
                child: ItemOptionsDialog(item: item, categoryName: categoryName),
              ),
            );
          },
        );
      } else {
        final hInset =
            ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2)
                .clamp(40.0, 300.0);
        result = await showDialog<CartItem>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: AppColors.white,
            insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppResponsive.largeBorderRadius(context))),
            clipBehavior: Clip.antiAlias,
            child: ItemOptionsDialog(item: item, categoryName: categoryName),
          ),
        );
      }
      if (result != null) await _addItemToCart(result);
    } else {
      final simpleCartItem = CartItem(
        productId: item.id,
        isStockManaged: item.trackInventory,
        id: const Uuid().v4(),
        title: item.name,
        price: item.price ?? 0,
        quantity: 1,
        taxRate: item.taxRate,
        weightDisplay: null,
        categoryName: categoryName,
      );
      await _addItemToCart(simpleCartItem);
    }
  }

  Future<void> _addItemToCart(CartItem cartItem) async {
    // First item of a not-yet-started day → offer to start it now (cancelable).
    if (restaurantCartStore.cartItems.isEmpty &&
        !await DayManagementService.isSessionOpen() &&
        mounted) {
      await promptStartDay(context);
    }
    try {
      final result = await restaurantCartStore.addToCart(cartItem);
      if (result['success'] == true) {
        if (mounted) {
          NotificationService.instance
              .showSuccess('${cartItem.title} added to cart');
        }
      } else {
        if (mounted) {
          NotificationService.instance
              .showError(result['message'] ?? 'Cannot add item to cart');
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error adding item to cart');
      }
    }
  }

  _StockStatus _getStockStatus(Items item) {
    if (!InventoryService.isStockGoverned(item)) return _StockStatus.notTracked;
    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;
    // Recipe-Based: availability comes from ingredients, not a stored figure.
    if (item.isRecipeBased) {
      switch (InventoryService.posStatusFromAvailable(
        available: InventoryService.effectiveAvailableStock(item),
        allowOrderWhenOutOfStock: allowOrderWhenOutOfStock,
      )) {
        case PosStockStatus.inStock:
          return _StockStatus.inStock;
        case PosStockStatus.orderAvailable:
          return _StockStatus.orderAvailable;
        case PosStockStatus.outOfStock:
          return _StockStatus.outOfStock;
        case PosStockStatus.notTracked:
          return _StockStatus.notTracked;
      }
    }
    if (item.variant != null && item.variant!.isNotEmpty) {
      bool hasAnyVariantInStock = false;
      for (var variant in item.variant!) {
        if ((variant.stockQuantity ?? 0) > 0) {
          hasAnyVariantInStock = true;
          break;
        }
      }
      if (hasAnyVariantInStock) return _StockStatus.inStock;
      return allowOrderWhenOutOfStock
          ? _StockStatus.orderAvailable
          : _StockStatus.outOfStock;
    }
    final stock = item.stockQuantity;
    if (stock <= 0) {
      return allowOrderWhenOutOfStock
          ? _StockStatus.orderAvailable
          : _StockStatus.outOfStock;
    }
    return _StockStatus.inStock;
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Stack(
        children: [
          Observer(
            builder: (_) {
              final hasItems = restaurantCartStore.cartItems.isNotEmpty;
              return Padding(
                padding: EdgeInsets.only(top: AppResponsive.smallSpacing(context), bottom: hasItems ? 80 : 0),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: AppResponsive.smallSpacing(context), vertical: 5),
                      child: AppTextField(
                        controller: _searchController,
                        hint: 'Search Items',
                        icon: Icons.search_rounded,
                      ),
                    ),
                    _buildChipStrip(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _isLoadingData
                          ? _loadingView()
                          : _buildCategoryList(),
                    ),
                  ],
                ),
              );
            },
          ),
          Observer(
            builder: (_) {
              if (restaurantCartStore.cartItems.isEmpty) {
                return const SizedBox.shrink();
              }
              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildCartBar(context, size),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _loadingView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            Text('Loading menu...',
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );

  // ── Category quick-nav chip strip (scrolls to + expands a section) ────────

  Widget _buildChipStrip() {
    return Observer(
      builder: (_) {
        final enabledItems =
            itemStore.items.where((i) => i.isEnabled && i.sellsAtPos).toList();
        final cats = categoryStore.categoriesWithItems(enabledItems);
        final hasFav = enabledItems.any((i) => i.isFavorite);
        final chips = <Widget>[];
        if (hasFav) {
          chips.add(_chip('Favorites', _kFavorites, Icons.star_rounded));
        }
        for (final c in cats) {
          chips.add(_chip(c.name, c.id, null));
        }
        return SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppResponsive.smallSpacing(context)),
            children: chips,
          ),
        );
      },
    );
  }

  Widget _chip(String label, String id, IconData? icon) {
    return Padding(
      padding: EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
      child: GestureDetector(
        onTap: () => _scrollToSection(id),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: AppResponsive.mediumSpacing(context), vertical: AppResponsive.smallSpacing(context)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppResponsive.smallIconSize(context), color: AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  /// Chip tap → expand that section and scroll it into view.
  void _scrollToSection(String id) {
    _expansionControllers[id]?.expand();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _sectionKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.05,
        );
      }
    });
  }

  /// Auto-expand every section while searching; collapse all when cleared.
  void _syncSearchExpansion() {
    if (query == _lastExpandQuery) return;
    final expanding = query.isNotEmpty || AppSettings.keepCategoriesOpen;
    _lastExpandQuery = query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in _expansionControllers.values) {
        try {
          expanding ? c.expand() : c.collapse();
        } catch (_) {}
      }
    });
  }

  // ── Expandable category sections (grid of items inside each) ──────────────

  Widget _buildCategoryList() {
    return Observer(
      builder: (_) {
        final cartItems = restaurantCartStore.cartItems.toList();
        final enabledItems =
            itemStore.items.where((i) => i.isEnabled && i.sellsAtPos).toList();
        final categories = categoryStore.categoriesWithItems(enabledItems);
        final q = query.toLowerCase();

        bool matches(Items i) =>
            i.name.toLowerCase().contains(q) ||
            (i.itemCode != null && i.itemCode!.toLowerCase().contains(q));

        // Searching but nothing matches anywhere → single empty state.
        if (query.isNotEmpty && !enabledItems.any(matches)) {
          return const AppEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No items found',
            message: 'Try a different search term.',
          );
        }

        final favItems = enabledItems
            .where((i) => i.isFavorite && (query.isEmpty || matches(i)))
            .toList();

        _syncSearchExpansion();

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: AppResponsive.smallSpacing(context), vertical: 5),
          child: Column(
            children: [
              if (favItems.isNotEmpty)
                _buildSection(
                  id: _kFavorites,
                  title: 'Favorites',
                  icon: Icons.star_rounded,
                  items: favItems,
                  cartItems: cartItems,
                ),
              ...categories.map((category) {
                final categoryItems = enabledItems
                    .where((i) => i.categoryOfItem == category.id)
                    .toList();
                final shown = query.isEmpty
                    ? categoryItems
                    : categoryItems.where(matches).toList();
                // Hide categories with no match while searching.
                if (query.isNotEmpty && shown.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _buildSection(
                  id: category.id,
                  title: category.name,
                  icon: Icons.restaurant_menu,
                  items: shown,
                  cartItems: cartItems,
                );
              }),
              // Items whose category no longer exists. A category delete
              // re-parents its items instead of destroying them, so without
              // this they would be enabled and on the menu but unreachable
              // here. Same section exists in menu.dart's accordion.
              Builder(
                builder: (_) {
                  final known =
                      categories.map((c) => c.id as String).toSet();
                  var orphans = enabledItems
                      .where((i) => !known.contains(i.categoryOfItem ?? ''))
                      .toList();
                  if (query.isNotEmpty) {
                    orphans = orphans.where(matches).toList();
                  }
                  if (orphans.isEmpty) return const SizedBox.shrink();
                  return _buildSection(
                    id: '__uncategorised__',
                    title: 'Uncategorized',
                    icon: Icons.restaurant_menu,
                    items: orphans,
                    cartItems: cartItems,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// One expandable section (a category or Favorites) — collapsed by default,
  /// tap the header to reveal its items as a GRID.
  Widget _buildSection({
    required String id,
    required String title,
    required IconData icon,
    required List<Items> items,
    required List<CartItem> cartItems,
  }) {
    _expansionControllers.putIfAbsent(id, () => ExpansibleController());
    _sectionKeys.putIfAbsent(id, () => GlobalKey());
    return Card(
      key: _sectionKeys[id],
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      elevation: 2,
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: _expansionControllers[id],
          initiallyExpanded: query.isNotEmpty || AppSettings.keepCategoriesOpen,
          tilePadding: EdgeInsets.symmetric(horizontal: AppResponsive.mediumSpacing(context)),
          leading: Container(
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: AppResponsive.getValue(context, mobile: 24.0, tablet: 26.0, desktop: 28.0)),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
                color: Colors.black87),
          ),
          subtitle: Text(
            '${items.length} item${items.length == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context), color: AppColors.textSecondary),
          ),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(AppResponsive.mediumSpacing(context), 0, AppResponsive.mediumSpacing(context), AppResponsive.mediumSpacing(context)),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppResponsive.gridColumns(context,
                    mobile: 2, tablet: 3, desktop: 4),
                crossAxisSpacing: AppResponsive.gridSpacing(context),
                mainAxisSpacing: AppResponsive.gridSpacing(context),
                // Absolute height on desktop — see the constant above.
                mainAxisExtent: AppResponsive.isDesktop(context)
                    ? kMenuGridItemCardHeightDesktop
                    : null,
                childAspectRatio: AppResponsive.getValue(context,
                    mobile: 0.75, tablet: 0.70,
                    // Ignored on desktop — mainAxisExtent pins the height.
                    desktop: 0.75),
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _buildGridItemCard(items[i], cartItems),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItemCard(Items item, List<CartItem> cartItems) {
    final stockStatus = _getStockStatus(item);
    final isDisabled = stockStatus == _StockStatus.outOfStock;
    final cartEntries =
        cartItems.where((c) => c.productId == item.id).toList();
    final int cartQty = cartEntries.fold<int>(0, (s, c) => s + c.quantity);
    final bool inCart = cartQty > 0;

    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: AppSettings.settingsNotifier,
      builder: (context, _, __) {
        final showImage = AppSettings.showItemImage;
        final showPrice = AppSettings.showItemPrice;
        return GestureDetector(
          onTap: isDisabled ? null : () => _handleItemTap(item),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDisabled
                      ? AppColors.surfaceMedium.withOpacity(0.5)
                      : inCart
                          ? AppColors.primary.withOpacity(0.04)
                          : AppColors.white,
                  borderRadius: BorderRadius.circular(AppResponsive.largeBorderRadius(context)),
                  border: Border.all(
                    color: inCart
                        ? AppColors.primary.withOpacity(0.45)
                        : (isDisabled
                            ? AppColors.divider
                            : AppColors.divider.withOpacity(0.5)),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: showImage
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    if (showImage)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMedium,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppResponsive.largeBorderRadius(context))),
                          ),
                          child: Center(child: _buildItemImageForGrid(item)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item.itemCode != null &&
                                    item.itemCode!.isNotEmpty)
                                ? '${item.itemCode} ${item.name}'
                                : item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: isDisabled
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (showPrice)
                                Flexible(
                                  child: Text(
                                    _getPriceDisplayForGrid(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                        fontSize: AppResponsive.bodyFontSize(context),
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary),
                                  ),
                                ),
                              if (!isDisabled)
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius:
                                            BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                      ),
                                      child: Icon(Icons.add,
                                          color: AppColors.white, size: AppResponsive.smallIconSize(context)),
                                    ),
                                    if (inCart)
                                      Positioned(
                                        top: -7,
                                        right: -7,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          constraints: const BoxConstraints(
                                              minWidth: 18, minHeight: 18),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 1.5),
                                          ),
                                          child: Text(
                                            '$cartQty',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(top: 6, right: 6, child: _favStar(item)),
              if (inCart)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _gridCartLabel(cartEntries, cartQty),
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _gridCartLabel(List<CartItem> entries, int qty) {
    final hasVariants = entries.any((c) => (c.variantName ?? '').isNotEmpty);
    if (!hasVariants) return 'In cart · $qty';
    return entries
        .map((c) =>
            '${(c.variantName ?? '').isNotEmpty ? c.variantName : 'Regular'} ×${c.quantity}')
        .join(', ');
  }

  Widget _buildItemImageForGrid(Items item) {
    if (item.imageBytes != null && item.imageBytes!.isNotEmpty) {
      final file = item.imageBytes;
      if (file != null) {
        return Image.memory(file,
            fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
    }
    return Icon(Icons.fastfood_rounded, size: AppResponsive.getValue(context, mobile: 48.0, tablet: 56.0, desktop: 64.0), color: AppColors.textSecondary);
  }

  String _getPriceDisplayForGrid(Items item) {
    if (item.price != null) {
      return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price!)}';
    }
    if (item.variant != null && item.variant!.isNotEmpty) {
      return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.variant!.first.price)}+';
    }
    return 'N/A';
  }

  Widget _favStar(Items item) {
    return GestureDetector(
      onTap: () => _toggleFavorite(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(
          item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          size: AppResponsive.smallIconSize(context),
          color: item.isFavorite ? Colors.amber : AppColors.textSecondary,
        ),
      ),
    );
  }

  // ── Bottom cart bar (same as the list screen) ─────────────────────────────

  Widget _buildCartBar(BuildContext context, Size size) {
    return Container(
      width: size.width,
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.mediumSpacing(context), vertical: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: Observer(
                builder: (_) {
                  final cartItems = restaurantCartStore.cartItems;
                  final total = cartItems.fold(
                      0.0, (sum, item) => sum + item.totalPrice);
                  final itemCount = cartItems.fold(
                      0, (sum, item) => sum + item.quantity);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        textScaler: const TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: AppResponsive.captionFontSize(context),
                            fontWeight: FontWeight.w400),
                      ),
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(total)}',
                        textScaler: const TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Expanded(
              flex: 2,
              child: CommonButton(
                bordercircular: 10,
                bgcolor: Colors.white,
                height: size.height * 0.055,
                onTap: () async {
                  if (widget.isForAddingItem == true) {
                    Navigator.pop(context);
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartScreen(
                            selectedTableNo: widget.tableIdForNewOrder),
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: AppResponsive.smallIconSize(context), color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'View Cart',
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                      textScaler: const TextScaler.linear(1),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/
