/*
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
  final _searchController = TextEditingController();

  // Selected values for hierarchy
  String? _selectedCategory;
  String? _selectedVariation;
  String? _selectedExtra;
  String? _selectedChoice;
  String? _selectedTax;

  // Edit mode tracking
  bool _isEditMode = false;
  int? _editingIndex;

  // Search mode tracking
  bool _isSearching = false;
  String _searchQuery = '';

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
    _searchController.dispose();
    super.dispose();
  }

  // Get filtered products based on search query
  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }

    final query = _searchQuery.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
             product.category.toLowerCase().contains(query) ||
             (product.variation?.toLowerCase().contains(query) ?? false) ||
             (product.sku?.toLowerCase().contains(query) ?? false) ||
             (product.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();
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

  void _editProduct(int index) {
    final product = _products[index];

    setState(() {
      _isEditMode = true;
      _editingIndex = index;

      // Populate form with product data
      _productNameController.text = product.name;
      _productPriceController.text = product.price.toString();
      _productDescriptionController.text = product.description ?? '';
      _productSkuController.text = product.sku ?? '';
      _productBarcodeController.text = product.barcode ?? '';
      _productStockController.text = product.stock.toString();

      _selectedCategory = product.category;
      _selectedVariation = product.variation;
      _selectedExtra = product.extras?.isNotEmpty == true ? product.extras!.first : null;
      _selectedChoice = product.choices?.values.firstOrNull;
    });

    // Switch to Add Product tab
    _tabController.animateTo(0);
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _editingIndex = null;
      _clearForm();
    });
  }

  void _clearForm() {
    _productNameController.clear();
    _productPriceController.clear();
    _productDescriptionController.clear();
    _productSkuController.clear();
    _productBarcodeController.clear();
    _productStockController.clear();
    _selectedCategory = null;
    _selectedVariation = null;
    _selectedExtra = null;
    _selectedChoice = null;
  }

  void _showProductOptions(int index) {
    final product = _products[index];
    final hasVariation = product.variation != null;
    final hasExtras = product.extras?.isNotEmpty == true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.inventory, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),

              // Edit Product Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit, color: AppColors.primary),
                ),
                title: const Text('Edit Product'),
                subtitle: const Text('Edit basic product information'),
                onTap: () {
                  Navigator.pop(context);
                  _editProduct(index);
                },
              ),

              // Edit Variation Option (only if has variation)
              if (hasVariation)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune, color: AppColors.secondary),
                  ),
                  title: const Text('Edit Variation'),
                  subtitle: Text('Current: ${product.variation}'),
                  onTap: () {
                    Navigator.pop(context);
                    _editProduct(index);
                    // Could add specific variation editing logic here
                  },
                ),

              // Edit Extras Option (only if has extras)
              if (hasExtras)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_circle, color: AppColors.accent),
                  ),
                  title: const Text('Edit Extras'),
                  subtitle: Text('Extras: ${product.extras!.join(", ")}'),
                  onTap: () {
                    Navigator.pop(context);
                    _editProduct(index);
                    // Could add specific extras editing logic here
                  },
                ),

              const SizedBox(height: 8),

              // Delete Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete, color: AppColors.danger),
                ),
                title: Text(
                  'Delete Product',
                  style: TextStyle(color: AppColors.danger),
                ),
                subtitle: const Text('Permanently remove this product'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(index);
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(int index) {
    print('Edit dialog called for index: $index');

    if (index < 0 || index >= _products.length) {
      print('Invalid index: $index');
      return;
    }

    final product = _products[index];
    print('Editing product: ${product.name}');

    // Create local controllers for the dialog
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.toString());
    final descriptionController = TextEditingController(text: product.description ?? '');
    final skuController = TextEditingController(text: product.sku ?? '');
    final barcodeController = TextEditingController(text: product.barcode ?? '');
    final stockController = TextEditingController(text: product.stock.toString());

    String? selectedCategory = product.category;
    String? selectedVariation = product.variation;
    String? selectedExtra = product.extras?.isNotEmpty == true ? product.extras!.first : null;
    String? selectedChoice = product.choices?.values.isNotEmpty == true
        ? product.choices!.values.first
        : null;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            'Edit Product',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              nameController.dispose();
                              priceController.dispose();
                              descriptionController.dispose();
                              skuController.dispose();
                              barcodeController.dispose();
                              stockController.dispose();
                              Navigator.pop(dialogContext);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Form Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name and Price
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Product Name*',
                                      prefixIcon: Icon(Icons.inventory, color: AppColors.primary),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: priceController,
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

                            // Description
                            TextField(
                              controller: descriptionController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                prefixIcon: Icon(Icons.description, color: AppColors.secondary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Category
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
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
                                setDialogState(() {
                                  selectedCategory = value;
                                  selectedVariation = null;
                                  selectedExtra = null;
                                  selectedChoice = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Variation and Extra
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedVariation,
                                    decoration: InputDecoration(
                                      labelText: 'Variation',
                                      prefixIcon: Icon(Icons.tune, color: AppColors.secondary),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: selectedCategory != null && _variations.containsKey(selectedCategory)
                                        ? _variations[selectedCategory]!.map((variation) {
                                      return DropdownMenuItem(
                                        value: variation,
                                        child: Text(variation),
                                      );
                                    }).toList()
                                        : [],
                                    onChanged: selectedCategory != null ? (value) {
                                      setDialogState(() {
                                        selectedVariation = value;
                                      });
                                    } : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedExtra,
                                    decoration: InputDecoration(
                                      labelText: 'Extra',
                                      prefixIcon: Icon(Icons.add_circle, color: AppColors.accent),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: selectedCategory != null && _extras.containsKey(selectedCategory)
                                        ? _extras[selectedCategory]!.map((extra) {
                                      return DropdownMenuItem(
                                        value: extra,
                                        child: Text(extra),
                                      );
                                    }).toList()
                                        : [],
                                    onChanged: selectedCategory != null ? (value) {
                                      setDialogState(() {
                                        selectedExtra = value;
                                        selectedChoice = null;
                                      });
                                    } : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Choice (if extra is selected)
                            if (selectedExtra != null && _choices.containsKey(selectedExtra))
                              Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: selectedChoice,
                                    decoration: InputDecoration(
                                      labelText: 'Choice',
                                      prefixIcon: Icon(Icons.check_circle, color: AppColors.orange),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: _choices[selectedExtra]!.map((choice) {
                                      return DropdownMenuItem(
                                        value: choice,
                                        child: Text(choice),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setDialogState(() {
                                        selectedChoice = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),

                            // SKU, Barcode, Stock
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: skuController,
                                    decoration: InputDecoration(
                                      labelText: 'SKU',
                                      prefixIcon: Icon(Icons.qr_code, color: AppColors.info),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: barcodeController,
                                    decoration: InputDecoration(
                                      labelText: 'Barcode',
                                      prefixIcon: Icon(Icons.barcode_reader, color: AppColors.info),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Stock
                            TextField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Stock',
                                prefixIcon: Icon(Icons.storage, color: AppColors.warning),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                nameController.dispose();
                                priceController.dispose();
                                descriptionController.dispose();
                                skuController.dispose();
                                barcodeController.dispose();
                                stockController.dispose();
                                Navigator.pop(dialogContext);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: AppColors.danger),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (nameController.text.isNotEmpty &&
                                    priceController.text.isNotEmpty &&
                                    selectedCategory != null) {
                                  setState(() {
                                    _products[index] = Product(
                                      name: nameController.text,
                                      category: selectedCategory!,
                                      variation: selectedVariation,
                                      extras: selectedExtra != null ? [selectedExtra!] : null,
                                      choices: selectedChoice != null ? {selectedExtra ?? '': selectedChoice!} : null,
                                      price: double.parse(priceController.text),
                                      sku: skuController.text,
                                      barcode: barcodeController.text,
                                      stock: int.tryParse(stockController.text) ?? 0,
                                      description: descriptionController.text,
                                    );
                                  });

                                  nameController.dispose();
                                  priceController.dispose();
                                  descriptionController.dispose();
                                  skuController.dispose();
                                  barcodeController.dispose();
                                  stockController.dispose();

                                  Navigator.pop(dialogContext);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Product updated successfully'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.save),
                              label: const Text('Update Product'),
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(int index) {
    final product = _products[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
            'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _products.removeAt(index);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Product deleted successfully'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _addProduct() {
    if (_productNameController.text.isNotEmpty &&
        _productPriceController.text.isNotEmpty &&
        _selectedCategory != null) {
      setState(() {
        final product = Product(
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
        );

        if (_isEditMode && _editingIndex != null) {
          // Update existing product
          _products[_editingIndex!] = product;
          _isEditMode = false;
          _editingIndex = null;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Product updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          // Add new product
          _products.add(product);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Product added successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }

        // Clear form
        _clearForm();
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
                        Icon(
                          _isEditMode ? Icons.edit : Icons.add_box,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditMode ? 'Edit Product' : 'Add Product Manually',
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
                              setState(() {
                                if (_isEditMode) {
                                  _cancelEdit();
                                } else {
                                  _clearForm();
                                }
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
                              _isEditMode ? 'Cancel Edit' : 'Clear Form',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _addProduct,
                            icon: Icon(_isEditMode ? Icons.save : Icons.add),
                            label: Text(_isEditMode ? 'Update Product' : 'Add Product'),
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
    print('Building product list tab. Product count: ${_products.length}');
    final filteredProducts = _filteredProducts;

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
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  Row(
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
                              '${filteredProducts.length}${_searchQuery.isNotEmpty ? '/${_products.length}' : ''} items',
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
                            icon: Icon(_isSearching ? Icons.close : Icons.search),
                            onPressed: () {
                              setState(() {
                                _isSearching = !_isSearching;
                                if (!_isSearching) {
                                  _searchController.clear();
                                  _searchQuery = '';
                                }
                              });
                            },
                            tooltip: _isSearching ? 'Close Search' : 'Search',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Search Bar
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search by name, category, SKU, or barcode...',
                          prefixIcon: Icon(Icons.search, color: AppColors.primary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Product List
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
                  : filteredProducts.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No products found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredProducts.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final productIndex = _products.indexOf(product);

                      return ListTile(
                        onLongPress: () => _showProductOptions(productIndex),
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${product.category}${product.variation != null ? ' • ${product.variation}' : ''} • \$${product.price}',
                            ),
                            if (product.variation != null || product.extras?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Long press for more options',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary.withOpacity(0.7),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
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
                              onPressed: () {
                                print('Edit button tapped for index: $productIndex');
                                _showEditDialog(productIndex);
                              },
                              tooltip: 'Edit Product',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 20, color: AppColors.danger),
                              onPressed: () {
                                print('Delete button tapped for index: $productIndex');
                                _showDeleteConfirmation(productIndex);
                              },
                              tooltip: 'Delete Product',
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
}*/
