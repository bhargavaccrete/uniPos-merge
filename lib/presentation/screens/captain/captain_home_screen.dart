import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';
import 'captain_login_screen.dart';

class CaptainHomeScreen extends StatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  State<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends State<CaptainHomeScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _loadError;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _variants = []; // variantStore models: {id, name}
  List<Map<String, dynamic>> _choices = [];
  List<Map<String, dynamic>> _extras = [];
  List<Map<String, dynamic>> _tables = [];

  String? _selectedCategoryId;
  Map<String, dynamic>? _selectedTable;

  final List<CartItem> _cart = [];

  String _staffName = '';
  String _posIp = '';

  // ── Orders tab ─────────────────────────────────────────────────────────────
  int _currentTab = 0; // 0=New Order, 1=Active Orders
  List<Map<String, dynamic>> _activeOrders = [];
  bool _isLoadingOrders = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _posIp = prefs.getString('captain_pos_ip') ?? '';
    _staffName = prefs.getString('captain_staff_name') ?? 'Waiter';
    await _loadMenuAndTables();
  }

  Future<void> _loadMenuAndTables() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final menuRes = await http.get(
        Uri.parse('http://$_posIp:9090/captain/menu'),
      ).timeout(const Duration(seconds: 10));

      final tablesRes = await http.get(
        Uri.parse('http://$_posIp:9090/captain/tables'),
      ).timeout(const Duration(seconds: 10));

      if (menuRes.statusCode == 200 && tablesRes.statusCode == 200) {
        final menu = jsonDecode(menuRes.body) as Map<String, dynamic>;
        setState(() {
          _categories = List<Map<String, dynamic>>.from(menu['categories'] ?? []);
          _items = List<Map<String, dynamic>>.from(menu['items'] ?? []);
          _variants = List<Map<String, dynamic>>.from(menu['variants'] ?? []);
          _choices = List<Map<String, dynamic>>.from(menu['choices'] ?? []);
          _extras = List<Map<String, dynamic>>.from(menu['extras'] ?? []);
          _tables = List<Map<String, dynamic>>.from(jsonDecode(tablesRes.body) as List);
          _selectedCategoryId = _categories.isNotEmpty ? _categories.first['id'] as String? : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _loadError = 'Failed to load menu from POS.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadError = 'Cannot reach POS. Check WiFi connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActiveOrders() async {
    if (_isLoadingOrders) return;
    setState(() => _isLoadingOrders = true);
    try {
      final res = await http.get(
        Uri.parse('http://$_posIp:9090/captain/active-orders'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() {
          _activeOrders = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      final res = await http.put(
        Uri.parse('http://$_posIp:9090/captain/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        _showSuccessSnack('Order marked as $status');
        await _loadActiveOrders();
        await _loadMenuAndTables(); // refresh table states
      } else {
        _showErrorSnack('Failed: ${data['error']}');
      }
    } catch (_) {
      _showErrorSnack('Cannot reach POS. Check WiFi.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredItems => _selectedCategoryId == null
      ? _items.where((i) => i['isEnabled'] != false).toList()
      : _items.where((i) =>
          i['isEnabled'] != false &&
          i['categoryOfItem'] == _selectedCategoryId).toList();

  int _cartQuantityFor(String productId) {
    return _cart.where((c) => c.productId == productId).fold(0, (sum, c) => sum + c.quantity);
  }

  double get _cartTotal => _cart.fold(0.0, (sum, c) => sum + c.totalPrice);
  int get _cartCount => _cart.fold(0, (sum, c) => sum + c.quantity);

  bool _itemHasCustomization(Map<String, dynamic> item) {
    final variants = item['variant'] as List?;
    final choiceIds = item['choiceIds'] as List?;
    final extraIds = item['extraId'] as List?;
    return (variants?.isNotEmpty ?? false) ||
           (choiceIds?.isNotEmpty ?? false) ||
           (extraIds?.isNotEmpty ?? false);
  }

  // ── Cart Operations ────────────────────────────────────────────────────────

  void _addSimpleItem(Map<String, dynamic> item) {
    final existing = _cart.cast<CartItem?>().firstWhere(
      (c) => c!.productId == item['id'] && c.variantName == null,
      orElse: () => null,
    );

    setState(() {
      if (existing != null) {
        final idx = _cart.indexOf(existing);
        _cart[idx] = existing.copyWith(quantity: existing.quantity + 1);
      } else {
        _cart.add(CartItem(
          id: '${item['id']}_${DateTime.now().millisecondsSinceEpoch}',
          productId: item['id'] as String,
          title: item['name'] as String,
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          isStockManaged: item['trackInventory'] as bool? ?? false,
          taxRate: (item['taxRate'] as num?)?.toDouble(),
          categoryName: _categories
              .cast<Map<String, dynamic>?>()
              .firstWhere((c) => c!['id'] == item['categoryOfItem'], orElse: () => null)
              ?['name'] as String?,
        ));
      }
    });
  }

  void _removeOneFromCart(String productId) {
    final existing = _cart.cast<CartItem?>().firstWhere(
      (c) => c!.productId == productId && c.variantName == null,
      orElse: () => null,
    );
    if (existing == null) return;
    setState(() {
      if (existing.quantity > 1) {
        final idx = _cart.indexOf(existing);
        _cart[idx] = existing.copyWith(quantity: existing.quantity - 1);
      } else {
        _cart.remove(existing);
      }
    });
  }

  void _removeCartItem(CartItem item) {
    setState(() => _cart.remove(item));
  }

  // ── Item tap ───────────────────────────────────────────────────────────────

  void _onItemTapped(Map<String, dynamic> item) {
    if (_itemHasCustomization(item)) {
      _showItemCustomizationSheet(item);
    } else {
      _addSimpleItem(item);
    }
  }

  // ── Customization sheet ────────────────────────────────────────────────────

  void _showItemCustomizationSheet(Map<String, dynamic> item) {
    // Resolve choice and extra objects from IDs
    final choiceIds = List<String>.from(item['choiceIds'] ?? []);
    final extraIds = List<String>.from(item['extraId'] ?? []);

    final itemChoices = _choices
        .where((c) => choiceIds.contains(c['id']))
        .toList();
    final itemExtras = _extras
        .where((e) => extraIds.contains(e['Id']))
        .toList();

    // item['variant'] = [{variantId, price, stockQuantity, trackInventory}]
    // Resolve display name from _variants store (which has {id, name})
    final itemVariants = (item['variant'] as List? ?? []).map((v) {
      final vMap = Map<String, dynamic>.from(v as Map);
      final storeEntry = _variants.cast<Map<String, dynamic>?>().firstWhere(
        (s) => s!['id'] == vMap['variantId'],
        orElse: () => null,
      );
      return <String, dynamic>{
        'id': vMap['variantId'],
        'name': storeEntry?['name'] ?? vMap['variantId'],
        'price': vMap['price'],
        'stockQuantity': (vMap['stockQuantity'] as num?)?.toDouble() ?? 0.0,
        'trackInventory': vMap['trackInventory'] as bool? ?? false,
      };
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ItemCustomizationSheet(
        item: item,
        variants: itemVariants,
        choices: itemChoices,
        extras: itemExtras,
        onAddToCart: (variant, choiceNames, extras, instruction) {
          _addCustomizedItem(
            item,
            variant: variant,
            choiceNames: choiceNames,
            extras: extras,
            instruction: instruction,
          );
        },
      ),
    );
  }

  void _addCustomizedItem(
    Map<String, dynamic> item, {
    Map<String, dynamic>? variant,
    List<String> choiceNames = const [],
    List<Map<String, dynamic>> extras = const [],
    String? instruction,
  }) {
    // When variant selected: variant price IS the item price (not additive to base)
    // This matches start order ItemOptionsDialog._recalculateTotal() behaviour
    final variantPrice = (variant?['price'] as num?)?.toDouble();
    final baseItemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
    final extrasTotal = extras.fold(0.0, (sum, e) =>
        sum + ((e['price'] as num?)?.toDouble() ?? 0.0) * ((e['quantity'] as int?) ?? 1));
    final totalPrice = (variantPrice ?? baseItemPrice) + extrasTotal;

    final categoryName = _categories
        .cast<Map<String, dynamic>?>()
        .firstWhere((c) => c!['id'] == item['categoryOfItem'], orElse: () => null)
        ?['name'] as String?;

    setState(() {
      _cart.add(CartItem(
        id: '${item['id']}_${DateTime.now().millisecondsSinceEpoch}',
        productId: item['id'] as String,
        title: item['name'] as String,
        price: totalPrice,
        isStockManaged: item['trackInventory'] as bool? ?? false,
        variantName: variant?['name'] as String?,
        variantPrice: variantPrice,
        choiceNames: choiceNames.isEmpty ? null : choiceNames,
        extras: extras.isEmpty ? null : extras,
        instruction: instruction,
        taxRate: (item['taxRate'] as num?)?.toDouble(),
        categoryName: categoryName,
      ));
    });
  }

  // ── Send Order ─────────────────────────────────────────────────────────────

  bool get _tableHasActiveOrder =>
      _selectedTable != null &&
      (_selectedTable!['currentOrderId'] as String?)?.isNotEmpty == true;

  Future<void> _sendOrder() async {
    if (_cart.isEmpty) return;

    final confirmed = await _showSendConfirmDialog();
    if (!confirmed) return;

    try {
      _showLoadingDialog(_tableHasActiveOrder ? 'Adding to order...' : 'Sending order...');

      final response = await http.post(
        Uri.parse('http://$_posIp:9090/captain/send-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': _cart.map((c) => c.toMap()).toList(),
          'orderType': _selectedTable != null ? 'Dine In' : 'Take Away',
          'tableNo': _selectedTable?['id'],
          'totalPrice': _cartTotal,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      Navigator.pop(context); // close loading

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final addedToExisting = data['addedToExisting'] as bool? ?? false;
        setState(() {
          _cart.clear();
          _selectedTable = null;
        });
        await _loadMenuAndTables(); // refresh table statuses
        _showSuccessSnack(addedToExisting
            ? 'Items added — KOT #${data['kotNumber']} sent!'
            : 'Order #${data['kotNumber']} sent to kitchen!');
      } else {
        _showErrorSnack('Failed: ${data['error']}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnack('Cannot reach POS. Check WiFi.');
    }
  }

  Future<bool> _showSendConfirmDialog() async {
    final isAdding = _tableHasActiveOrder;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              isAdding ? 'Add to Existing Order?' : 'Send Order?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedTable != null) ...[
                  Text('Table: ${_selectedTable!['name'] ?? _selectedTable!['id']}',
                      style: GoogleFonts.poppins(fontSize: 14)),
                  if (isAdding)
                    Text('Adding to active order',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning)),
                ],
                const SizedBox(height: 4),
                Text('Items: $_cartCount', style: GoogleFonts.poppins(fontSize: 14)),
                Text('Total: ₹${_cartTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdding ? AppColors.warning : AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(isAdding ? 'Add Items' : 'Send',
                    style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message, style: GoogleFonts.poppins()),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Table picker ───────────────────────────────────────────────────────────

  void _showTablePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TablePickerSheet(
        tables: _tables,
        selected: _selectedTable,
        onSelect: (t) {
          setState(() => _selectedTable = t);
          Navigator.pop(context);
        },
        onClear: () {
          setState(() => _selectedTable = null);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Cart sheet ─────────────────────────────────────────────────────────────

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) => _CartSheet(
            cart: _cart,
            total: _cartTotal,
            selectedTable: _selectedTable,
            isAddingToOrder: _tableHasActiveOrder,
            onRemove: (item) {
              _removeCartItem(item);
              setSheetState(() {});
              setState(() {});
            },
            onTableTap: () {
              Navigator.pop(context);
              _showTablePicker();
            },
            onSend: () {
              Navigator.pop(context);
              _sendOrder();
            },
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('captain_logged_in', false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CaptainLoginScreen()),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool ready = !_isLoading && _loadError == null;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildError()
              : IndexedStack(
                  index: _currentTab,
                  children: [
                    _buildBody(),
                    _buildOrdersTab(),
                  ],
                ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ready && _currentTab == 0) _buildCartBar(),
          NavigationBar(
            selectedIndex: _currentTab,
            onDestinationSelected: (i) {
              setState(() => _currentTab = i);
              if (i == 1) _loadActiveOrders();
            },
            backgroundColor: Colors.white,
            indicatorColor: AppColors.accent.withOpacity(0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.restaurant_menu_outlined, color: AppColors.textSecondary),
                selectedIcon: Icon(Icons.restaurant_menu, color: AppColors.accent),
                label: 'New Order',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _activeOrders.isNotEmpty,
                  label: Text('${_activeOrders.length}'),
                  child: Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _activeOrders.isNotEmpty,
                  label: Text('${_activeOrders.length}'),
                  child: Icon(Icons.receipt_long, color: AppColors.accent),
                ),
                label: 'Orders',
              ),
            ],
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.accent,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Captain App',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          Text(_staffName,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        ],
      ),
      actions: [
        // Table selector
        TextButton.icon(
          onPressed: _showTablePicker,
          icon: Icon(Icons.table_restaurant, color: Colors.white, size: 18),
          label: Text(
            _selectedTable != null ? 'T: ${_selectedTable!['id']}' : 'Table',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          ),
        ),
        // Refresh
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadMenuAndTables,
          tooltip: 'Refresh menu',
        ),
        // Logout
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: AppColors.danger.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(_loadError!, style: GoogleFonts.poppins(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMenuAndTables,
            icon: const Icon(Icons.refresh),
            label: Text('Retry', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        // Category sidebar
        _buildCategorySidebar(),
        // Item grid
        Expanded(child: _buildItemGrid()),
      ],
    );
  }

  Widget _buildCategorySidebar() {
    return Container(
      width: AppResponsive.isMobile(context) ? 90 : 120,
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSelected = cat['id'] == _selectedCategoryId;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryId = cat['id'] as String?),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: AppColors.accent, width: 1.5)
                    : null,
              ),
              child: Text(
                cat['name'] as String? ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemGrid() {
    final items = _filteredItems;
    if (items.isEmpty) {
      return Center(
        child: Text('No items in this category',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
      );
    }

    final crossCount = AppResponsive.isMobile(context) ? 2 : 3;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ItemCard(
        item: items[i],
        quantityInCart: _cartQuantityFor(items[i]['id'] as String),
        onTap: () => _onItemTapped(items[i]),
        onRemove: () => _removeOneFromCart(items[i]['id'] as String),
      ),
    );
  }

  // ── Orders Tab ─────────────────────────────────────────────────────────────

  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Header row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('Active Orders',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              if (_isLoadingOrders)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadActiveOrders,
                  tooltip: 'Refresh',
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _activeOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 56,
                          color: AppColors.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No active orders',
                          style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _loadActiveOrders,
                        icon: const Icon(Icons.refresh),
                        label: Text('Refresh', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _activeOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildOrderCard(_activeOrders[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? '';
    final tableNo = order['tableNo'] as String? ?? 'Take Away';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final items = order['items'] as List? ?? [];
    final timeStamp = order['timeStamp'] as String?;
    final kotNumbers = order['kotNumbers'] as List? ?? [];

    // Time since order
    String timeAgo = '';
    if (timeStamp != null) {
      final dt = DateTime.tryParse(timeStamp);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
        else timeAgo = '${diff.inHours}h ${diff.inMinutes % 60}m ago';
      }
    }

    final statusColor = _orderStatusColor(status);

    return GestureDetector(
      onTap: () => _showOrderDetailSheet(order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_orderStatusIcon(status), color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Table $tableNo',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(status,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${items.length} item${items.length != 1 ? 's' : ''}'
                    '${kotNumbers.isNotEmpty ? '  •  KOT #${kotNumbers.last}' : ''}'
                    '${timeAgo.isNotEmpty ? '  •  $timeAgo' : ''}',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${total.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'Processing': return AppColors.info;
      case 'Cooking':    return AppColors.warning;
      case 'Ready':      return AppColors.success;
      case 'Running':    return AppColors.accent;
      case 'Served':     return Colors.purple;
      default:           return AppColors.textSecondary;
    }
  }

  IconData _orderStatusIcon(String status) {
    switch (status) {
      case 'Processing': return Icons.hourglass_top_rounded;
      case 'Cooking':    return Icons.local_fire_department;
      case 'Ready':      return Icons.check_circle_outline;
      case 'Running':    return Icons.directions_run;
      case 'Served':     return Icons.room_service_outlined;
      default:           return Icons.receipt_long;
    }
  }

  void _showOrderDetailSheet(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _OrderDetailSheet(
        order: order,
        onAddItems: () {
          Navigator.pop(context);
          // Pre-select this table then switch to New Order tab
          final tableNo = order['tableNo'] as String?;
          if (tableNo != null) {
            final tableMatch = _tables.cast<Map<String, dynamic>?>()
                .firstWhere((t) => t!['id'] == tableNo, orElse: () => null);
            if (tableMatch != null) setState(() => _selectedTable = tableMatch);
          }
          setState(() => _currentTab = 0);
        },
        onUpdateStatus: (status) {
          Navigator.pop(context);
          _updateOrderStatus(order['orderId'] as String, status);
        },
      ),
    );
  }

  Widget _buildCartBar() {
    if (_cart.isEmpty) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: _showCartSheet,
      child: Container(
        height: 64,
        color: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_cartCount',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'View Cart',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            Text(
              '₹${_cartTotal.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_up, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ── Item Card ──────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int quantityInCart;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ItemCard({
    required this.item,
    required this.quantityInCart,
    required this.onTap,
    required this.onRemove,
  });

  // ── Stock helpers (mirrors start_new.dart logic) ──────────────────────────

  _StockStatus _stockStatus() {
    final track = item['trackInventory'] as bool? ?? false;
    if (!track) return _StockStatus.notTracked;

    final variants = item['variant'] as List?;
    final allow = item['allowOrderWhenOutOfStock'] as bool? ?? true;

    if (variants != null && variants.isNotEmpty) {
      // Mirror POS logic: variant item is in stock if ANY variant has stock
      final hasAnyInStock = variants.any((v) {
        final vMap = v as Map;
        final vTrack = vMap['trackInventory'] as bool? ?? false;
        if (!vTrack) return true;
        return ((vMap['stockQuantity'] as num?)?.toDouble() ?? 0.0) > 0;
      });
      if (hasAnyInStock) return _StockStatus.inStock;
      return allow ? _StockStatus.orderAvailable : _StockStatus.outOfStock;
    }

    // No variants: check item-level stock
    final qty = (item['stockQuantity'] as num?)?.toDouble() ?? 0.0;
    if (qty > 0) return _StockStatus.inStock;
    return allow ? _StockStatus.orderAvailable : _StockStatus.outOfStock;
  }

  String _stockLabel(_StockStatus status) {
    final track = item['trackInventory'] as bool? ?? false;
    if (!track) return '';

    final variants = item['variant'] as List?;

    if (variants != null && variants.isNotEmpty) {
      if (status == _StockStatus.inStock) return 'In Stock';
      return status == _StockStatus.orderAvailable ? 'Order Available' : 'Out of Stock';
    }

    final qty = (item['stockQuantity'] as num?)?.toDouble() ?? 0.0;
    if (qty <= 0) return status == _StockStatus.orderAvailable ? 'Order Available' : 'Out of Stock';
    final unit = item['unit'] as String? ?? 'pcs';
    return '${qty.toStringAsFixed(0)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = item['imageBytes'];
    Uint8List? imageData;
    if (imageBytes is List && imageBytes.isNotEmpty) {
      imageData = Uint8List.fromList(List<int>.from(imageBytes));
    }

    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final hasVariants = (item['variant'] as List?)?.isNotEmpty ?? false;
    final isVeg = item['isVeg'] == 'veg';
    final stockStatus = _stockStatus();
    final isDisabled = stockStatus == _StockStatus.outOfStock;
    final stockLabel = _stockLabel(stockStatus);

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image / placeholder
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: imageData != null
                          ? Image.memory(imageData, width: double.infinity, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.accent.withOpacity(0.08),
                              child: Center(
                                child: Icon(Icons.fastfood, size: 36, color: AppColors.accent.withOpacity(0.4)),
                              ),
                            ),
                    ),
                    // Veg/Non-veg indicator
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(color: isVeg ? Colors.green : Colors.red, width: 1.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isVeg ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Stock badge (top right)
                    if (stockLabel.isNotEmpty)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: stockStatus == _StockStatus.outOfStock
                                ? AppColors.danger
                                : stockStatus == _StockStatus.orderAvailable
                                    ? AppColors.warning
                                    : AppColors.success,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            stockLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    // Cart quantity badge (when no stock label)
                    else if (quantityInCart > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$quantityInCart',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Details
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['name'] as String? ?? '',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Price — show "₹X+" when item has variants
                          Text(
                            hasVariants
                                ? '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}+'
                                : '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDisabled ? AppColors.textSecondary : AppColors.accent,
                            ),
                          ),
                          // +/- controls (hidden when disabled)
                          if (!isDisabled) ...[
                            if (quantityInCart > 0)
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: onRemove,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.remove, size: 14, color: AppColors.danger),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: onTap,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.add, size: 14, color: AppColors.accent),
                                    ),
                                  ),
                                ],
                              )
                            else
                              GestureDetector(
                                onTap: onTap,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StockStatus { notTracked, inStock, orderAvailable, outOfStock }

// ── Order Detail Sheet ─────────────────────────────────────────────────────────

class _OrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAddItems;
  final void Function(String status) onUpdateStatus;

  const _OrderDetailSheet({
    required this.order,
    required this.onAddItems,
    required this.onUpdateStatus,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'Processing': return AppColors.info;
      case 'Cooking':    return AppColors.warning;
      case 'Ready':      return AppColors.success;
      case 'Running':    return AppColors.accent;
      case 'Served':     return Colors.purple;
      default:           return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status   = order['status'] as String? ?? '';
    final tableNo  = order['tableNo'] as String? ?? 'Take Away';
    final total    = (order['total'] as num?)?.toDouble() ?? 0.0;
    final items    = List<Map<String, dynamic>>.from(order['items'] as List? ?? []);
    final kotNums  = (order['kotNumbers'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final color    = _statusColor(status);

    // Determine available status actions for captain
    final canMarkServed = status == 'Ready' || status == 'Cooking';
    final canRequestBill = status == 'Running' || status == 'Served';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Table $tableNo',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                      Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(status,
                                style: GoogleFonts.poppins(
                                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          if (kotNums.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text('KOT: ${kotNums.join(', ')}',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text('₹${total.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Items list
          Expanded(
            child: ListView.separated(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = items[i];
                final name = it['title'] as String? ?? it['name'] as String? ?? '';
                final variant = it['variantName'] as String?;
                final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                final price = (it['totalPrice'] as num?)?.toDouble()
                    ?? (it['price'] as num?)?.toDouble() ?? 0.0;
                final choices = (it['choiceNames'] as List?)?.cast<String>() ?? [];
                final extras = it['extras'] as List? ?? [];
                final note = it['instruction'] as String?;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Qty badge
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('$qty',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.bold,
                                  color: AppColors.accent)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.poppins(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            if (variant != null)
                              Text(variant,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: AppColors.textSecondary)),
                            if (choices.isNotEmpty)
                              Text(choices.join(', '),
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: AppColors.textSecondary)),
                            if (extras.isNotEmpty)
                              Text(
                                (extras as List).map((e) =>
                                    (e as Map)['displayName'] ?? e['name'] ?? '').join(', '),
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: AppColors.textSecondary),
                              ),
                            if (note != null && note.isNotEmpty)
                              Text('Note: $note',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: AppColors.warning,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      Text('₹${price.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Action buttons
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
                12 + MediaQuery.of(context).viewInsets.bottom),
            child: Row(
              children: [
                // Add Items always available
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddItems,
                    icon: const Icon(Icons.add),
                    label: Text('Add Items', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (canMarkServed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onUpdateStatus('Served'),
                      icon: const Icon(Icons.room_service_outlined),
                      label: Text('Mark Served', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
                if (canRequestBill) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onUpdateStatus('Bill Requested'),
                      icon: const Icon(Icons.receipt_outlined),
                      label: Text('Request Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Table Picker Sheet ─────────────────────────────────────────────────────────

class _TablePickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> tables;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onClear;

  const _TablePickerSheet({
    required this.tables,
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select Table',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              if (selected != null)
                TextButton(
                  onPressed: onClear,
                  child: Text('Clear', style: GoogleFonts.poppins(color: AppColors.danger)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Take Away if no table selected',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.2,
              ),
              itemCount: tables.length,
              itemBuilder: (_, i) {
                final t = tables[i];
                final isOccupied = t['status'] == 'Occupied';
                final isSelected = selected?['id'] == t['id'];
                return GestureDetector(
                  onTap: () => onSelect(t),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent
                          : isOccupied
                              ? AppColors.danger.withOpacity(0.1)
                              : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : isOccupied
                                ? AppColors.danger.withOpacity(0.4)
                                : AppColors.success.withOpacity(0.4),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.table_restaurant,
                          size: 20,
                          color: isSelected
                              ? Colors.white
                              : isOccupied
                                  ? AppColors.danger
                                  : AppColors.success,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${t['id']}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
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

// ── Cart Sheet ─────────────────────────────────────────────────────────────────

class _CartSheet extends StatelessWidget {
  final List<CartItem> cart;
  final double total;
  final Map<String, dynamic>? selectedTable;
  final bool isAddingToOrder;
  final ValueChanged<CartItem> onRemove;
  final VoidCallback onTableTap;
  final VoidCallback onSend;
  final ScrollController scrollController;

  const _CartSheet({
    required this.cart,
    required this.total,
    required this.selectedTable,
    required this.isAddingToOrder,
    required this.onRemove,
    required this.onTableTap,
    required this.onSend,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Order', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: onTableTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.tablesTab.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.tablesTab.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.table_restaurant, size: 14, color: AppColors.tablesTab),
                      const SizedBox(width: 6),
                      Text(
                        selectedTable != null ? 'Table: ${selectedTable!['id']}' : 'Take Away',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.tablesTab, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 12, color: AppColors.tablesTab),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        // Cart items
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cart.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = cart[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                title: Text(
                  item.title + (item.variantName != null ? ' (${item.variantName})' : ''),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: item.choiceNames != null
                    ? Text(item.choiceNames!.join(', '),
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '× ${item.quantity}  ₹${item.totalPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onRemove(item),
                      child: Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Total + Send
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                  Text('₹${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAddingToOrder ? AppColors.warning : AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isAddingToOrder ? 'Add to Order' : 'Send to Kitchen',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Item Customization Sheet ───────────────────────────────────────────────────

class _ItemCustomizationSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> variants;
  final List<Map<String, dynamic>> choices;   // [{id, name, choiceOption:[{id,name}]}]
  final List<Map<String, dynamic>> extras;    // [{id, Ename, topping:[{name,price}]}]
  final void Function(
    Map<String, dynamic>? variant,
    List<String> choiceNames,
    List<Map<String, dynamic>> extras,
    String? instruction,
  ) onAddToCart;

  const _ItemCustomizationSheet({
    required this.item,
    required this.variants,
    required this.choices,
    required this.extras,
    required this.onAddToCart,
  });

  @override
  State<_ItemCustomizationSheet> createState() => _ItemCustomizationSheetState();
}

class _ItemCustomizationSheetState extends State<_ItemCustomizationSheet> {
  Map<String, dynamic>? _selectedVariant;
  // choiceId → set of selected option names
  final Map<String, Set<String>> _selectedChoiceOptions = {};
  // name → {price, categoryName, categoryId} (matches POS extras format)
  final Map<String, Map<String, dynamic>> _selectedToppings = {};
  final TextEditingController _instructionController = TextEditingController();

  bool _variantOutOfStock(Map<String, dynamic> v) {
    final track = v['trackInventory'] as bool? ?? false;
    if (!track) return false;
    return ((v['stockQuantity'] as num?)?.toDouble() ?? 0.0) <= 0;
  }

  @override
  void initState() {
    super.initState();
    // Pre-select first in-stock variant (mirrors ItemOptionsDialog._prepareVariants)
    if (widget.variants.isNotEmpty) {
      _selectedVariant = widget.variants.firstWhere(
        (v) => !_variantOutOfStock(v),
        orElse: () => widget.variants.first,
      );
    }
  }

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  // Variant price IS the item price when selected (not additive)
  // Mirrors ItemOptionsDialog._recalculateTotal()
  double get _totalPrice {
    final double base;
    if (_selectedVariant != null) {
      base = (_selectedVariant!['price'] as num?)?.toDouble() ?? 0.0;
    } else {
      base = (widget.item['price'] as num?)?.toDouble() ?? 0.0;
    }
    final extrasAdd = _selectedToppings.values
        .fold(0.0, (s, e) => s + ((e['price'] as num?)?.toDouble() ?? 0.0));
    return base + extrasAdd;
  }

  void _submit() {
    final allChoiceNames = _selectedChoiceOptions.values
        .expand((names) => names)
        .toList();

    // Build extras in POS format: {name, displayName, price, categoryName, categoryId, quantity}
    final extrasList = _selectedToppings.entries.map((entry) {
      final data = entry.value;
      final catName = data['categoryName'] as String? ?? '';
      return <String, dynamic>{
        'name': entry.key,
        'displayName': catName.isNotEmpty ? '$catName - ${entry.key}' : entry.key,
        'price': data['price'],
        'categoryName': catName,
        'categoryId': data['categoryId'] ?? '',
        'quantity': 1,
      };
    }).toList();

    widget.onAddToCart(
      _selectedVariant,
      allChoiceNames,
      extrasList,
      _instructionController.text.trim().isEmpty ? null : _instructionController.text.trim(),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item['name'] as String? ?? '',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Customise your order',
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${_totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Scrollable options
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // ── Variants ──────────────────────────────────────────────
                if (widget.variants.isNotEmpty) ...[
                  _sectionHeader('Choose Variant', required: true),
                  ...widget.variants.map((v) {
                    final isSelected = _selectedVariant?['id'] == v['id'];
                    final vPrice = (v['price'] as num?)?.toDouble() ?? 0.0;
                    final outOfStock = _variantOutOfStock(v);
                    return _OptionTile(
                      title: v['name'] as String? ?? '',
                      subtitle: outOfStock
                          ? 'Out of Stock'
                          : '₹${vPrice.toStringAsFixed(vPrice.truncateToDouble() == vPrice ? 0 : 2)}',
                      isSelected: isSelected,
                      isRadio: true,
                      isDisabled: outOfStock,
                      onTap: outOfStock ? () {} : () => setState(() => _selectedVariant = v),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // ── Choices ───────────────────────────────────────────────
                for (final choice in widget.choices) ...[
                  _sectionHeader(choice['name'] as String? ?? 'Choice'),
                  ...() {
                    final opts = List<Map<String, dynamic>>.from(
                        choice['choiceOption'] as List? ?? []);
                    final choiceId = choice['id'] as String;
                    _selectedChoiceOptions.putIfAbsent(choiceId, () => {});
                    return opts.map((opt) {
                      final optName = opt['name'] as String? ?? '';
                      final isSelected = _selectedChoiceOptions[choiceId]!.contains(optName);
                      return _OptionTile(
                        title: optName,
                        isSelected: isSelected,
                        isRadio: false,
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedChoiceOptions[choiceId]!.remove(optName);
                          } else {
                            _selectedChoiceOptions[choiceId]!.add(optName);
                          }
                        }),
                      );
                    });
                  }(),
                  const SizedBox(height: 16),
                ],

                // ── Extras ────────────────────────────────────────────────
                for (final extra in widget.extras) ...[
                  _sectionHeader(extra['Ename'] as String? ?? 'Extras'),
                  ...() {
                    final toppings = List<Map<String, dynamic>>.from(
                        extra['topping'] as List? ?? []);
                    final catName = extra['Ename'] as String? ?? '';
                    final catId = extra['id'] as String? ?? '';
                    return toppings.map((t) {
                      final tName = t['name'] as String? ?? '';
                      final tPrice = (t['price'] as num?)?.toDouble() ?? 0.0;
                      final isSelected = _selectedToppings.containsKey(tName);
                      return _OptionTile(
                        title: tName,
                        subtitle: tPrice > 0 ? '+₹${tPrice.toStringAsFixed(2)}' : null,
                        isSelected: isSelected,
                        isRadio: false,
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedToppings.remove(tName);
                          } else {
                            _selectedToppings[tName] = {
                              'price': tPrice,
                              'categoryName': catName,
                              'categoryId': catId,
                            };
                          }
                        }),
                      );
                    });
                  }(),
                  const SizedBox(height: 16),
                ],

                // ── Instruction ───────────────────────────────────────────
                _sectionHeader('Special Instruction (optional)'),
                TextField(
                  controller: _instructionController,
                  maxLines: 2,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Less spicy, no onions...',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 80), // space for bottom button
              ],
            ),
          ),

          // Add to cart button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Add to Cart  •  ₹${_totalPrice.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (required) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Required',
                style: GoogleFonts.poppins(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Option Tile ────────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final bool isRadio;
  final bool isDisabled;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.isSelected,
    required this.isRadio,
    required this.onTap,
    this.subtitle,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.45 : 1.0,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio or Checkbox indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: isRadio ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isRadio ? null : BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  width: 2,
                ),
                color: isSelected ? AppColors.accent : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      isRadio ? Icons.circle : Icons.check,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDisabled
                      ? AppColors.danger
                      : isSelected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}