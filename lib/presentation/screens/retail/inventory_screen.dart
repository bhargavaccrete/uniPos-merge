import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';

import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:unipos/presentation/screens/retail/scanner_screen.dart';
import 'package:unipos/presentation/screens/retail/add_product_screen.dart';
import 'package:unipos/presentation/screens/retail/variant_management_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addItemToCart(ProductModel product) async {
    // Get variants for this product
    final variants = await productStore.getVariantsForProduct(product.productId);

    if (variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No variants available for this product'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // If product has multiple variants, show selection dialog
    if (variants.length > 1 && product.hasVariants) {
      _showVariantSelectionDialog(product, variants);
    } else {
      // Add the only/default variant to cart
      cartStore.addItem(product, variants.first);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.productName} added to cart'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showVariantSelectionDialog(ProductModel product, List<VarianteModel> variants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select ${product.productName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: variants.length,
            itemBuilder: (context, index) {
              final variant = variants[index];
              return ListTile(
                title: Text(_getVariantDisplayName(variant)),
                subtitle: Text('₹${variant.costPrice?.toStringAsFixed(2) ?? '0.00'} • Stock: ${variant.stockQty}'),
                onTap: () {
                  Navigator.pop(context);
                  cartStore.addItem(product, variant);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.productName} added to cart'),
                      backgroundColor: const Color(0xFF4CAF50),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getVariantDisplayName(VarianteModel variant) {
    final parts = <String>[];
    if (variant.size != null) parts.add('Size: ${variant.size}');
    if (variant.color != null) parts.add('Color: ${variant.color}');
    if (variant.weight != null) parts.add('Weight: ${variant.weight}');
    return parts.isEmpty ? 'Default' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddProductScreen()),
              );
            },
            tooltip: 'Add New Item',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderRow(),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
          Expanded(
            child: _buildProductListWithSearch(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: const [
          Expanded(
            child: Text(
              'Product Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ),
          Text(
            'Category',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B6B6B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListWithSearch() {
    return Observer(
      builder: (context) {
        final allProducts = productStore.products;

        final filteredProducts = _searchQuery.isEmpty
            ? allProducts
            : allProducts.where((product) {
                return product.productName.toLowerCase().contains(_searchQuery) ||
                    product.category.toLowerCase().contains(_searchQuery);
              }).toList();

        return Column(
          children: [
            // Search bar row
            _buildSearchBarRow(),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
            // Items list below
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Show filtered products
                  if (filteredProducts.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: Color(0xFFD0D0D0)),
                            SizedBox(height: 12),
                            Text(
                              'No products found',
                              style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredProducts.map((product) {
                      return _buildProductCard(product);
                    }).toList(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBarRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name or scan barcode...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B0B0)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF4CAF50), size: 20),
              onPressed: () async {
                final String? barcode = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                );

                if (barcode != null && mounted) {
                  final product = await productStore.findByBarcode(barcode);
                  if (product != null) {
                    await _addItemToCart(product);
                    _searchController.clear();
                  }
                }
              },
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          onSubmitted: (value) async {
            if (value.isNotEmpty) {
              final product = await productStore.findByBarcode(value);
              if (product != null) {
                await _addItemToCart(product);
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return FutureBuilder<List<VarianteModel>>(
      future: productStore.getVariantsForProduct(product.productId),
      builder: (context, snapshot) {
        final variants = snapshot.data ?? [];
        final totalStock = variants.fold<int>(0, (sum, v) => sum + v.stockQty);
        final price = variants.isNotEmpty && variants.first.costPrice != null
            ? variants.first.costPrice!
            : 0.0;

        return InkWell(
          onTap: () => _addItemToCart(product),
          onLongPress: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VariantManagementScreen(product: product),
              ),
            );
            // Refresh the screen to reflect any variant changes
            setState(() {});
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Item Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
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
                        // Category and Stock
                        Row(
                          children: [
                            Text(
                              product.category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                            ),
                            Text(
                              'Stock: $totalStock',
                              style: TextStyle(
                                fontSize: 11,
                                color: totalStock < 10 ? Colors.red : const Color(0xFF9E9E9E),
                                fontWeight: totalStock < 10 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (product.hasVariants) ...[
                              const Text(
                                ' • ',
                                style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                              ),
                              Text(
                                '${variants.length} variants',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4CAF50),
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
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}