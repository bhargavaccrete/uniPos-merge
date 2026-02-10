
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:unipos/util/color.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/visual_keyboard.dart';
import 'WeightItemDialog.dart';
import 'item_options_dialog.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
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

  String? activeCategory;
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _codehereFocusNode = FocusNode();
  final Map<String, GlobalKey> _categoryKeys = {};
  bool _isLoadingData = false;


  @override
  void initState() {
    super.initState();
    _loadData();

    _searchController.addListener((){
      setState(() {
        query = _searchController.text;
      });
    });

    // Listen for search field focus - show visual keyboard if enabled
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && AppSettings.visualKeyboard) {
        FocusScope.of(context).requestFocus(FocusNode());
        VisualKeyboardHelper.show(
          context: context,
          controller: _searchController,
          keyboardType: KeyboardType.text,
        );
      }
    });


    _codehereFocusNode.addListener(() {
      if (_codehereFocusNode.hasFocus && AppSettings.visualKeyboard) {
        FocusScope.of(context).requestFocus(FocusNode());
        VisualKeyboardHelper.show(
          context: context,
          controller: _codeController,
          keyboardType: KeyboardType.text,
        );
      }
    });
  }

  Future<void> _loadData() async {
    // Prevent concurrent loads
    if (_isLoadingData) return;

    _isLoadingData = true;
    try {
      print('📥 MenuScreen: Loading data...');
      await Future.wait([
        categoryStore.loadCategories(),
        itemStore.loadItems(),
        restaurantCartStore.loadCartItems(),
      ]);
      print('✅ MenuScreen: Data loaded - ${categoryStore.categories.length} categories, ${itemStore.items.length} items');
    } finally {
      _isLoadingData = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      print("Could not find category for item: ${item.name}. Defaulting to 'Uncategorized'");
      categoryName = 'Uncategorized';
    }

    if (hasVariants||hasExtra||hasChoice) {
      final result = await showModalBottomSheet<CartItem>(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.4,
            minChildSize: 0.3,
            maxChildSize: 0.5,
            builder: (_, controller) {
              return SingleChildScrollView(
                controller: controller,
                child: ItemOptionsDialog(item: item, categoryName: categoryName),
              );
            },
          );
        },
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
        imagePath: '',
        price: item.price ?? 0,
        quantity: 1,
        taxRate: item.taxRate,
        weightDisplay: null,
        categoryName: categoryName,
      );

      print('--- ADD TO CART --- Product ID: "${simpleCartItem.productId}", Stock Managed: ${simpleCartItem.isStockManaged}');

      await _addItemToCart(simpleCartItem);
    }
  }

  Future<void> _addItemToCart(CartItem cartItem) async {
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
      print('Error adding to cart: $e');
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

  void _showCategoryJumpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Observer(
          builder: (_) {
            final allCategories = categoryStore.categories;

            return Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.category, color: AppColors.primary, size: 20),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Jump to Category',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: allCategories.length,
                      itemBuilder: (context, index) {
                        final category = allCategories[index];
                        final firstLetter = category.name.isNotEmpty
                            ? category.name[0].toUpperCase()
                            : '?';

                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                firstLetter,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () {
                            Navigator.pop(context);
                            final key = _categoryKeys[category.id];
                            if (key != null && key.currentContext != null) {
                              Scrollable.ensureVisible(
                                key.currentContext!,
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      floatingActionButton: isTablet ? null : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Refresh button for debugging
          FloatingActionButton(
            mini: true,
            heroTag: 'refresh',
            onPressed: () {
              print('🔄 Manual refresh triggered');
              _isLoadingData = false; // Reset flag
              _loadData();
            },
            backgroundColor: AppColors.success,
            child: Icon(Icons.refresh, color: Colors.white, size: 20),
          ),
          SizedBox(height: 10),
          Observer(
            builder: (_) {
              final hasItems = restaurantCartStore.cartItems.isNotEmpty;
              return Padding(
                padding: EdgeInsets.only(bottom: hasItems ? 80 : 0),
                child: FloatingActionButton(
                  heroTag: 'category',
                  onPressed: _showCategoryJumpSheet,
                  backgroundColor: AppColors.primary,
                  elevation: 6,
                  child: Icon(Icons.category, color: Colors.white, size: 28),
                ),
              );
            },
          ),
        ],
      ),
      body: isTablet ? _buildTabletLayout(context, size) : _buildMobileLayout(context, size),
    );
  }

  Widget _buildMobileLayout(BuildContext context, Size size) {
    final height = size.height;
    final width = size.width;

    return Stack(
        children: [
          Observer(
            builder: (_) {
              final hasItems = restaurantCartStore.cartItems.isNotEmpty;
              return Padding(
                padding: EdgeInsets.only(top: 10, bottom: hasItems ? 80 : 0),
                child: Column(
              children: [
                // Search text field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Container(
                            height: height * 0.04,
                            child: TextField(
                              textAlign: TextAlign.center,
                              controller: _codeController,
                              focusNode: _codehereFocusNode,
                              readOnly: AppSettings.visualKeyboard,
                              onTap: AppSettings.visualKeyboard? (){
                                VisualKeyboardHelper.show(
                                  context: context,
                                  controller: _codeController,
                                  keyboardType: KeyboardType.text,
                                );
                              } : null,
                              decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  hintText: 'Code Here',
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: AppSettings.visualKeyboard
                                      ? Icon(Icons.keyboard, size: 18, color: AppColors.primary)
                                      : null,
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  border: OutlineInputBorder()),
                            )),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Container(
                            height: height * 0.04,
                            child: TextField(
                              textAlign: TextAlign.center,
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              readOnly: AppSettings.visualKeyboard,
                              onTap: AppSettings.visualKeyboard ? () {
                                VisualKeyboardHelper.show(
                                  context: context,
                                  controller: _searchController,
                                  keyboardType: KeyboardType.text,
                                );
                              } : null,
                              decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  hintText: 'Search Items',
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: AppSettings.visualKeyboard
                                      ? Icon(Icons.keyboard, size: 18, color: AppColors.primary)
                                      : Icon(Icons.search, size: 18, color: Colors.grey),
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  border: OutlineInputBorder()),
                            )),
                      ),
                    ],
                  ),
                ),

                // Collapsible Category Sections
                Expanded(
                  child: Observer(
                    builder: (_) {
                      final allCategories = categoryStore.categories;

                      if (allCategories.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No Categories Found',
                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }

                      final allItems = itemStore.items;
                      final visibleItems = allItems.where((item) => item.isEnabled).toList();

                      return ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            itemCount: allCategories.length,
                            itemBuilder: (context, index) {
                              final category = allCategories[index];

                              // Create or get key for this category
                              if (!_categoryKeys.containsKey(category.id)) {
                                _categoryKeys[category.id] = GlobalKey();
                              }

                              // Filter items by category
                              final categoryItems = visibleItems.where((item) => item.categoryOfItem == category.id).toList();

                              // Apply search filter
                              final searchFilteredItems = query.isEmpty
                                  ? categoryItems
                                  : categoryItems.where((item) {
                                      return item.name.toLowerCase().contains(query.toLowerCase());
                                    }).toList();

                              // Don't show empty categories when searching
                              if (query.isNotEmpty && searchFilteredItems.isEmpty) {
                                return SizedBox.shrink();
                              }

                              return Card(
                                key: _categoryKeys[category.id],
                                margin: EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                color: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    initiallyExpanded: query.isNotEmpty,
                                    leading: Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.restaurant_menu,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      category.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${searchFilteredItems.length} items',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    children: [
                                      if (searchFilteredItems.isEmpty)
                                        Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Text(
                                            'No items in this category',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      else
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: NeverScrollableScrollPhysics(),
                                          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                                          itemCount: searchFilteredItems.length,
                                          separatorBuilder: (_, __) => SizedBox(height: 8),
                                          itemBuilder: (context, itemIndex) {
                                            final item = searchFilteredItems[itemIndex];
                                            return _ItemListTile(
                                              item: item,
                                              onTap: () => _handleItemTap(item),
                                              formatStock: _formatStockDisplay,
                                              getStockStatus: _getStockStatus,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
        // Left Sidebar
        Container(
          width: 200,
          color: AppColors.white,
          child: Observer(
            builder: (_) {
              final allCategories = categoryStore.categories;
              return Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search menu items...',
                        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surfaceMedium,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ),

                  // All Items Button
                  _buildCategoryButton(
                    icon: Icons.grid_view,
                    label: 'All Items',
                    isSelected: activeCategory == null,
                    onTap: () {
                      setState(() {
                        activeCategory = null;
                      });
                    },
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
                          onTap: () {
                            setState(() {
                              activeCategory = category.id;
                            });
                          },
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
          child: Stack(
            children: [
              Observer(
                builder: (_) {
                  final hasItems = restaurantCartStore.cartItems.isNotEmpty;
                  return Padding(
                    padding: EdgeInsets.only(bottom: hasItems ? 80 : 16),
                    child: Observer(
                  builder: (_) {
                    final allItems = itemStore.items;
                    var filteredItems = allItems.where((item) => item.isEnabled).toList();

                    // Filter by category
                    if (activeCategory != null) {
                      filteredItems = filteredItems.where((item) => item.categoryOfItem == activeCategory).toList();
                    }

                    // Filter by search query
                    if (query.isNotEmpty) {
                      filteredItems = filteredItems.where((item) {
                        return item.name.toLowerCase().contains(query.toLowerCase());
                      }).toList();
                    }

                    if (filteredItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: AppColors.divider),
                            SizedBox(height: 16),
                            Text(
                              'No items found',
                              style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildGridItemCard(item);
                      },
                    );
                  },
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

  Widget _buildGridItemCard(Items item) {
    final stockStatus = _getStockStatus(item);
    final isDisabled = stockStatus == StockStatus.outOfStock;

    return GestureDetector(
      onTap: isDisabled ? null : () => _handleItemTap(item),
      child: Container(
        decoration: BoxDecoration(
          color: isDisabled ? AppColors.surfaceMedium.withOpacity(0.5) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDisabled ? AppColors.divider : AppColors.divider.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMedium,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: _buildItemImageForGrid(item),
                ),
              ),
            ),

            // Item Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getPriceDisplayForGrid(item),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (!isDisabled)
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add, color: AppColors.white, size: 16),
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
                  final total = restaurantCartStore.cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
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
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;
  const _ItemListTile({required this.item, required this.onTap, required this.formatStock, required this.getStockStatus});

  @override
  State<_ItemListTile> createState() => _ItemListTileState();
}

class _ItemListTileState extends State<_ItemListTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final stockStatus = widget.getStockStatus(widget.item);
    final isDisabled = stockStatus == StockStatus.outOfStock;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled ? null : (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        decoration: BoxDecoration(
          color: _isPressed ? AppColors.primary.withOpacity(0.08) : isDisabled ? AppColors.surfaceMedium.withOpacity(0.5) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _isPressed ? AppColors.primary.withOpacity(0.3) : isDisabled ? AppColors.divider : AppColors.divider.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(color: AppColors.surfaceMedium, borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildItemImage()),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: isDisabled ? AppColors.textSecondary : AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(_getPriceDisplay(), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      if (widget.item.trackInventory) ...[const SizedBox(width: 10), _buildStockBadge(stockStatus)],
                    ],
                  ),
                ],
              ),
            ),
            if (!isDisabled)
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.white, size: 20),
              ),
          ],
        ),
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
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Text(text, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)));
  }
}
