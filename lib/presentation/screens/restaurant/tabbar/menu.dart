import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_cart.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/color.dart';
import '../../../../util/restaurant/staticswitch.dart';
import 'WeightItemDialog.dart';
import 'item_options_dialog.dart';

class MenuScreen extends StatefulWidget {
  final String? tableIdForNewOrder;
  final OrderModel? existingOrder;
  final bool isForAddingItem;

  const MenuScreen({
    super.key,
    this.existingOrder,
    this.isForAddingItem = false,
    this.tableIdForNewOrder,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  // State variables
  bool isCartShow = false;
  double totalPrice = 0.0;
  int totalItems = 0;
  List<CartItem> cartItemsList = [];
  Set<String> expandedCategories = {};
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _fabAnimationController;
  late AnimationController _cartSlideController;
  late Animation<double> _fabScaleAnimation;
  late Animation<Offset> _cartSlideAnimation;

  // Category scroll keys for navigation
  final Map<String, GlobalKey> _categoryKeys = {};

  @override
  void initState() {
    super.initState();
    loadCartItems();

    if (widget.tableIdForNewOrder != null) {
      _storeSelectedTable(widget.tableIdForNewOrder!);
    }

    _searchController.addListener(() {
      setState(() {
        query = _searchController.text;
      });
    });

    // Initialize animations
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _cartSlideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    _cartSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cartSlideController,
      curve: Curves.easeOutCubic,
    ));

    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _cartSlideController.dispose();
    super.dispose();
  }

  void _storeSelectedTable(String tableId) async {
    final appBox = Hive.box('app_state');
    await appBox.put('selected_table_for_new_order', tableId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ITEM TAP HANDLER
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _handleItemTap(Items item) async {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Weight items
    if (item.isSoldByWeight) {
      final CartItem? weightCartItem = await showWeightItemDialog(context, item);
      if (weightCartItem != null) {
        await _addItemToCart(weightCartItem);
      }
      return;
    }

    final bool hasVariants = item.variant != null && item.variant!.isNotEmpty;

    // Find category name
    String? categoryName;
    try {
      final categoryBox = Hive.box<Category>('categories');
      final category = categoryBox.values.firstWhere((cat) => cat.id == item.categoryOfItem);
      categoryName = category.name;
    } catch (e) {
      categoryName = 'Uncategorized';
    }

    if (hasVariants) {
      final result = await showModalBottomSheet<CartItem>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildVariantBottomSheet(item, categoryName),
      );

      if (result != null) {
        await _addItemToCart(result);
      }
    } else {
      final simpleCartItem = CartItem(
        productId: item.id,
        isStockManaged: item.trackInventory,
        id: const Uuid().v4(),
        title: item.name,
        imagePath: Uint8List(0), // CartItem uses path as identifier, not actual image data
        price: item.price ?? 0,
        quantity: 1,
        taxRate: item.taxRate,
        weightDisplay: null,
        categoryName: categoryName,
      );
      await _addItemToCart(simpleCartItem);
    }
  }

  Widget _buildVariantBottomSheet(Items item, String? categoryName) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (_, controller) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: ItemOptionsDialog(item: item, categoryName: categoryName),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addItemToCart(CartItem cartItem) async {
    try {
      final result = await HiveCart.addToCart(cartItem);

      if (result['success'] == true) {
        await loadCartItems();

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

  Future<void> loadCartItems() async {
    try {
      final items = await HiveCart.getAllCartItems();
      setState(() {
        cartItemsList = items;
        totalPrice = items.fold(0.0, (sum, item) => sum + item.totalPrice);
        totalItems = items.fold(0, (sum, item) => sum + item.quantity);
        isCartShow = items.isNotEmpty;

        if (isCartShow) {
          _cartSlideController.forward();
        } else {
          _cartSlideController.reverse();
        }
      });
    } catch (e) {
      print('Error loading cart items: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STOCK DISPLAY HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  String _formatStockDisplay(Items item) {
    if (!item.trackInventory) return '';

    final stock = item.stockQuantity;
    final unit = item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');
    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    if (stock <= 0) {
      return allowOrderWhenOutOfStock ? 'Order Available' : 'Out of Stock';
    }

    if (item.isSoldByWeight) {
      if (unit.toUpperCase().contains('GM') || unit.toUpperCase().contains('GRAM')) {
        return '${stock.toStringAsFixed(stock == stock.toInt() ? 0 : 1)}${unit}';
      } else if (unit.toUpperCase().contains('KG')) {
        if (stock >= 1000) {
          double kg = stock / 1000;
          return '${kg.toStringAsFixed(kg == kg.toInt() ? 0 : 1)}KG';
        } else {
          return '${stock.toStringAsFixed(0)}GM';
        }
      }
      return '${stock.toStringAsFixed(2)}${unit}';
    } else {
      return '${stock.toStringAsFixed(0)} ${unit}';
    }
  }

  StockStatus _getStockStatus(Items item) {
    if (!item.trackInventory) return StockStatus.notTracked;

    final stock = item.stockQuantity;
    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    if (stock <= 0) {
      return allowOrderWhenOutOfStock ? StockStatus.orderAvailable : StockStatus.outOfStock;
    }
    return StockStatus.inStock;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CATEGORY NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════
  void _scrollToCategory(String categoryId) {
    final key = _categoryKeys[categoryId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
    Navigator.pop(context); // Close the navigation menu
  }

  void _showCategoryNavigator(List<Category> categories) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CategoryNavigator(
        categories: categories,
        onCategoryTap: _scrollToCategory,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD METHOD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Header with search
                _buildHeader(size),

                // Menu content
                Expanded(
                  child: isTablet
                      ? _buildTabletLayout(size)
                      : _buildMobileLayout(size),
                ),
              ],
            ),

            // Floating cart bar
            if (isCartShow)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _cartSlideAnimation,
                  child: _buildCartBar(size),
                ),
              ),

            // Floating action button for category navigation (mobile only)
            if (!isTablet)
              Positioned(
                bottom: isCartShow ? 100 : 24,
                right: 20,
                child: ScaleTransition(
                  scale: _fabScaleAnimation,
                  child: _buildCategoryFAB(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(Size size) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menu',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.tableIdForNewOrder != null
                            ? 'Table ${widget.tableIdForNewOrder}'
                            : 'Quick Order',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Cart indicator
              if (isCartShow)
                GestureDetector(
                  onTap: () => _navigateToCart(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$totalItems',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surfaceMedium,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT - Collapsible Categories
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(Size size) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Category>('categories').listenable(),
      builder: (context, categoryBox, _) {
        final categories = categoryBox.values.toList();

        if (categories.isEmpty) {
          return _buildEmptyState('No categories found');
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<Items>('itemBoxs').listenable(),
          builder: (context, itemBox, _) {
            final allItems = itemBox.values.where((item) => item.isEnabled).toList();

            // Filter items based on search
            final filteredItems = query.isEmpty
                ? allItems
                : allItems.where((item) {
              return item.name.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: 12,
                bottom: isCartShow ? 120 : 80,
                left: 16,
                right: 16,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryItems = filteredItems
                    .where((item) => item.categoryOfItem == category.id)
                    .toList();

                if (categoryItems.isEmpty && query.isNotEmpty) {
                  return const SizedBox.shrink();
                }

                // Register category key for navigation
                _categoryKeys[category.id] = GlobalKey();

                return _CollapsibleCategorySection(
                  key: _categoryKeys[category.id],
                  category: category,
                  items: categoryItems,
                  isExpanded: expandedCategories.contains(category.id) || query.isNotEmpty,
                  onToggle: () {
                    setState(() {
                      if (expandedCategories.contains(category.id)) {
                        expandedCategories.remove(category.id);
                      } else {
                        expandedCategories.add(category.id);
                      }
                    });
                  },
                  onItemTap: _handleItemTap,
                  formatStock: _formatStockDisplay,
                  getStockStatus: _getStockStatus,
                );
              },
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TABLET LAYOUT - Side Categories
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout(Size size) {
    String? selectedCategory;

    return Row(
      children: [
        // Category sidebar
        Container(
          width: 200,
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(
              right: BorderSide(color: AppColors.divider),
            ),
          ),
          child: ValueListenableBuilder(
            valueListenable: Hive.box<Category>('categories').listenable(),
            builder: (context, categoryBox, _) {
              final categories = categoryBox.values.toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: categories.length + 1, // +1 for "All" option
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildCategorySidebarItem(
                      'All Items',
                      Icons.grid_view_rounded,
                      selectedCategory == null,
                          () => setState(() => selectedCategory = null),
                    );
                  }

                  final category = categories[index - 1];
                  return _buildCategorySidebarItem(
                    category.name,
                    Icons.folder_rounded,
                    selectedCategory == category.id,
                        () => setState(() => selectedCategory = category.id),
                  );
                },
              );
            },
          ),
        ),

        // Items grid
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: Hive.box<Items>('itemBoxs').listenable(),
            builder: (context, itemBox, _) {
              var items = itemBox.values.where((item) => item.isEnabled).toList();

              // Filter by category
              if (selectedCategory != null) {
                items = items.where((item) => item.categoryOfItem == selectedCategory).toList();
              }

              // Filter by search
              if (query.isNotEmpty) {
                items = items.where((item) {
                  return item.name.toLowerCase().contains(query.toLowerCase());
                }).toList();
              }

              if (items.isEmpty) {
                return _buildEmptyState('No items found');
              }

              return GridView.builder(
                padding: EdgeInsets.only(
                  top: 16,
                  bottom: isCartShow ? 120 : 24,
                  left: 16,
                  right: 16,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: size.width > 900 ? 4 : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _ItemCard(
                    item: items[index],
                    onTap: () => _handleItemTap(items[index]),
                    formatStock: _formatStockDisplay,
                    getStockStatus: _getStockStatus,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySidebarItem(String name, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CART BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCartBar(Size size) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cart info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalItems items',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          // View cart button
          GestureDetector(
            onTap: _navigateToCart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    'View Cart',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCart() async {
    HapticFeedback.mediumImpact();

    if (widget.isForAddingItem == true) {
      Navigator.pop(context);
    } else {
      final appBox = Hive.box('app_state');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(
            selectedTableNo: widget.tableIdForNewOrder,
          ),
        ),
      );
      appBox.delete('selected_table_for_new_order');
      await loadCartItems();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CATEGORY FAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCategoryFAB() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Category>('categories').listenable(),
      builder: (context, categoryBox, _) {
        final categories = categoryBox.values.toList();

        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _showCategoryNavigator(categories);
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.menu_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COLLAPSIBLE CATEGORY SECTION
// ═══════════════════════════════════════════════════════════════════════════
class _CollapsibleCategorySection extends StatefulWidget {
  final Category category;
  final List<Items> items;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Function(Items) onItemTap;
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;

  const _CollapsibleCategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.isExpanded,
    required this.onToggle,
    required this.onItemTap,
    required this.formatStock,
    required this.getStockStatus,
  });

  @override
  State<_CollapsibleCategorySection> createState() => _CollapsibleCategorySectionState();
}

class _CollapsibleCategorySectionState extends State<_CollapsibleCategorySection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(_expandAnimation);

    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_CollapsibleCategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category header
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onToggle();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isExpanded
                    ? AppColors.primary.withOpacity(0.05)
                    : AppColors.white,
                borderRadius: widget.isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.category_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.items.length} items',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _rotateAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMedium,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items list
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: widget.items.isEmpty
                ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No items in this category',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            )
                : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _ItemListTile(
                  item: widget.items[index],
                  onTap: () => widget.onItemTap(widget.items[index]),
                  formatStock: widget.formatStock,
                  getStockStatus: widget.getStockStatus,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ITEM LIST TILE (Mobile)
// ═══════════════════════════════════════════════════════════════════════════
class _ItemListTile extends StatelessWidget {
  final Items item;
  final VoidCallback onTap;
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;

  const _ItemListTile({
    required this.item,
    required this.onTap,
    required this.formatStock,
    required this.getStockStatus,
  });

  @override
  Widget build(BuildContext context) {
    final stockStatus = getStockStatus(item);
    final isDisabled = stockStatus == StockStatus.outOfStock;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.surfaceMedium.withOpacity(0.5)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled ? AppColors.divider : AppColors.divider.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            // Item image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildItemImage(),
              ),
            ),
            const SizedBox(width: 14),

            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDisabled
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _getPriceDisplay(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (item.trackInventory) ...[
                        const SizedBox(width: 10),
                        _buildStockBadge(stockStatus),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Add button
            if (!isDisabled)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage() {
    if (item.imageBytes != null && item.imageBytes!.isNotEmpty) {
      final file = item.imageBytes;
      if (file!=null) {
        return Image.memory(
          file,
          fit: BoxFit.cover,
          width: 56,
          height: 56,
        );
      }
    }
    return Icon(
      Icons.fastfood_rounded,
      size: 24,
      color: AppColors.textSecondary,
    );
  }

  String _getPriceDisplay() {
    if (item.price != null) {
      return '₹${item.price!.toStringAsFixed(2)}';
    } else if (item.variant != null && item.variant!.isNotEmpty) {
      return '₹${item.variant!.first.price.toStringAsFixed(2)}+';
    }
    return 'Price N/A';
  }

  Widget _buildStockBadge(StockStatus status) {
    Color bgColor;
    Color textColor;
    String text = formatStock(item);

    switch (status) {
      case StockStatus.inStock:
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        break;
      case StockStatus.orderAvailable:
        bgColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        break;
      case StockStatus.outOfStock:
        bgColor = AppColors.danger.withOpacity(0.1);
        textColor = AppColors.danger;
        break;
      case StockStatus.notTracked:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ITEM CARD (Tablet/Desktop)
// ═══════════════════════════════════════════════════════════════════════════
class _ItemCard extends StatefulWidget {
  final Items item;
  final VoidCallback onTap;
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;

  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.formatStock,
    required this.getStockStatus,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final stockStatus = widget.getStockStatus(widget.item);
    final isDisabled = stockStatus == StockStatus.outOfStock;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: isDisabled ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        decoration: BoxDecoration(
          color: isDisabled ? AppColors.surfaceMedium : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _isPressed
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.cardShadow,
              blurRadius: _isPressed ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMedium,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(child: _buildItemImage()),

                    // Stock badge
                    if (widget.item.trackInventory)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildStockBadge(stockStatus),
                      ),
                  ],
                ),
              ),
            ),

            // Info section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDisabled
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getPriceDisplay(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (!isDisabled)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: AppColors.white,
                              size: 18,
                            ),
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
    );
  }

  Widget _buildItemImage() {
    if (widget.item.imageBytes != null && widget.item.imageBytes!.isNotEmpty) {
      final file = widget.item.imageBytes!;
      if (file!= '') {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Image.memory(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      }
    }
    return Icon(
      Icons.fastfood_rounded,
      size: 48,
      color: AppColors.textSecondary.withOpacity(0.5),
    );
  }

  String _getPriceDisplay() {
    if (widget.item.price != null) {
      return '₹${widget.item.price!.toStringAsFixed(2)}';
    } else if (widget.item.variant != null && widget.item.variant!.isNotEmpty) {
      return '₹${widget.item.variant!.first.price.toStringAsFixed(2)}+';
    }
    return 'N/A';
  }

  Widget _buildStockBadge(StockStatus status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case StockStatus.inStock:
        bgColor = AppColors.success;
        textColor = AppColors.white;
        icon = Icons.check_circle_rounded;
        break;
      case StockStatus.orderAvailable:
        bgColor = AppColors.warning;
        textColor = AppColors.white;
        icon = Icons.access_time_rounded;
        break;
      case StockStatus.outOfStock:
        bgColor = AppColors.danger;
        textColor = AppColors.white;
        icon = Icons.remove_circle_rounded;
        break;
      case StockStatus.notTracked:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            widget.formatStock(widget.item),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CATEGORY NAVIGATOR (Bottom Sheet)
// ═══════════════════════════════════════════════════════════════════════════
class _CategoryNavigator extends StatelessWidget {
  final List<Category> categories;
  final Function(String) onCategoryTap;

  const _CategoryNavigator({
    required this.categories,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Jump to Category',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Category list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onCategoryTap(category.id);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.8),
                                AppColors.secondary.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              category.name.isNotEmpty
                                  ? category.name[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            category.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STOCK STATUS ENUM
// ═══════════════════════════════════════════════════════════════════════════
enum StockStatus {
  inStock,
  orderAvailable,
  outOfStock,
  notTracked,
}