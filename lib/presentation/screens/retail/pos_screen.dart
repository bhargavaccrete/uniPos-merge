import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/responsive.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:unipos/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:unipos/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:unipos/presentation/screens/retail/scanner_screen.dart';
import 'package:unipos/presentation/screens/retail/checkout_screen.dart';
import 'package:unipos/presentation/screens/retail/parked_sales_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

import 'package:uuid/uuid.dart';

import '../../widget/retail/variant_picker_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearchMode = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeStores();
  }

  Future<void> _initializeStores() async {
    // Wait a frame to ensure stores are registered
    await Future.delayed(Duration.zero);

    // Verify stores are available
    try {
      final _ = productStore;
      final __ = cartStore;
      final ___ = holdSaleStore;

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Check if this is the first time user is visiting POS screen
        _checkAndShowWelcomeDialog();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error initializing POS: $e');
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _checkAndShowWelcomeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('first_time_pos') ?? true;

    if (isFirstTime && mounted) {
      // Wait a bit for the screen to be fully rendered
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        await _showWelcomeDialog();
        await prefs.setBool('first_time_pos', false);
      }
    }
  }

  Future<void> _showWelcomeDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: const [
            Icon(Icons.celebration, color: Color(0xFF4CAF50), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Welcome to Your POS!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your store is now ready! Here\'s how to get started:',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 20),
              _buildWelcomeStep(
                Icons.qr_code_scanner,
                'Scan Barcodes',
                'Use the scanner button to quickly add products',
              ),
              _buildWelcomeStep(
                Icons.search,
                'Search Products',
                'Type product names in the search bar',
              ),
              _buildWelcomeStep(
                Icons.add_shopping_cart,
                'Add to Cart',
                'Tap on products to add them to your cart',
              ),
              _buildWelcomeStep(
                Icons.pause_circle_outline,
                'Hold Sales',
                'Park incomplete sales and restore them later',
              ),
              _buildWelcomeStep(
                Icons.payment,
                'Checkout',
                'Process payments and complete transactions',
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 24,
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final results = await productStore.searchProducts(query);
    setState(() {
      _searchResults = results;
      _showSearchResults = results.isNotEmpty;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showSearchResults = false;
      _isSearchMode = false;
    });
  }

  Future<void> _onProductSelected(ProductModel product) async {
    final variants = await productStore.getVariantsForProduct(product.productId);

    if (variants.isEmpty) {
      if (mounted) {
        NotificationService.instance.showError('No variants available for this product');
      }
      return;
    }

    if (variants.length == 1) {
      // Single variant - add directly
      final result = await cartStore.addItem(product, variants.first);
      _clearSearch();
      if (mounted) {
        if (result.success) {
          NotificationService.instance.showSuccess('${product.productName} added to cart');
        } else {
          NotificationService.instance.showError(result.errorMessage ?? 'Cannot add item');
        }
      }
    } else {
      // Multiple variants - show selection dialog
      _clearSearch();
      _showVariantSelectionDialog(product, variants);
    }
  }

  Future<void> _handleBarcodeScanned(String barcode) async {
    if (barcode.isEmpty) return;

    // Find the exact variant by barcode
    final variant = await productStore.findVariantByBarcode(barcode);

    if (variant != null) {
      // Get the product for this variant
      final product = await productStore.findByBarcode(barcode);

      if (product != null) {
        // Add the exact scanned variant to cart
        final result = await cartStore.addItem(product, variant);

        if (mounted) {
          // Clear search field and hide search results
          _clearSearch();
          if (result.success) {
            NotificationService.instance.showSuccess('${product.productName} ${_getVariantDisplayName(variant)} added to cart');
          } else {
            NotificationService.instance.showError(result.errorMessage ?? 'Cannot add item');
          }
        }
      }
    } else {
      // Barcode not found - don't show error if it looks like a product search
      // Only show error for numeric-only input (likely a barcode)
      final isLikelyBarcode = RegExp(r'^\d+$').hasMatch(barcode);
      if (mounted && isLikelyBarcode) {
        NotificationService.instance.showError('Product not found for barcode: $barcode');
        _clearSearch();
      }
    }
  }

  void _showVariantSelectionDialog(ProductModel product, List<VarianteModel> variants) async {
    // Use WooCommerce-style variant picker for better UX
    final selectedVariant = await VariantPickerDialog.show(
      context: context,
      product: product,
      variants: variants,
    );

    if (selectedVariant != null && mounted) {
      final result = await cartStore.addItem(product, selectedVariant);
      _barcodeController.clear();
      if (result.success) {
        NotificationService.instance.showSuccess('${product.productName} ${selectedVariant.shortDescription} added to cart');
      } else {
        NotificationService.instance.showError(result.errorMessage ?? 'Cannot add item');
      }
    }
  }

  String _getVariantDisplayName(VarianteModel variant) {
    final parts = <String>[];
    if (variant.size != null) parts.add('Size: ${variant.size}');
    if (variant.color != null) parts.add('Color: ${variant.color}');
    if (variant.weight != null) parts.add('Weight: ${variant.weight}');
    return parts.isEmpty ? 'Default' : parts.join(' • ');
  }

  Future<void> _holdCurrentSale() async {
    if (cartStore.itemCount == 0) {
      NotificationService.instance.showError('Cart is empty. Nothing to hold.');
      return;
    }

    // Ask for optional note
    String? note;
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final noteController = TextEditingController();
        return AlertDialog(
          title: const Text('Hold Sale'),
          content: TextField(
            controller: noteController,
            decoration: const InputDecoration(
              hintText: 'Reason (optional)',
              hintStyle: TextStyle(fontSize: 14),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, noteController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hold'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    note = result.isEmpty ? null : result;

    try {
      // Create hold sale
      const uuid = Uuid();
      final holdSaleId = 'HOLD_${uuid.v4()}';

      final holdSale = HoldSaleModel.create(
        holdSaleId: holdSaleId,
        note: note,
        totalItems: cartStore.totalItems,
        subtotal: cartStore.totalPrice,
      );

      // Create hold sale items from cart
      final holdSaleItems = cartStore.items.map((cartItem) {
        return HoldSaleItemModel.create(
          holdSaleId: holdSaleId,
          variantId: cartItem.variantId,
          productId: cartItem.productId,
          productName: cartItem.productName,
          size: cartItem.size,
          color: cartItem.color,
          weight: cartItem.weight,
          price: cartItem.price,
          qty: cartItem.qty,
          barcode: cartItem.barcode,
        );
      }).toList();

      // Save hold sale
      await holdSaleStore.addHoldSale(holdSale, holdSaleItems);

      // Clear cart
      await cartStore.clearCart();

      if (mounted) {
        NotificationService.instance.showSuccess('Sale parked successfully!');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error parking sale: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Billing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
              SizedBox(height: 16),
              Text(
                'Initializing POS...',
                style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(context),
      body: Responsive(
        mobile: _buildMobileLayout(context),
        tablet: _buildTabletLayout(context),
        desktop: _buildDesktopLayout(context),
      ),
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Billing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/retail-menu');
        },
        tooltip: 'Back to Home',
      ),
      actions: [
        Observer(
          builder: (context) => Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.pause_circle_outline, color: Colors.orange),
                tooltip: 'View parked sales',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ParkedSalesScreen(),
                    ),
                  );
                },
              ),
              if (holdSaleStore.holdSaleCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${holdSaleStore.holdSaleCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Observer(
          builder: (context) => IconButton(
            icon: const Icon(Icons.pause, color: Colors.orange),
            tooltip: 'Hold current sale',
            onPressed: cartStore.itemCount > 0 ? _holdCurrentSale : null,
          ),
        ),
      ],
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildSearchBarWithScanner(context),
        if (_showSearchResults) _buildSearchResults(),
        if (!_showSearchResults) ...[
          _buildHeaderRow(context),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
          Expanded(
            child: _buildSimpleCart(context),
          ),
        ],
        _buildSimpleSummary(context),
      ],
    );
  }

  // ==================== TABLET LAYOUT ====================
  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        // Left side: Search/Product Panel (40%)
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildSearchBarWithScanner(context),
              if (_showSearchResults)
                _buildSearchResults()
              else
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 64, color: Color(0xFFD0D0D0)),
                          SizedBox(height: 16),
                          Text(
                            'Search for products',
                            style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Vertical divider
        Container(
          width: 1,
          color: const Color(0xFFE8E8E8),
        ),
        // Right side: Cart Panel (60%)
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildHeaderRow(context),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
              Expanded(
                child: _buildSimpleCart(context),
              ),
              _buildSimpleSummary(context),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== DESKTOP LAYOUT ====================
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left side: Search/Product Panel (35%)
        Expanded(
          flex: 35,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: const Color(0xFFE8E8E8), width: 1),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Search',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSearchBarWithScanner(context),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
                if (_showSearchResults)
                  _buildSearchResults()
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 20),
                          const Text(
                            'Search for products',
                            style: TextStyle(fontSize: 18, color: Color(0xFF6B6B6B)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use the search bar or scanner',
                            style: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Right side: Cart Panel (65%)
        Expanded(
          flex: 65,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE8E8E8), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Shopping Cart',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Observer(
                      builder: (context) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${cartStore.itemCount} items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderRow(context),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
              Expanded(
                child: _buildSimpleCart(context),
              ),
              _buildSimpleSummary(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBarWithScanner(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Row(
        children: [
          // Main search field (product name + barcode)
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
              ),
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                onChanged: _onSearchChanged,
                onSubmitted: (value) async {
                  // On Enter/Submit - try barcode first, then search
                  if (value.isNotEmpty) {
                    await _handleBarcodeScanned(value);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search product or enter barcode...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B0B0)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15,vertical: 16),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B), size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF6B6B6B), size: 15),
                          onPressed: _clearSearch,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Barcode scanner button
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () async {
                final String? barcode = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                );

                if (barcode != null) {
                  await _handleBarcodeScanned(barcode);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_searchResults.length} products found',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6B6B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: _clearSearch,
                    child: const Text(
                      'Back to Cart',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  return _buildProductSearchItem(product);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSearchItem(ProductModel product) {
    return FutureBuilder<List<VarianteModel>>(
      future: productStore.getVariantsForProduct(product.productId),
      builder: (context, snapshot) {
        final variants = snapshot.data ?? [];
        final firstVariant = variants.isNotEmpty ? variants.first : null;
        
        // Calculate price with fallbacks
        double price = 0;
        if (firstVariant != null) {
          price = firstVariant.effectivePrice;
        }
        
        // If price is still 0 (no variants or variant has 0 price), try product defaults
        if (price == 0) {
          price = product.defaultPrice ?? product.defaultMrp ?? 0;
        }

        final stock = variants.fold<int>(0, (sum, v) => sum + v.stockQty);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _onProductSelected(product),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Product icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF4CAF50),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              product.category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                            if (variants.length > 1) ...[
                              const Text(' • ', style: TextStyle(color: Color(0xFF6B6B6B))),
                              Text(
                                '${variants.length} variants',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Price and stock
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: CurrencyHelper.currencyNotifier,
                        builder: (context, currencyCode, child) {
                          return ValueListenableBuilder<int>(
                            valueListenable: DecimalSettings.precisionNotifier,
                            builder: (context, precision, child) {
                              final symbol = CurrencyHelper.currentSymbol;
                              final formattedPrice = price.toStringAsFixed(precision);
                              return Text(
                                '$symbol$formattedPrice',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: stock > 0
                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          stock > 0 ? 'Stock: $stock' : 'Out of stock',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: stock > 0 ? const Color(0xFF4CAF50) : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Add icon
                  const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: const [
          // Item Name header
          Expanded(
            flex: 3,
            child: Text(
              'Item Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Quantity header
          SizedBox(
            width: 110,
            child: Text(
              'Quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Price header
          SizedBox(
            width: 70,
            child: Text(
              'Price',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Space for delete icon
          SizedBox(width: 40),
        ],
      ),
    );
  }



  Widget _buildSimpleCart(BuildContext context) {
    return Observer(
      builder: (context) {
        if (cartStore.itemCount == 0) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFFD0D0D0)),
                SizedBox(height: 16),
                Text(
                  'Cart is empty',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
                ),
                SizedBox(height: 8),
                Text(
                  'Scan or search items to add',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cartStore.itemCount,
          itemBuilder: (context, index) {
            // Wrap each item in Observer to react to individual item changes
            return Observer(
              builder: (context) {
                // Access item directly from store to ensure reactivity
                if (index >= cartStore.items.length) {
                  return const SizedBox.shrink();
                }
                final item = cartStore.items[index];

                return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Item Name
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            cartStore.getDisplayName(item),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          ValueListenableBuilder<String>(
                            valueListenable: CurrencyHelper.currencyNotifier,
                            builder: (context, currencyCode, child) {
                              return ValueListenableBuilder<int>(
                                valueListenable: DecimalSettings.precisionNotifier,
                                builder: (context, precision, child) {
                                  final symbol = CurrencyHelper.currentSymbol;
                                  final formattedPrice = item.price.toStringAsFixed(precision);
                                  return Text(
                                    '$symbol$formattedPrice',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B6B6B),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Quantity Controls
                    Container(
                      width: 90,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          InkWell(
                            onTap: () {
                              cartStore.decrementQuantity(item.variantId);
                            },
                            child: Container(
                              width: 28,
                              height: 32,
                              alignment: Alignment.center,
                              child: const Icon(Icons.remove, size: 14, color: Color(0xFF6B6B6B)),
                            ),
                          ),
                          Text(
                            item.qty.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          InkWell(
                            onTap: () async {
                              final result = await cartStore.incrementQuantity(item.variantId);
                              if (!result.success && mounted) {
                                NotificationService.instance.showError(result.errorMessage ?? 'Cannot add more items');
                              }
                            },
                            child: Container(
                              width: 28,
                              height: 32,
                              alignment: Alignment.center,
                              child: const Icon(Icons.add, size: 14, color: Color(0xFF4CAF50)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Total Price
                    SizedBox(
                      width: 60,
                      child: ValueListenableBuilder<String>(
                        valueListenable: CurrencyHelper.currencyNotifier,
                        builder: (context, currencyCode, child) {
                          return ValueListenableBuilder<int>(
                            valueListenable: DecimalSettings.precisionNotifier,
                            builder: (context, precision, child) {
                              final symbol = CurrencyHelper.currentSymbol;
                              final formattedTotal = item.total.toStringAsFixed(precision);
                              return Text(
                                '$symbol$formattedTotal',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                                textAlign: TextAlign.right,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Delete Icon
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () {
                          cartStore.removeItem(item.variantId);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  });}

  Widget _buildSimpleSummary(BuildContext context) {
    return Observer(
      builder: (context) {
        if (cartStore.itemCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Item count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${cartStore.itemCount} Items',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: CurrencyHelper.currencyNotifier,
                      builder: (context, currencyCode, child) {
                        return ValueListenableBuilder<int>(
                          valueListenable: DecimalSettings.precisionNotifier,
                          builder: (context, precision, child) {
                            final symbol = CurrencyHelper.currentSymbol;
                            final formattedPrice = cartStore.totalPrice.toStringAsFixed(precision);
                            return Text(
                              '$symbol$formattedPrice',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B6B6B),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Discount
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Text(
                    //   'Discount',
                    //   style: TextStyle(
                    //     fontSize: 14,
                    //     color: Color(0xFF6B6B6B),
                    //   ),
                    // ),
                    // Text(
                    //   '₹0.00',
                    //   style: TextStyle(
                    //     fontSize: 14,
                    //     color: Color(0xFF6B6B6B),
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 8),
                // Tax
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tax',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: CurrencyHelper.currencyNotifier,
                      builder: (context, currencyCode, child) {
                        return ValueListenableBuilder<int>(
                          valueListenable: DecimalSettings.precisionNotifier,
                          builder: (context, precision, child) {
                            final symbol = CurrencyHelper.currentSymbol;
                            final formattedGst = cartStore.totalGstAmount.toStringAsFixed(precision);
                            return Text(
                              '$symbol$formattedGst',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B6B6B),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 0.5, color: Color(0xFFE8E8E8)),
                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: CurrencyHelper.currencyNotifier,
                      builder: (context, currencyCode, child) {
                        return ValueListenableBuilder<int>(
                          valueListenable: DecimalSettings.precisionNotifier,
                          builder: (context, precision, child) {
                            final symbol = CurrencyHelper.currentSymbol;
                            final formattedTotal = cartStore.totalPrice.toStringAsFixed(precision);
                            return Text(
                              '$symbol$formattedTotal',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Navigate to checkout screen
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CheckoutScreen(),
                        ),
                      );

                      // If checkout was successful, show success message
                      if (result == true && mounted) {
                        NotificationService.instance.showSuccess('Checkout completed successfully!');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:  AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Proceed to Checkout',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}