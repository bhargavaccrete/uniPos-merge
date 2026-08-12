import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/presentation/screens/retail/scanner_screen.dart';
import 'package:billberrylite/presentation/screens/retail/add_product_screen.dart';
import 'package:billberrylite/presentation/screens/retail/variant_management_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      return product.productName.toLowerCase().contains(_searchQuery) ||
          categoryName.contains(_searchQuery);
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
    _showProductVariantsDialog(product);
  }

  // ==================== VARIANT DETAILS DIALOG ====================
  void _showProductVariantsDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (dialogContext) => Observer(
        builder: (_) {
          // Read inside the Observer so the dialog stays correct while it is
          // open — e.g. after editing variants and coming back.
          final variants = productStore.variantsFor(product.productId);
          return AppDialogShell(
            title: product.productName,
            subtitle:
                categoryStore.categoryNameById[product.category] ?? product.category,
            accent: AppColors.primary,
            icon: Icons.inventory_2_rounded,
            body: _buildVariantsDialogBody(variants),
            actions: [
              appDialogCancelButton(dialogContext, label: 'Close'),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: 'Edit Variants',
                onPressed: () async {
                  // Capture before popping — pushing on a popped dialog's
                  // context would throw.
                  final navigator = Navigator.of(context);
                  Navigator.of(dialogContext).pop();
                  await navigator.push(
                    MaterialPageRoute(
                      builder: (_) => VariantManagementScreen(product: product),
                    ),
                  );
                  // No setState needed — VariantManagementScreen mutates
                  // through productStore actions, which drive the observables.
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVariantsDialogBody(List<VarianteModel> variants) {
    final totalStock = variants.fold<int>(0, (sum, v) => sum + v.stockQty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Summary Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryTile(
                icon: Icons.inventory_2_rounded,
                value: '${variants.length}',
                label: 'Variants',
              ),
              _buildSummaryTile(
                icon: Icons.storage_rounded,
                value: '$totalStock',
                label: 'Total Stock',
              ),
              _buildSummaryTile(
                icon: Icons.sell_rounded,
                valueWidget: _buildPriceText(
                  variants.isNotEmpty ? variants.first.sellingPrice ?? 0 : 0,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                label: 'Price',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Variants List
        if (variants.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: AppEmptyState(
              icon: Icons.layers_outlined,
              title: 'No variants found',
              dense: true,
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: variants.length,
              itemBuilder: (context, index) =>
                  _buildVariantTile(variants[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    String? value,
    Widget? valueWidget,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        valueWidget ??
            Text(
              value ?? '',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildVariantTile(VarianteModel variant) {
    final status = productStore.stockStatusForVariant(variant);
    final isLowStock = status != RetailStockStatus.inStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isLowStock ? AppColors.danger : AppColors.success)
              .withOpacity(0.12),
          child: Icon(
            Icons.inventory_2_rounded,
            color: isLowStock ? AppColors.danger : AppColors.success,
            size: 20,
          ),
        ),
        title: Text(
          variant.displayName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Stock: ${variant.stockQty}',
                  style: GoogleFonts.poppins(
                    color: isLowStock ? AppColors.danger : AppColors.textSecondary,
                    fontWeight: isLowStock ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
                if (isLowStock) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.warning_rounded,
                      color: AppColors.danger, size: 14),
                ],
              ],
            ),
            if (variant.barcode?.isNotEmpty ?? false)
              Text(
                'Barcode: ${variant.barcode}',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildPriceText(
              variant.sellingPrice ?? 0,
              fontSize: 14,
              color: AppColors.success,
            ),
            if (variant.costPrice != null)
              _buildPriceText(
                variant.costPrice!,
                fontSize: 11,
                color: AppColors.textSecondary,
                prefix: 'Cost: ',
                bold: false,
              ),
          ],
        ),
      ),
    );
  }

  /// Currency/precision-aware amount. Kept as one helper so the
  /// nested ValueListenableBuilders aren't repeated at five call sites.
  Widget _buildPriceText(
    double amount, {
    required double fontSize,
    required Color color,
    String prefix = '',
    bool bold = true,
  }) {
    return ValueListenableBuilder<String>(
      valueListenable: CurrencyHelper.currencyNotifier,
      builder: (context, currencyCode, child) {
        return ValueListenableBuilder<int>(
          valueListenable: DecimalSettings.precisionNotifier,
          builder: (context, precision, child) {
            final symbol = CurrencyHelper.currentSymbol;
            return Text(
              '$prefix$symbol${amount.toStringAsFixed(precision)}',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Inventory',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddProductScreen()),
            ),
            tooltip: 'Add New Item',
          ),
        ],
      ),
      body: SafeArea(
        child: AppResponsive.isDesktop(context)
            ? _buildDesktopLayout(context)
            : AppResponsive.isTablet(context)
                ? _buildTabletLayout(context)
                : _buildMobileLayout(context),
      ),
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildHeaderRow(),
        const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
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

        if (rows.isEmpty) {
          return const AppEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No products found',
            message: 'Try a different search term.',
          );
        }

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
      onTap: () => _showProductVariantsDialog(row.product),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.product.productName,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

        if (rows.isEmpty) {
          return const AppEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No products found',
            message: 'Try a different search term.',
          );
        }

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
      onTap: () => _showProductVariantsDialog(row.product),
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
            ],
          ),
        ),
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
  Widget _buildHeaderRow() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Product Name',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            'Category',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarRow() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: AppTextField(
        controller: _searchController,
        hint: 'Search by name or scan barcode...',
        icon: Icons.search_rounded,
        suffixIcon: IconButton(
          icon: const Icon(Icons.qr_code_scanner,
              color: AppColors.primary, size: 20),
          onPressed: () async {
            final String? barcode = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (context) => const ScannerScreen()),
            );
            if (barcode == null || !mounted) return;
            await _openProductByBarcode(barcode);
          },
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
