import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/util/color.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/attribute_value_model_220.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/repositories/tax_details_repository.dart';
import '../../../domain/store/common/add_product_form_store.dart';
import '../../../domain/store/retail/product_store.dart';
import '../../../domain/store/retail/attribute_store.dart';
import '../../../util/responsive.dart';
import 'package:unipos/presentation/screens/retail/import_product/bulk_import_screen.dart';
import 'package:unipos/presentation/screens/restaurant/import/restaurant_bulk_import_service.dart';
import 'package:unipos/presentation/screens/restaurant/import/bulk_import_test_screen_v3.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/category_selector_sheet.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/add_category_dialog.dart';

class AddProductScreen extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const AddProductScreen({
    Key? key,
    this.onNext,
    this.onPrevious,
  }) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AddProductFormStore _formStore;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  RestaurantBulkImportService? _restaurantImportService;

  // Lazy getter for restaurant import service
  RestaurantBulkImportService get restaurantImportService {
    _restaurantImportService ??= RestaurantBulkImportService();
    return _restaurantImportService!;
  }

  // Text Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _taxRateController = TextEditingController();

  // Retail Controllers
  final _brandController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _mrpController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _hsnCodeController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();

  // Restaurant Controllers
  final _unitController = TextEditingController();
  final _restaurantStockController = TextEditingController();

  // Bulk variant editing
  final Set<String> _selectedVariantsForBulk = {};
  final _bulkCostPriceController = TextEditingController();
  final _bulkSellingPriceController = TextEditingController();
  final _bulkStockController = TextEditingController();

  // Edit mode tracking
  String? _editingProductId;
  String? _editingRestaurantItemId;

  // Search & Filter state
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Retail Filters
  Set<String> _selectedCategories = {};
  String? _selectedProductType; // 'all', 'simple', 'variable'
  Set<String> _selectedBrands = {};
  String _retailSortBy = 'name_asc'; // 'name_asc', 'name_desc', 'recent'

  // Restaurant Filters
  String? _selectedVegFilter; // 'all', 'veg', 'non-veg'
  String? _selectedStatusFilter; // 'all', 'active', 'disabled'
  String _restaurantSortBy = 'name_asc'; // 'name_asc', 'name_desc', 'price_asc', 'price_desc'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _formStore = AddProductFormStore();

    // Load attributes from repository (including imported attributes)
    // Only for retail mode
    if (AppConfig.isRetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final attributeStore = locator<AttributeStore>();
        attributeStore.loadAttributes();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _taxRateController.dispose();
    _brandController.dispose();
    _subCategoryController.dispose();
    _mrpController.dispose();
    _costPriceController.dispose();
    _hsnCodeController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    _restaurantStockController.dispose();
    _bulkCostPriceController.dispose();
    _bulkSellingPriceController.dispose();
    _bulkStockController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _formStore.setImagePath(image.path);
      final bytes = await image.readAsBytes();
      _formStore.setImageBytes(bytes);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _taxRateController.clear();
    _brandController.clear();
    _subCategoryController.clear();
    _mrpController.clear();
    _costPriceController.clear();
    _hsnCodeController.clear();
    _skuController.clear();
    _barcodeController.clear();
    _stockController.clear();
    _minStockController.clear();
    _unitController.clear();
    _restaurantStockController.clear();
    _formStore.reset();

    // Clear edit mode
    setState(() {
      _editingProductId = null;
      _editingRestaurantItemId = null;
    });
  }

  Future<void> _submitForm() async {
    // Sync text controllers to store
    _formStore.setName(_nameController.text);
    _formStore.setDescription(_descriptionController.text);
    _formStore.setPrice(double.tryParse(_priceController.text) ?? 0);
    _formStore.setTaxRate(double.tryParse(_taxRateController.text) ?? 0);

    if (AppConfig.isRetail) {
      _formStore.setBrandName(_brandController.text.isEmpty ? null : _brandController.text);
      _formStore.setSubCategory(_subCategoryController.text.isEmpty ? null : _subCategoryController.text);
      _formStore.setMrp(double.tryParse(_mrpController.text) ?? 0);
      _formStore.setCostPrice(double.tryParse(_costPriceController.text) ?? 0);
      _formStore.setHsnCode(_hsnCodeController.text.isEmpty ? null : _hsnCodeController.text);
      _formStore.setSku(_skuController.text);
      _formStore.setBarcode(_barcodeController.text);
      _formStore.setStockQuantity(int.tryParse(_stockController.text) ?? 0);
      _formStore.setMinStock(int.tryParse(_minStockController.text) ?? 0);
    } else {
      _formStore.setUnit(_unitController.text.isEmpty ? null : _unitController.text);
      _formStore.setRestaurantStockQuantity(double.tryParse(_restaurantStockController.text) ?? 0);
    }

    bool success = false;

    // Check if we're in edit mode
    if (_editingProductId != null && AppConfig.isRetail) {
      // Update existing retail product
      success = await _updateRetailProduct();
    } else if (_editingRestaurantItemId != null && AppConfig.isRestaurant) {
      // Update existing restaurant item
      success = await _updateRestaurantItem();
    } else {
      // Add new product/item
      success = await _formStore.submit();
    }

    if (success && mounted) {
      final isEditMode = _editingProductId != null || _editingRestaurantItemId != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? (AppConfig.isRetail ? 'Product updated successfully!' : 'Item updated successfully!')
                : (AppConfig.isRetail ? 'Product added successfully!' : 'Item added successfully!'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _clearForm();
    } else if (_formStore.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formStore.errorMessage!),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ==================== UPDATE METHODS ====================

  Future<bool> _updateRetailProduct() async {
    try {
      final productStore = locator<ProductStore>();

      // Create updated product
      final product = ProductModel.fromProduct(
        productId: _editingProductId!,
        productName: _formStore.name.trim(),
        category: _formStore.selectedCategoryId!,
        subCategory: _formStore.subCategory,
        brandName: _formStore.brandName,
        imagePath: _formStore.imagePath,
        description: _formStore.description.isNotEmpty ? _formStore.description : null,
        hasVariants: _formStore.isVariableProduct,
        productType: _formStore.productType,
        defaultPrice: _formStore.isSimpleProduct ? _formStore.price : null,
        defaultMrp: _formStore.isSimpleProduct ? _formStore.mrp : null,
        defaultCostPrice: _formStore.isSimpleProduct ? _formStore.costPrice : null,
        gstRate: _formStore.taxRate > 0 ? _formStore.taxRate : null,
        hsnCode: _formStore.hsnCode,
      );

      // Update product in database
      await productStore.updateProduct(product);

      // Update or create variants
      if (_formStore.isVariableProduct) {
        // For variable products, update/create all variants from the form
        for (final variantData in _formStore.retailVariants) {
          final variant = VarianteModel.create(
            varianteId: variantData.id,
            productId: _editingProductId!,
            sku: variantData.sku,
            barcode: variantData.barcode,
            size: variantData.attributes['Size'],
            color: variantData.attributes['Color'],
            weight: variantData.attributes['Weight'],
            customAttributes: variantData.attributes,
            attributeValueIds: variantData.attributeValueIds,
            mrp: variantData.mrp,
            costPrice: variantData.costPrice,
            sellingPrice: variantData.price,
            stockQty: variantData.stockQuantity,
            minStock: _formStore.minStock,
            taxRate: _formStore.taxRate > 0 ? _formStore.taxRate : null,
          );

          // Check if variant exists, if so update, otherwise add
          final existingVariant = await productStore.getVariantById(variantData.id);
          if (existingVariant != null) {
            await productStore.updateVariant(variant);
          } else {
            await productStore.addVariant(variant);
          }
        }
      } else {
        // For simple products, update the default variant
        final variants = await productStore.getVariantsForProduct(_editingProductId!);
        if (variants.isNotEmpty) {
          final defaultVariant = variants.firstWhere(
                (v) => v.isDefault,
            orElse: () => variants.first,
          );

          final updatedVariant = defaultVariant.copyWith(
            sku: _formStore.sku,
            barcode: _formStore.barcode,
            mrp: _formStore.mrp,
            costPrice: _formStore.costPrice,
            sellingPrice: _formStore.price,
            stockQty: _formStore.stockQuantity,
            minStock: _formStore.minStock,
            taxRate: _formStore.taxRate > 0 ? _formStore.taxRate : null,
          );

          await productStore.updateVariant(updatedVariant);
        }
      }

      return true;
    } catch (e) {
      _formStore.errorMessage = 'Failed to update product: $e';
      return false;
    }
  }

  Future<bool> _updateRestaurantItem() async {
    try {
      // Get all items from store
      await itemStore.loadItems();
      final allItems = itemStore.items.toList();

      // Get the existing item to preserve fields not in the form
      final existingItem = allItems.firstWhere(
            (item) => item.id == _editingRestaurantItemId,
      );

      // Convert image path to bytes if a new image was selected
      Uint8List? imageBytes = existingItem.imageBytes; // Keep existing bytes by default
      
      if (_formStore.imageBytes != null) {
        imageBytes = _formStore.imageBytes;
      } else if (_formStore.imagePath != null && _formStore.imagePath!.isNotEmpty) {
        try {
          final file = File(_formStore.imagePath!);
          if (file.existsSync()) {
            imageBytes = await file.readAsBytes();
          }
        } catch (e) {
          print('Error reading image bytes: $e');
        }
      }

      // Create updated item
      final updatedItem = existingItem.copyWith(
        name: _formStore.name.trim(),
        description: _formStore.description.isNotEmpty ? _formStore.description : null,
        categoryOfItem: _formStore.selectedCategoryId,
        imageBytes: imageBytes,
        price: _formStore.hasPortionSizes ? null : _formStore.price,
        taxRate: _formStore.taxRate > 0 ? _formStore.taxRate : null,
        unit: _formStore.unit,
        isVeg: _formStore.isVeg,
        trackInventory: _formStore.trackInventory,
        stockQuantity: _formStore.trackInventory && !_formStore.hasPortionSizes
            ? _formStore.restaurantStockQuantity
            : null,
        allowOrderWhenOutOfStock: _formStore.allowOrderWhenOutOfStock,
        isSoldByWeight: _formStore.isSoldByWeight,
        lastEditedTime: DateTime.now(),
      );

      // Update item in database
      await itemStore.updateItem(updatedItem);

      return true;
    } catch (e) {
      _formStore.errorMessage = 'Failed to update item: $e';
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAddProductTab(isDesktop, isTablet, isMobile),
                _buildProductListTab(),
              ],
            ),
          ),
          // Setup Wizard Navigation (shown only when callbacks are provided)
          if (widget.onNext != null && widget.onPrevious != null)
            _buildSetupWizardNavigation(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final title = AppConfig.isRetail ? 'Product Management' : 'Menu Management';

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(color: AppColors.darkNeutral),
      ),
      // leading: IconButton(
      //   icon: const Icon(Icons.arrow_back, color: AppColors.darkNeutral),
      //   onPressed: () => Navigator.pop(context),
      // ),
      actions: [
        IconButton(
          icon: const Icon(Icons.download, color: AppColors.primary),
          onPressed: () => _downloadTemplate(),
          tooltip: 'Download Template',
        ),
        IconButton(
          icon: const Icon(Icons.upload_file, color: AppColors.success),
          onPressed: () => _uploadExcel(),
          tooltip: 'Upload Excel',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        tabs: [
          Tab(
            text: AppConfig.isRetail ? 'Add Product' : 'Add Item',
            icon: const Icon(Icons.add_box),
          ),
          Tab(
            text: AppConfig.isRetail ? 'Product List' : 'Item List',
            icon: const Icon(Icons.inventory),
          ),
        ],
      ),
    );
  }

  Widget _buildAddProductTab(bool isDesktop, bool isTablet, bool isMobile) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Excel Import Card
                if (AppConfig.isRetail) _buildExcelImportCard(),
                const SizedBox(height: 24),

                // Main Form Card
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                      // Header
                      _buildSectionHeader(
                        icon: Icons.edit,
                        title: AppConfig.isRetail ? 'Add Product Manually' : 'Add Menu Item',
                      ),
                      const Divider(height: 30),

                      // Section 1: Basic Information
                      _buildBasicInfoSection(isMobile),
                      const SizedBox(height: 24),

                      // Section 2: Pricing & Tax
                      _buildPricingSection(isMobile),
                      const SizedBox(height: 24),

                      // Section 3: Variants/Sizes (Dynamic)
                      if (AppConfig.isRetail)
                        _buildRetailVariantsSection(isMobile)
                      else
                        _buildRestaurantSizesSection(isMobile),
                      const SizedBox(height: 24),

                      // Section 4: Customization (Restaurant Only)
                      if (AppConfig.isRestaurant) ...[
                        _buildCustomizationSection(isMobile),
                        const SizedBox(height: 24),
                      ],

                      // Section 5: Inventory
                      _buildInventorySection(isMobile),
                      const SizedBox(height: 24),

                      // Section 6: Identification (Retail Only)
                      if (AppConfig.isRetail) ...[
                        _buildIdentificationSection(isMobile),
                        const SizedBox(height: 24),
                      ],

                      // Action Buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkNeutral,
          ),
        ),
      ],
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkNeutral,
        ),
      ),
    );
  }

  // ==================== SECTION 1: BASIC INFO ====================

  Widget _buildBasicInfoSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSectionTitle('Basic Information'),

        // Image Picker
        _buildImagePicker(),
        const SizedBox(height: 16),

        // Name & Price Row
        if (isMobile)
          Column(
            children: [
              _buildTextField(
                controller: _nameController,
                label: AppConfig.isRetail ? 'Product Name*' : 'Item Name*',
                icon: Icons.inventory,
              ),
              const SizedBox(height: 16),
              // Show price field only for Restaurant mode (for Retail, it's in Pricing & Tax section)
              if (AppConfig.isRestaurant && !_formStore.hasPortionSizes)
                _buildTextField(
                  controller: _priceController,
                  label: 'Price*',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  iconColor: AppColors.success,
                ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _nameController,
                  label: AppConfig.isRetail ? 'Product Name*' : 'Item Name*',
                  icon: Icons.inventory,
                ),
              ),
              const SizedBox(width: 16),
              // Show price field only for Restaurant mode (for Retail, it's in Pricing & Tax section)
              Expanded(
                child: Observer(
                  builder: (_) => (AppConfig.isRestaurant && !_formStore.hasPortionSizes)
                      ? _buildTextField(
                    controller: _priceController,
                    label: 'Price*',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    iconColor: AppColors.success,
                  )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),

        // Category Dropdown
        _buildCategoryDropdown(),
        const SizedBox(height: 16),

        // Retail-specific fields
        if (AppConfig.isRetail) ...[
          if (isMobile)
            Column(
              children: [
                _buildTextField(
                  controller: _brandController,
                  label: 'Brand Name',
                  icon: Icons.business,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _subCategoryController,
                  label: 'Sub-category',
                  icon: Icons.category_outlined,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _brandController,
                    label: 'Brand Name',
                    icon: Icons.business,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _subCategoryController,
                    label: 'Sub-category',
                    icon: Icons.category_outlined,
                  ),
                ),
              ],
            ),
        ],

        // Restaurant-specific fields
        if (AppConfig.isRestaurant) ...[
          if (isMobile)
            Column(
              children: [
                _buildTextField(
                  controller: _unitController,
                  label: 'Unitt (e.g., pcs, kg)',
                  icon: Icons.straighten,
                ),
                const SizedBox(height: 16),
                _buildVegToggle(),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _unitController,
                    label: 'Unit (e.g., pcs, kg)',
                    icon: Icons.straighten,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildVegToggle()),
              ],
            ),
        ],

        const SizedBox(height: 16),

        // Description
        _buildTextField(
          controller: _descriptionController,
          label: 'Description',
          icon: Icons.description,
          maxLines: 3,
          iconColor: AppColors.secondary,
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Observer(
      builder: (_) => GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _formStore.imageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _formStore.imageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                )
              : _formStore.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_formStore.imagePath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'Tap to add image',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVegToggle() {
    return Observer(
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.eco, color: AppColors.success),
            const SizedBox(width: 12),
            const Text('Type: '),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Veg'),
              selected: _formStore.isVeg == 'veg',
              onSelected: (_) => _formStore.setIsVeg('veg'),
              selectedColor: AppColors.success.withOpacity(0.2),
              avatar: _formStore.isVeg == 'veg'
                  ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            ChoiceChip(

              label: const Text('Non-Veg'),
              selected: _formStore.isVeg == 'non-veg',
              onSelected: (_) => _formStore.setIsVeg('non-veg'),
              selectedColor: AppColors.danger.withOpacity(0.2),
              avatar: _formStore.isVeg == 'non-veg'
                  ? const Icon(Icons.check_circle, color: AppColors.danger, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    if (AppConfig.isRetail) {
      final productStore = locator<ProductStore>();
      return Observer(
        builder: (_) {
          // Ensure the selected value is valid or null
          final selectedValue = productStore.categories.contains(_formStore.selectedCategoryId)
              ? _formStore.selectedCategoryId
              : null;

          return DropdownButtonFormField<String>(
            value: selectedValue,
            decoration: InputDecoration(
              labelText: 'Category*',
              prefixIcon: const Icon(Icons.category, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: productStore.categories.map((category) {
              return DropdownMenuItem(value: category, child: Text(category));
            }).toList(),
            onChanged: (value) => _formStore.setSelectedCategoryId(value),
            hint: const Text('Select category'),
          );
        },
      );
    } else {
      // Restaurant mode - use category store
      return Observer(
        builder: (_) {
          final categories = categoryStore.categories.toList();
          final categoryIds = categories.map((c) => c.id).toList();

          // Ensure selected value is valid
          final selectedValue = categoryIds.contains(_formStore.selectedCategoryId)
              ? _formStore.selectedCategoryId
              : null;

          return InkWell(
            onTap: () async {
              // Show category selector bottom sheet
              final result = await CategorySelectorSheet.show(
                context,
                selectedCategoryId: selectedValue,
                onAddCategory: () async {
                  Navigator.pop(context);
                  await AddCategoryDialog.show(context);
                },
              );

              if (result != null) {
                setState(() {
                  _formStore.setSelectedCategoryId(result.id);
                });
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Category*',
                prefixIcon: const Icon(Icons.category, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                selectedValue != null && categories.isNotEmpty
                    ? categories.firstWhere((c) => c.id == selectedValue, orElse: () => categories.first).name
                    : 'Select or Add Category',
                style: TextStyle(
                  color: selectedValue != null ? Colors.black : Colors.grey[600],
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildGstDropdown() {
    // Fetch tax rates from saved tax details (for retail)
    final taxDetailsRepo = locator<TaxDetailsRepository>();
    final savedTax = taxDetailsRepo.get();

    // Get tax rates from saved details, or use default if none saved
    List<String> gstRates = [];
    if (savedTax != null && savedTax.taxRates != null && savedTax.taxRates!.isNotEmpty) {
      gstRates = savedTax.taxRates!.map((tax) => tax.rate.toString()).toList();
    } else {
      // Fallback to common GST rates if no tax rates were added during setup
      gstRates = ['0', '5', '12', '18', '28'];
    }

    return DropdownButtonFormField<String>(
      value: _taxRateController.text.isEmpty ? null : _taxRateController.text,
      decoration: InputDecoration(
        labelText: 'GST Rate (%)',
        prefixIcon: const Icon(Icons.percent, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: gstRates.map((rate) {
        return DropdownMenuItem(
          value: rate,
          child: Text('$rate%'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _taxRateController.text = value ?? '';
        });
      },
      hint: const Text('Select GST rate'),
    );
  }

  Widget _buildRestaurantTaxDropdown() {
    // Use tax store to access taxes
    final taxes = taxStore.taxes.toList();

    List<Map<String, String>> taxRates = [
      {'id': '', 'name': 'No Tax', 'rate': '0'},
    ];

    taxRates.addAll(
      taxes.map((tax) => {
        'id': tax.id,
        'name': tax.taxname,
        'rate': tax.taxperecentage.toString(),
      }),
    );

    // Find current selected value
    final currentValue = _taxRateController.text.isEmpty ? null : _taxRateController.text;

    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: 'Tax Rate',
        prefixIcon: const Icon(Icons.receipt_outlined, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: taxRates.map<DropdownMenuItem<String>>((tax) {
        return DropdownMenuItem<String>(
          value: tax['rate']!,
          child: Text('${tax['name']} (${tax['rate']}%)'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _taxRateController.text = value ?? '';
        });
      },
      hint: const Text('Select tax rate'),
    );
  }

  // ==================== SECTION 2: PRICING ====================

  Widget _buildPricingSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSectionTitle('Pricing & Tax'),

        // GST/Tax Rate Dropdown for both Retail and Restaurant
        if (isMobile)
          AppConfig.isRetail
              ? _buildGstDropdown()
              : _buildRestaurantTaxDropdown()
        else
          Row(
            children: [
              Expanded(
                child: AppConfig.isRetail
                    ? _buildGstDropdown()
                    : _buildRestaurantTaxDropdown(),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),

        // Retail-specific pricing (only for Simple products, not Variable)
        if (AppConfig.isRetail) ...[
          const SizedBox(height: 16),
          Observer(
            builder: (_) {
              // Hide pricing fields for Variable products (prices are set per variant)
              final isVariable = _formStore.productType == 'variable';

              if (isVariable) {
                // For variable products, show info message and HSN Code only
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Prices will be set individually for each variant',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _hsnCodeController,
                      label: 'HSN Code',
                      icon: Icons.qr_code_2,
                    ),
                  ],
                );
              }

              // For simple products, show all pricing fields
              return isMobile
                  ? Column(
                children: [
                  _buildTextField(
                    controller: _costPriceController,
                    label: 'Cost Price*',
                    icon: Icons.money_off,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _priceController,
                    label: 'Selling Price*',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    iconColor: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _mrpController,
                    label: 'MRP',
                    icon: Icons.price_check,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _hsnCodeController,
                    label: 'HSN Code',
                    icon: Icons.qr_code_2,
                  ),
                ],
              )
                  : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _costPriceController,
                          label: 'Cost Price*',
                          icon: Icons.money_off,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'Selling Price*',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                          iconColor: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _mrpController,
                          label: 'MRP',
                          icon: Icons.price_check,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _hsnCodeController,
                          label: 'HSN Code',
                          icon: Icons.qr_code_2,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(child: SizedBox.shrink()),
                      const SizedBox(width: 16),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ],
              );
            },
          ),

          // Profit Margin Display
          const SizedBox(height: 16),
          Observer(
            builder: (_) {
              final costPrice = double.tryParse(_costPriceController.text) ?? 0;
              final price = double.tryParse(_priceController.text) ?? 0;
              if (costPrice > 0 && price > 0) {
                final profit = price - costPrice;
                final margin = (profit / costPrice) * 100;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: profit >= 0 ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        profit >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: profit >= 0 ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Profit: ₹${profit.toStringAsFixed(2)} (${margin.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: profit >= 0 ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ],
    );
  }

  // ==================== SECTION 3: VARIANTS ====================

  Widget _buildRetailVariantsSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSectionTitle('Product Variants'),

        // Product Type Toggle
        Observer(
          builder: (_) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('Product Type: ', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Simple'),
                  selected: _formStore.productType == 'simple',
                  onSelected: (_) => _formStore.setProductType('simple'),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Variable'),
                  selected: _formStore.productType == 'variable',
                  onSelected: (_) => _formStore.setProductType('variable'),
                  selectedColor: AppColors.secondary.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ),

        // Variable Product Options
        Observer(
          builder: (_) {
            if (_formStore.productType != 'variable') {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildAttributeSelector(),
                const SizedBox(height: 16),
                _buildVariantsList(isMobile),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttributeSelector() {
    final attributeStore = locator<AttributeStore>();

    return Observer(
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Attributes:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              TextButton.icon(
                onPressed: () => _showAddAttributeDialog(attributeStore),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Attribute'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show message if no attributes
          if (attributeStore.attributes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'No attributes found',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Attributes define product variants like Size, Color, Material, etc.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _createDefaultAttributes(attributeStore),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Create Default Attributes (Size, Color, Weight)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attributeStore.attributes.map((attr) {
                final isSelected = _formStore.selectedAttributeIds.contains(attr.attributeId);
                return FilterChip(
                  label: Text(attr.name),
                  selected: isSelected,
                  onSelected: (_) => _formStore.toggleAttribute(attr.attributeId),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                );
              }).toList(),
            ),

          // Show values for selected attributes
          ..._formStore.selectedAttributeIds.map((attrId) {
            final attr = attributeStore.attributes.firstWhere((a) => a.attributeId == attrId);
            final values = attributeStore.getValuesForAttribute(attrId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('${attr.name} Values:', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: values.map((val) {
                    final isSelected = _formStore.selectedAttributeValues[attrId]?.contains(val.valueId) ?? false;
                    return FilterChip(
                      label: Text(val.value),
                      selected: isSelected,
                      onSelected: (_) => _formStore.toggleAttributeValue(attrId, val.valueId),
                      selectedColor: AppColors.secondary.withOpacity(0.2),
                      avatar: val.colorCode != null
                          ? CircleAvatar(
                        backgroundColor: _parseColor(val.colorCode!),
                        radius: 10,
                      )
                          : null,
                    );
                  }).toList(),
                ),
              ],
            );
          }),

          // Generate Variants Button
          if (_formStore.selectedAttributeIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _showVariantGenerationDialog(attributeStore);
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Variants'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildVariantsList(bool isMobile) {
    return Observer(
      builder: (_) {
        if (_formStore.retailVariants.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No variants yet. Select attributes and generate variants.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Variants (${_formStore.retailVariants.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Bulk Edit Bar
            _buildBulkEditBar(isMobile),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _formStore.retailVariants.length,
              itemBuilder: (context, index) {
                final variant = _formStore.retailVariants[index];
                return _buildVariantCard(variant, index, isMobile);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulkEditBar(bool isMobile) {
    // Cache variant count to avoid accessing observable list multiple times
    final variantCount = _formStore.retailVariants.length;
    final allSelected = variantCount > 0 && _selectedVariantsForBulk.length == variantCount;
    final noneSelected = _selectedVariantsForBulk.isEmpty;
    final selectedCount = _selectedVariantsForBulk.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Select All / Unselect All
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFF57C00), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bulk Edit - $selectedCount / $variantCount selected',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF57C00),
                  ),
                ),
              ),
              TextButton(
                onPressed: allSelected
                    ? null
                    : () {
                  setState(() {
                    _selectedVariantsForBulk.clear();
                    // Create a copy of the list to avoid concurrent modification
                    final variants = _formStore.retailVariants.toList();
                    for (var v in variants) {
                      _selectedVariantsForBulk.add(v.id);
                    }
                  });
                },
                child: Text(
                  'Select All',
                  style: TextStyle(
                    fontSize: 12,
                    color: allSelected ? Colors.grey : const Color(0xFFF57C00),
                  ),
                ),
              ),
              const Text(' | ', style: TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: noneSelected
                    ? null
                    : () {
                  setState(() {
                    _selectedVariantsForBulk.clear();
                  });
                },
                child: Text(
                  'Unselect All',
                  style: TextStyle(
                    fontSize: 12,
                    color: noneSelected ? Colors.grey : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bulk pricing fields
          if (isMobile)
            Column(
              children: [
                TextField(
                  controller: _bulkCostPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bulkSellingPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Selling Price',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bulkStockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bulkCostPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bulkSellingPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bulkStockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock',
                      hintText: '0',
                      border: OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              onPressed: _applyBulkPricing,
              icon: const Icon(Icons.done_all),
              label: const Text('Apply to Selected Variants'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF57C00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Workflow: 1) Enter price/stock above  2) Select variants  3) Click Apply. Fields will clear automatically for next group. You can repeat for different prices.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _applyBulkPricing() {
    final costPrice = double.tryParse(_bulkCostPriceController.text);
    final sellingPrice = double.tryParse(_bulkSellingPriceController.text);
    final stock = int.tryParse(_bulkStockController.text);

    if (costPrice == null && sellingPrice == null && stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one value to apply'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedVariantsForBulk.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one variant'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedCount = _selectedVariantsForBulk.length;

    // Create a copy of selected IDs to avoid concurrent modification
    final selectedIds = Set<String>.from(_selectedVariantsForBulk);

    // Apply to selected variants
    try {
      for (int i = 0; i < _formStore.retailVariants.length; i++) {
        final variant = _formStore.retailVariants[i];
        if (selectedIds.contains(variant.id)) {
          _formStore.updateRetailVariant(
            i,
            variant.copyWith(
              costPrice: costPrice ?? variant.costPrice,
              price: sellingPrice ?? variant.price,
              stockQuantity: stock ?? variant.stockQuantity,
            ),
          );
        }
      }

      // Clear inputs and selections for next group
      setState(() {
        _bulkCostPriceController.clear();
        _bulkSellingPriceController.clear();
        _bulkStockController.clear();
        _selectedVariantsForBulk.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Applied to $selectedCount variant(s). Ready for next group.'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying bulk pricing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildVariantCard(VariantFormData variant, int index, bool isMobile) {
    final isSelected = _selectedVariantsForBulk.contains(variant.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.orange.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.orange : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedVariantsForBulk.add(variant.id);
              } else {
                _selectedVariantsForBulk.remove(variant.id);
              }
            });
          },
          activeColor: Colors.orange,
        ),
        title: Text(variant.name.isEmpty ? 'Variant ${index + 1}' : variant.name),
        subtitle: Text('Price: ₹${variant.price} | Stock: ${variant.stockQuantity}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: AppColors.danger),
          onPressed: () => _formStore.removeRetailVariant(index),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isMobile)
                  Column(
                    children: [
                      TextFormField(
                        initialValue: variant.sku,
                        decoration: const InputDecoration(
                          labelText: 'SKU',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(sku: v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: variant.barcode,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(barcode: v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: variant.price.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(price: double.tryParse(v) ?? 0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: variant.stockQuantity.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(stockQuantity: int.tryParse(v) ?? 0),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: variant.sku,
                          decoration: const InputDecoration(
                            labelText: 'SKU',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _formStore.updateRetailVariant(
                            index,
                            variant.copyWith(sku: v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: variant.barcode,
                          decoration: const InputDecoration(
                            labelText: 'Barcode',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _formStore.updateRetailVariant(
                            index,
                            variant.copyWith(barcode: v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: variant.price.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _formStore.updateRetailVariant(
                            index,
                            variant.copyWith(price: double.tryParse(v) ?? 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: variant.stockQuantity.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Stock',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _formStore.updateRetailVariant(
                            index,
                            variant.copyWith(stockQuantity: int.tryParse(v) ?? 0),
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
    );
  }

  Widget _buildRestaurantSizesSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSectionTitle('Variants'),

        // Has Variants Toggle
        Observer(
          builder: (_) => SwitchListTile(
            title: const Text('Has Multiple Variants'),
            subtitle: const Text('Enable if item has different sizes (Small, Medium, Large)'),
            value: _formStore.hasPortionSizes,
            onChanged: (v) => _formStore.setHasPortionSizes(v),
            activeColor: AppColors.primary,
          ),
        ),

        // Variants List
        Observer(
          builder: (_) {
            if (!_formStore.hasPortionSizes) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                const SizedBox(height: 16),
                ..._formStore.portionSizes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final size = entry.value;
                  return _buildPortionSizeCard(size, index, isMobile);
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _formStore.addPortionSize(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Variant'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPortionSizeCard(PortionSizeFormData size, int index, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: size.name,
                decoration: InputDecoration(
                  labelText: 'Variant Name',
                  hintText: 'e.g., Small, Medium, Large',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                onChanged: (v) => _formStore.updatePortionSize(
                  index,
                  size.copyWith(name: v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: size.price > 0 ? size.price.toString() : '',
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: '₹',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _formStore.updatePortionSize(
                  index,
                  size.copyWith(price: double.tryParse(v) ?? 0),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_formStore.trackInventory)
              Expanded(
                child: TextFormField(
                  initialValue: size.stockQuantity > 0 ? size.stockQuantity.toString() : '',
                  decoration: InputDecoration(
                    labelText: 'Stock',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _formStore.updatePortionSize(
                    index,
                    size.copyWith(stockQuantity: double.tryParse(v) ?? 0),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.danger),
              onPressed: () => _formStore.removePortionSize(index),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SECTION 4: CUSTOMIZATION (RESTAURANT) ====================

  Widget _buildCustomizationSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSectionTitle('Customization Options'),

        // Choice Groups
        _buildChoiceGroupsSelector(),
        const SizedBox(height: 16),

        // Extra Groups
        _buildExtraGroupsSelector(),
      ],
    );
  }

  Widget _buildChoiceGroupsSelector() {
    return Observer(
      builder: (context) {
        final choices = choiceStore.choices.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choice Groups (Free Selections)',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (choices.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No choice groups available. Create them in settings.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: choices.map((choice) {
                  final isSelected = _formStore.selectedChoiceIds.contains(choice.id);
                  return FilterChip(
                    label: Text(choice.name),
                    selected: isSelected,
                    onSelected: (_) => _formStore.toggleChoiceGroup(choice.id),
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    avatar: isSelected
                        ? const Icon(Icons.check_circle, size: 18, color: AppColors.primary)
                        : const Icon(Icons.radio_button_unchecked, size: 18),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildExtraGroupsSelector() {
    return Observer(
      builder: (context) {
        final extras = extraStore.extras.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Extra Groups (Paid Add-ons)',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (extras.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No extra groups available. Create them in settings.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Column(
                children: extras.map((extra) {
                  final isSelected = _formStore.selectedExtraIds.contains(extra.Id);
                  final constraint = _formStore.extraConstraints[extra.Id];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      title: Text(extra.Ename),
                      subtitle: isSelected && constraint != null
                          ? Row(
                        children: [
                          const Text('Min: '),
                          SizedBox(
                            width: 50,
                            child: TextFormField(
                              initialValue: constraint.min.toString(),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _formStore.setExtraConstraint(
                                extra.Id,
                                int.tryParse(v) ?? 0,
                                constraint.max,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text('Max: '),
                          SizedBox(
                            width: 50,
                            child: TextFormField(
                              initialValue: constraint.max.toString(),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _formStore.setExtraConstraint(
                                extra.Id,
                                constraint.min,
                                int.tryParse(v) ?? 5,
                              ),
                            ),
                          ),
                        ],
                      )
                          : Text('${extra.topping?.length ?? 0} toppings'),
                      value: isSelected,
                      onChanged: (_) => _formStore.toggleExtraGroup(extra.Id),
                      activeColor: AppColors.primary,
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }

  // ==================== SECTION 5: INVENTORY ====================

  Widget _buildInventorySection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSectionTitle('Inventory Details'),

        if (AppConfig.isRetail) ...[
          // Retail Inventory (Simple product only)
          Observer(
            builder: (_) {
              if (_formStore.productType == 'variable') {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Stock is managed per variant for variable products.',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return isMobile
                  ? Column(
                children: [
                  _buildTextField(
                    controller: _stockController,
                    label: 'Initial Stock',
                    icon: Icons.inventory_2,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _minStockController,
                    label: 'Min Stock (Alert)',
                    icon: Icons.warning_amber,
                    keyboardType: TextInputType.number,
                    iconColor: AppColors.warning,
                  ),
                ],
              )
                  : Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _stockController,
                      label: 'Initial Stock',
                      icon: Icons.inventory_2,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _minStockController,
                      label: 'Min Stock (Alert)',
                      icon: Icons.warning_amber,
                      keyboardType: TextInputType.number,
                      iconColor: AppColors.warning,
                    ),
                  ),
                ],
              );
            },
          ),
        ] else ...[
          // Restaurant Inventory Options
          Observer(
            builder: (_) => Column(
              children: [
                SwitchListTile(
                  title: const Text('Track Inventory'),
                  subtitle: const Text('Enable stock tracking for this item'),
                  value: _formStore.trackInventory,
                  onChanged: (v) => _formStore.setTrackInventory(v),
                  activeColor: AppColors.primary,
                ),

                if (_formStore.trackInventory && !_formStore.hasPortionSizes) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _restaurantStockController,
                    label: 'Stock Quantity',
                    icon: Icons.inventory_2,
                    keyboardType: TextInputType.number,
                  ),
                ],

                // Only show "Allow Order When Out of Stock" if tracking inventory
                if (_formStore.trackInventory)
                  SwitchListTile(
                    title: const Text('Allow Order When Out of Stock'),
                    subtitle: const Text('Customers can still order when stock is 0'),
                    value: _formStore.allowOrderWhenOutOfStock,
                    onChanged: (v) => _formStore.setAllowOrderWhenOutOfStock(v),
                    activeColor: AppColors.warning,
                  ),

                SwitchListTile(
                  title: const Text('Sold by Weight'),
                  subtitle: const Text('Item is priced by weight (kg, grams)'),
                  value: _formStore.isSoldByWeight,
                  onChanged: (v) => _formStore.setIsSoldByWeight(v),
                  activeColor: AppColors.secondary,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==================== SECTION 6: IDENTIFICATION (RETAIL) ====================

  Widget _buildIdentificationSection(bool isMobile) {
    return Observer(
      builder: (_) {
        if (_formStore.productType == 'variable') {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'SKU and Barcode are managed per variant for variable products.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubSectionTitle('Product Identification'),
            if (isMobile)
              Column(
                children: [
                  _buildTextField(
                    controller: _skuController,
                    label: 'SKU',
                    icon: Icons.qr_code,
                    iconColor: AppColors.info,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.auto_awesome),
                      onPressed: () {
                        // Auto-generate SKU
                        final sku = 'SKU-${DateTime.now().millisecondsSinceEpoch}';
                        _skuController.text = sku;
                      },
                      tooltip: 'Auto-generate',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _barcodeController,
                    label: 'Barcode',
                    icon: Icons.barcode_reader,
                    iconColor: AppColors.info,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () {
                        // Scan barcode
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Barcode scanner coming soon')),
                        );
                      },
                      tooltip: 'Scan',
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _skuController,
                      label: 'SKU',
                      icon: Icons.qr_code,
                      iconColor: AppColors.info,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: () {
                          final sku = 'SKU-${DateTime.now().millisecondsSinceEpoch}';
                          _skuController.text = sku;
                        },
                        tooltip: 'Auto-generate',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _barcodeController,
                      label: 'Barcode',
                      icon: Icons.barcode_reader,
                      iconColor: AppColors.info,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Barcode scanner coming soon')),
                          );
                        },
                        tooltip: 'Scan',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  // ==================== ACTION BUTTONS ====================

  Widget _buildActionButtons() {
    // Determine if we're in edit mode
    final isEditMode = _editingProductId != null || _editingRestaurantItemId != null;

    return Observer(
      builder: (_) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _formStore.isLoading ? null : _clearForm,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Clear Form',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _formStore.isLoading ? null : _submitForm,
              icon: _formStore.isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Icon(isEditMode ? Icons.update : Icons.add),
              label: Text(
                isEditMode
                    ? (AppConfig.isRetail ? 'Update Product' : 'Update Item')
                    : (AppConfig.isRetail ? 'Add Product' : 'Add Item'),
              ),
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
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color? iconColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: iconColor ?? AppColors.primary),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
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
          const Icon(
            Icons.table_chart,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bulk Import via Excel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConfig.isRetail
                      ? 'Upload multiple products at once using Excel'
                      : 'Upload multiple menu items at once using Excel',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (AppConfig.isRestaurant) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BulkImportTestScreenV3(),
                  ),
                );
              },
              icon: const Icon(Icons.science, size: 18),
              label: const Text('Test V3'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
          ],
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

  void _downloadTemplate() async {
    if (AppConfig.isRetail) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BulkImportScreen(),
        ),
      );
    } else if (AppConfig.isRestaurant) {
      final message = await restaurantImportService.downloadTemplate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: message.startsWith('Error') || message == 'Permission denied'
                ? AppColors.danger
                : AppColors.success,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bulk import is not available for this mode'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _uploadExcel() async {
    if (AppConfig.isRetail) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BulkImportScreen(),
        ),
      );
    } else if (AppConfig.isRestaurant) {
      try {
        final allSheets = await restaurantImportService.pickAndParseFile();
        if (allSheets.isNotEmpty) {
          // Count total rows from Items sheet
          final itemsSheet = allSheets['Items'];
          final itemCount = (itemsSheet?.length ?? 1) - 1; // Subtract header row

          // Show confirmation dialog with preview
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Import Data from ${allSheets.length} Sheets?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sheets found: ${allSheets.keys.join(', ')}'),
                    const SizedBox(height: 10),
                    if (itemCount > 0) Text('Items to import: $itemCount'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Get the navigator before closing any dialogs
                    final navigator = Navigator.of(context, rootNavigator: true);

                    Navigator.pop(context);

                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final result = await restaurantImportService.importData(allSheets);

                      // Close loading dialog using the saved navigator reference
                      try {
                        navigator.pop();
                      } catch (e) {
                        print('Error closing loading dialog: $e');
                      }

                      if (!mounted) return;

                      // Show detailed result dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(result.success ? '✅ Import Successful' : '⚠️ Import Completed with Issues'),
                          content: SingleChildScrollView(
                            child: Text(result.getSummary()),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );

                      // Data is already saved to Hive by the import service
                      // Force a complete rebuild by popping all dialogs and refreshing
                      if (mounted) {
                        // Add a small delay to ensure all Hive listeners are triggered
                        await Future.delayed(const Duration(milliseconds: 200));
                        setState(() {});

                        // Notify user to navigate to manage menu
                        if (result.success && result.itemsImported > 0) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('✅ Import successful! Go to "Manage Menu" to view all imported items.'),
                                  duration: const Duration(seconds: 5),
                                  backgroundColor: Colors.green,
                                  action: SnackBarAction(
                                    label: 'Got it',
                                    textColor: Colors.white,
                                    onPressed: () {},
                                  ),
                                ),
                              );
                            }
                          });
                        }
                      }
                    } catch (e) {
                      if (!mounted) return;

                      // Close loading dialog
                      Navigator.of(context, rootNavigator: true).pop();

                      // Show error dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('❌ Import Failed'),
                          content: Text('Error during import: $e'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Import'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import failed: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bulk import is not available for this mode'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  // ==================== EDIT FUNCTIONS ====================

  Future<void> _editRetailProduct(ProductModel product) async {
    // Set edit mode
    setState(() {
      _editingProductId = product.productId;
    });

    // Populate form with product data
    _nameController.text = product.productName;
    _descriptionController.text = product.description ?? '';
    _brandController.text = product.brandName ?? '';
    _subCategoryController.text = product.subCategory ?? '';
    _hsnCodeController.text = product.hsnCode ?? '';

    // For simple products, use default price/mrp/cost from ProductModel
    if (product.defaultPrice != null) {
      _priceController.text = product.defaultPrice.toString();
    }
    if (product.defaultMrp != null) {
      _mrpController.text = product.defaultMrp.toString();
    }
    if (product.defaultCostPrice != null) {
      _costPriceController.text = product.defaultCostPrice.toString();
    }

    // Update form store
    _formStore.setSelectedCategoryId(product.category);
    _formStore.setTaxRate(product.gstRate ?? 0);
    _formStore.setProductType(product.hasVariants ? 'variable' : 'simple');

    // Load variants from the database
    final productStore = locator<ProductStore>();
    final variants = await productStore.getVariantsForProduct(product.productId);

    if (product.hasVariants && variants.isNotEmpty) {
      // Variable product: Load all variants into the form
      _formStore.retailVariants.clear();
      for (final variant in variants) {
        _formStore.retailVariants.add(VariantFormData(
          id: variant.varianteId,
          name: variant.shortDescription,
          attributes: variant.customAttributes ?? {},
          attributeValueIds: variant.attributeValueIds ?? {},
          sku: variant.sku ?? '',
          barcode: variant.barcode ?? '',
          price: variant.sellingPrice ?? 0,
          costPrice: variant.costPrice ?? 0,
          mrp: variant.mrp ?? 0,
          stockQuantity: variant.stockQty,
        ));
      }
    } else if (!product.hasVariants && variants.isNotEmpty) {
      // Simple product: Load default variant data into form fields
      final defaultVariant = variants.firstWhere(
            (v) => v.isDefault,
        orElse: () => variants.first,
      );

      _skuController.text = defaultVariant.sku ?? '';
      _barcodeController.text = defaultVariant.barcode ?? '';
      _stockController.text = defaultVariant.stockQty.toString();
      _minStockController.text = defaultVariant.minStock?.toString() ?? '';

      // Override prices with variant data if available
      if (defaultVariant.sellingPrice != null) {
        _priceController.text = defaultVariant.sellingPrice.toString();
      }
      if (defaultVariant.mrp != null) {
        _mrpController.text = defaultVariant.mrp.toString();
      }
      if (defaultVariant.costPrice != null) {
        _costPriceController.text = defaultVariant.costPrice.toString();
      }
    }

    // Switch to Add Product tab
    _tabController.animateTo(0);

    // Scroll to top
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing: ${product.productName}${product.hasVariants ? " (${variants.length} variants)" : ""}'),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _editRestaurantItem(dynamic item) {
    // Set edit mode
    setState(() {
      _editingRestaurantItemId = item.id;
    });

    // Populate form with item data
    _nameController.text = item.name;
    _descriptionController.text = item.description ?? '';
    _priceController.text = item.price?.toString() ?? '';
    _unitController.text = item.unit ?? '';
    _restaurantStockController.text = item.stock?.toString() ?? '';

    // Update form store with correct method names
    _formStore.setSelectedCategoryId(item.category ?? '');
    _formStore.setTaxRate(item.taxRate ?? 0);

    // Switch to Add Product tab
    _tabController.animateTo(0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing: ${item.name}'),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== PRODUCT LIST TAB ====================

  Widget _buildProductListTab() {
    if (AppConfig.isRetail) {
      return _buildRetailProductList();
    } else {
      return _buildRestaurantItemList();
    }
  }

  Widget _buildRetailProductList() {
    final productStore = locator<ProductStore>();

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
            Observer(
              builder: (_) {
                final filteredProducts = _getFilteredRetailProducts(productStore);
                return _buildListHeader(filteredProducts.length, 'Products');
              },
            ),
            Expanded(
              child: Observer(
                builder: (_) {
                  final filteredProducts = _getFilteredRetailProducts(productStore);
                  return filteredProducts.isEmpty
                      ? _buildEmptyState('products')
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: product.imagePath != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(product.imagePath!),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.inventory, color: AppColors.primary),
                              ),
                              title: Text(
                                product.productName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${product.category} • ${product.hasVariants ? "Variable" : "Simple"}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _editRetailProduct(product),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: AppColors.danger),
                                    onPressed: () => productStore.deleteProduct(product.productId),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantItemList() {
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
            Observer(
              builder: (context) {
                final items = itemStore.items.toList();
                final filteredItems = _getFilteredRestaurantItems(items);
                return _buildListHeader(filteredItems.length, 'Items');
              },
            ),
            Expanded(
              child: Observer(
                builder: (context) {
                  if (itemStore.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = itemStore.items.toList();
                  final filteredItems = _getFilteredRestaurantItems(items);

                  if (filteredItems.isEmpty) {
                    return _buildEmptyState('items');
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: item.isVeg == 'veg'
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: item.imageBytes != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              item.imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Icon(
                            Icons.restaurant,
                            color: item.isVeg == 'veg' ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '₹${item.price ?? "Multiple sizes"} • ${item.isEnabled ? "Active" : "Disabled"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: item.isEnabled,
                              onChanged: (_) async {
                                final updatedItem = item.copyWith(isEnabled: !item.isEnabled);
                                await itemStore.updateItem(updatedItem);
                              },
                              activeColor: AppColors.success,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editRestaurantItem(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: AppColors.danger),
                              onPressed: () async {
                                await itemStore.deleteItem(item.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader(int count, String type) {
    final activeFilters = _getActiveFilterCount();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$type List',
                style: const TextStyle(
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
                      '$count items',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter button with badge
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () async {
                          if (AppConfig.isRetail) {
                            await _showRetailFilterDialog();
                          } else {
                            // For restaurant, get items from store
                            await itemStore.loadItems();
                            final items = itemStore.items.toList();
                            await _showRestaurantFilterDialog(items);
                          }
                        },
                        tooltip: 'Filter',
                      ),
                      if (activeFilters > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$activeFilters',
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
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppConfig.isRetail
                  ? 'Search by name, category, brand, SKU, or barcode...'
                  : 'Search by name or category...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
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
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),

          // Active filter badges
          if (activeFilters > 0 || _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Search query badge
                if (_searchQuery.isNotEmpty)
                  Chip(
                    label: Text('Search: "$_searchQuery"'),
                    onDeleted: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                    backgroundColor: AppColors.info.withOpacity(0.2),
                  ),

                // Category filter badges
                if (_selectedCategories.isNotEmpty)
                  ..._selectedCategories.map((cat) => Chip(
                    label: Text('Category: $cat'),
                    onDeleted: () {
                      setState(() {
                        _selectedCategories.remove(cat);
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                  )),

                // Retail-specific badges
                if (AppConfig.isRetail) ...[
                  if (_selectedProductType != null && _selectedProductType != 'all')
                    Chip(
                      label: Text('Type: ${_selectedProductType![0].toUpperCase()}${_selectedProductType!.substring(1)}'),
                      onDeleted: () {
                        setState(() {
                          _selectedProductType = 'all';
                        });
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
                      backgroundColor: AppColors.secondary.withOpacity(0.2),
                    ),
                  if (_selectedBrands.isNotEmpty)
                    ..._selectedBrands.map((brand) => Chip(
                      label: Text('Brand: $brand'),
                      onDeleted: () {
                        setState(() {
                          _selectedBrands.remove(brand);
                        });
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
                      backgroundColor: AppColors.success.withOpacity(0.2),
                    )),
                ],

                // Restaurant-specific badges
                if (AppConfig.isRestaurant) ...[
                  if (_selectedVegFilter != null && _selectedVegFilter != 'all')
                    Chip(
                      label: Text(_selectedVegFilter == 'veg' ? 'Veg Only' : 'Non-Veg Only'),
                      onDeleted: () {
                        setState(() {
                          _selectedVegFilter = 'all';
                        });
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
                      backgroundColor: _selectedVegFilter == 'veg'
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.danger.withOpacity(0.2),
                    ),
                  if (_selectedStatusFilter != null && _selectedStatusFilter != 'all')
                    Chip(
                      label: Text('Status: ${_selectedStatusFilter![0].toUpperCase()}${_selectedStatusFilter!.substring(1)}'),
                      onDeleted: () {
                        setState(() {
                          _selectedStatusFilter = 'all';
                        });
                      },
                      deleteIcon: const Icon(Icons.close, size: 18),
                      backgroundColor: _selectedStatusFilter == 'active'
                          ? AppColors.success.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                    ),
                ],

                // Clear all filters button
                if (activeFilters > 0 || _searchQuery.isNotEmpty)
                  ActionChip(
                    label: const Text('Clear All', style: TextStyle(color: AppColors.danger)),
                    onPressed: _clearAllFilters,
                    backgroundColor: AppColors.danger.withOpacity(0.1),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
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
            'No $type added yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add $type manually or upload Excel file',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(0),
            icon: const Icon(Icons.add),
            label: Text('Add First ${type == 'products' ? 'Product' : 'Item'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ATTRIBUTE HELPER METHODS ====================

  Future<void> _createDefaultAttributes(AttributeStore attributeStore) async {
    try {
      // Create Size attribute with values
      final sizeCreated = await attributeStore.addAttribute('Size');
      if (sizeCreated) {
        final sizeAttr = attributeStore.attributes.firstWhere((a) => a.name == 'Size');
        await attributeStore.addMultipleValues(
          sizeAttr.attributeId,
          ['Small', 'Medium', 'Large', 'Extra Large'],
        );
      }

      // Create Color attribute with values
      final colorCreated = await attributeStore.addAttribute('Color');
      if (colorCreated) {
        final colorAttr = attributeStore.attributes.firstWhere((a) => a.name == 'Color');
        await attributeStore.addMultipleValues(
          colorAttr.attributeId,
          ['Red', 'Blue', 'Green', 'Black', 'White'],
          colorCodes: ['#FF0000', '#0000FF', '#00FF00', '#000000', '#FFFFFF'],
        );
      }

      // Create Weight attribute with values
      final weightCreated = await attributeStore.addAttribute('Weight');
      if (weightCreated) {
        final weightAttr = attributeStore.attributes.firstWhere((a) => a.name == 'Weight');
        await attributeStore.addMultipleValues(
          weightAttr.attributeId,
          ['250g', '500g', '1kg'],
        );
      }

      // Force UI update by triggering a rebuild
      if (mounted) {
        setState(() {});

        final message = attributeStore.errorMessage ?? 'Default attributes created successfully!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: attributeStore.errorMessage != null ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _createDefaultAttributes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating attributes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddAttributeDialog(AttributeStore attributeStore) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Attribute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Attribute Name',
                hintText: 'e.g., Size, Color, Material',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'You can add values for this attribute after creating it.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an attribute name')),
                );
                return;
              }

              final success = await attributeStore.addAttribute(name);
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Attribute "$name" created successfully!')),
                  );
                  _showAddValuesDialog(attributeStore, attributeStore.attributes.last);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(attributeStore.errorMessage ?? 'Failed to create attribute'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddValuesDialog(AttributeStore attributeStore, AttributeModel attribute) {
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Values for ${attribute.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'e.g., Small, Medium, Large',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) async {
                if (value.trim().isNotEmpty) {
                  await attributeStore.addValue(attribute.attributeId, value.trim());
                  valueController.clear();
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Press Enter to add each value. Click Done when finished.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = valueController.text.trim();
              if (value.isNotEmpty) {
                await attributeStore.addValue(attribute.attributeId, value);
                valueController.clear();
              }
            },
            child: const Text('Add Value'),
          ),
        ],
      ),
    );
  }

  void _showVariantGenerationDialog(AttributeStore attributeStore) {
    // Generate preview combinations
    final selectedAttrs = <String, List<AttributeValueModel>>{};
    for (final attrId in _formStore.selectedAttributeIds) {
      final valueIds = _formStore.selectedAttributeValues[attrId] ?? [];
      if (valueIds.isNotEmpty) {
        final attr = attributeStore.attributes.firstWhere((a) => a.attributeId == attrId);
        final values = attributeStore.allValues
            .where((v) => v.attributeId == attrId && valueIds.contains(v.valueId))
            .toList();
        if (values.isNotEmpty) {
          selectedAttrs[attr.name] = values;
        }
      }
    }

    final combinations = _generateCombinationsPreview(selectedAttrs);
    final selectedCombinations = List<bool>.filled(combinations.length, true); // All selected by default

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Variants to Generate'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select which variants you want to create. You can set prices and stock after generation using the bulk edit tool.',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Variant Selection Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Variants to Generate (${combinations.length} total)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (int i = 0; i < selectedCombinations.length; i++) {
                                  selectedCombinations[i] = true;
                                }
                              });
                            },
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (int i = 0; i < selectedCombinations.length; i++) {
                                  selectedCombinations[i] = false;
                                }
                              });
                            },
                            child: const Text('Deselect All'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: combinations.length,
                      itemBuilder: (context, index) {
                        final combo = combinations[index];
                        final variantName = combo.values.map((v) => v.value).join(' - ');

                        return CheckboxListTile(
                          dense: true,
                          title: Text(variantName),
                          value: selectedCombinations[index],
                          onChanged: (bool? value) {
                            setState(() {
                              selectedCombinations[index] = value ?? false;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Count selected variants
                final selectedCount = selectedCombinations.where((s) => s).length;

                if (selectedCount == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one variant'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Generate only selected variants with default values (0)
                // User will set prices using bulk edit bar after generation
                _formStore.retailVariants.clear();
                for (int i = 0; i < combinations.length; i++) {
                  if (selectedCombinations[i]) {
                    final combo = combinations[i];
                    final variantName = combo.values.map((v) => v.value).join(' - ');

                    _formStore.retailVariants.add(VariantFormData(
                      id: const Uuid().v4(),
                      name: variantName,
                      attributes: Map.fromEntries(
                        combo.entries.map((e) => MapEntry(e.key, e.value.value)),
                      ),
                      attributeValueIds: Map.fromEntries(
                        combo.entries.map((e) => MapEntry(e.key, e.value.valueId)),
                      ),
                      price: 0, // Will be set using bulk edit
                      costPrice: 0, // Will be set using bulk edit
                      mrp: 0,
                      stockQuantity: 0, // Will be set using bulk edit
                    ));
                  }
                }

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Generated $selectedCount variant(s). Now set prices using bulk edit below.'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              child: const Text('Generate Selected Variants'),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, AttributeValueModel>> _generateCombinationsPreview(
      Map<String, List<AttributeValueModel>> attrs,
      ) {
    if (attrs.isEmpty) return [];

    final keys = attrs.keys.toList();
    final result = <Map<String, AttributeValueModel>>[];

    void generate(int index, Map<String, AttributeValueModel> current) {
      if (index == keys.length) {
        result.add(Map.from(current));
        return;
      }

      final key = keys[index];
      for (final value in attrs[key]!) {
        current[key] = value;
        generate(index + 1, current);
      }
    }

    generate(0, {});
    return result;
  }

  // ==================== SEARCH & FILTER METHODS ====================

  List<ProductModel> _getFilteredRetailProducts(ProductStore productStore) {
    var filtered = productStore.products.toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        final searchLower = _searchQuery.toLowerCase();
        return product.productName.toLowerCase().contains(searchLower) ||
            (product.category?.toLowerCase().contains(searchLower) ?? false) ||
            (product.brandName?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((product) =>
          product.category != null && _selectedCategories.contains(product.category)).toList();
    }

    // Apply product type filter
    if (_selectedProductType != null && _selectedProductType != 'all') {
      filtered = filtered.where((product) {
        if (_selectedProductType == 'simple') return !product.hasVariants;
        if (_selectedProductType == 'variable') return product.hasVariants;
        return true;
      }).toList();
    }

    // Apply brand filter
    if (_selectedBrands.isNotEmpty) {
      filtered = filtered.where((product) =>
          product.brandName != null && _selectedBrands.contains(product.brandName!)).toList();
    }

    // Apply sorting
    if (_retailSortBy == 'name_asc') {
      filtered.sort((a, b) => a.productName.compareTo(b.productName));
    } else if (_retailSortBy == 'name_desc') {
      filtered.sort((a, b) => b.productName.compareTo(a.productName));
    } else if (_retailSortBy == 'recent') {
      filtered = filtered.reversed.toList();
    }

    return filtered;
  }

  List<Items> _getFilteredRestaurantItems(List<Items> items) {
    var filtered = items.toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final searchLower = _searchQuery.toLowerCase();
        return item.name.toLowerCase().contains(searchLower) ||
            (item.categoryOfItem?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((item) =>
          item.categoryOfItem != null && _selectedCategories.contains(item.categoryOfItem!)).toList();
    }

    // Apply veg/non-veg filter
    if (_selectedVegFilter != null && _selectedVegFilter != 'all') {
      filtered = filtered.where((item) => item.isVeg == _selectedVegFilter).toList();
    }

    // Apply status filter
    if (_selectedStatusFilter != null && _selectedStatusFilter != 'all') {
      if (_selectedStatusFilter == 'active') {
        filtered = filtered.where((item) => item.isEnabled).toList();
      } else if (_selectedStatusFilter == 'disabled') {
        filtered = filtered.where((item) => !item.isEnabled).toList();
      }
    }

    // Apply sorting
    if (_restaurantSortBy == 'name_asc') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else if (_restaurantSortBy == 'name_desc') {
      filtered.sort((a, b) => b.name.compareTo(a.name));
    } else if (_restaurantSortBy == 'price_asc') {
      filtered.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
    } else if (_restaurantSortBy == 'price_desc') {
      filtered.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
    }

    return filtered;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCategories.isNotEmpty) count++;
    if (AppConfig.isRetail) {
      if (_selectedProductType != null && _selectedProductType != 'all') count++;
      if (_selectedBrands.isNotEmpty) count++;
    } else {
      if (_selectedVegFilter != null && _selectedVegFilter != 'all') count++;
      if (_selectedStatusFilter != null && _selectedStatusFilter != 'all') count++;
    }
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategories.clear();
      _selectedProductType = 'all';
      _selectedBrands.clear();
      _selectedVegFilter = 'all';
      _selectedStatusFilter = 'all';
      _retailSortBy = 'name_asc';
      _restaurantSortBy = 'name_asc';
    });
  }

  Future<void> _showRetailFilterDialog() async {
    final productStore = locator<ProductStore>();

    // Get unique categories and brands from products
    final categories = productStore.products
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()..sort();

    final brands = productStore.products
        .map((p) => p.brandName)
        .where((b) => b != null && b.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()..sort();

    final tempCategories = Set<String>.from(_selectedCategories);
    final tempBrands = Set<String>.from(_selectedBrands);
    String tempProductType = _selectedProductType ?? 'all';
    String tempSortBy = _retailSortBy;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filter Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempCategories.clear();
                    tempBrands.clear();
                    tempProductType = 'all';
                    tempSortBy = 'name_asc';
                  });
                },
                child: const Text('Clear All', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Type Filter
                  const Text('Product Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: tempProductType == 'all',
                        onSelected: (_) => setDialogState(() => tempProductType = 'all'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempProductType == 'all' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Simple'),
                        selected: tempProductType == 'simple',
                        onSelected: (_) => setDialogState(() => tempProductType = 'simple'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempProductType == 'simple' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Variable'),
                        selected: tempProductType == 'variable',
                        onSelected: (_) => setDialogState(() => tempProductType = 'variable'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempProductType == 'variable' ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Filter
                  if (categories.isNotEmpty) ...[
                    const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) => FilterChip(
                        label: Text(category),
                        selected: tempCategories.contains(category),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              tempCategories.add(category);
                            } else {
                              tempCategories.remove(category);
                            }
                          });
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempCategories.contains(category) ? Colors.white : Colors.black),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Brand Filter
                  if (brands.isNotEmpty) ...[
                    const Text('Brands', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: brands.map((brand) => FilterChip(
                        label: Text(brand),
                        selected: tempBrands.contains(brand),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              tempBrands.add(brand);
                            } else {
                              tempBrands.remove(brand);
                            }
                          });
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempBrands.contains(brand) ? Colors.white : Colors.black),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sort By
                  const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Name (A-Z)'),
                        selected: tempSortBy == 'name_asc',
                        onSelected: (_) => setDialogState(() => tempSortBy = 'name_asc'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempSortBy == 'name_asc' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Name (Z-A)'),
                        selected: tempSortBy == 'name_desc',
                        onSelected: (_) => setDialogState(() => tempSortBy = 'name_desc'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempSortBy == 'name_desc' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Recently Added'),
                        selected: tempSortBy == 'recent',
                        onSelected: (_) => setDialogState(() => tempSortBy = 'recent'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempSortBy == 'recent' ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategories = tempCategories;
                  _selectedBrands = tempBrands;
                  _selectedProductType = tempProductType;
                  _retailSortBy = tempSortBy;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRestaurantFilterDialog(List<Items> items) async {
    // Get unique categories from items
    final categories = items
        .map((i) => i.categoryOfItem)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()..sort();

    final tempCategories = Set<String>.from(_selectedCategories);
    String tempVegFilter = _selectedVegFilter ?? 'all';
    String tempStatusFilter = _selectedStatusFilter ?? 'all';
    String tempSortBy = _restaurantSortBy;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filter Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempCategories.clear();
                    tempVegFilter = 'all';
                    tempStatusFilter = 'all';
                    tempSortBy = 'name_asc';
                  });
                },
                child: const Text('Clear All', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Veg/Non-Veg Filter
                  const Text('Food Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: tempVegFilter == 'all',
                        onSelected: (_) => setDialogState(() => tempVegFilter = 'all'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempVegFilter == 'all' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Veg'),
                        selected: tempVegFilter == 'veg',
                        onSelected: (_) => setDialogState(() => tempVegFilter = 'veg'),
                        selectedColor: AppColors.success,
                        labelStyle: TextStyle(color: tempVegFilter == 'veg' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Non-Veg'),
                        selected: tempVegFilter == 'non-veg',
                        onSelected: (_) => setDialogState(() => tempVegFilter = 'non-veg'),
                        selectedColor: AppColors.danger,
                        labelStyle: TextStyle(color: tempVegFilter == 'non-veg' ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status Filter
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: tempStatusFilter == 'all',
                        onSelected: (_) => setDialogState(() => tempStatusFilter = 'all'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempStatusFilter == 'all' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Active'),
                        selected: tempStatusFilter == 'active',
                        onSelected: (_) => setDialogState(() => tempStatusFilter = 'active'),
                        selectedColor: AppColors.success,
                        labelStyle: TextStyle(color: tempStatusFilter == 'active' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Disabled'),
                        selected: tempStatusFilter == 'disabled',
                        onSelected: (_) => setDialogState(() => tempStatusFilter = 'disabled'),
                        selectedColor: Colors.orange,
                        labelStyle: TextStyle(color: tempStatusFilter == 'disabled' ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Filter
                  if (categories.isNotEmpty) ...[
                    const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) => FilterChip(
                        label: Text(category),
                        selected: tempCategories.contains(category),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              tempCategories.add(category);
                            } else {
                              tempCategories.remove(category);
                            }
                          });
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempCategories.contains(category) ? Colors.white : Colors.black),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sort By
                  const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Name (A-Z)'),
                        selected: tempSortBy == 'name_asc',
                        onSelected: (_) => setDialogState(() => tempSortBy = 'name_asc'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempSortBy == 'name_asc' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Name (Z-A)'),
                        selected: tempSortBy == 'name_desc',
                        onSelected: (_) => setDialogState(() => tempSortBy = 'name_desc'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempSortBy == 'name_desc' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Price (Low-High)'),
                        selected: tempSortBy == 'price_asc',
                        onSelected: (_) => setDialogState(() => tempSortBy = 'price_asc'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempSortBy == 'price_asc' ? Colors.white : Colors.black),
                      ),
                      ChoiceChip(
                        label: const Text('Price (High-Low)'),
                        selected: tempSortBy == 'price_desc',
                        onSelected: (_) => setDialogState(() => tempSortBy = 'price_desc'),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: tempSortBy == 'price_desc' ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategories = tempCategories;
                  _selectedVegFilter = tempVegFilter;
                  _selectedStatusFilter = tempStatusFilter;
                  _restaurantSortBy = tempSortBy;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SETUP WIZARD NAVIGATION ====================

  Widget _buildSetupWizardNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onPrevious,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: widget.onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'Next: Payment Setup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
