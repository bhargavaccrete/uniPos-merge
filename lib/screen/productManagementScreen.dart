import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:excel/excel.dart'; // Add to pubspec.yaml
// import 'package:path_provider/path_provider.dart'; // Add to pubspec.yaml

// Import your utilities
import '../util/color.dart';
import '../util/responsive.dart';

import 'package:unipos/presentation/screens/retail/import_product/bulk_import_screen.dart';
import 'package:unipos/presentation/screens/retail/payment_setup_navigation_screen.dart';

// ============== PRODUCT MANAGEMENT SCREEN ==============
class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form Controllers for Manual Product Add
  final _productNameController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productSkuController = TextEditingController();
  final _productBarcodeController = TextEditingController();
  final _productStockController = TextEditingController();

  // Selected values for hierarchy
  String? _selectedCategory;
  String? _selectedVariation;
  String? _selectedExtra;
  String? _selectedChoice;
  String? _selectedTax;

  // Sample data structure
  final Map<String, List<String>> _categories = {
    'Food': ['Pizza', 'Burger', 'Pasta'],
    'Beverages': ['Coffee', 'Tea', 'Juice'],
    'Electronics': ['Mobile', 'Laptop', 'Accessories'],
  };

  final Map<String, List<String>> _variations = {
    'Pizza': ['Small', 'Medium', 'Large'],
    'Coffee': ['Hot', 'Cold'],
    'Mobile': ['128GB', '256GB', '512GB'],
  };

  final Map<String, List<String>> _extras = {
    'Pizza': ['Extra Cheese', 'Olives', 'Mushrooms'],
    'Coffee': ['Extra Shot', 'Whipped Cream'],
  };

  final Map<String, List<String>> _choices = {
    'Extra Cheese': ['Regular', 'Double'],
    'Extra Shot': ['Single', 'Double'],
  };

  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productNameController.dispose();
    _productPriceController.dispose();
    _productDescriptionController.dispose();
    _productSkuController.dispose();
    _productBarcodeController.dispose();
    _productStockController.dispose();
    super.dispose();
  }

  Future<void> _uploadExcel() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BulkImportScreen()),
    );
  }

  void _downloadTemplate() {
    // Download Excel template
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading template...'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _addProduct() {
    if (_productNameController.text.isNotEmpty &&
        _productPriceController.text.isNotEmpty &&
        _selectedCategory != null) {
      setState(() {
        _products.add(Product(
          name: _productNameController.text,
          category: _selectedCategory!,
          variation: _selectedVariation,
          extras: _selectedExtra != null ? [_selectedExtra!] : null,
          choices: _selectedChoice != null ? {_selectedExtra ?? '': _selectedChoice!} : null,
          price: double.parse(_productPriceController.text),
          sku: _productSkuController.text,
          barcode: _productBarcodeController.text,
          stock: int.tryParse(_productStockController.text) ?? 0,
          description: _productDescriptionController.text,
        ));

        // Clear form
        _productNameController.clear();
        _productPriceController.clear();
        _productDescriptionController.clear();
        _productSkuController.clear();
        _productBarcodeController.clear();
        _productStockController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Product added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Product Management',
          style: TextStyle(color: AppColors.darkNeutral),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkNeutral),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.primary),
            onPressed: _downloadTemplate,
            tooltip: 'Download Template',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, color: AppColors.success),
            onPressed: _uploadExcel,
            tooltip: 'Upload Excel',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Add Product', icon: Icon(Icons.add_box)),
            Tab(text: 'Product List', icon: Icon(Icons.inventory)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddProductTab(),
          _buildProductListTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PaymentSetupNavigationScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Next: Setup'),
      ),
    );
  }

  Widget _buildAddProductTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Excel Import Section
              _buildExcelImportCard(),
              const SizedBox(height: 20),

              // Manual Add Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit, color: AppColors.primary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Add Product Manually',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNeutral,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    // Basic Information
                    Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkNeutral,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _productNameController,
                            decoration: InputDecoration(
                              labelText: 'Product Name*',
                              prefixIcon: Icon(Icons.inventory, color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _productPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Price*',
                              prefixIcon: Icon(Icons.attach_money, color: AppColors.success),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _productDescriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description, color: AppColors.secondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Product Hierarchy
                    Text(
                      'Product Classification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkNeutral,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category*',
                        prefixIcon: Icon(Icons.category, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: _categories.keys.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _selectedVariation = null;
                          _selectedExtra = null;
                          _selectedChoice = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedVariation,
                            decoration: InputDecoration(
                              labelText: 'Variation',
                              prefixIcon: Icon(Icons.tune, color: AppColors.secondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: _selectedCategory != null && _variations.containsKey(_selectedCategory)
                                ? _variations[_selectedCategory]!.map((variation) {
                              return DropdownMenuItem(
                                value: variation,
                                child: Text(variation),
                              );
                            }).toList()
                                : [],
                            onChanged: _selectedCategory != null ? (value) {
                              setState(() {
                                _selectedVariation = value;
                              });
                            } : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedExtra,
                            decoration: InputDecoration(
                              labelText: 'Extra',
                              prefixIcon: Icon(Icons.add_circle, color: AppColors.accent),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: _selectedCategory != null && _extras.containsKey(_selectedCategory)
                                ? _extras[_selectedCategory]!.map((extra) {
                              return DropdownMenuItem(
                                value: extra,
                                child: Text(extra),
                              );
                            }).toList()
                                : [],
                            onChanged: _selectedCategory != null ? (value) {
                              setState(() {
                                _selectedExtra = value;
                                _selectedChoice = null;
                              });
                            } : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_selectedExtra != null && _choices.containsKey(_selectedExtra))
                      DropdownButtonFormField<String>(
                        value: _selectedChoice,
                        decoration: InputDecoration(
                          labelText: 'Choice',
                          prefixIcon: Icon(Icons.check_circle, color: AppColors.orange),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: _choices[_selectedExtra]!.map((choice) {
                          return DropdownMenuItem(
                            value: choice,
                            child: Text(choice),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedChoice = value;
                          });
                        },
                      ),

                    const SizedBox(height: 20),

                    // Inventory Details
                    Text(
                      'Inventory Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkNeutral,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _productSkuController,
                            decoration: InputDecoration(
                              labelText: 'SKU',
                              prefixIcon: Icon(Icons.qr_code, color: AppColors.info),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _productBarcodeController,
                            decoration: InputDecoration(
                              labelText: 'Barcode',
                              prefixIcon: Icon(Icons.barcode_reader, color: AppColors.info),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _productStockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Initial Stock',
                              prefixIcon: Icon(Icons.storage, color: AppColors.warning),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Clear form
                              _productNameController.clear();
                              _productPriceController.clear();
                              _productDescriptionController.clear();
                              _productSkuController.clear();
                              _productBarcodeController.clear();
                              _productStockController.clear();
                              setState(() {
                                _selectedCategory = null;
                                _selectedVariation = null;
                                _selectedExtra = null;
                                _selectedChoice = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: AppColors.danger),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Clear Form',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _addProduct,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExcelImportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.table_chart,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Import Products',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Download template and upload products via CSV',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BulkImportScreen()),
              );
            },
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Start Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Product List',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNeutral,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_products.length} items',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {},
                        tooltip: 'Filter',
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {},
                        tooltip: 'Search',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _products.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No products added yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add products manually or upload Excel file',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        _tabController.animateTo(0);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _products.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${product.category}${product.variation != null ? ' • ${product.variation}' : ''} • \$${product.price}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.stock > 0
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Stock: ${product.stock}',
                            style: TextStyle(
                              fontSize: 12,
                              color: product.stock > 0
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, size: 20, color: AppColors.danger),
                          onPressed: () {
                            setState(() {
                              _products.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============== DATA MODELS ==============
class TaxItem {
  final String name;
  final double rate;
  final bool isDefault;

  TaxItem(this.name, this.rate, this.isDefault);
}

class Product {
  final String name;
  final String category;
  final String? variation;
  final List<String>? extras;
  final Map<String, String>? choices;
  final double price;
  final String? sku;
  final String? barcode;
  final int stock;
  final String? description;

  Product({
    required this.name,
    required this.category,
    this.variation,
    this.extras,
    this.choices,
    required this.price,
    this.sku,
    this.barcode,
    this.stock = 0,
    this.description,
  });
}