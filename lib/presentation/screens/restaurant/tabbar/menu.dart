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
import '../../../../util/restaurant/staticswitch.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/common/app_text_field.dart';
import 'WeightItemDialog.dart';
import 'item_options_dialog.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';

part 'widgets/category_section_card.dart';

enum StockStatus { inStock, orderAvailable, outOfStock, notTracked }

class MenuScreen extends StatefulWidget {
  final String? tableIdForNewOrder;
  final OrderModel? existingOrder;
  final bool isForAddingItem;

  const MenuScreen({super.key, this.existingOrder, this.isForAddingItem = false, this.tableIdForNewOrder});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // Sentinel category id for the "Favorites" tab.
  static const String _kFavorites = '__favorites__';
  int _scrollRequestId = 0;

  void _toggleFavorite(Items item) {
    itemStore.updateItem(item.copyWith(isFavorite: !item.isFavorite));
  }

  /// Tappable star overlay used on item cards to mark/unmark favorite.
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
          size: 18,
          color: item.isFavorite ? Colors.amber : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Mobile "Favorites" section pinned at the top of the category list.
  Widget _buildFavoritesSection(List<Items> visibleItems, String query, String lowerQuery, List<CartItem> cartItems) {
    var favItems = visibleItems.where((i) => i.isFavorite).toList();
    if (query.isNotEmpty) {
      favItems = favItems.where((i) =>
          i.name.toLowerCase().contains(lowerQuery) ||
          (i.itemCode != null && i.itemCode!.toLowerCase().contains(lowerQuery))).toList();
    }
    // No favorites yet (or none match the search) — hide the section entirely,
    // just like the Favorites strip chip. It appears only once an item is starred.
    if (favItems.isEmpty) return const SizedBox.shrink();
    // Register key + controller under the favorites sentinel so the quick-nav
    // strip can expand/scroll to it via the same _selectStripCategory path as a
    // real category section.
    _categoryKeys.putIfAbsent(_kFavorites, () => GlobalKey());
    _expansionControllers.putIfAbsent(_kFavorites, () => ExpansibleController());

    return Card(
      key: _categoryKeys[_kFavorites],
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: _expansionControllers[_kFavorites],
          // Collapsed by default — opens on tap (or auto-opens during search),
          // matching the category tiles below.
          initiallyExpanded: query.isNotEmpty,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
          ),
          title: Text('Favorites',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          subtitle: Text('${favItems.length} items',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: favItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = favItems[i];
                return _ItemListTile(
                  key: ValueKey('${item.id}_${item.isFavorite}'),
                  item: item,
                  onTap: () => _handleItemTap(item),
                  onToggleFavorite: () => _toggleFavorite(item),
                  formatStock: _formatStockDisplay,
                  getStockStatus: _getStockStatus,
                  cartEntries:
                      cartItems.where((c) => c.productId == item.id).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  String? activeCategory;
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final Map<String, GlobalKey> _categoryKeys = {};
  final Map<String, ExpansibleController> _expansionControllers = {};
  final ScrollController _listScrollController = ScrollController();
  bool _isLoadingData = false;


  @override
  void initState() {
    super.initState();
    _loadData();

    _searchController.addListener(() {
      setState(() {
        query = _searchController.text;
      });
    });
  }

  /// Expand all category sections while a search is active (collapse when
  /// cleared). Scheduled from build() so it runs AFTER the search results have
  /// been laid out — only then are the tiles attached to their controllers.
  /// `initiallyExpanded` alone doesn't work: it applies only on a tile's first
  /// build, so sections already on screen stay collapsed when the search starts.
  String _lastExpandQuery = '';
  void _syncSearchExpansion() {
    if (query == _lastExpandQuery) return;
    final expanding = query.isNotEmpty;
    _lastExpandQuery = query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final controller in _expansionControllers.values) {
        try {
          expanding ? controller.expand() : controller.collapse();
        } catch (_) {
          // Tile not attached yet (off-screen) — it picks up the state via
          // `initiallyExpanded` when first built.
        }
      }
    });
  }

  Future<void> _loadData({bool force = false}) async {
    if (_isLoadingData && !force) return;
    if (!mounted) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      await Future.wait([
        categoryStore.loadCategories(),
        itemStore.loadItems(),
        restaurantCartStore.loadCartItems(),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Data loading timed out after 10 seconds');
        },
      );
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error loading menu: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleItemTap(Items item) async {
    if (item.isSoldByWeight) {
      final CartItem? weightCartItem = await showWeightItemDialog(context, item);
      if (weightCartItem != null) {
        await _addItemToCart(weightCartItem);
      }
      return;
    }

    final bool hasVariants = item.variant != null && item.variant!.isNotEmpty;
    final bool hasExtra = item.extraId != null && item.extraId!.isNotEmpty;
    final bool hasChoice = item.choiceIds != null && item.choiceIds!.isNotEmpty;
    String? categoryName;
    try {
      final category = categoryStore.categories.firstWhere((cat) => cat.id == item.categoryOfItem);
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
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: ItemOptionsDialog(
                  item: item,
                  categoryName: categoryName,
                ),
              ),
            );
          },
        );
      } else {
        final hInset = ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2)
            .clamp(40.0, 300.0);
        result = await showDialog<CartItem>(
          context: context,
          builder: (_) => Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: ItemOptionsDialog(
              item: item,
              categoryName: categoryName,
            ),
          ),
        );
      }

      if (result != null) {
        await _addItemToCart(result);
      }
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
    // Either choice still adds the item; the day is ENFORCED at checkout, so an
    // order can never be placed without a session even if this is cancelled.
    if (restaurantCartStore.cartItems.isEmpty &&
        !await DayManagementService.isSessionOpen() &&
        mounted) {
      await promptStartDay(context);
    }
    try {
      final result = await restaurantCartStore.addToCart(cartItem);

      if (result['success'] == true) {
        if (mounted) {
          NotificationService.instance.showSuccess(
            '${cartItem.title} added to cart',
          );
        }
      } else {
        if (mounted) {
          NotificationService.instance.showError(
            result['message'] ?? 'Cannot add item to cart',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError(
          'Error adding item to cart',
        );
      }
    }
  }


  String _formatStockDisplay(Items item) {
    if (!item.trackInventory) return '';

    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    // For items with variants, show variant availability status
    if (item.variant != null && item.variant!.isNotEmpty) {
      int inStockCount = 0;
      int totalVariants = item.variant!.length;

      for (var variant in item.variant!) {
        final variantStock = variant.stockQuantity ?? 0;
        if (variantStock > 0) {
          inStockCount++;
        }
      }

      if (inStockCount == 0) {
        // All variants out of stock
        if (allowOrderWhenOutOfStock) {
          return 'Order Available';
        } else {
          return 'Out of Stock';
        }
      } else if (inStockCount == totalVariants) {
        // All variants in stock
        return 'All Variants Available';
      } else {
        // Some variants in stock
        return '$inStockCount/$totalVariants Variants';
      }
    }

    // For regular items without variants, show base stock
    final stock = item.stockQuantity;
    final unit = item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');

    if (stock <= 0) {
      if (allowOrderWhenOutOfStock) {
        return 'Order Available';
      } else {
        return 'Out of Stock';
      }
    }

    if (item.isSoldByWeight) {
      final upperUnit = unit.toUpperCase();
      final isGm = upperUnit.contains('GM') || upperUnit.contains('GRAM') || upperUnit == 'G';
      final isKg = upperUnit.contains('KG');

      if (isGm && stock >= 1000) {
        // Stock in grams but large enough to show as kg
        final kg = stock / 1000;
        return '${kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 1)} kg';
      } else if (isKg || isGm) {
        // Show in item's own unit
        final formatted = stock == stock.roundToDouble()
            ? stock.toStringAsFixed(0)
            : stock.toStringAsFixed(2);
        return '$formatted $unit';
      }
      return '${stock.toStringAsFixed(2)} $unit';
    } else {
      return '${stock.toStringAsFixed(0)} $unit';
    }
  }

  StockStatus _getStockStatus(Items item) {
    if (!item.trackInventory) return StockStatus.notTracked;

    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    // For items with variants, check if at least one variant has stock
    if (item.variant != null && item.variant!.isNotEmpty) {
      bool hasAnyVariantInStock = false;

      for (var variant in item.variant!) {
        final variantStock = variant.stockQuantity ?? 0;
        if (variantStock > 0) {
          hasAnyVariantInStock = true;
          break;
        }
      }

      if (hasAnyVariantInStock) {
        return StockStatus.inStock;
      } else {
        // All variants are out of stock
        if (allowOrderWhenOutOfStock) {
          return StockStatus.orderAvailable;
        } else {
          return StockStatus.outOfStock;
        }
      }
    }

    // For regular items without variants, check base stock
    final stock = item.stockQuantity;
    if (stock <= 0) {
      if (allowOrderWhenOutOfStock) {
        return StockStatus.orderAvailable;
      } else {
        return StockStatus.outOfStock;
      }
    } else {
      return StockStatus.inStock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: isTablet ? _buildTabletLayout(context, size) : _buildMobileLayout(context, size),
    );
  }

  Widget _buildMobileLayout(BuildContext context, Size size) {
    final height = size.height;

    return Stack(
      children: [
        Observer(
          builder: (_) {
            final hasItems = restaurantCartStore.cartItems.isNotEmpty;
            return Padding(
                padding: EdgeInsets.only(top: 10, bottom: hasItems ? 80 : 0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: AppTextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        hint: 'Search Items',
                        icon: Icons.search_rounded,
                      ),
                    ),

                    // Horizontal category quick-nav strip — replaces the category FAB
                    Observer(
                      builder: (_) {
                        final enabledItems =
                            itemStore.items.where((i) => i.isEnabled).toList();
                        final cats =
                            categoryStore.categoriesWithItems(enabledItems);
                        // Show a Favorites pill first, but only when there are
                        // favorites to jump to (mirrors hiding empty categories).
                        final hasFav = enabledItems.any((i) => i.isFavorite);
                        return _HorizontalCategoryStrip(
                          categories: cats,
                          hasFavorites: hasFav,
                          activeCategory: activeCategory,
                          onCategorySelected: _selectStripCategory,
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    // Collapsible Category Sections
                    Expanded(
                      child: _isLoadingData
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Loading menu...',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Observer(
                        builder: (_) {
                          final allCategories = categoryStore.categories;

                          if (allCategories.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.category_outlined, size: 64, color: AppColors.textSecondary),
                                  SizedBox(height: 16),
                                  Text(
                                    'No Categories Found',
                                    style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            );
                          }

                          final allItems = itemStore.items;
                          final visibleItems = allItems.where((item) => item.isEnabled).toList();
                          final lowerQuery = query.toLowerCase();
                          // Snapshot the cart HERE (synchronously, inside the
                          // Observer) so the cards react to add/remove/qty —
                          // ListView item builders run lazily and wouldn't track.
                          final cartItems = restaurantCartStore.cartItems.toList();

                          // Hide categories with no items — the order screen only
                          // needs categories you can actually pick from.
                          final categories =
                              categoryStore.categoriesWithItems(visibleItems);

                          // Auto-open category sections while searching (runs
                          // post-frame, once per query change).
                          _syncSearchExpansion();

                          return SingleChildScrollView(
                            controller: _listScrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Column(
                              children: [
                                _buildFavoritesSection(visibleItems, query, lowerQuery, cartItems),
                                ...categories.map((category) {
                                  if (!_categoryKeys.containsKey(category.id)) {
                                    _categoryKeys[category.id] = GlobalKey();
                                  }
                                  if (!_expansionControllers.containsKey(category.id)) {
                                    _expansionControllers[category.id] = ExpansibleController();
                                  }

                                  final categoryItems = visibleItems.where((item) => item.categoryOfItem == category.id).toList();

                                  final searchFilteredItems = query.isEmpty
                                      ? categoryItems
                                      : categoryItems.where((item) {
                                    return item.name.toLowerCase().contains(lowerQuery) ||
                                        (item.itemCode != null && item.itemCode!.toLowerCase().contains(lowerQuery));
                                  }).toList();

                                  // Don't show empty categories when searching
                                  if (query.isNotEmpty && searchFilteredItems.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  return _CategorySectionCard(
                                    category: category,
                                    searchFilteredItems: searchFilteredItems,
                                    initiallyExpanded: query.isNotEmpty,
                                    controller: _expansionControllers[category.id],
                                    cardKey: _categoryKeys[category.id]!,
                                    cartItems: cartItems,
                                    onItemTap: _handleItemTap,
                                    onToggleFavorite: _toggleFavorite,
                                    formatStock: _formatStockDisplay,
                                    getStockStatus: _getStockStatus,
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ));
          },
        ),

        // Fixed Cart Bar at Bottom
        Observer(
          builder: (_) {
            if (restaurantCartStore.cartItems.isEmpty) return SizedBox.shrink();
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCartBar(context, size),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, Size size) {
    return Row(
      children: [
        // Left Sidebar — category navigation
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(right: BorderSide(color: AppColors.divider)),
          ),
          child: Observer(
            builder: (_) {
              final enabledItems =
                  itemStore.items.where((i) => i.isEnabled).toList();
              final allCategories =
                  categoryStore.categoriesWithItems(enabledItems);
              return Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: AppTextField(
                      controller: _searchController,
                      hint: 'Search items…',
                      icon: Icons.search_rounded,
                    ),
                  ),

                  // Favorites Button (pinned at top)
                  _buildCategoryButton(
                    icon: Icons.star_rounded,
                    label: 'Favorites',
                    isSelected: activeCategory == _kFavorites,
                    onTap: () => setState(() => activeCategory = _kFavorites),
                  ),

                  // All Items Button
                  _buildCategoryButton(
                    icon: Icons.grid_view,
                    label: 'All Items',
                    isSelected: activeCategory == null,
                    onTap: () => setState(() => activeCategory = null),
                  ),

                  // Category List
                  Expanded(
                    child: ListView.builder(
                      itemCount: allCategories.length,
                      itemBuilder: (context, index) {
                        final category = allCategories[index];
                        return _buildCategoryButton(
                          icon: Icons.folder_outlined,
                          label: category.name,
                          isSelected: activeCategory == category.id,
                          onTap: () => setState(() => activeCategory = category.id),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Main Content Area
        Expanded(
          child: _isLoadingData
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading menu...',
                        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Observer(
                      builder: (_) {
                        final hasItems = restaurantCartStore.cartItems.isNotEmpty;
                        // Tracked cart snapshot for the in-cart badges/highlight.
                        final cartItems = restaurantCartStore.cartItems.toList();
                        final allItems = itemStore.items;
                        var filteredItems = allItems.where((item) => item.isEnabled).toList();

                        if (activeCategory == _kFavorites) {
                          filteredItems = filteredItems.where((item) => item.isFavorite).toList();
                        } else if (activeCategory != null) {
                          filteredItems = filteredItems.where((item) => item.categoryOfItem == activeCategory).toList();
                        }

                        if (query.isNotEmpty) {
                          final lowerQuery = query.toLowerCase();
                          filteredItems = filteredItems.where((item) =>
                              item.name.toLowerCase().contains(lowerQuery) ||
                              (item.itemCode != null && item.itemCode!.toLowerCase().contains(lowerQuery))).toList();
                        }

                        if (filteredItems.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: AppColors.divider),
                                const SizedBox(height: 16),
                                Text('No items found', style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }

                        final gridColumns = AppResponsive.gridColumns(context, mobile: 2, tablet: 3, desktop: 4);
                        final aspectRatio = AppResponsive.getValue(context, mobile: 0.75, tablet: 0.70, desktop: 0.75);

                        return Padding(
                          padding: EdgeInsets.only(bottom: hasItems ? 80 : 16),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridColumns,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: aspectRatio,
                            ),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) => _buildGridItemCard(filteredItems[index], cartItems),
                          ),
                        );
                      },
                    ),

                    // Fixed Cart Bar at Bottom
                    Observer(
                      builder: (_) {
                        if (restaurantCartStore.cartItems.isEmpty) return const SizedBox.shrink();
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
        ),
      ],
    );
  }

  Widget _buildCategoryButton({required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItemCard(Items item, List<CartItem> cartItems) {
    final stockStatus = _getStockStatus(item);
    final isDisabled = stockStatus == StockStatus.outOfStock;
    // Cart entries for this item (snapshot tracked at the grid Observer top).
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
              borderRadius: BorderRadius.circular(16),
              // In-cart items stay calm: a thin accent border + the small green
              // "in cart" pill mark them, instead of a heavy fill/glow.
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
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Image — conditionally shown
                if (showImage)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMedium,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Center(child: _buildItemImageForGrid(item)),
                    ),
                  ),

                // Item Details
                Expanded(
                  flex: showImage ? 2 : 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item.itemCode != null && item.itemCode!.isNotEmpty)
                                  ? '${item.itemCode} ${item.name}'
                                  : item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDisabled ? AppColors.textSecondary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (showPrice)
                              Text(
                                _getPriceDisplayForGrid(item),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
            if (!isDisabled)
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.add, color: AppColors.white, size: 16),
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
                                              color: Colors.white, width: 1.5),
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
                ),
              ],
            ),
          ),
              Positioned(
                top: 6,
                right: 6,
                child: _favStar(item),
              ),
              // "In cart" pill at the top-left mirrors the favourite star.
              if (inCart)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
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

  /// Short cart label for the grid pill: total qty, or variant breakdown when
  /// the item was added with variants (e.g. "Large ×2, Regular ×1").
  String _gridCartLabel(List<CartItem> entries, int qty) {
    final hasVariants =
        entries.any((c) => (c.variantName ?? '').isNotEmpty);
    if (!hasVariants) return 'In cart · $qty';
    return entries
        .map((c) =>
            '${(c.variantName ?? '').isNotEmpty ? c.variantName : 'Regular'} ×${c.quantity}')
        .join(', ');
  }

  Widget _buildItemImageForGrid(Items item) {
    if (item.imageBytes != null && item.imageBytes!.isNotEmpty) {
      final file = item.imageBytes;
      if (file != null) return Image.memory(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return Icon(Icons.fastfood_rounded, size: 48, color: AppColors.textSecondary);
  }

  String _getPriceDisplayForGrid(Items item) {
    if (item.price != null) return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price!)}';
    if (item.variant != null && item.variant!.isNotEmpty) return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.variant!.first.price)}+';
    return 'N/A';
  }

  void _scrollToCategoryWhenStable(String categoryId, int requestId, {int maxFrames = 20}) {
    double lastHeight = 0.0;
    int frameCount = 0;

    void checkStability() {
      if (!mounted || requestId != _scrollRequestId) return;

      final key = _categoryKeys[categoryId];
      final context = key?.currentContext;

      if (context != null) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final double currentHeight = box.size.height;
          frameCount++;

          debugPrint('[MENU_TRACE] [SCROLL-POLL] t=${DateTime.now().millisecondsSinceEpoch}ms categoryId=$categoryId frame=$frameCount height=$currentHeight');

          const double kHeightTolerance = 0.5;
          if ((currentHeight - lastHeight).abs() > kHeightTolerance && frameCount < maxFrames) {
            lastHeight = currentHeight;
            WidgetsBinding.instance.addPostFrameCallback((_) => checkStability());
            return;
          }
        }
      }

      if (context != null && mounted && requestId == _scrollRequestId) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null && box.attached) {
          final RenderBox? scrollBox = Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
          if (scrollBox != null) {
            try {
              final double localY = box.localToGlobal(Offset.zero, ancestor: scrollBox).dy;
              if (localY.abs() < 1.5) {
                return;
              }
              if (_listScrollController.hasClients) {
                final double currentOffset = _listScrollController.offset;
                final double maxOffset = _listScrollController.position.maxScrollExtent;
                if ((currentOffset - maxOffset).abs() < 1.5) {
                  return;
                }
              }
            } catch (_) {}
          }

          final offset = _listScrollController.hasClients ? _listScrollController.offset : 0.0;
          debugPrint('[MENU_TRACE] [SCROLL-STABLE] t=${DateTime.now().millisecondsSinceEpoch}ms categoryId=$categoryId offset=$offset');

          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: 0.0,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          );
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => checkStability());
  }

  /// A single pill in the horizontal quick-nav strip. Shared by the Favorites
  /// chip and the per-category chips.
  void _selectStripCategory(String categoryId) {
    // Collapse the previously active category
    if (activeCategory != null && activeCategory != categoryId) {
      final prev = _expansionControllers[activeCategory];
      if (prev != null) {
        try {
          debugPrint('[MENU_TRACE] [COLLAPSE] t=${DateTime.now().millisecondsSinceEpoch}ms categoryId=$activeCategory');
          prev.collapse();
        } catch (_) {}
      }
    }

    activeCategory = categoryId;

    // Expand the selected category immediately (always built and mounted)
    final ctrl = _expansionControllers[categoryId];
    if (ctrl != null) {
      try {
        debugPrint('[MENU_TRACE] [EXPAND] t=${DateTime.now().millisecondsSinceEpoch}ms categoryId=$categoryId');
        ctrl.expand();
      } catch (_) {}
    }

    // Increment request ID to cancel any pending stabilization frame checks
    final int currentId = ++_scrollRequestId;

    // Cancelable Dynamic Correction: Refocus precisely once layout has fully stabilized
    _scrollToCategoryWhenStable(categoryId, currentId);
  }

  Widget _buildCartBar(BuildContext context, Size size) {
    return Container(
      width: size.width,
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
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
                  final total = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
                  final itemCount = cartItems.fold(0, (sum, item) => sum + item.quantity);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(total)}',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(width: 10),
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
                          selectedTableNo: widget.tableIdForNewOrder,
                        ),
                      ),
                    );
                    // Cart items automatically update via MobX reactivity
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'View Cart',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      textScaler: TextScaler.linear(1),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
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

// ═══════════════════════════════════════════════════════════════════════════
// ITEM LIST TILE
// ═══════════════════════════════════════════════════════════════════════════
class _ItemListTile extends StatefulWidget {
  final Items item;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;
  /// Cart entries for THIS item (matched by productId). Drives the in-cart
  /// quantity badge, highlight, and per-variant "in cart" summary.
  final List<CartItem> cartEntries;
  const _ItemListTile({super.key, required this.item, required this.onTap, required this.onToggleFavorite, required this.formatStock, required this.getStockStatus, this.cartEntries = const []});

  @override
  State<_ItemListTile> createState() => _ItemListTileState();
}

class _ItemListTileState extends State<_ItemListTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final stockStatus = widget.getStockStatus(widget.item);
    final isDisabled = stockStatus == StockStatus.outOfStock;
    final int cartQty =
        widget.cartEntries.fold<int>(0, (s, c) => s + c.quantity);
    final bool inCart = cartQty > 0;

    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: AppSettings.settingsNotifier,
      builder: (context, _, __) {
        final showImage = AppSettings.showItemImage;
        final showPrice = AppSettings.showItemPrice;

        return GestureDetector(
          onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
          onTapUp: isDisabled ? null : (_) { setState(() => _isPressed = false); widget.onTap(); },
          onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
            decoration: BoxDecoration(
              color: _isPressed
                  ? AppColors.primary.withOpacity(0.08)
                  : isDisabled
                      ? AppColors.surfaceMedium.withOpacity(0.5)
                      : inCart
                          ? AppColors.primary.withOpacity(0.04)
                          : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              // In-cart items stay calm: a thin accent border + the small green
              // "in cart" chip mark them, instead of a heavy fill/glow.
              border: Border.all(
                color: _isPressed
                    ? AppColors.primary.withOpacity(0.3)
                    : inCart
                        ? AppColors.primary.withOpacity(0.45)
                        : isDisabled
                            ? AppColors.divider
                            : AppColors.divider.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (showImage) ...[
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(color: AppColors.surfaceMedium, borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildItemImage()),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.item.itemCode != null && widget.item.itemCode!.isNotEmpty)
                            ? '${widget.item.itemCode} ${widget.item.name}'
                            : widget.item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: isDisabled ? AppColors.textSecondary : AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (showPrice)
                            Text(_getPriceDisplay(), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          if (widget.item.trackInventory) ...[
                            if (showPrice) const SizedBox(width: 10),
                            Flexible(child: _buildStockBadge(stockStatus)),
                          ],
                        ],
                      ),
                      // In-cart summary: total qty, or per-variant breakdown.
                      if (inCart) ...[
                        const SizedBox(height: 6),
                        _buildCartSummary(),
                      ],
                    ],
                  ),
                ),
                InkWell(
                  onTap: widget.onToggleFavorite,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      widget.item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 22,
                      color: widget.item.isFavorite ? Colors.amber : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (!isDisabled)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: const Icon(Icons.add_rounded, color: AppColors.white, size: 20),
                      ),
                      // Count badge — how many of this item are in the cart.
                      if (inCart)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints:
                                const BoxConstraints(minWidth: 20, minHeight: 20),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              '$cartQty',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Compact in-cart summary: "2 in cart" or per-variant "Large ×2, Regular ×1".
  Widget _buildCartSummary() {
    final hasVariants =
        widget.cartEntries.any((c) => (c.variantName ?? '').isNotEmpty);
    final String label;
    if (hasVariants) {
      label = widget.cartEntries
          .map((c) =>
              '${(c.variantName ?? '').isNotEmpty ? c.variantName : 'Regular'} ×${c.quantity}')
          .join(', ');
    } else {
      final qty =
          widget.cartEntries.fold<int>(0, (s, c) => s + c.quantity);
      label = '$qty in cart';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 13, color: AppColors.success),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage() {
    if (widget.item.imageBytes != null && widget.item.imageBytes!.isNotEmpty) {
      final file = widget.item.imageBytes;
      if (file!=null) return Image.memory(file, fit: BoxFit.cover, width: 58, height: 58);
    }
    return const Icon(Icons.fastfood_rounded, size: 26, color: AppColors.textSecondary);
  }

  String _getPriceDisplay() {
    if (widget.item.price != null) return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(widget.item.price!)}';
    if (widget.item.variant != null && widget.item.variant!.isNotEmpty) return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(widget.item.variant!.first.price)}+';
    return 'Price N/A';
  }

  Widget _buildStockBadge(StockStatus status) {
    Color bgColor, textColor;
    String text = widget.formatStock(widget.item);
    switch (status) {
      case StockStatus.inStock: bgColor = AppColors.success.withOpacity(0.12); textColor = AppColors.success; break;
      case StockStatus.orderAvailable: bgColor = AppColors.warning.withOpacity(0.12); textColor = AppColors.warning; break;
      case StockStatus.outOfStock: bgColor = AppColors.danger.withOpacity(0.12); textColor = AppColors.danger; break;
      case StockStatus.notTracked: return const SizedBox.shrink();
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)));
  }
}

class _HorizontalCategoryStrip extends StatefulWidget {
  final List<dynamic> categories;
  final bool hasFavorites;
  final String? activeCategory;
  final ValueChanged<String> onCategorySelected;

  const _HorizontalCategoryStrip({
    required this.categories,
    required this.hasFavorites,
    required this.activeCategory,
    required this.onCategorySelected,
  });

  @override
  State<_HorizontalCategoryStrip> createState() => _HorizontalCategoryStripState();
}

class _HorizontalCategoryStripState extends State<_HorizontalCategoryStrip> {
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.activeCategory;
  }

  @override
  void didUpdateWidget(covariant _HorizontalCategoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeCategory != oldWidget.activeCategory) {
      _activeCategory = widget.activeCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty && !widget.hasFavorites) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: widget.categories.length + (widget.hasFavorites ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (widget.hasFavorites && i == 0) {
            return _buildStripChip(
              label: 'Favorites',
              icon: Icons.star_rounded,
              isActive: _activeCategory == _MenuScreenState._kFavorites,
              onTap: () {
                setState(() => _activeCategory = _MenuScreenState._kFavorites);
                widget.onCategorySelected(_MenuScreenState._kFavorites);
              },
            );
          }
          final cat = widget.categories[i - (widget.hasFavorites ? 1 : 0)];
          return _buildStripChip(
            label: cat.name,
            isActive: _activeCategory == cat.id,
            onTap: () {
              setState(() => _activeCategory = cat.id);
              widget.onCategorySelected(cat.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildStripChip({
    required String label,
    IconData? icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isActive ? Colors.white : Colors.amber),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
