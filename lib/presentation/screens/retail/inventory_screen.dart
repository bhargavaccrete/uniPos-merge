import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';

import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/presentation/screens/retail/scanner_screen.dart';
import 'package:billberrylite/presentation/screens/retail/add_product_screen.dart';
import 'package:billberrylite/presentation/screens/retail/product_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  /// True when hosted as a tab of ProductManagementScreen — the host owns the
  /// AppBar (and its contextual Add action), so this screen drops its own.
  final bool embedded;

  /// Ticks when the host switches tabs; clears the search box so the other tab
  /// is never filtered by a query typed on this one.
  final Listenable? clearSearchSignal;

  const InventoryScreen({
    super.key,
    this.embedded = false,
    this.clearSearchSignal,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.clearSearchSignal?.addListener(_clearSearch);
  }

  @override
  void dispose() {
    widget.clearSearchSignal?.removeListener(_clearSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty && _searchQuery.isEmpty) return;
    _searchController.clear();
    if (mounted) setState(() => _searchQuery = '');
  }

  Future<void> _loadData({bool force = false}) async {
    if (_isLoadingData && !force) return;
    if (!mounted) return;

    setState(() => _isLoadingData = true);

    try {
      await Future.wait([
        categoryStore.loadCategories(),
        productStore.loadProducts(),
        productStore.loadVariants(),
        // Also pre-warms the lazy singleton so no Observer constructs it mid-build.
        stockAlertStore.loadSettings(),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Data loading timed out after 10 seconds');
        },
      );
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error loading inventory: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  /// Products matching the current search, each paired with its derived stock,
  /// price and status. MUST be called inside an Observer builder: it is what
  /// registers the MobX dependencies, and the lazy `itemBuilder`s of the grids
  /// run outside the reaction, where store reads would neither track nor
  /// memoise.
  List<_ProductRow> _visibleRows() {
    final names = categoryStore.categoryNameById;
    final index = productStore.variantsByProduct;

    return productStore.products.where((product) {
      if (_searchQuery.isEmpty) return true;
      final categoryName = (names[product.category] ?? '').toLowerCase();
      if (product.productName.toLowerCase().contains(_searchQuery) ||
          categoryName.contains(_searchQuery)) {
        return true;
      }
      // The search hint promises barcodes, and a typed SKU is just as likely —
      // both live on the variants, not the product.
      final variants = index[product.productId] ?? const <VarianteModel>[];
      return variants.any((v) =>
          (v.barcode?.toLowerCase().contains(_searchQuery) ?? false) ||
          (v.sku?.toLowerCase().contains(_searchQuery) ?? false));
    }).map((product) {
      final variants = index[product.productId] ?? const <VarianteModel>[];
      final totalStock =
          variants.fold<int>(0, (sum, v) => sum + v.stockQty);
      return _ProductRow(
        product: product,
        variants: variants,
        categoryName: names[product.category] ?? product.category,
        totalStock: totalStock,
        status: productStore.stockStatusForQty(totalStock),
        price: productStore.costPriceFor(product.productId),
      );
    }).toList();
  }

  Future<void> _openProductByBarcode(String barcode) async {
    final product = await productStore.findByBarcode(barcode);
    if (!mounted) return;
    if (product == null) {
      NotificationService.instance
          .showWarning('No product found for that barcode');
      return;
    }
    _searchController.clear();
    setState(() => _searchQuery = '');
    _openProduct(product);
  }

  // ==================== PRODUCT ACTIONS ====================
  /// A product has exactly one destination — its own screen. No intermediate
  /// dialog, and no second route to the variant list.
  void _openProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  /// Edit / Delete for a product. Behind an overflow menu rather than visible
  /// chips, matching the Categories tab and the variant rows.
  Widget _buildProductMenu(ProductModel product) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert,
          color: AppColors.textSecondary, size: 20),
      padding: EdgeInsets.zero,
      // M3 tints menu surfaces by default; keep them plain white.
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') {
          openEditProductScreen(context, product);
        } else if (value == 'delete') {
          _deleteProduct(product);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text('Edit Product',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.danger),
              const SizedBox(width: 12),
              Text('Delete Product',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.danger)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteProduct(ProductModel product) async {
    // Deleting the product takes its variants with it (productStore.deleteProduct
    // prunes them), so say so before asking.
    final variantCount = productStore.variantCountFor(product.productId);

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Product?',
      message: variantCount > 0
          ? 'Delete "${product.productName}"? Its $variantCount variant'
              '${variantCount == 1 ? '' : 's'} and all their stock are removed '
              'with it.'
          : 'Delete "${product.productName}"?',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    await productStore.deleteProduct(product.productId);
    if (!mounted) return;
    NotificationService.instance
        .showSuccess('${product.productName} deleted');
  }

  /// Plain price label — no listener of its own; the [MoneyScope] around the
  /// body drives it.
  Widget _buildPriceText(
    double amount, {
    required double fontSize,
    required Color color,
    String prefix = '',
    bool bold = true,
  }) {
    return Text(
      '$prefix${formatMoney(amount)}',
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: widget.embedded
          ? null
          : buildPrimaryAppBar(
              title: 'Inventory',
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => openAddProductScreen(context),
                  tooltip: 'Add New Item',
                ),
              ],
            ),
      body: SafeArea(
        child: MoneyScope(
          child: AppResponsive.isDesktop(context)
              ? _buildDesktopLayout(context)
              : AppResponsive.isTablet(context)
                  ? _buildTabletLayout(context)
                  : _buildMobileLayout(context),
        ),
      ),
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildSearchBarRow(),
        const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
        Expanded(child: _buildProductList()),
      ],
    );
  }

  // ==================== TABLET LAYOUT ====================
  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      children: [
        _buildSearchBarRow(),
        const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
        Expanded(child: _buildProductGrid(context)),
      ],
    );
  }

  // ==================== DESKTOP LAYOUT ====================
  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Product Inventory',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Observer(
                builder: (context) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${productStore.products.length} products',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: _buildSearchBarRow(),
        ),
        Expanded(child: _buildProductGrid(context)),
      ],
    );
  }

  // ==================== GRID (Tablet & Desktop) ====================
  Widget _buildProductGrid(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    // Column counts preserved from the previous hardcoded layouts.
    final columns =
        AppResponsive.gridColumns(context, mobile: 1, tablet: 2, desktop: 3);
    final spacing =
        AppResponsive.getValue(context, mobile: 16.0, tablet: 16.0, desktop: 24.0);
    final aspectRatio =
        AppResponsive.getValue(context, mobile: 1.3, tablet: 1.3, desktop: 1.4);
    final padding = AppResponsive.getValue(
      context,
      mobile: const EdgeInsets.all(20),
      tablet: const EdgeInsets.all(20),
      desktop: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
    );

    return Observer(
      builder: (context) {
        final rows = _visibleRows();

        if (rows.isEmpty) return _buildEmptyState();

        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: rows.length,
          itemBuilder: (context, index) => _buildProductGridCard(rows[index]),
        );
      },
    );
  }

  Widget _buildProductGridCard(_ProductRow row) {
    return InkWell(
      onTap: () => _openProduct(row.product),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1),
          // Same soft lift the POS and report cards use.
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThumbnail(row.product, 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.product.productName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildProductMenu(row.product),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  row.categoryName,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: _stockColor(row.status),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Stock: ${row.totalStock}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _stockColor(row.status),
                      fontWeight: _stockWeight(row.status),
                    ),
                  ),
                  if (row.product.hasVariants) ...[
                    const SizedBox(width: 8),
                    _buildVariantCountChip(row.variants.length),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _buildPriceText(
                row.price,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== LIST (Mobile) ====================
  Widget _buildProductList() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return Observer(
      builder: (context) {
        final rows = _visibleRows();

        if (rows.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: rows.length,
          itemBuilder: (context, index) => _buildProductCard(rows[index]),
        );
      },
    );
  }

  Widget _buildProductCard(_ProductRow row) {
    return InkWell(
      onTap: () => _openProduct(row.product),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildThumbnail(row.product, 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.product.productName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            row.categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          ' • ',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        Text(
                          'Stock: ${row.totalStock}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _stockColor(row.status),
                            fontWeight: _stockWeight(row.status),
                          ),
                        ),
                        if (row.product.hasVariants) ...[
                          Text(
                            ' • ',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            '${row.variants.length} variants',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildPriceText(
                row.price,
                fontSize: 15,
                color: AppColors.primary,
              ),
              _buildProductMenu(row.product),
            ],
          ),
        ),
      ),
    );
  }

  /// Product photo, or a neutral placeholder so rows stay aligned whether or
  /// not a photo was set.
  Widget _buildThumbnail(ProductModel product, double size) {
    final bytes = product.imageBytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceMedium,
        child: bytes == null
            ? Icon(Icons.inventory_2_outlined,
                size: size * 0.5, color: AppColors.textSecondary)
            : Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildVariantCountChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$count variants',
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: AppColors.info,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ==================== SHARED CHROME ====================
  Widget _buildSearchBarRow() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: AppTextField(
        controller: _searchController,
        hint: 'Search by name or scan barcode...',
        icon: Icons.search_rounded,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only offered once there is something to clear.
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary, size: 20),
                tooltip: 'Clear search',
                visualDensity: VisualDensity.compact,
                onPressed: _clearSearch,
              ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner,
                  color: AppColors.primary, size: 20),
              tooltip: 'Scan barcode',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final String? barcode = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                );
                if (barcode == null || !mounted) return;
                await _openProductByBarcode(barcode);
              },
            ),
          ],
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
        onFieldSubmitted: (value) async {
          if (value.isEmpty) return;
          await _openProductByBarcode(value);
        },
      ),
    );
  }

  /// Two very different "nothing here" cases: a search that matched nothing
  /// (offer nothing — clearing the box is the fix) versus an empty catalog
  /// (offer the Add action, since the AppBar `+` is hidden while empty).
  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No products found',
        message: 'Try a different search term.',
      );
    }
    return AppEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'No products yet',
      message: 'Add your first product to start billing.',
      action: appEmptyStateAction(
        label: 'Add Product',
        onPressed: () => openAddProductScreen(context),
      ),
    );
  }

  // ==================== PRESENTATION MAPPERS ====================
  Color _stockColor(RetailStockStatus status) =>
      status == RetailStockStatus.inStock
          ? AppColors.textSecondary
          : AppColors.danger;

  FontWeight _stockWeight(RetailStockStatus status) =>
      status == RetailStockStatus.inStock ? FontWeight.w400 : FontWeight.w600;
}

/// A product plus everything the cards render, derived once inside the Observer.
class _ProductRow {
  final ProductModel product;
  final List<VarianteModel> variants;
  final String categoryName;
  final int totalStock;
  final RetailStockStatus status;
  final double price;

  const _ProductRow({
    required this.product,
    required this.variants,
    required this.categoryName,
    required this.totalStock,
    required this.status,
    required this.price,
  });
}
