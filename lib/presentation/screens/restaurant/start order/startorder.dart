import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/models/restaurant/db/database/hive_cart.dart';
import '../../../../data/models/restaurant/db/database/hive_Table.dart';
import '../../../../data/models/restaurant/db/database/hive_order.dart';
import '../../../../data/models/restaurant/db/database/hive_pastorder.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../widget/componets/restaurant/componets/drawer.dart';
import '../start order/cart/cart.dart';
import '../tabbar/WeightItemDialog.dart';
import '../tabbar/item_options_dialog.dart';
import '../tabbar/orderdetails.dart';


// ═══════════════════════════════════════════════════════════════════════════
// APP COLORS
// ═══════════════════════════════════════════════════════════════════════════
class AppColors {
  static const Color primary = Color(0xFF0D47A1);
  static const Color secondary = Color(0xFF00695C);
  static const Color accent = Color(0xFFF57F17);
  static const Color danger = Color(0xFFC62828);
  static const Color success = Color(0xFF2E7D32);
  static const Color orange = Color(0xFFD84315);
  static const Color info = Color(0xFF1976D2);
  static const Color warning = Color(0xFFF9A825);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkNeutral = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceMedium = Color(0xFFEEF2F6);
  static const Color cardShadow = Color(0x1A0D47A1);
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color menuTab = Color(0xFF0D47A1);
  static const Color ordersTab = Color(0xFFD84315);
  static const Color tablesTab = Color(0xFF00695C);
}

enum StockStatus { inStock, orderAvailable, outOfStock, notTracked }

// ═══════════════════════════════════════════════════════════════════════════
// MAIN POS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class POSMainScreen extends StatefulWidget {
  final String? tableIdForNewOrder;
  final OrderModel? existingOrder;
  final bool isForAddingItem;
  final bool? isFromCart;

  const POSMainScreen({
    super.key,
    this.tableIdForNewOrder,
    this.existingOrder,
    this.isForAddingItem = false,
    this.isFromCart = false,
  });

  @override
  State<POSMainScreen> createState() => _POSMainScreenState();
}

class _POSMainScreenState extends State<POSMainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool isCartShow = false;
  double totalPrice = 0.0;
  int totalItems = 0;
  List<CartItem> cartItemsList = [];

  final List<_TabConfig> _tabs = [
    _TabConfig(label: 'Menu', icon: Icons.restaurant_menu_outlined, activeIcon: Icons.restaurant_menu_rounded, color: AppColors.menuTab),
    _TabConfig(label: 'Orders', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, color: AppColors.ordersTab),
    _TabConfig(label: 'Tables', icon: Icons.table_restaurant_outlined, activeIcon: Icons.table_restaurant_rounded, color: AppColors.tablesTab),
  ];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCartItems();
    if (widget.tableIdForNewOrder != null) {
      _storeSelectedTable(widget.tableIdForNewOrder!);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() => _currentTabIndex = _tabController.index);
    HapticFeedback.selectionClick();
  }

  void _storeSelectedTable(String tableId) async {
    final appBox = Hive.box('app_state');
    await appBox.put('selected_table_for_new_order', tableId);
  }

  Future<void> _loadCartItems() async {
    try {
      final items = await HiveCart.getAllCartItems();
      setState(() {
        cartItemsList = items;
        totalPrice = items.fold(0.0, (sum, item) => sum + item.totalPrice);
        totalItems = items.fold(0, (sum, item) => sum + item.quantity);
        isCartShow = items.isNotEmpty;
      });
    } catch (e) {
      print('Error loading cart items: $e');
    }
  }

  Color get _currentTabColor => _tabs[_currentTabIndex].color;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.white,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.surfaceLight,
        body: Column(
          children: [
            _buildHeader(size, isTablet),
            if (isTablet) _buildTabletTabBar(),
            Expanded(
              child: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _MenuTabContent(
                        tableIdForNewOrder: widget.tableIdForNewOrder,
                        existingOrder: widget.existingOrder,
                        isForAddingItem: widget.isForAddingItem,
                        onCartUpdated: _loadCartItems,
                        isCartShow: isCartShow,
                      ),
                      _OrdersTabContent(),
                      _TablesTabContent(
                        isFromCart: widget.isFromCart ?? false,
                        onTableSelected: (tableId) => _tabController.animateTo(0),
                      ),
                    ],
                  ),
                  if (isCartShow && _currentTabIndex == 0)
                    Positioned(bottom: 0, left: 0, right: 0, child: _buildCartBar()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: isTablet ? null : _buildBottomNav(bottomPadding),
        drawer: Drawerr(),
      ),
    );
  }

  Widget _buildHeader(Size size, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: _currentTabColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              _buildAnimatedLogo(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UniPOS', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(_getSubtitle(), key: ValueKey(_currentTabIndex), style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: _currentTabColor)),
                    ),
                  ],
                ),
              ),
              _buildHeaderActions(),
            ],
          ),
        ),
      ),
    );
  }

  String _getSubtitle() {
    switch (_currentTabIndex) {
      case 0: return widget.tableIdForNewOrder != null ? 'Table ${widget.tableIdForNewOrder}' : 'Quick Order';
      case 1: return 'Order Management';
      case 2: return 'Table Layout';
      default: return '';
    }
  }

  Widget _buildAnimatedLogo() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_currentTabColor, _currentTabColor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _currentTabColor.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(_tabs[_currentTabIndex].activeIcon, key: ValueKey(_currentTabIndex), color: AppColors.white, size: 26),
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      children: [
        if (_currentTabIndex == 0 && isCartShow) _CartBadgeButton(count: totalItems, onTap: _navigateToCart),
        const SizedBox(width: 8),
        _HeaderActionButton(icon: Icons.sync_rounded, onTap: () { HapticFeedback.lightImpact(); _loadCartItems(); }),
        SizedBox(width: 16),
        _HeaderActionButton(
          icon: Icons.menu,
          onTap: () {
            print("button is getting pessed ---------> ");
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ],
    );
  }

  void _navigateToCart() async {
    HapticFeedback.mediumImpact();
    if (widget.isForAddingItem == true) {
      Navigator.pop(context);
    } else {
      final appBox = Hive.box('app_state');
      await Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(selectedTableNo: widget.tableIdForNewOrder)));
      appBox.delete('selected_table_for_new_order');
      await _loadCartItems();
    }
  }

  Widget _buildTabletTabBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        indicatorColor: _currentTabColor,
        labelColor: _currentTabColor,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
        tabs: _tabs.map((tab) => Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(tab.activeIcon, size: 20), const SizedBox(width: 8), Text(tab.label)]))).toList(),
      ),
    );
  }

  Widget _buildCartBar() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) => Transform.translate(offset: Offset(0, 80 * (1 - value)), child: Opacity(opacity: value, child: child)),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withBlue(180)]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.shopping_bag_rounded, color: AppColors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$totalItems items', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.white.withOpacity(0.8))),
                  Text('₹${totalPrice.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.white)),
                ],
              ),
            ),
            GestureDetector(
              onTap: _navigateToCart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Text('View Cart', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(double bottomPadding) {
    return Container(
      decoration: BoxDecoration(color: AppColors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final isSelected = _currentTabIndex == index;
              return _BottomNavItem(icon: isSelected ? tab.activeIcon : tab.icon, label: tab.label, color: tab.color, isSelected: isSelected, onTap: () => _tabController.animateTo(index));
            }),
          ),
        ),
      ),
    );
  }
}

class _TabConfig {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color color;
  _TabConfig({required this.label, required this.icon, required this.activeIcon, required this.color});
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: AppColors.surfaceMedium, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
    );
  }
}

class _CartBadgeButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CartBadgeButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(30)),
        child: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded, color: AppColors.white, size: 20),
            const SizedBox(width: 8),
            Text('$count', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white)),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _BottomNavItem({required this.icon, required this.label, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 16, vertical: 12),
        decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: isSelected ? 26 : 24),
            if (isSelected) ...[const SizedBox(width: 10), Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: color))],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MENU TAB CONTENT
// ═══════════════════════════════════════════════════════════════════════════
class _MenuTabContent extends StatefulWidget {
  final String? tableIdForNewOrder;
  final OrderModel? existingOrder;
  final bool isForAddingItem;
  final VoidCallback onCartUpdated;
  final bool isCartShow;

  const _MenuTabContent({this.tableIdForNewOrder, this.existingOrder, this.isForAddingItem = false, required this.onCartUpdated, required this.isCartShow});

  @override
  State<_MenuTabContent> createState() => _MenuTabContentState();
}

class _MenuTabContentState extends State<_MenuTabContent> {
  Set<String> expandedCategories = {};
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleItemTap(Items item) async {
    HapticFeedback.lightImpact();

    if (item.isSoldByWeight) {
      final CartItem? weightCartItem = await showWeightItemDialog(context, item);
      if (weightCartItem != null) await _addItemToCart(weightCartItem);
      return;
    }

    String? categoryName;
    try {
      final categoryBox = Hive.box<Category>('categories');
      final category = categoryBox.values.firstWhere((cat) => cat.id == item.categoryOfItem);
      categoryName = category.name;
    } catch (e) {
      categoryName = 'Uncategorized';
    }

    if (item.variant != null && item.variant!.isNotEmpty) {
      final result = await showModalBottomSheet<CartItem>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: DraggableScrollableSheet(
            expand: false, initialChildSize: 0.45, minChildSize: 0.3, maxChildSize: 0.7,
            builder: (_, controller) => Column(
              children: [
                Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
                Expanded(child: SingleChildScrollView(controller: controller, child: ItemOptionsDialog(item: item, categoryName: categoryName))),
              ],
            ),
          ),
        ),
      );
      if (result != null) await _addItemToCart(result);
    } else {
      final simpleCartItem = CartItem(
        productId: item.id, isStockManaged: item.trackInventory, id: const Uuid().v4(),
        title: item.name, imagePath: item.imageBytes , price: item.price ?? 0,
        quantity: 1, taxRate: item.taxRate, weightDisplay: null, categoryName: categoryName,
      );
      await _addItemToCart(simpleCartItem);
    }
  }

  Future<void> _addItemToCart(CartItem cartItem) async {
    try {
      final result = await HiveCart.addToCart(cartItem);
      if (result['success'] == true) {
        widget.onCartUpdated();
        if (mounted) NotificationService.instance.showSuccess('${cartItem.title} added to cart');
      } else {
        if (mounted) NotificationService.instance.showError(result['message'] ?? 'Cannot add item to cart');
      }
    } catch (e) {
      if (mounted) NotificationService.instance.showError('Error adding item to cart');
    }
  }

  String _formatStockDisplay(Items item) {
    if (!item.trackInventory) return '';
    final stock = item.stockQuantity;
    final unit = item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');
    if (stock <= 0) return item.allowOrderWhenOutOfStock ? 'Order Available' : 'Out of Stock';
    if (item.isSoldByWeight) {
      if (unit.toUpperCase().contains('KG')) {
        if (stock >= 1000) return '${(stock / 1000).toStringAsFixed(1)}KG';
        return '${stock.toStringAsFixed(0)}GM';
      }
      return '${stock.toStringAsFixed(2)}$unit';
    }
    return '${stock.toStringAsFixed(0)} $unit';
  }

  StockStatus _getStockStatus(Items item) {
    if (!item.trackInventory) return StockStatus.notTracked;
    if (item.stockQuantity <= 0) return item.allowOrderWhenOutOfStock ? StockStatus.orderAvailable : StockStatus.outOfStock;
    return StockStatus.inStock;
  }

  void _scrollToCategory(String categoryId) {
    final key = _categoryKeys[categoryId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 2))]),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => query = value),
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search menu items...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    suffixIcon: query.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded), color: AppColors.textSecondary, onPressed: () { _searchController.clear(); setState(() => query = ''); FocusScope.of(context).unfocus(); }) : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ),
            Expanded(child: isTablet ? _buildTabletLayout(size) : _buildMobileLayout()),
          ],
        ),
        if (!isTablet)
          Positioned(
            bottom: widget.isCartShow ? 100 : 24,
            right: 20,
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Category>('categories').listenable(),
              builder: (context, categoryBox, _) {
                final categories = categoryBox.values.toList();
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    showModalBottomSheet(
                      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
                      builder: (context) => _CategoryNavigator(categories: categories, onCategoryTap: _scrollToCategory),
                    );
                  },
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.secondary, AppColors.secondary.withGreen(120)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.category_rounded, color: AppColors.white, size: 28),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Category>('categories').listenable(),
      builder: (context, categoryBox, _) {
        final categories = categoryBox.values.toList();
        if (categories.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)), const SizedBox(height: 16), Text('No categories found', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary))]));

        return ValueListenableBuilder(
          valueListenable: Hive.box<Items>('itemBoxs').listenable(),
          builder: (context, itemBox, _) {
            final allItems = itemBox.values.where((item) => item.isEnabled).toList();
            final filteredItems = query.isEmpty ? allItems : allItems.where((item) => item.name.toLowerCase().contains(query.toLowerCase())).toList();

            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(top: 4, bottom: widget.isCartShow ? 120 : 80, left: 16, right: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryItems = filteredItems.where((item) => item.categoryOfItem == category.id).toList();
                if (categoryItems.isEmpty && query.isNotEmpty) return const SizedBox.shrink();
                _categoryKeys[category.id] = GlobalKey();

                return _CollapsibleCategorySection(
                  key: _categoryKeys[category.id],
                  category: category, items: categoryItems,
                  isExpanded: expandedCategories.contains(category.id) || query.isNotEmpty,
                  onToggle: () => setState(() { if (expandedCategories.contains(category.id)) expandedCategories.remove(category.id); else expandedCategories.add(category.id); }),
                  onItemTap: _handleItemTap, formatStock: _formatStockDisplay, getStockStatus: _getStockStatus,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTabletLayout(Size size) {
    String? selectedCategory;
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Row(
          children: [
            Container(
              width: 200,
              decoration: BoxDecoration(color: AppColors.white, border: Border(right: BorderSide(color: AppColors.divider))),
              child: ValueListenableBuilder(
                valueListenable: Hive.box<Category>('categories').listenable(),
                builder: (context, categoryBox, _) {
                  final categories = categoryBox.values.toList();
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildCategorySidebarItem('All Items', Icons.grid_view_rounded, selectedCategory == null, () => setLocalState(() => selectedCategory = null));
                      final category = categories[index - 1];
                      return _buildCategorySidebarItem(category.name, Icons.folder_rounded, selectedCategory == category.id, () => setLocalState(() => selectedCategory = category.id));
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box<Items>('itemBoxs').listenable(),
                builder: (context, itemBox, _) {
                  var items = itemBox.values.where((item) => item.isEnabled).toList();
                  if (selectedCategory != null) items = items.where((item) => item.categoryOfItem == selectedCategory).toList();
                  if (query.isNotEmpty) items = items.where((item) => item.name.toLowerCase().contains(query.toLowerCase())).toList();
                  if (items.isEmpty) return Center(child: Text('No items found', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppColors.textSecondary)));

                  return GridView.builder(
                    padding: EdgeInsets.only(top: 16, bottom: widget.isCartShow ? 120 : 24, left: 16, right: 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: size.width > 900 ? 4 : 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _ItemCard(item: items[index], onTap: () => _handleItemTap(items[index]), formatStock: _formatStockDisplay, getStockStatus: _getStockStatus),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySidebarItem(String name, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.white : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? AppColors.white : AppColors.textPrimary))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ORDERS TAB CONTENT
// ═══════════════════════════════════════════════════════════════════════════
class _OrdersTabContent extends StatefulWidget {
  @override
  State<_OrdersTabContent> createState() => _OrdersTabContentState();
}

class _OrdersTabContentState extends State<_OrdersTabContent> {
  String selectedFilter = "Active Order";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: _FilterChip(label: 'Active Orders', icon: Icons.pending_actions_rounded, isSelected: selectedFilter == "Active Order", color: AppColors.orange, onTap: () => setState(() => selectedFilter = "Active Order"))),
              const SizedBox(width: 12),
              Expanded(child: _FilterChip(label: 'Past Orders', icon: Icons.history_rounded, isSelected: selectedFilter == "Past Order", color: AppColors.secondary, onTap: () => setState(() => selectedFilter = "Past Order"))),
            ],
          ),
        ),
        Expanded(child: selectedFilter == "Active Order" ? _ActiveOrdersContent() : _PastOrdersContent()),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : AppColors.divider, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? AppColors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrdersContent extends StatefulWidget {
  @override
  State<_ActiveOrdersContent> createState() => _ActiveOrdersContentState();
}

class _ActiveOrdersContentState extends State<_ActiveOrdersContent> {
  Box<OrderModel>? _ordersBox;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openBox();
  }

  Future<void> _openBox() async {
    try {
      if (Hive.isBoxOpen('ordersBox')) {
        _ordersBox = Hive.box<OrderModel>('ordersBox');
      } else {
        _ordersBox = await Hive.openBox<OrderModel>('ordersBox');
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.orange));
    }

    if (_error != null || _ordersBox == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)), const SizedBox(height: 16), Text('No active orders', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary))]));
    }

    return ValueListenableBuilder(
      valueListenable: _ordersBox!.listenable(),
      builder: (context, ordersBox, _) {
        final orders = ordersBox.values.toList();
        if (orders.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)), const SizedBox(height: 16), Text('No active orders', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary))]));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: orders.length,
          itemBuilder: (context, index) => _ActiveOrderCard(order: orders[index]),
        );
      },
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  const _ActiveOrderCard({required this.order});

  Color get _statusColor {
    switch (order.status?.toLowerCase()) {
      case 'cooking': return AppColors.orange;
      case 'ready': return AppColors.success;
      case 'served': return AppColors.secondary;
      default: return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(existingOrder: order, selectedTableNo: order.tableNo)));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.receipt_long_rounded, color: _statusColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.tableNo != null ? 'Table ${order.tableNo}' : 'Order #${order.id.substring(0, 8)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('${order.items?.length ?? 0} items • ${order.orderType ?? 'Dine In'}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${(order.totalPrice ?? 0).toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(order.status ?? 'Pending', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (order.timeStamp != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(_formatTime(order.timeStamp!), style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return DateFormat('hh:mm a').format(dateTime);
  }
}

class _PastOrdersContent extends StatefulWidget {
  @override
  State<_PastOrdersContent> createState() => _PastOrdersContentState();
}

class _PastOrdersContentState extends State<_PastOrdersContent> {
  Box<pastOrderModel>? _pastOrdersBox;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openBox();
  }

  Future<void> _openBox() async {
    try {
      if (Hive.isBoxOpen('pastOrdersBox')) {
        _pastOrdersBox = Hive.box<pastOrderModel>('pastOrdersBox');
      } else {
        _pastOrdersBox = await Hive.openBox<pastOrderModel>('pastOrdersBox');
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
    }

    if (_error != null || _pastOrdersBox == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.5)), const SizedBox(height: 16), Text('No past orders', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary))]));
    }

    return ValueListenableBuilder(
      valueListenable: _pastOrdersBox!.listenable(),
      builder: (context, pastOrdersBox, _) {
        final orders = pastOrdersBox.values.toList();
        orders.sort((a, b) => (b.orderAt ?? DateTime.now()).compareTo(a.orderAt ?? DateTime.now()));
        if (orders.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.5)), const SizedBox(height: 16), Text('No past orders', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary))]));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: orders.length,
          itemBuilder: (context, index) => _PastOrderCard(order: orders[index]),
        );
      },
    );
  }
}

class _PastOrderCard extends StatelessWidget {
  final pastOrderModel order;
  const _PastOrderCard({required this.order});

  Color get _statusColor {
    final status = order.orderStatus?.toLowerCase() ?? '';
    if (status.contains('refund')) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (context) => Orderdetails(Order: order)));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.check_circle_rounded, color: _statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName?.isNotEmpty == true ? order.customerName! : 'Order #${order.id.substring(0, 8)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('${order.items?.length ?? 0} items • ${order.orderType ?? 'Take Away'}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                      if (order.orderAt != null) Text(DateFormat('dd MMM, hh:mm a').format(order.orderAt!), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${(order.totalPrice ?? 0).toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(order.paymentmode ?? 'Cash', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor)),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TABLES TAB CONTENT
// ═══════════════════════════════════════════════════════════════════════════
class _TablesTabContent extends StatefulWidget {
  final bool isFromCart;
  final Function(String) onTableSelected;
  const _TablesTabContent({required this.isFromCart, required this.onTableSelected});

  @override
  State<_TablesTabContent> createState() => _TablesTabContentState();
}

class _TablesTabContentState extends State<_TablesTabContent> {
  Box<TableModel>? _tablesBox;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openBox();
  }

  Future<void> _openBox() async {
    try {
      if (Hive.isBoxOpen('tablesBox')) {
        _tablesBox = Hive.box<TableModel>('tablesBox');
      } else {
        _tablesBox = await Hive.openBox<TableModel>('tablesBox');
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _addTable,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.secondary, AppColors.secondary.withGreen(120)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded, color: AppColors.white, size: 22),
                        const SizedBox(width: 8),
                        Text('Add Table', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(AppColors.success, 'Available'),
              _buildLegendItem(AppColors.warning, 'Reserved'),
              _buildLegendItem(AppColors.danger, 'Occupied'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildTablesGrid()),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildTablesGrid() {
    if (_error != null || _tablesBox == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.table_restaurant_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)), const SizedBox(height: 16), Text('No tables found.\nAdd one to get started.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary))]));
    }

    return ValueListenableBuilder(
      valueListenable: _tablesBox!.listenable(),
      builder: (context, tableBox, _) {
        if (tableBox.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.table_restaurant_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)), const SizedBox(height: 16), Text('No tables found.\nAdd one to get started.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary))]));

        final allTables = tableBox.values.toList();
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.1),
          itemCount: allTables.length,
          itemBuilder: (context, index) => _BeautifulTableCard(table: allTables[index], onTap: () => _onTableTapped(allTables[index])),
        );
      },
    );
  }

  void _addTable() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add New Table', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: 'Enter Table Name (e.g., T-4)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.plusJakartaSans())),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newTable = TableModel(id: controller.text.trim());
                await HiveTables.addTable(newTable);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Add', style: GoogleFonts.plusJakartaSans(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _onTableTapped(TableModel table) async {
    HapticFeedback.mediumImpact();
    if (table.status == 'Cooking' || table.status == 'Reserved' || table.status == 'Running') {
      final existingOrder = await HiveOrders.getActiveOrderByTableId(table.id);
      if (existingOrder != null) {
        final appStateBox = Hive.box('app_state');
        await appStateBox.put('is_existing_order', true);
        await appStateBox.put('table_id', existingOrder.tableNo);
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(existingOrder: existingOrder, selectedTableNo: table.id)));
      } else {
        NotificationService.instance.showError('Could not find an active order for Table ${table.id}.');
      }
    } else {
      if (widget.isFromCart) {
        Navigator.pop(context, table.id);
      } else {
        widget.onTableSelected(table.id);
      }
    }
  }
}

class _BeautifulTableCard extends StatefulWidget {
  final TableModel table;
  final VoidCallback onTap;
  const _BeautifulTableCard({required this.table, required this.onTap});

  @override
  State<_BeautifulTableCard> createState() => _BeautifulTableCardState();
}

class _BeautifulTableCardState extends State<_BeautifulTableCard> {
  bool _isPressed = false;

  Color get _statusColor {
    switch (widget.table.status) {
      case 'Cooking': case 'Running': return AppColors.danger;
      case 'Reserved': return AppColors.warning;
      default: return AppColors.success;
    }
  }

  String _formatOrderTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      final difference = DateTime.now().difference(dateTime);
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.table.status == 'Available' || widget.table.status == null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _statusColor, width: 2.5),
          boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _statusColor.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(Icons.table_restaurant_rounded, color: _statusColor, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.table.id, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  if (!isAvailable) ...[
                    const SizedBox(height: 6),
                    Text('₹${widget.table.currentOrderTotal?.toStringAsFixed(0) ?? '0'}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (widget.table.timeStamp != null && widget.table.timeStamp!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(_formatOrderTime(widget.table.timeStamp), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: -10, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor, width: 2),
                  boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text(widget.table.status ?? 'Available', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
              ),
            ),
          ],
        ),
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

  const _CollapsibleCategorySection({super.key, required this.category, required this.items, required this.isExpanded, required this.onToggle, required this.onItemTap, required this.formatStock, required this.getStockStatus});

  @override
  State<_CollapsibleCategorySection> createState() => _CollapsibleCategorySectionState();
}

class _CollapsibleCategorySectionState extends State<_CollapsibleCategorySection> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _expandAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(_expandAnimation);
    if (widget.isExpanded) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_CollapsibleCategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) widget.isExpanded ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); widget.onToggle(); },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: widget.isExpanded ? AppColors.primary.withOpacity(0.05) : AppColors.white, borderRadius: widget.isExpanded ? const BorderRadius.vertical(top: Radius.circular(18)) : BorderRadius.circular(18)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                    child: const Icon(Icons.category_rounded, size: 22, color: AppColors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.category.name, style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${widget.items.length} items', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _rotateAnimation,
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceMedium, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 22)),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: widget.items.isEmpty
                ? Padding(padding: const EdgeInsets.all(20), child: Text('No items in this category', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary)))
                : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _ItemListTile(item: widget.items[index], onTap: () => widget.onItemTap(widget.items[index]), formatStock: widget.formatStock, getStockStatus: widget.getStockStatus),
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
          color: _isPressed ? AppColors.primary.withOpacity(0.08) : isDisabled ? AppColors.surfaceMedium.withOpacity(0.5) : AppColors.surfaceLight,
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
                  Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: isDisabled ? AppColors.textSecondary : AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(_getPriceDisplay(), style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      if (widget.item.trackInventory) ...[const SizedBox(width: 10), _buildStockBadge(stockStatus)],
                    ],
                  ),
                ],
              ),
            ),
            if (!isDisabled)
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withBlue(180)]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]),
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
    if (widget.item.price != null) return '₹${widget.item.price!.toStringAsFixed(2)}';
    if (widget.item.variant != null && widget.item.variant!.isNotEmpty) return '₹${widget.item.variant!.first.price.toStringAsFixed(2)}+';
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
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ITEM CARD (Tablet)
// ═══════════════════════════════════════════════════════════════════════════
class _ItemCard extends StatefulWidget {
  final Items item;
  final VoidCallback onTap;
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;
  const _ItemCard({required this.item, required this.onTap, required this.formatStock, required this.getStockStatus});

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
      onTapUp: isDisabled ? null : (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        decoration: BoxDecoration(color: isDisabled ? AppColors.surfaceMedium : AppColors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: _isPressed ? AppColors.primary.withOpacity(0.2) : AppColors.cardShadow, blurRadius: _isPressed ? 16 : 10, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: AppColors.surfaceMedium, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
                child: Stack(children: [Center(child: _buildItemImage()), if (widget.item.trackInventory) Positioned(top: 8, right: 8, child: _buildStockBadge(stockStatus))]),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDisabled ? AppColors.textSecondary : AppColors.textPrimary)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_getPriceDisplay(), style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        if (!isDisabled) Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_rounded, color: AppColors.white, size: 18)),
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
      final file = widget.item.imageBytes;
      if (file!="") return ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: Image.memory(file!, fit: BoxFit.cover, width: double.infinity, height: double.infinity));
    }
    return Icon(Icons.fastfood_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.5));
  }

  String _getPriceDisplay() {
    if (widget.item.price != null) return '₹${widget.item.price!.toStringAsFixed(2)}';
    if (widget.item.variant != null && widget.item.variant!.isNotEmpty) return '₹${widget.item.variant!.first.price.toStringAsFixed(2)}+';
    return 'N/A';
  }

  Widget _buildStockBadge(StockStatus status) {
    Color bgColor, textColor; IconData icon;
    switch (status) {
      case StockStatus.inStock: bgColor = AppColors.success; textColor = AppColors.white; icon = Icons.check_circle_rounded; break;
      case StockStatus.orderAvailable: bgColor = AppColors.warning; textColor = AppColors.white; icon = Icons.access_time_rounded; break;
      case StockStatus.outOfStock: bgColor = AppColors.danger; textColor = AppColors.white; icon = Icons.remove_circle_rounded; break;
      case StockStatus.notTracked: return const SizedBox.shrink();
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: textColor), const SizedBox(width: 4), Text(widget.formatStock(widget.item), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: textColor))]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CATEGORY NAVIGATOR
// ═══════════════════════════════════════════════════════════════════════════
class _CategoryNavigator extends StatelessWidget {
  final List<Category> categories;
  final Function(String) onCategoryTap;
  const _CategoryNavigator({required this.categories, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.category_rounded, color: AppColors.secondary, size: 22)),
                const SizedBox(width: 14),
                Text('Jump to Category', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); onCategoryTap(category.id); },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]), borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(category.name.isNotEmpty ? category.name[0].toUpperCase() : '?', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(category.name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
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