import 'package:flutter/material.dart';
import 'package:billberrylite/domain/services/retail/simple_product_fields_service.dart';
import 'package:billberrylite/domain/services/retail/variant_attribute_mapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import '../../../core/config/app_config.dart';
import '../../../core/config/tariff_code_rule.dart';
import '../../../core/config/tax_feature.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/attribute_value_model_220.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../domain/store/common/add_product_form_store.dart';
import '../../../domain/store/retail/product_store.dart';
import '../../../domain/store/retail/attribute_store.dart';
import '../../../util/common/app_responsive.dart';
import '../../../presentation/widget/componets/common/app_text_field.dart';
import '../../../presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/screens/retail/simple_product_fields_screen.dart';
import 'package:billberrylite/presentation/screens/retail/import_product/bulk_import_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/import/restaurant_bulk_import_service.dart';
import 'package:billberrylite/presentation/screens/restaurant/import/bulk_import_screen.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/category_selector_sheet.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/bottom_sheets/add_category_dialog.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/core/constants/item_units.dart';
import 'package:billberrylite/domain/services/retail/expiry_status.dart';
import 'package:billberrylite/presentation/widget/componets/retail/expiry_date_field.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';

class AddProductScreen extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const AddProductScreen({Key? key, this.onNext, this.onPrevious})
    : super(key: key);

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

  // Persistent per-variant field controllers, keyed by variant id then field
  // name (sku/barcode/costPrice/price/mrp/stockQuantity). AppTextField needs
  // a real controller — this is what lets externally-triggered changes
  // (bulk edit, SKU auto-generate) show up immediately in an open card.
  final Map<String, Map<String, TextEditingController>> _variantControllers =
      {};

  TextEditingController _variantController(
    String variantId,
    String field,
    String initialText,
  ) {
    final fields = _variantControllers.putIfAbsent(variantId, () => {});
    return fields.putIfAbsent(
      field,
      () => TextEditingController(text: initialText),
    );
  }

  void _disposeVariantControllers(String variantId) {
    final fields = _variantControllers.remove(variantId);
    if (fields != null) {
      for (final c in fields.values) {
        c.dispose();
      }
    }
  }

  void _disposeAllVariantControllers() {
    for (final fields in _variantControllers.values) {
      for (final c in fields.values) {
        c.dispose();
      }
    }
    _variantControllers.clear();
  }

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
  String _restaurantSortBy =
      'name_asc'; // 'name_asc', 'name_desc', 'price_asc', 'price_desc'

  // Shown above attribute value chips until the user long-presses one for the
  // first time; dismissal is persisted so it never shows again after that.
  static const _longPressTipPrefsKey =
      'attribute_value_longpress_tip_dismissed';
  bool _showLongPressTip = false;

  @override
  void initState() {
    super.initState();
    _loadSimpleFields();
    _tabController = TabController(length: 2, vsync: this);
    _formStore = AddProductFormStore();

    // Load attributes from repository (including imported attributes)
    // Only for retail mode
    if (AppConfig.isRetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final attributeStore = locator<AttributeStore>();
        attributeStore.loadAttributes();
      });
      SharedPreferences.getInstance().then((prefs) {
        if (!mounted) return;
        if (!(prefs.getBool(_longPressTipPrefsKey) ?? false)) {
          setState(() => _showLongPressTip = true);
        }
      });
    }
  }

  Future<void> _dismissLongPressTip() async {
    if (!_showLongPressTip) return;
    setState(() => _showLongPressTip = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_longPressTipPrefsKey, true);
  }

  @override
  void dispose() {
    for (final c in _simpleFieldControllers.values) {
      c.dispose();
    }
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
    _disposeAllVariantControllers();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();

      // Validate image size (max 2MB)
      final int maxSizeInBytes = 2 * 1024 * 1024; // 2MB
      if (bytes.length > maxSizeInBytes) {
        if (mounted) {
          NotificationService.instance.showError(
            'Image is too large. Please select an image under 2MB.',
          );
        }
        return;
      }

      _formStore.setImagePath(image.path);
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
    _disposeAllVariantControllers();

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
      _formStore.setBrandName(
        _brandController.text.isEmpty ? null : _brandController.text,
      );
      _formStore.setSubCategory(
        _subCategoryController.text.isEmpty
            ? null
            : _subCategoryController.text,
      );
      _formStore.setMrp(double.tryParse(_mrpController.text) ?? 0);
      _formStore.setCostPrice(double.tryParse(_costPriceController.text) ?? 0);
      _formStore.setHsnCode(
        _hsnCodeController.text.isEmpty ? null : _hsnCodeController.text,
      );
      _formStore.setSku(_skuController.text);
      _formStore.setBarcode(_barcodeController.text);
      _formStore.setStockQuantity(double.tryParse(_stockController.text) ?? 0);
      _formStore.setMinStock(double.tryParse(_minStockController.text) ?? 0);
    } else {
      _formStore.setUnit(
        _unitController.text.isEmpty ? null : _unitController.text,
      );
      _formStore.setRestaurantStockQuantity(
        double.tryParse(_restaurantStockController.text) ?? 0,
      );
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
      final isEditMode =
          _editingProductId != null || _editingRestaurantItemId != null;
      final message = isEditMode
          ? (AppConfig.isRetail
                ? 'Product updated successfully!'
                : 'Item updated successfully!')
          : (AppConfig.isRetail
                ? 'Product added successfully!'
                : 'Item added successfully!');
      NotificationService.instance.showSuccess(message);
      _clearForm();
    } else if (_formStore.errorMessage != null && mounted) {
      NotificationService.instance.showError(_formStore.errorMessage!);
    }
  }

  // ==================== UPDATE METHODS ====================

  /// Resolves the display name of the form's selected category, used as the
  /// SKU prefix when auto-generating.
  String? _selectedCategoryName() {
    for (final c in categoryStore.categories) {
      if (c.id == _formStore.selectedCategoryId) return c.name;
    }
    return null;
  }

  /// Auto-generates a SKU only when [currentSku] is blank — an existing SKU
  /// (user-typed or previously generated) is never touched.
  Future<String> _skuOrGenerated(String currentSku) async {
    if (currentSku.trim().isNotEmpty) return currentSku;
    return skuGeneratorService.generate(_selectedCategoryName());
  }

  /// "Auto-generate" button next to the SKU field — never overwrites an
  /// existing value, matching the same rule applied at save time.
  Future<void> _onAutoGenerateSkuPressed() async {
    if (_skuController.text.trim().isNotEmpty) {
      NotificationService.instance.showError(
        'SKU is already set — clear it first to generate a new one.',
      );
      return;
    }
    final sku = await skuGeneratorService.generate(_selectedCategoryName());
    if (!mounted) return;
    setState(() => _skuController.text = sku);
  }

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
        description: _formStore.description.isNotEmpty
            ? _formStore.description
            : null,
        hasVariants: _formStore.isVariableProduct,
        productType: _formStore.productType,
        defaultPrice: _formStore.isSimpleProduct ? _formStore.price : null,
        defaultMrp: _formStore.isSimpleProduct ? _formStore.mrp : null,
        defaultCostPrice: _formStore.isSimpleProduct
            ? _formStore.costPrice
            : null,
        gstRate: _formStore.taxRate > 0 ? _formStore.taxRate : null,
        taxId: _formStore.selectedTaxId,
        imageBytes: _formStore.imageBytes,
        hsnCode: _formStore.hsnCode,
        allowOrderWhenOutOfStock: _formStore.allowOrderWhenOutOfStock,
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
            sku: await _skuOrGenerated(variantData.sku),
            barcode: variantData.barcode,
            customAttributes: variantData.attributes,
            attributeValueIds: variantData.attributeValueIds,
            mrp: variantData.mrp,
            costPrice: variantData.costPrice,
            sellingPrice: variantData.price,
            stockQty: variantData.stockQuantity,
            minStock: _formStore.minStock,
            taxRate: _formStore.taxRate > 0 ? _formStore.taxRate : null,
            taxId: _formStore.selectedTaxId,
            isDecimalQuantity: _formStore.isDecimalQuantity,
            unit: _formStore.unit,
            expiryDate: _formStore.expiryDate?.toIso8601String(),
          );

          // Check if variant exists, if so update, otherwise add
          final existingVariant = await productStore.getVariantById(
            variantData.id,
          );
          final result = existingVariant != null
              ? await productStore.updateVariant(variant)
              : await productStore.addVariant(variant);
          // The repository refuses a barcode another variant holds. Surface it
          // rather than losing the variant silently.
          if (!result.success) {
            NotificationService.instance.showError(
              result.errorMessage ?? 'Could not save variant.',
            );
            return false;
          }
        }
      } else {
        // For simple products, update the default variant
        final variants = await productStore.getVariantsForProduct(
          _editingProductId!,
        );
        if (variants.isNotEmpty) {
          final defaultVariant = variants.firstWhere(
            (v) => v.isDefault,
            orElse: () => variants.first,
          );

          final updatedVariant = defaultVariant.copyWith(
            customAttributes: mergeVariantAttributes(
              Map.of(_formStore.simpleFieldValues),
            ),
            sku: await _skuOrGenerated(_formStore.sku),
            barcode: _formStore.barcode,
            mrp: _formStore.mrp,
            costPrice: _formStore.costPrice,
            sellingPrice: _formStore.price,
            stockQty: _formStore.stockQuantity,
            minStock: _formStore.minStock,
            taxRate: _formStore.taxRate > 0 ? _formStore.taxRate : null,
            taxId: _formStore.selectedTaxId,
            isDecimalQuantity: _formStore.isDecimalQuantity,
            unit: _formStore.unit,
            expiryDate: _formStore.expiryDate?.toIso8601String(),
            clearExpiryDate: _formStore.expiryDate == null,
          );

          final result = await productStore.updateVariant(updatedVariant);
          if (!result.success) {
            NotificationService.instance.showError(
              result.errorMessage ?? 'Could not save variant.',
            );
            return false;
          }
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
      Uint8List? imageBytes =
          existingItem.imageBytes; // Keep existing bytes by default

      if (_formStore.imageBytes != null) {
        imageBytes = _formStore.imageBytes;
      } else if (_formStore.imagePath != null &&
          _formStore.imagePath!.isNotEmpty) {
        try {
          final file = File(_formStore.imagePath!);
          if (file.existsSync()) {
            imageBytes = await file.readAsBytes();
          }
        } catch (e) {}
      }

      // Create updated item
      final updatedItem = existingItem.copyWith(
        name: _formStore.name.trim(),
        description: _formStore.description.isNotEmpty
            ? _formStore.description
            : null,
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
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildAddProductTab(), _buildProductListTab()],
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
        style: GoogleFonts.poppins(color: AppColors.darkNeutral),
      ),
      // leading: IconButton(
      //   icon: const Icon(Icons.arrow_back, color: AppColors.darkNeutral),
      //   onPressed: () => Navigator.pop(context),
      // ),
      // Retail's bulk-import entry point lives in the "Bulk Import via Excel"
      // card on the Add Product tab instead — these icons were fully redundant
      // with it there (both just re-opened the same BulkImportScreen), and
      // "Download Template" didn't actually download anything for retail.
      // Restaurant keeps them: Download saves a real template file and Upload
      // does its own inline pick/parse flow, distinct from the card's screen.
      actions: [
        if (AppConfig.isRestaurant) ...[
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

  /// Below this MEASURED pane width the form sections stack instead of going
  /// two-up. Measured, not a screen breakpoint: this tab renders inside the
  /// wizard's capped PageView, so screen width overstates the space here.
  static const double _twoColumnMinWidth = 600;

  Widget _buildAddProductTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _twoColumnMinWidth;
        return _buildAddProductForm(context, isMobile);
      },
    );
  }

  Widget _buildAddProductForm(BuildContext context, bool isMobile) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(
        isMobile ? 16 : AppResponsive.extraLargeSpacing(context),
      ),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: AppResponsive.maxContentWidth(context),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Excel Import Card
                if (AppConfig.isRetail) ...[
                  _buildExcelImportCard(),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Main Form Card
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
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
                        title: AppConfig.isRetail
                            ? 'Add Product Manually'
                            : 'Add Menu Item',
                      ),
                      const Divider(height: 30),

                      // Section 1: Basic Information
                      _buildBasicInfoSection(isMobile),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Section 2: Pricing & Tax
                      _buildPricingSection(isMobile),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Section 3: Variants/Sizes (Dynamic)
                      if (AppConfig.isRetail)
                        _buildRetailVariantsSection(isMobile)
                      else
                        _buildRestaurantSizesSection(isMobile),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Section 4: Customization (Restaurant Only)
                      if (AppConfig.isRestaurant) ...[
                        _buildCustomizationSection(isMobile),
                        SizedBox(
                          height: AppResponsive.extraLargeSpacing(context),
                        ),
                      ],

                      // Section 5: Inventory
                      _buildInventorySection(isMobile),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Section 6: Identification (Retail Only)
                      if (AppConfig.isRetail) ...[
                        _buildIdentificationSection(isMobile),
                        SizedBox(
                          height: AppResponsive.extraLargeSpacing(context),
                        ),
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
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.headingFontSize(context),
            color: AppColors.darkNeutral,
            fontWeight: FontWeight.bold,
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
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.subheadingFontSize(context),
          color: AppColors.darkNeutral,
          fontWeight: FontWeight.w600,
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
        SizedBox(height: AppResponsive.largeSpacing(context)),

        // Name & Price Row
        if (isMobile)
          Column(
            children: [
              _buildTextField(
                controller: _nameController,
                label: AppConfig.isRetail ? 'Product Name*' : 'Item Name*',
                icon: Icons.inventory,
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
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
              SizedBox(width: AppResponsive.largeSpacing(context)),
              // Show price field only for Restaurant mode (for Retail, it's in Pricing & Tax section)
              Expanded(
                child: Observer(
                  builder: (_) =>
                      (AppConfig.isRestaurant && !_formStore.hasPortionSizes)
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
        SizedBox(height: AppResponsive.largeSpacing(context)),

        // Category Dropdown
        _buildCategoryDropdown(),
        SizedBox(height: AppResponsive.largeSpacing(context)),

        // Retail-specific fields
        if (AppConfig.isRetail) ...[
          if (isMobile)
            Column(
              children: [
                _buildTextField(
                  controller: _brandController,
                  label: 'Brand Name (optional)',
                  icon: Icons.business,
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),
                _buildTextField(
                  controller: _subCategoryController,
                  label: 'Sub-category (optional)',
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
                    label: 'Brand Name (optional)',
                    icon: Icons.business,
                  ),
                ),
                SizedBox(width: AppResponsive.largeSpacing(context)),
                Expanded(
                  child: _buildTextField(
                    controller: _subCategoryController,
                    label: 'Sub-category (optional)',
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
                SizedBox(height: AppResponsive.largeSpacing(context)),
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
                SizedBox(width: AppResponsive.largeSpacing(context)),
                Expanded(child: _buildVegToggle()),
              ],
            ),
        ],

        SizedBox(height: AppResponsive.largeSpacing(context)),

        // Description
        _buildTextField(
          controller: _descriptionController,
          label: 'Description (optional)',
          icon: Icons.description,
          maxLines: 3,
          iconColor: AppColors.secondary,
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Observer(
      builder: (_) {
        final hasBytes = _formStore.imageBytes != null;
        final hasPath = _formStore.imagePath != null;
        return InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadius(context),
              ),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.hardEdge,
            child: hasBytes
                ? Image.memory(
                    _formStore.imageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  )
                : hasPath
                ? Image.file(
                    File(_formStore.imagePath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                          AppResponsive.mediumSpacing(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_rounded,
                          size: AppResponsive.largeIconSize(context),
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      Text(
                        'Tap to add image',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildVegToggle() {
    return Observer(
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.eco_rounded,
              color: AppColors.success,
              size: AppResponsive.iconSize(context),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Text(
              'Type: ',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: Text(
                'Veg',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
              selected: _formStore.isVeg == 'veg',
              onSelected: (_) => _formStore.setIsVeg('veg'),
              selectedColor: AppColors.success.withValues(alpha: 0.2),
              avatar: _formStore.isVeg == 'veg'
                  ? Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: AppResponsive.smallIconSize(context),
                    )
                  : null,
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            ChoiceChip(
              label: Text(
                'Non-Veg',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
              selected: _formStore.isVeg == 'non-veg',
              onSelected: (_) => _formStore.setIsVeg('non-veg'),
              selectedColor: AppColors.danger.withValues(alpha: 0.2),
              avatar: _formStore.isVeg == 'non-veg'
                  ? Icon(
                      Icons.check_circle,
                      color: AppColors.danger,
                      size: AppResponsive.smallIconSize(context),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Observer(
      builder: (_) {
        final categories = categoryStore.categories.toList();
        final categoryIds = categories.map((c) => c.id).toList();

        // Ensure selected value is valid
        final selectedValue =
            categoryIds.contains(_formStore.selectedCategoryId)
            ? _formStore.selectedCategoryId
            : null;

        return InkWell(
          onTap: () async {
            // Show category selector bottom sheet — lets the user create a
            // new category inline instead of only picking from existing ones.
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
            decoration: _fieldDec(
              'Category*',
              Icons.category_rounded,
              suffixIcon: const Icon(
                Icons.arrow_drop_down,
                color: AppColors.textSecondary,
              ),
            ),
            child: Text(
              selectedValue != null && categories.isNotEmpty
                  ? categories
                        .firstWhere(
                          (c) => c.id == selectedValue,
                          orElse: () => categories.first,
                        )
                        .name
                  : 'Select or Add Category',
              style: GoogleFonts.poppins(
                color: selectedValue != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: AppResponsive.bodyFontSize(context),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Picks the shared Tax ENTITY, not a bare percentage. `taxId` is the
  /// canonical link (the POS screen does the same); the rate is only a cached
  /// number the store derives via `setSelectedTaxId`, so a later edit to the
  /// tax record still reaches products created here.
  Widget _buildGstDropdown() {
    final taxes = taxStore.taxes;

    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        hoverColor: AppColors.primary.withValues(alpha: 0.06),
      ),
      child: Observer(
        builder: (_) => DropdownButtonFormField<String>(
          value: taxes.any((t) => t.id == _formStore.selectedTaxId)
              ? _formStore.selectedTaxId
              : null,
          isExpanded: true,
          decoration: _fieldDec('Tax Rate (Optional)', Icons.percent),
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            color: AppColors.textPrimary,
          ),
          dropdownColor: Colors.white,
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                'No tax',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
            ),
            ...taxes.map(
              (tax) => DropdownMenuItem(
                value: tax.id,
                child: Text(
                  '${tax.taxname} (${tax.taxperecentage ?? 0}%)',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                  ),
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() {
            _formStore.setSelectedTaxId(value);
            // Keep the controller in step: _submitForm reads it back into the
            // store, and a stale value there would overwrite the derived rate.
            _taxRateController.text = _formStore.taxRate > 0
                ? _formStore.taxRate.toString()
                : '';
          }),
        ),
      ),
    );
  }

  /// Sells by weight/volume rather than whole pieces, plus the unit that names
  /// the measure. Mirrors the POS screen's control - isDecimalQuantity is the
  /// single switch that permits a fractional quantity anywhere in the app.
  Widget _buildUnitOfMeasureSection() {
    return Observer(
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: _formStore.isDecimalQuantity,
            onChanged: (v) =>
                setState(() => _formStore.setIsDecimalQuantity(v)),
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: const Text('Sold by weight / volume'),
            subtitle: Text(
              _formStore.isDecimalQuantity
                  ? 'Quantities may be fractional, e.g. 1.75 ${_formStore.unit ?? 'kg'}'
                  : 'Counted in whole pieces',
            ),
          ),
          if (_formStore.isDecimalQuantity) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            DropdownButtonFormField<String>(
              initialValue: kItemUnits.contains(_formStore.unit)
                  ? _formStore.unit
                  : 'kg',
              decoration: _fieldDec('Unit', Icons.straighten),
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textPrimary,
              ),
              dropdownColor: Colors.white,
              // Reuses restaurant's canonical list so the two sides can never
              // drift apart on what a unit is called.
              items: kItemUnits
                  .where((u) => u != 'piece')
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _formStore.setUnit(v));
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Optional expiry for this product's variants. Turning the switch OFF clears
  /// the date, so nothing stale can survive.
  Widget _buildExpirySection() {
    return Observer(
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: _formStore.expiryDate != null,
            onChanged: (on) => setState(() {
              _formStore.setExpiryDate(
                on
                    ? dateOnly(DateTime.now().add(const Duration(days: 7)))
                    : null,
              );
            }),
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: const Text('Has an expiry date'),
            subtitle: Text(
              _formStore.expiryDate == null
                  ? 'This product does not expire'
                  : 'Alerts $kExpiryWarningDays days before it expires',
            ),
          ),
          if (_formStore.expiryDate != null) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            ExpiryDateField(
              value: _formStore.expiryDate,
              onPick: (picked) =>
                  setState(() => _formStore.setExpiryDate(picked)),
              onClear: () => setState(() => _formStore.setExpiryDate(null)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestaurantTaxDropdown() {
    // Use tax store to access taxes
    final taxes = taxStore.taxes.toList();

    List<Map<String, String>> taxRates = [
      {'id': '', 'name': 'No Tax', 'rate': '0'},
    ];

    taxRates.addAll(
      taxes.map(
        (tax) => {
          'id': tax.id,
          'name': tax.taxname,
          'rate': tax.taxperecentage.toString(),
        },
      ),
    );

    // Find current selected value
    final currentValue = _taxRateController.text.isEmpty
        ? null
        : _taxRateController.text;

    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: _fieldDec('Tax Rate', Icons.receipt_outlined),
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        color: AppColors.textPrimary,
      ),
      items: taxRates.map<DropdownMenuItem<String>>((tax) {
        return DropdownMenuItem<String>(
          value: tax['rate']!,
          child: Text(
            '${tax['name']} (${tax['rate']}%)',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _taxRateController.text = value ?? '';
        });
      },
      hint: Text(
        'Select tax rate',
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.bodyFontSize(context),
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // ==================== SECTION 2: PRICING ====================

  Widget _buildPricingSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSectionTitle(TaxFeature.enabled ? 'Pricing & Tax' : 'Pricing'),

        // GST/Tax Rate Dropdown for both Retail and Restaurant — hidden
        // entirely when tax is disabled for this business.
        if (TaxFeature.enabled) ...[
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
                SizedBox(width: AppResponsive.largeSpacing(context)),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
        ],

        // Retail-specific pricing (only for Simple products, not Variable)
        if (AppConfig.isRetail) ...[
          SizedBox(height: AppResponsive.largeSpacing(context)),
          Observer(
            builder: (_) {
              // Hide pricing fields for Variable products (prices are set per variant)
              final isVariable = _formStore.productType == 'variable';

              if (isVariable) {
                // For variable products, show info message and HSN Code only
                return Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        AppResponsive.mediumSpacing(context),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(
                          AppResponsive.smallBorderRadius(context),
                        ),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: AppResponsive.iconSize(context),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Expanded(
                            child: Text(
                              'Prices will be set individually for each variant',
                              style: GoogleFonts.poppins(
                                color: Colors.blue.shade900,
                                fontSize: AppResponsive.smallFontSize(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (TaxFeature.enabled) ...[
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildTextField(
                        controller: _hsnCodeController,
                        label: TariffCodeRule.label,
                        icon: Icons.qr_code_2,
                      ),
                    ],
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
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        _buildTextField(
                          controller: _priceController,
                          label: 'Selling Price*',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                          iconColor: AppColors.success,
                        ),
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        _buildTextField(
                          controller: _mrpController,
                          label: 'MRP',
                          icon: Icons.price_check,
                          keyboardType: TextInputType.number,
                        ),
                        if (TaxFeature.enabled) ...[
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                          _buildTextField(
                            controller: _hsnCodeController,
                            label: TariffCodeRule.label,
                            icon: Icons.qr_code_2,
                          ),
                        ],
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
                            SizedBox(
                              width: AppResponsive.largeSpacing(context),
                            ),
                            Expanded(
                              child: _buildTextField(
                                controller: _priceController,
                                label: 'Selling Price*',
                                icon: Icons.attach_money,
                                keyboardType: TextInputType.number,
                                iconColor: AppColors.success,
                              ),
                            ),
                            SizedBox(
                              width: AppResponsive.largeSpacing(context),
                            ),
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
                        if (TaxFeature.enabled) ...[
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _hsnCodeController,
                                  label: TariffCodeRule.label,
                                  icon: Icons.qr_code_2,
                                ),
                              ),
                              SizedBox(
                                width: AppResponsive.largeSpacing(context),
                              ),
                              const Expanded(child: SizedBox.shrink()),
                              SizedBox(
                                width: AppResponsive.largeSpacing(context),
                              ),
                              const Expanded(child: SizedBox.shrink()),
                            ],
                          ),
                        ],
                      ],
                    );
            },
          ),

          // Profit Margin Display
          SizedBox(height: AppResponsive.largeSpacing(context)),
          Observer(
            builder: (_) {
              final costPrice = double.tryParse(_costPriceController.text) ?? 0;
              final price = double.tryParse(_priceController.text) ?? 0;
              if (costPrice > 0 && price > 0) {
                final profit = price - costPrice;
                final margin = (profit / costPrice) * 100;
                return Container(
                  padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                  decoration: BoxDecoration(
                    color: profit >= 0
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        color: profit >= 0
                            ? AppColors.success
                            : AppColors.danger,
                        profit >= 0 ? Icons.trending_up : Icons.trending_down,
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Text(
                        'Profit: ${CurrencyHelper.currentSymbol}${profit.toStringAsFixed(2)} (${margin.toStringAsFixed(1)}%)',
                        style: GoogleFonts.poppins(
                          color: profit >= 0
                              ? AppColors.success
                              : AppColors.danger,
                          fontWeight: FontWeight.w600,
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
        Text(
          'Product Type',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Observer(
          builder: (_) => Row(
            children: [
              Expanded(
                child: _buildSelectableCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Simple',
                  selected: _formStore.productType == 'simple',
                  onTap: () => _formStore.setProductType('simple'),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                child: _buildSelectableCard(
                  icon: Icons.style_outlined,
                  label: 'Variable',
                  selected: _formStore.productType == 'variable',
                  onTap: () => _formStore.setProductType('variable'),
                ),
              ),
            ],
          ),
        ),

        // Simple Product descriptor fields (configured in Settings)
        Observer(
          builder: (_) => _formStore.productType == 'simple'
              ? _buildSimpleFieldsSection(isMobile)
              : const SizedBox.shrink(),
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
                SizedBox(height: AppResponsive.largeSpacing(context)),
                _buildAttributeSelector(),
                SizedBox(height: AppResponsive.largeSpacing(context)),
                _buildVariantsList(isMobile),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Icon+label selectable card — matches the AnimatedContainer idiom used
  /// for option selectors elsewhere in the wizard (e.g. staff role picker).
  Widget _buildSelectableCard({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color accent = AppColors.primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(
            color: selected ? accent : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppResponsive.iconSize(context),
              color: selected ? accent : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: selected ? accent : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pill-shaped selectable chip — same idiom as [_buildSelectableCard], used
  /// for attribute/value chips in place of stock FilterChip.
  Widget _buildSelectableChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color accent = AppColors.primary,
    Widget? avatar,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[avatar, const SizedBox(width: 6)],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: selected ? accent : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Non-toggleable pill button ("+ Add Value" / "+ Add Attribute" style),
  /// same visual weight as [_buildSelectableChip] but always in the
  /// unselected/tinted-outline state since it triggers an action, not a
  /// selection.
  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color accent = AppColors.primary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppResponsive.smallIconSize(context),
              color: accent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
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
              Text(
                'Select Attributes:',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddAttributeDialog(attributeStore),
                icon: Icon(
                  Icons.add,
                  size: AppResponsive.smallIconSize(context),
                ),
                label: Text(
                  'Add Attribute',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),

          // Show message if no attributes
          if (attributeStore.attributes.isEmpty)
            Container(
              padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadius(context),
                ),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Text(
                        'No attributes found',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  Text(
                    'Attributes define product variants like Size, Color, Material, etc.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  ElevatedButton.icon(
                    onPressed: () => _createDefaultAttributes(attributeStore),
                    icon: Icon(
                      Icons.auto_awesome,
                      size: AppResponsive.smallIconSize(context),
                    ),
                    label: Text(
                      'Create Starter Attributes',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                      ),
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
                final isSelected = _formStore.selectedAttributeIds.contains(
                  attr.attributeId,
                );
                return _buildSelectableChip(
                  label: attr.name,
                  selected: isSelected,
                  onTap: () => _formStore.toggleAttribute(attr.attributeId),
                  accent: AppColors.primary,
                );
              }).toList(),
            ),

          // One-time hint that values support long-press for edit/delete
          if (_formStore.selectedAttributeIds.isNotEmpty &&
              _showLongPressTip) ...[
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tip: Long press a value to edit or delete it.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          // Show values for selected attributes
          ..._formStore.selectedAttributeIds.map((attrId) {
            final attr = attributeStore.attributes.firstWhere(
              (a) => a.attributeId == attrId,
            );
            final values = attributeStore.getValuesForAttribute(attrId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                Text(
                  '${attr.name} Values:',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (values.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'No values yet for ${attr.name}.',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...values.map((val) {
                      final isSelected =
                          _formStore.selectedAttributeValues[attrId]?.contains(
                            val.valueId,
                          ) ??
                          false;
                      return GestureDetector(
                        onLongPress: () =>
                            _showValueActionsSheet(attributeStore, attr, val),
                        child: _buildSelectableChip(
                          label: val.value,
                          selected: isSelected,
                          onTap: () => _formStore.toggleAttributeValue(
                            attrId,
                            val.valueId,
                          ),
                          accent: AppColors.secondary,
                          avatar: val.colorCode != null
                              ? CircleAvatar(
                                  backgroundColor: _parseColor(val.colorCode!),
                                  radius: 8,
                                )
                              : null,
                        ),
                      );
                    }),
                    _buildActionPill(
                      icon: Icons.add,
                      label: 'Add Value',
                      onPressed: () =>
                          _showAddValueToAttributeDialog(attributeStore, attr),
                    ),
                  ],
                ),
              ],
            );
          }),

          // Generate Variants Button
          if (_formStore.selectedAttributeIds.isNotEmpty) ...[
            SizedBox(height: AppResponsive.largeSpacing(context)),
            ElevatedButton.icon(
              onPressed: () {
                _showVariantGenerationDialog(attributeStore);
              },
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                'Generate Variants',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context),
                  ),
                ),
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
            padding: EdgeInsets.all(AppResponsive.extraLargeSpacing(context)),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Center(
              child: Text(
                'No variants yet. Select attributes and generate variants.',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Variants (${_formStore.retailVariants.length})',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),

            // Bulk Edit Bar
            _buildBulkEditBar(isMobile),
            SizedBox(height: AppResponsive.mediumSpacing(context)),

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
    final allSelected =
        variantCount > 0 && _selectedVariantsForBulk.length == variantCount;
    final noneSelected = _selectedVariantsForBulk.isEmpty;
    final selectedCount = _selectedVariantsForBulk.length;

    return Container(
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Select All / Unselect All
          Row(
            children: [
              Icon(
                Icons.edit_note,
                color: AppColors.warning,
                size: AppResponsive.iconSize(context),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                child: Text(
                  'Bulk Edit - $selectedCount / $variantCount selected',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
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
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: allSelected
                        ? AppColors.textSecondary
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                ' | ',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
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
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: noneSelected
                        ? AppColors.textSecondary
                        : AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),

          // Bulk pricing fields
          if (isMobile)
            Column(
              children: [
                AppTextField(
                  controller: _bulkCostPriceController,
                  label: 'Cost Price',
                  hint: '0.00',
                  icon: Icons.money_off,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                AppTextField(
                  controller: _bulkSellingPriceController,
                  label: 'Selling Price',
                  hint: '0.00',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                AppTextField(
                  controller: _bulkStockController,
                  label: 'Stock',
                  hint: '0',
                  icon: Icons.inventory_2,
                  keyboardType: TextInputType.number,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _bulkCostPriceController,
                    label: 'Cost Price',
                    hint: '0.00',
                    icon: Icons.money_off,
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Expanded(
                  child: AppTextField(
                    controller: _bulkSellingPriceController,
                    label: 'Selling Price',
                    hint: '0.00',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Expanded(
                  child: AppTextField(
                    controller: _bulkStockController,
                    label: 'Stock',
                    hint: '0',
                    icon: Icons.inventory_2,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Center(
            child: ElevatedButton.icon(
              onPressed: _applyBulkPricing,
              icon: const Icon(Icons.done_all),
              label: Text(
                'Apply to Selected Variants',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            'Workflow: 1) Enter price/stock above  2) Select variants  3) Click Apply. Fields will clear automatically for next group. You can repeat for different prices.',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: AppResponsive.captionFontSize(context),
            ),
          ),
        ],
      ),
    );
  }

  void _applyBulkPricing() {
    final costPrice = double.tryParse(_bulkCostPriceController.text);
    final sellingPrice = double.tryParse(_bulkSellingPriceController.text);
    final stock = double.tryParse(_bulkStockController.text);

    if (costPrice == null && sellingPrice == null && stock == null) {
      NotificationService.instance.showError(
        'Please enter at least one value to apply',
      );
      return;
    }

    if (_selectedVariantsForBulk.isEmpty) {
      NotificationService.instance.showError(
        'Please select at least one variant',
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
          final updated = variant.copyWith(
            costPrice: costPrice ?? variant.costPrice,
            price: sellingPrice ?? variant.price,
            stockQuantity: stock ?? variant.stockQuantity,
          );
          _formStore.updateRetailVariant(i, updated);

          // Keep an already-open card's fields in sync with the bulk update.
          final fields = _variantControllers[variant.id];
          if (fields != null) {
            if (costPrice != null)
              fields['costPrice']?.text = updated.costPrice.toString();
            if (sellingPrice != null)
              fields['price']?.text = updated.price.toString();
            if (stock != null)
              fields['stockQuantity']?.text = updated.stockQuantity.toString();
          }
        }
      }

      // Clear inputs and selections for next group
      setState(() {
        _bulkCostPriceController.clear();
        _bulkSellingPriceController.clear();
        _bulkStockController.clear();
        _selectedVariantsForBulk.clear();
      });

      NotificationService.instance.showSuccess(
        '✓ Applied to $selectedCount variant(s). Ready for next group.',
      );
    } catch (e) {
      NotificationService.instance.showError('Error applying bulk pricing: $e');
    }
  }

  Widget _buildVariantCard(VariantFormData variant, int index, bool isMobile) {
    final isSelected = _selectedVariantsForBulk.contains(variant.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.warning.withValues(alpha: 0.08)
            : AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(
          color: isSelected ? AppColors.warning : AppColors.divider,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
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
          activeColor: AppColors.warning,
        ),
        title: Text(
          variant.name.isEmpty ? 'Variant ${index + 1}' : variant.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'SKU: ${variant.sku.trim().isEmpty ? "Auto" : variant.sku} | '
          'Price: ${CurrencyHelper.currentSymbol}${variant.price} | Stock: ${variant.stockQuantity}',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: AppColors.danger),
          onPressed: () {
            _disposeVariantControllers(variant.id);
            _formStore.removeRetailVariant(index);
          },
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
            child: Column(
              children: [
                if (isMobile)
                  Column(
                    children: [
                      _buildVariantSkuField(variant, index),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      _buildVariantField(
                        variant: variant,
                        field: 'barcode',
                        label: 'Barcode',
                        icon: Icons.qr_code_2,
                        initialValue: variant.barcode,
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(barcode: v),
                        ),
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      _buildVariantField(
                        variant: variant,
                        field: 'costPrice',
                        label: 'Cost Price',
                        icon: Icons.money_off,
                        initialValue: variant.costPrice.toString(),
                        numeric: true,
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(costPrice: double.tryParse(v) ?? 0),
                        ),
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      _buildVariantField(
                        variant: variant,
                        field: 'price',
                        label: 'Selling Price',
                        icon: Icons.attach_money,
                        initialValue: variant.price.toString(),
                        numeric: true,
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(price: double.tryParse(v) ?? 0),
                        ),
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      _buildVariantField(
                        variant: variant,
                        field: 'mrp',
                        label: 'MRP',
                        icon: Icons.price_check,
                        initialValue: variant.mrp.toString(),
                        numeric: true,
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(mrp: double.tryParse(v) ?? 0),
                        ),
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      _buildVariantField(
                        variant: variant,
                        field: 'stockQuantity',
                        label: 'Initial Stock',
                        icon: Icons.inventory_2,
                        initialValue: variant.stockQuantity.toString(),
                        numeric: true,
                        onChanged: (v) => _formStore.updateRetailVariant(
                          index,
                          variant.copyWith(
                            stockQuantity: double.tryParse(v) ?? 0,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildVariantSkuField(variant, index),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Expanded(
                            child: _buildVariantField(
                              variant: variant,
                              field: 'barcode',
                              label: 'Barcode',
                              icon: Icons.qr_code_2,
                              initialValue: variant.barcode,
                              onChanged: (v) => _formStore.updateRetailVariant(
                                index,
                                variant.copyWith(barcode: v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildVariantField(
                              variant: variant,
                              field: 'costPrice',
                              label: 'Cost Price',
                              icon: Icons.money_off,
                              initialValue: variant.costPrice.toString(),
                              numeric: true,
                              onChanged: (v) => _formStore.updateRetailVariant(
                                index,
                                variant.copyWith(
                                  costPrice: double.tryParse(v) ?? 0,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Expanded(
                            child: _buildVariantField(
                              variant: variant,
                              field: 'price',
                              label: 'Selling Price',
                              icon: Icons.attach_money,
                              initialValue: variant.price.toString(),
                              numeric: true,
                              onChanged: (v) => _formStore.updateRetailVariant(
                                index,
                                variant.copyWith(
                                  price: double.tryParse(v) ?? 0,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Expanded(
                            child: _buildVariantField(
                              variant: variant,
                              field: 'mrp',
                              label: 'MRP',
                              icon: Icons.price_check,
                              initialValue: variant.mrp.toString(),
                              numeric: true,
                              onChanged: (v) => _formStore.updateRetailVariant(
                                index,
                                variant.copyWith(mrp: double.tryParse(v) ?? 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildVariantField(
                              variant: variant,
                              field: 'stockQuantity',
                              label: 'Initial Stock',
                              icon: Icons.inventory_2,
                              initialValue: variant.stockQuantity.toString(),
                              numeric: true,
                              onChanged: (v) => _formStore.updateRetailVariant(
                                index,
                                variant.copyWith(
                                  stockQuantity: double.tryParse(v) ?? 0,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          const Expanded(child: SizedBox.shrink()),
                        ],
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

  /// `AppTextField` bound to a persistent per-(variant,field) controller, so
  /// externally-triggered changes (bulk edit) show up immediately without
  /// needing a key-remount trick.
  Widget _buildVariantField({
    required VariantFormData variant,
    required String field,
    required String label,
    required IconData icon,
    required String initialValue,
    required ValueChanged<String> onChanged,
    bool numeric = false,
  }) {
    final controller = _variantController(variant.id, field, initialValue);
    return AppTextField(
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
    );
  }

  /// SKU field with an "Auto-generate" suffix button. Writes directly to the
  /// persistent controller so the generated value appears immediately.
  Widget _buildVariantSkuField(VariantFormData variant, int index) {
    final controller = _variantController(variant.id, 'sku', variant.sku);
    return AppTextField(
      controller: controller,
      label: 'SKU',
      icon: Icons.qr_code,
      suffixIcon: IconButton(
        icon: Icon(Icons.auto_awesome, size: AppResponsive.iconSize(context)),
        onPressed: () =>
            _onAutoGenerateVariantSkuPressed(index, variant, controller),
        tooltip: 'Auto-generate',
      ),
      onChanged: (v) =>
          _formStore.updateRetailVariant(index, variant.copyWith(sku: v)),
    );
  }

  Future<void> _onAutoGenerateVariantSkuPressed(
    int index,
    VariantFormData variant,
    TextEditingController skuController,
  ) async {
    if (variant.sku.trim().isNotEmpty) {
      NotificationService.instance.showError(
        'SKU is already set — clear it first to generate a new one.',
      );
      return;
    }
    final sku = await skuGeneratorService.generate(_selectedCategoryName());
    if (!mounted) return;
    _formStore.updateRetailVariant(index, variant.copyWith(sku: sku));
    skuController.text = sku;
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
            subtitle: const Text(
              'Enable if item has different sizes (Small, Medium, Large)',
            ),
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
                SizedBox(height: AppResponsive.largeSpacing(context)),
                ..._formStore.portionSizes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final size = entry.value;
                  return _buildPortionSizeCard(size, index, isMobile);
                }),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                OutlinedButton.icon(
                  onPressed: () => _formStore.addPortionSize(),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Add Variant',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.buttonFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

  Widget _buildPortionSizeCard(
    PortionSizeFormData size,
    int index,
    bool isMobile,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: size.name,
                decoration: InputDecoration(
                  labelText: 'Variant Name',
                  hintText: 'e.g., Small, Medium, Large',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                  isDense: true,
                ),
                onChanged: (v) =>
                    _formStore.updatePortionSize(index, size.copyWith(name: v)),
              ),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Expanded(
              child: TextFormField(
                initialValue: size.price > 0 ? size.price.toString() : '',
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: CurrencyHelper.currentSymbol,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _formStore.updatePortionSize(
                  index,
                  size.copyWith(price: double.tryParse(v) ?? 0),
                ),
              ),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            if (_formStore.trackInventory)
              Expanded(
                child: TextFormField(
                  initialValue: size.stockQuantity > 0
                      ? size.stockQuantity.toString()
                      : '',
                  decoration: InputDecoration(
                    labelText: 'Stock',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppResponsive.smallBorderRadius(context),
                      ),
                    ),
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
        SizedBox(height: AppResponsive.largeSpacing(context)),

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
            Text(
              'Choice Groups (Free Selections)',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            if (choices.isEmpty)
              Container(
                padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                ),
                child: Text(
                  'No choice groups available. Create them in settings.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: choices.map((choice) {
                  final isSelected = _formStore.selectedChoiceIds.contains(
                    choice.id,
                  );
                  return FilterChip(
                    label: Text(choice.name),
                    selected: isSelected,
                    onSelected: (_) => _formStore.toggleChoiceGroup(choice.id),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    avatar: isSelected
                        ? Icon(
                            Icons.check_circle,
                            size: AppResponsive.smallIconSize(context),
                            color: AppColors.primary,
                          )
                        : Icon(
                            Icons.radio_button_unchecked,
                            size: AppResponsive.smallIconSize(context),
                          ),
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
            Text(
              'Extra Groups (Paid Add-ons)',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            if (extras.isEmpty)
              Container(
                padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                ),
                child: Text(
                  'No extra groups available. Create them in settings.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Column(
                children: extras.map((extra) {
                  final isSelected = _formStore.selectedExtraIds.contains(
                    extra.Id,
                  );
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
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) =>
                                        _formStore.setExtraConstraint(
                                          extra.Id,
                                          int.tryParse(v) ?? 0,
                                          constraint.max,
                                        ),
                                  ),
                                ),
                                SizedBox(
                                  width: AppResponsive.largeSpacing(context),
                                ),
                                const Text('Max: '),
                                SizedBox(
                                  width: 50,
                                  child: TextFormField(
                                    initialValue: constraint.max.toString(),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) =>
                                        _formStore.setExtraConstraint(
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

        // Unit of measure + expiry apply to every variant of the product, so
        // they sit above the per-variant stock fields and stay visible for
        // variable products too (where the stock inputs are hidden).
        if (AppConfig.isRetail) ...[
          _buildUnitOfMeasureSection(),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          _buildExpirySection(),
          SizedBox(height: AppResponsive.largeSpacing(context)),
        ],

        if (AppConfig.isRetail) ...[
          // Retail Inventory (Simple product only)
          Observer(
            builder: (_) {
              if (_formStore.productType == 'variable') {
                return Container(
                  padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Expanded(
                        child: Text(
                          'Stock is managed per variant for variable products.',
                          style: GoogleFonts.poppins(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  SwitchListTile(
                    title: const Text('Track Inventory'),
                    subtitle: const Text(
                      'Enable stock tracking for this product',
                    ),
                    value: _formStore.trackInventory,
                    onChanged: (v) => _formStore.setTrackInventory(v),
                    activeColor: AppColors.primary,
                  ),
                  if (_formStore.trackInventory) ...[
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    isMobile
                        ? Column(
                            children: [
                              _buildTextField(
                                controller: _stockController,
                                label: 'Initial Stock',
                                icon: Icons.inventory_2,
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(
                                height: AppResponsive.largeSpacing(context),
                              ),
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
                              SizedBox(
                                width: AppResponsive.largeSpacing(context),
                              ),
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
                          ),
                  ],
                  // Mirrors the restaurant switch below. Only meaningful when
                  // stock is being tracked at all.
                  if (_formStore.trackInventory)
                    SwitchListTile(
                      title: const Text('Allow Order When Out of Stock'),
                      subtitle: const Text(
                        'Sells on at zero stock — the count goes negative',
                      ),
                      value: _formStore.allowOrderWhenOutOfStock,
                      onChanged: (v) =>
                          _formStore.setAllowOrderWhenOutOfStock(v),
                      activeColor: AppColors.warning,
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

                if (_formStore.trackInventory &&
                    !_formStore.hasPortionSizes) ...[
                  SizedBox(height: AppResponsive.largeSpacing(context)),
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
                    subtitle: const Text(
                      'Customers can still order when stock is 0',
                    ),
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
            padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Expanded(
                  child: Text(
                    'SKU and Barcode are managed per variant for variable products.',
                    style: GoogleFonts.poppins(color: Colors.black87),
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
                      onPressed: _onAutoGenerateSkuPressed,
                      tooltip: 'Auto-generate',
                    ),
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  _buildTextField(
                    controller: _barcodeController,
                    label: 'Barcode',
                    icon: Icons.barcode_reader,
                    iconColor: AppColors.info,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () {
                        // Scan barcode
                        NotificationService.instance.showSuccess(
                          'Barcode scanner coming soon',
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
                        onPressed: _onAutoGenerateSkuPressed,
                        tooltip: 'Auto-generate',
                      ),
                    ),
                  ),
                  SizedBox(width: AppResponsive.largeSpacing(context)),
                  Expanded(
                    child: _buildTextField(
                      controller: _barcodeController,
                      label: 'Barcode',
                      icon: Icons.barcode_reader,
                      iconColor: AppColors.info,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () {
                          NotificationService.instance.showSuccess(
                            'Barcode scanner coming soon',
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
    final isEditMode =
        _editingProductId != null || _editingRestaurantItemId != null;

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
              child: Text(
                'Clear Form',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.buttonFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
          SizedBox(width: AppResponsive.largeSpacing(context)),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _formStore.isLoading ? null : _submitForm,
              icon: _formStore.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
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
                foregroundColor: Colors.white,
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

  InputDecoration _fieldDec(
    String label,
    IconData icon, {
    Color? iconColor,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        color: AppColors.textSecondary,
        fontSize: AppResponsive.smallFontSize(context),
      ),
      prefixIcon: Icon(
        icon,
        color: iconColor ?? AppColors.primary,
        size: AppResponsive.iconSize(context),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

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
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        color: AppColors.textPrimary,
      ),
      decoration: _fieldDec(
        label,
        icon,
        iconColor: iconColor,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildExcelImportCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            size: AppResponsive.largeIconSize(context),
            color: AppColors.primary,
            Icons.table_chart,
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Text(
              'Bulk Import via Excel',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                color: AppColors.darkNeutral,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppConfig.isRestaurant
                      ? const RestaurantBulkImportScreen()
                      : const BulkImportScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.upload_file,
              size: AppResponsive.smallIconSize(context),
            ),
            label: Text(
              'Import',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.buttonFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        MaterialPageRoute(builder: (context) => const BulkImportScreen()),
      );
    } else if (AppConfig.isRestaurant) {
      final message = await restaurantImportService.downloadTemplate();
      if (mounted) {
        if (message.startsWith('Error') || message == 'Permission denied') {
          NotificationService.instance.showError(message);
        } else {
          NotificationService.instance.showSuccess(message);
        }
      }
    } else {
      NotificationService.instance.showError(
        'Bulk import is not available for this mode',
      );
    }
  }

  void _uploadExcel() async {
    if (AppConfig.isRetail) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BulkImportScreen()),
      );
    } else if (AppConfig.isRestaurant) {
      try {
        final allSheets = await restaurantImportService.pickAndParseFile();
        if (allSheets.isNotEmpty) {
          // Count total rows from Items sheet
          final itemsSheet = allSheets['Items'];
          final itemCount =
              (itemsSheet?.length ?? 1) - 1; // Subtract header row

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
                    SizedBox(height: AppResponsive.smallSpacing(context)),
                    if (itemCount > 0) Text('Items to import: $itemCount'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Get the navigator before closing any dialogs
                    final navigator = Navigator.of(
                      context,
                      rootNavigator: true,
                    );

                    Navigator.pop(context);

                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final result = await restaurantImportService.importData(
                        allSheets,
                      );

                      // Close loading dialog using the saved navigator reference
                      try {
                        navigator.pop();
                      } catch (e) {}

                      if (!mounted) return;

                      // Show detailed result dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            result.success
                                ? '✅ Import Successful'
                                : '⚠️ Import Completed with Issues',
                          ),
                          content: SingleChildScrollView(
                            child: Text(result.getSummary()),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'OK',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                              NotificationService.instance.showSuccess(
                                '✅ Import successful! Go to "Manage Menu" to view all imported items.',
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
                              child: Text(
                                'OK',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Import',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.buttonFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          NotificationService.instance.showError('Import failed: $e');
        }
      }
    } else {
      NotificationService.instance.showError(
        'Bulk import is not available for this mode',
      );
    }
  }

  // ==================== EDIT FUNCTIONS ====================

  /// Descriptor fields for a SIMPLE product (Settings → Simple Product Fields).
  /// Mirrors the retail Add Product screen so both entry points behave alike.
  List<AttributeModel> _simpleFields = [];
  final Map<String, TextEditingController> _simpleFieldControllers = {};

  Future<void> _loadSimpleFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() => _simpleFields = fields);
  }

  TextEditingController _simpleFieldController(AttributeModel attribute) =>
      _simpleFieldControllers.putIfAbsent(attribute.attributeId, () {
        final c = TextEditingController(
          text: _formStore.simpleFieldValues[attribute.name] ?? '',
        );
        return c;
      });

  /// Inputs for the configured descriptor fields, shown for simple products.
  /// Values land in the default variant's `customAttributes` on save.
  ///
  /// Always rendered — even with no fields configured — so the customise action
  /// stays reachable. During setup the user hasn't seen Settings yet, so this
  /// is the only place they can change what Size / Color / Weight should be.
  Widget _buildSimpleFieldsSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppResponsive.largeSpacing(context)),
        Row(
          children: [
            Text(
              'Product Details',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                color: AppColors.darkNeutral,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.tune,
                size: AppResponsive.iconSize(context),
                color: AppColors.primary,
              ),
              tooltip: 'Choose which fields appear',
              visualDensity: VisualDensity.compact,
              onPressed: _openSimpleFieldSettings,
            ),
          ],
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        if (_simpleFields.isEmpty)
          Text(
            'No detail fields. Tap the tune icon to add Size, Colour, Flavour '
            'or your own — price, stock, barcode and SKU always show.',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          )
        else
          for (final attribute in _simpleFields) ...[
            _buildSimpleFieldInput(attribute),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
          ],
      ],
    );
  }

  /// One descriptor input. Offers the attribute's preset values as a menu while
  /// still accepting free text — same behaviour as the retail Add Product form.
  Widget _buildSimpleFieldInput(AttributeModel attribute) {
    final controller = _simpleFieldController(attribute);
    final values = attributeStore.getValues(attribute.attributeId);

    return AppTextField(
      controller: controller,
      label: attribute.name,
      hint: _simpleFieldHint(attribute),
      onChanged: (v) => _formStore.setSimpleFieldValue(attribute.name, v),
      suffixIcon: values.isEmpty
          ? null
          : PopupMenuButton<String>(
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: AppResponsive.iconSize(context),
                color: AppColors.textSecondary,
              ),
              tooltip: 'Choose ${attribute.name}',
              // M3 tints menu surfaces by default; keep them plain white.
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadius(context),
                ),
              ),
              onSelected: (value) {
                controller.text = value;
                _formStore.setSimpleFieldValue(attribute.name, value);
              },
              itemBuilder: (_) => values
                  .map(
                    (v) => PopupMenuItem<String>(
                      value: v.value,
                      child: Text(
                        v.value,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  /// Opens the shared Simple Product Fields configurator, then re-resolves the
  /// list. Values and controllers for fields the user just removed are dropped
  /// so a deleted field can't still be written onto the default variant.
  Future<void> _openSimpleFieldSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SimpleProductFieldsScreen()),
    );
    if (!mounted) return;

    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;

    final keptNames = fields.map((a) => a.name).toSet();
    for (final name in _formStore.simpleFieldValues.keys.toList()) {
      if (!keptNames.contains(name)) _formStore.setSimpleFieldValue(name, '');
    }

    final keptIds = fields.map((a) => a.attributeId).toSet();
    for (final id in _simpleFieldControllers.keys.toList()) {
      if (!keptIds.contains(id)) _simpleFieldControllers.remove(id)?.dispose();
    }

    setState(() => _simpleFields = fields);
  }

  String? _simpleFieldHint(AttributeModel attribute) {
    final values = attributeStore.getValues(attribute.attributeId);
    return values.isEmpty ? null : 'e.g. ${values.first.value}';
  }

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
    // setSelectedTaxId re-derives the rate; fall back to the stored gstRate for
    // products saved before taxId existed (or whose tax record is gone).
    _formStore.setSelectedTaxId(product.taxId);
    _formStore.setAllowOrderWhenOutOfStock(product.sellsWhenOutOfStock);
    if (_formStore.taxRate == 0 && (product.gstRate ?? 0) > 0) {
      _formStore.setTaxRate(product.gstRate!);
    }
    _taxRateController.text = _formStore.taxRate > 0
        ? _formStore.taxRate.toString()
        : '';
    _formStore.setProductType(product.hasVariants ? 'variable' : 'simple');
    // Round-trip the descriptor fields from the product's default variant.
    if (!product.hasVariants) {
      // A local `productStore` is declared further down this method, so
      // resolve the singleton explicitly here.
      final existing = locator<ProductStore>().variantsFor(product.productId);
      final defaultVariant = existing.isEmpty
          ? null
          : existing.firstWhere(
              (v) => v.isDefault,
              orElse: () => existing.first,
            );
      defaultVariant?.customAttributes?.forEach((key, value) {
        _formStore.setSimpleFieldValue(key, value);
        final attribute = attributeStore.getAttributeByName(key);
        if (attribute != null) {
          _simpleFieldController(attribute).text = value;
        }
      });
    }
    // Existing products already have stock data — keep it visible on edit
    // instead of hiding it behind the Track Inventory toggle.
    _formStore.setTrackInventory(true);

    // Load variants from the database
    final productStore = locator<ProductStore>();
    final variants = await productStore.getVariantsForProduct(
      product.productId,
    );

    // Unit / decimal-quantity / expiry are written identically onto every
    // variant, so the first one is authoritative for the form.
    if (variants.isNotEmpty) {
      final first = variants.first;
      _formStore.setIsDecimalQuantity(first.isDecimalQuantity);
      if (first.isDecimalQuantity && first.unit != null) {
        _formStore.setUnit(first.unit);
      }
      _formStore.setExpiryDate(first.expiryDateTime);
    }

    if (product.hasVariants && variants.isNotEmpty) {
      // Variable product: Load all variants into the form
      _disposeAllVariantControllers();
      _formStore.retailVariants.clear();
      for (final variant in variants) {
        _formStore.retailVariants.add(
          VariantFormData(
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
          ),
        );
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

    NotificationService.instance.showSuccess(
      'Editing: ${product.productName}${product.hasVariants ? " (${variants.length} variants)" : ""}',
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
    _restaurantStockController.text = item.stockQuantity?.toString() ?? '';

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

  /// Product thumbnail. Falls back to the placeholder icon when the image file
  /// is missing/unreadable (e.g. moved or cleared by the OS) instead of
  /// letting Image.file throw and break the whole row.
  Widget _buildProductThumb(String? imagePath) {
    const placeholder = Icon(Icons.inventory, color: AppColors.primary);
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
      ),
      child: imagePath == null
          ? placeholder
          : ClipRRect(
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
            ),
    );
  }

  /// Deleting a product also cascades to all its variants, so confirm first.
  Future<void> _confirmDeleteRetailProduct(ProductModel product) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Product?',
      message: product.hasVariants
          ? '"${product.productName}" and all of its variants will be permanently deleted. This cannot be undone.'
          : '"${product.productName}" will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirmed || !mounted) return;
    await locator<ProductStore>().deleteProduct(product.productId);
  }

  Widget _buildRetailProductList() {
    final productStore = locator<ProductStore>();

    return Container(
      padding: EdgeInsets.all(
        AppResponsive.getValue(
          context,
          mobile: 20.0,
          tablet: 24.0,
          desktop: 28.0,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Observer(
              builder: (_) {
                final filteredProducts = _getFilteredRetailProducts(
                  productStore,
                );
                return _buildListHeader(filteredProducts.length, 'Products');
              },
            ),
            Expanded(
              child: Observer(
                builder: (_) {
                  final filteredProducts = _getFilteredRetailProducts(
                    productStore,
                  );
                  return filteredProducts.isEmpty
                      ? _buildEmptyState('products')
                      : ListView.separated(
                          padding: EdgeInsets.all(
                            AppResponsive.getValue(
                              context,
                              mobile: 20.0,
                              tablet: 24.0,
                              desktop: 28.0,
                            ),
                          ),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ListTile(
                              leading: _buildProductThumb(product.imagePath),
                              title: Text(
                                product.productName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${categoryStore.getCategoryById(product.category)?.name ?? product.category} • ${product.hasVariants ? "Variable" : "Simple"}',
                              ),
                              // Visible edit/delete rather than an overflow
                              // menu: same as the restaurant item list below and
                              // retail's category/product/variant rows.
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RowActionButton(
                                    icon: Icons.edit_outlined,
                                    color: AppColors.primary,
                                    tooltip: 'Edit',
                                    onTap: () => _editRetailProduct(product),
                                  ),
                                  SizedBox(
                                    width: AppResponsive.smallSpacing(context),
                                  ),
                                  RowActionButton(
                                    icon: Icons.delete_outline_rounded,
                                    color: AppColors.danger,
                                    tooltip: 'Delete',
                                    onTap: () =>
                                        _confirmDeleteRetailProduct(product),
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
      padding: EdgeInsets.all(
        AppResponsive.getValue(
          context,
          mobile: 20.0,
          tablet: 24.0,
          desktop: 28.0,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                    padding: EdgeInsets.all(
                      AppResponsive.getValue(
                        context,
                        mobile: 20.0,
                        tablet: 24.0,
                        desktop: 28.0,
                      ),
                    ),
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
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppResponsive.smallBorderRadius(context),
                            ),
                          ),
                          child: item.imageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppResponsive.smallBorderRadius(context),
                                  ),
                                  child: Image.memory(
                                    item.imageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(Icons.restaurant),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${CurrencyHelper.currentSymbol}${item.price ?? "Multiple sizes"} • ${item.isEnabled ? "Active" : "Disabled"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: item.isEnabled,
                              onChanged: (_) async {
                                final updatedItem = item.copyWith(
                                  isEnabled: !item.isEnabled,
                                );
                                await itemStore.updateItem(updatedItem);
                              },
                              activeColor: AppColors.success,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: AppResponsive.iconSize(context),
                              ),
                              onPressed: () => _editRestaurantItem(item),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                size: AppResponsive.iconSize(context),
                                color: AppColors.danger,
                              ),
                              onPressed: () async {
                                final confirmed = await showAppConfirmDialog(
                                  context: context,
                                  title: 'Delete Item?',
                                  message:
                                      '"${item.name}" will be permanently deleted. This cannot be undone.',
                                  confirmLabel: 'Delete',
                                  accent: AppColors.danger,
                                  icon: Icons.delete_outline_rounded,
                                );
                                if (!confirmed) return;
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
      padding: EdgeInsets.all(
        AppResponsive.getValue(
          context,
          mobile: 20.0,
          tablet: 24.0,
          desktop: 28.0,
        ),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppResponsive.borderRadius(context)),
        ),
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
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.headingFontSize(context),
                  color: AppColors.darkNeutral,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count items',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: AppResponsive.mediumSpacing(context)),
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
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: AppResponsive.captionFontSize(
                                  context,
                                ),
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

          SizedBox(height: AppResponsive.mediumSpacing(context)),

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
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),

          // Active filter badges
          if (activeFilters > 0 || _searchQuery.isNotEmpty) ...[
            SizedBox(height: AppResponsive.mediumSpacing(context)),
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
                    deleteIcon: Icon(
                      Icons.close,
                      size: AppResponsive.smallIconSize(context),
                    ),
                    backgroundColor: AppColors.info.withValues(alpha: 0.2),
                  ),

                // Category filter badges
                if (_selectedCategories.isNotEmpty)
                  ..._selectedCategories.map(
                    (cat) => Chip(
                      label: Text(
                        'Category: ${categoryStore.getCategoryById(cat)?.name ?? cat}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedCategories.remove(cat);
                        });
                      },
                      deleteIcon: Icon(
                        Icons.close,
                        size: AppResponsive.smallIconSize(context),
                      ),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),

                // Retail-specific badges
                if (AppConfig.isRetail) ...[
                  if (_selectedProductType != null &&
                      _selectedProductType != 'all')
                    Chip(
                      label: Text(
                        'Type: ${_selectedProductType![0].toUpperCase()}${_selectedProductType!.substring(1)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedProductType = 'all';
                        });
                      },
                      deleteIcon: Icon(
                        Icons.close,
                        size: AppResponsive.smallIconSize(context),
                      ),
                      backgroundColor: AppColors.secondary.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  if (_selectedBrands.isNotEmpty)
                    ..._selectedBrands.map(
                      (brand) => Chip(
                        label: Text('Brand: $brand'),
                        onDeleted: () {
                          setState(() {
                            _selectedBrands.remove(brand);
                          });
                        },
                        deleteIcon: Icon(
                          Icons.close,
                          size: AppResponsive.smallIconSize(context),
                        ),
                        backgroundColor: AppColors.success.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                ],

                // Restaurant-specific badges
                if (AppConfig.isRestaurant) ...[
                  if (_selectedVegFilter != null && _selectedVegFilter != 'all')
                    Chip(
                      label: Text(
                        _selectedVegFilter == 'veg'
                            ? 'Veg Only'
                            : 'Non-Veg Only',
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedVegFilter = 'all';
                        });
                      },
                      deleteIcon: Icon(
                        Icons.close,
                        size: AppResponsive.smallIconSize(context),
                      ),
                      backgroundColor: _selectedVegFilter == 'veg'
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.danger.withValues(alpha: 0.2),
                    ),
                  if (_selectedStatusFilter != null &&
                      _selectedStatusFilter != 'all')
                    Chip(
                      label: Text(
                        'Status: ${_selectedStatusFilter![0].toUpperCase()}${_selectedStatusFilter!.substring(1)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedStatusFilter = 'all';
                        });
                      },
                      deleteIcon: Icon(
                        Icons.close,
                        size: AppResponsive.smallIconSize(context),
                      ),
                      backgroundColor: _selectedStatusFilter == 'active'
                          ? AppColors.success.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                    ),
                ],

                // Clear all filters button
                if (activeFilters > 0 || _searchQuery.isNotEmpty)
                  ActionChip(
                    label: Text(
                      'Clear All',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.buttonFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                    onPressed: _clearAllFilters,
                    backgroundColor: AppColors.danger.withValues(alpha: 0.1),
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
            size: AppResponsive.getValue(
              context,
              mobile: 80.0,
              tablet: 96.0,
              desktop: 112.0,
            ),
            color: Colors.grey[300],
            Icons.inventory_2,
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          Text(
            'No $type added yet',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            'Add $type manually or upload Excel file',
            style: GoogleFonts.poppins(
              color: Colors.grey[400],
              fontSize: AppResponsive.bodyFontSize(context),
            ),
          ),
          SizedBox(height: AppResponsive.extraLargeSpacing(context)),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(0),
            icon: const Icon(Icons.add),
            label: Text('Add First ${type == 'products' ? 'Product' : 'Item'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
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
        final sizeAttr = attributeStore.attributes.firstWhere(
          (a) => a.name == 'Size',
        );
        await attributeStore.addMultipleValues(sizeAttr.attributeId, [
          'Small',
          'Medium',
          'Large',
          'Extra Large',
        ]);
      }

      // Create Color attribute with values
      final colorCreated = await attributeStore.addAttribute('Color');
      if (colorCreated) {
        final colorAttr = attributeStore.attributes.firstWhere(
          (a) => a.name == 'Color',
        );
        await attributeStore.addMultipleValues(
          colorAttr.attributeId,
          ['Red', 'Blue', 'Green', 'Black', 'White'],
          colorCodes: ['#FF0000', '#0000FF', '#00FF00', '#000000', '#FFFFFF'],
        );
      }

      // Create Weight attribute with values
      final weightCreated = await attributeStore.addAttribute('Weight');
      if (weightCreated) {
        final weightAttr = attributeStore.attributes.firstWhere(
          (a) => a.name == 'Weight',
        );
        await attributeStore.addMultipleValues(weightAttr.attributeId, [
          '250g',
          '500g',
          '1kg',
        ]);
      }

      // Force UI update by triggering a rebuild
      if (mounted) {
        setState(() {});

        final message =
            attributeStore.errorMessage ??
            'Default attributes created successfully!';
        if (attributeStore.errorMessage != null) {
          NotificationService.instance.showError(message);
        } else {
          NotificationService.instance.showSuccess(message);
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error creating attributes: $e');
      }
    }
  }

  void _showAddAttributeDialog(AttributeStore attributeStore) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        Future<void> create() async {
          final name = nameController.text.trim();
          if (name.isEmpty) {
            NotificationService.instance.showError(
              'Please enter an attribute name',
            );
            return;
          }

          final success = await attributeStore.addAttribute(name);
          if (mounted) {
            Navigator.pop(context);
            if (success) {
              NotificationService.instance.showSuccess(
                'Attribute "$name" created successfully!',
              );
              _showAddValuesDialog(
                attributeStore,
                attributeStore.attributes.last,
              );
            } else {
              NotificationService.instance.showError(
                attributeStore.errorMessage ?? 'Failed to create attribute',
              );
            }
          }
        }

        return DialogDisposeScope(
          disposables: [nameController],
          child: AppDialogShell(
            title: 'Add New Attribute',
            icon: Icons.label_outline,
            accent: AppColors.primary,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: nameController,
                  label: 'Attribute Name',
                  hint: 'e.g., Size, Color, Material',
                  icon: Icons.label_outline,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => create(),
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                Text(
                  'You can add values for this attribute after creating it.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              appDialogCancelButton(context),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              appDialogPrimaryButton(label: 'Create', onPressed: create),
            ],
          ),
        );
      },
    );
  }

  void _showAddValuesDialog(
    AttributeStore attributeStore,
    AttributeModel attribute,
  ) {
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => DialogDisposeScope(
        disposables: [valueController],
        child: AppDialogShell(
          title: 'Add Values for ${attribute.name}',
          icon: Icons.playlist_add,
          accent: AppColors.primary,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: valueController,
                label: 'Value',
                hint: 'e.g., Small, Medium, Large',
                icon: Icons.label_outline,
                autofocus: true,
                onFieldSubmitted: (value) async {
                  if (value.trim().isNotEmpty) {
                    await attributeStore.addValue(
                      attribute.attributeId,
                      value.trim(),
                    );
                    valueController.clear();
                  }
                },
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              Text(
                'Press Enter to add each value. Click Done when finished.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(context, label: 'Done'),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            appDialogPrimaryButton(
              label: 'Add Value',
              onPressed: () async {
                final value = valueController.text.trim();
                if (value.isNotEmpty) {
                  await attributeStore.addValue(attribute.attributeId, value);
                  valueController.clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showValueActionsSheet(
    AttributeStore attributeStore,
    AttributeModel attribute,
    AttributeValueModel value,
  ) {
    _dismissLongPressTip();

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
              child: Text(
                value.value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: AppResponsive.subheadingFontSize(context),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Edit Value'),
              onTap: () {
                Navigator.pop(context);
                _showEditAttributeValueDialog(attributeStore, attribute, value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Value'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteAttributeValue(attributeStore, attribute, value);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddValueToAttributeDialog(
    AttributeStore attributeStore,
    AttributeModel attribute,
  ) {
    final valueController = TextEditingController();
    final colorController = TextEditingController();
    final isColor =
        attribute.name.toLowerCase().contains('color') ||
        attribute.name.toLowerCase().contains('colour');

    showDialog(
      context: context,
      builder: (context) => DialogDisposeScope(
        disposables: [valueController, colorController],
        child: AppDialogShell(
          title: 'Add ${attribute.name} Value',
          icon: Icons.add_circle_outline,
          accent: AppColors.primary,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: valueController,
                label: 'Value',
                icon: Icons.label_outline,
                autofocus: true,
              ),
              if (isColor) ...[
                SizedBox(height: AppResponsive.largeSpacing(context)),
                AppTextField(
                  controller: colorController,
                  label: 'Color Code (optional)',
                  hint: '#FF0000',
                  icon: Icons.palette_outlined,
                ),
              ],
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Text(
                'Tip: separate multiple values with commas',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(context),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            appDialogPrimaryButton(
              label: 'Add',
              onPressed: () async {
                final input = valueController.text.trim();
                if (input.isEmpty) {
                  NotificationService.instance.showError(
                    'Please enter a value',
                  );
                  return;
                }

                final values = input
                    .split(',')
                    .map((v) => v.trim())
                    .where((v) => v.isNotEmpty)
                    .toList();

                bool success;
                if (values.length > 1) {
                  success = await attributeStore.addMultipleValues(
                    attribute.attributeId,
                    values,
                  );
                } else {
                  success = await attributeStore.addValue(
                    attribute.attributeId,
                    values.first,
                    colorCode: colorController.text.trim().isNotEmpty
                        ? colorController.text.trim()
                        : null,
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
                if (success) {
                  NotificationService.instance.showSuccess(
                    'Added ${values.length} value(s)',
                  );
                } else {
                  NotificationService.instance.showError(
                    attributeStore.errorMessage ?? 'Failed to add value',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAttributeValueDialog(
    AttributeStore attributeStore,
    AttributeModel attribute,
    AttributeValueModel value,
  ) {
    final valueController = TextEditingController(text: value.value);
    final colorController = TextEditingController(text: value.colorCode ?? '');
    final isColor =
        attribute.name.toLowerCase().contains('color') ||
        attribute.name.toLowerCase().contains('colour');

    showDialog(
      context: context,
      builder: (context) => DialogDisposeScope(
        disposables: [valueController, colorController],
        child: AppDialogShell(
          title: 'Edit ${attribute.name} Value',
          icon: Icons.edit_outlined,
          accent: AppColors.primary,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: valueController,
                label: 'Value',
                icon: Icons.label_outline,
                autofocus: true,
              ),
              if (isColor) ...[
                SizedBox(height: AppResponsive.largeSpacing(context)),
                AppTextField(
                  controller: colorController,
                  label: 'Color Code (optional)',
                  hint: '#FF0000',
                  icon: Icons.palette_outlined,
                ),
              ],
            ],
          ),
          actions: [
            appDialogCancelButton(context),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            appDialogPrimaryButton(
              label: 'Update',
              onPressed: () async {
                final newValue = valueController.text.trim();
                if (newValue.isEmpty) {
                  NotificationService.instance.showError(
                    'Please enter a value',
                  );
                  return;
                }

                final success = await attributeStore.updateValue(
                  value.valueId,
                  value: newValue,
                  colorCode: colorController.text.trim().isNotEmpty
                      ? colorController.text.trim()
                      : null,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                }
                if (success) {
                  NotificationService.instance.showSuccess(
                    'Value "$newValue" updated',
                  );
                } else {
                  NotificationService.instance.showError(
                    attributeStore.errorMessage ?? 'Failed to update value',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAttributeValue(
    AttributeStore attributeStore,
    AttributeModel attribute,
    AttributeValueModel value,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Value?',
      message: 'Are you sure you want to delete "${value.value}"?',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;

    final success = await attributeStore.deleteValue(value.valueId);
    if (success) {
      // Deselecting a deleted value so it can't linger selected —
      // reassign (not mutate in place) to trigger MobX reactivity,
      // matching _formStore.toggleAttributeValue's own pattern.
      final selected =
          _formStore.selectedAttributeValues[attribute.attributeId];
      if (selected != null && selected.contains(value.valueId)) {
        _formStore.selectedAttributeValues[attribute.attributeId] = selected
            .where((id) => id != value.valueId)
            .toList();
      }
      NotificationService.instance.showSuccess(
        'Value "${value.value}" deleted',
      );
    } else {
      NotificationService.instance.showError(
        attributeStore.errorMessage ?? 'Failed to delete value',
      );
    }
  }

  void _showVariantGenerationDialog(AttributeStore attributeStore) {
    // Generate preview combinations
    final selectedAttrs = <String, List<AttributeValueModel>>{};
    for (final attrId in _formStore.selectedAttributeIds) {
      final valueIds = _formStore.selectedAttributeValues[attrId] ?? [];
      if (valueIds.isNotEmpty) {
        final attr = attributeStore.attributes.firstWhere(
          (a) => a.attributeId == attrId,
        );
        final values = attributeStore.allValues
            .where(
              (v) => v.attributeId == attrId && valueIds.contains(v.valueId),
            )
            .toList();
        if (values.isNotEmpty) {
          selectedAttrs[attr.name] = values;
        }
      }
    }

    final combinations = _generateCombinationsPreview(selectedAttrs);
    final selectedCombinations = List<bool>.filled(
      combinations.length,
      true,
    ); // All selected by default

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AppDialogShell(
          title: 'Select Variants to Generate',
          icon: Icons.auto_awesome,
          accent: AppColors.secondary,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info message
              Container(
                padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context),
                  ),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                      size: AppResponsive.iconSize(context),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: Text(
                        'Select which variants you want to create. You can set prices and stock after generation using the bulk edit tool.',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: AppResponsive.bodyFontSize(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),

              // Variant Selection Section
              Text(
                'Select Variants to Generate (${combinations.length} total)',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (int i = 0; i < selectedCombinations.length; i++) {
                          selectedCombinations[i] = true;
                        }
                      });
                    },
                    child: Text(
                      'Select All',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (int i = 0; i < selectedCombinations.length; i++) {
                          selectedCombinations[i] = false;
                        }
                      });
                    },
                    child: Text(
                      'Deselect All',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: combinations.length,
                  itemBuilder: (context, index) {
                    final combo = combinations[index];
                    final variantName = combo.values
                        .map((v) => v.value)
                        .join(' - ');

                    return CheckboxListTile(
                      dense: true,
                      title: Text(
                        variantName,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          color: AppColors.textPrimary,
                        ),
                      ),
                      value: selectedCombinations[index],
                      activeColor: AppColors.secondary,
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
          actions: [
            appDialogCancelButton(context),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            appDialogPrimaryButton(
              color: AppColors.secondary,
              label: 'Generate Selected Variants',
              onPressed: () {
                // Count selected variants
                final selectedCount = selectedCombinations
                    .where((s) => s)
                    .length;

                if (selectedCount == 0) {
                  NotificationService.instance.showError(
                    'Please select at least one variant',
                  );
                  return;
                }

                // Generate only selected variants with default values (0)
                // User will set prices using bulk edit bar after generation
                _disposeAllVariantControllers();
                _formStore.retailVariants.clear();
                for (int i = 0; i < combinations.length; i++) {
                  if (selectedCombinations[i]) {
                    final combo = combinations[i];
                    final variantName = combo.values
                        .map((v) => v.value)
                        .join(' - ');

                    _formStore.retailVariants.add(
                      VariantFormData(
                        id: const Uuid().v4(),
                        name: variantName,
                        attributes: Map.fromEntries(
                          combo.entries.map(
                            (e) => MapEntry(e.key, e.value.value),
                          ),
                        ),
                        // Keyed by attributeId, not name — see the same note in
                        // AddProductFormStore._generateRetailVariants.
                        attributeValueIds: Map.fromEntries(
                          combo.entries.map(
                            (e) =>
                                MapEntry(e.value.attributeId, e.value.valueId),
                          ),
                        ),
                        price: 0, // Will be set using bulk edit
                        costPrice: 0, // Will be set using bulk edit
                        mrp: 0,
                        stockQuantity: 0, // Will be set using bulk edit
                      ),
                    );
                  }
                }

                Navigator.pop(context);

                NotificationService.instance.showSuccess(
                  '✓ Generated $selectedCount variant(s). Now set prices using bulk edit below.',
                );
              },
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
        final categoryName =
            categoryStore.getCategoryById(product.category)?.name ??
            product.category;
        return product.productName.toLowerCase().contains(searchLower) ||
            categoryName.toLowerCase().contains(searchLower) ||
            (product.brandName?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered
          .where(
            (product) =>
                product.category != null &&
                _selectedCategories.contains(product.category),
          )
          .toList();
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
      filtered = filtered
          .where(
            (product) =>
                product.brandName != null &&
                _selectedBrands.contains(product.brandName!),
          )
          .toList();
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
      filtered = filtered
          .where(
            (item) =>
                item.categoryOfItem != null &&
                _selectedCategories.contains(item.categoryOfItem!),
          )
          .toList();
    }

    // Apply veg/non-veg filter
    if (_selectedVegFilter != null && _selectedVegFilter != 'all') {
      filtered = filtered
          .where((item) => item.isVeg == _selectedVegFilter)
          .toList();
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
      if (_selectedProductType != null && _selectedProductType != 'all')
        count++;
      if (_selectedBrands.isNotEmpty) count++;
    } else {
      if (_selectedVegFilter != null && _selectedVegFilter != 'all') count++;
      if (_selectedStatusFilter != null && _selectedStatusFilter != 'all')
        count++;
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

  // ── Filter dialog building blocks ──────────────────────────────────────────
  // Shared by the retail and restaurant filter dialogs so both stay identical.

  Widget _filterSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: AppResponsive.bodyFontSize(context),
      ),
    ),
  );

  /// Single-select chip (product type, sort order). [accent] carries semantic
  /// meaning where the option has one (Veg = green, Non-Veg = red) and
  /// defaults to primary for neutral options.
  Widget _filterChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color? accent,
  }) {
    final color = accent ?? AppColors.primary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: color,
      backgroundColor: AppColors.white,
      showCheckmark: false,
      side: BorderSide(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }

  /// Multi-select chip (categories, brands).
  Widget _filterMultiChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
    selectedColor: AppColors.primary,
    backgroundColor: AppColors.white,
    showCheckmark: false,
    side: BorderSide(),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    labelStyle: GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    ),
  );

  /// "Clear All" affordance shown at the top of a filter dialog body. Disabled
  /// (greyed, non-tappable) when there is nothing to clear.
  Widget _filterClearAllRow({
    required bool hasActiveFilters,
    required VoidCallback onClear,
  }) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: hasActiveFilters ? onClear : null,
      icon: Icon(Icons.refresh_rounded),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      label: Text(
        'Clear All',
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.bodyFontSize(context),
          fontWeight: FontWeight.w600,
          color: hasActiveFilters ? AppColors.danger : AppColors.textSecondary,
        ),
      ),
    ),
  );

  Future<void> _showRetailFilterDialog() async {
    final productStore = locator<ProductStore>();

    final categories = categoryStore.categories.toList();
    final brands =
        productStore.products
            .map((p) => p.brandName)
            .where((b) => b != null && b.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

    final tempCategories = Set<String>.from(_selectedCategories);
    final tempBrands = Set<String>.from(_selectedBrands);
    String tempProductType = _selectedProductType ?? 'all';
    String tempSortBy = _retailSortBy;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasActiveFilters =
              tempCategories.isNotEmpty ||
              tempBrands.isNotEmpty ||
              tempProductType != 'all' ||
              tempSortBy != 'name_asc';

          return AppDialogShell(
            title: 'Filter Products',
            subtitle: 'Narrow down the list',
            accent: AppColors.primary,
            icon: Icons.filter_list_rounded,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterClearAllRow(
                  hasActiveFilters: hasActiveFilters,
                  onClear: () => setDialogState(() {
                    tempCategories.clear();
                    tempBrands.clear();
                    tempProductType = 'all';
                    tempSortBy = 'name_asc';
                  }),
                ),
                const SizedBox(height: 4),

                // Product Type
                _filterSectionLabel('Product Type'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in const [
                      ('all', 'All'),
                      ('simple', 'Simple'),
                      ('variable', 'Variable'),
                    ])
                      _filterChoiceChip(
                        label: type.$2,
                        selected: tempProductType == type.$1,
                        onSelected: () =>
                            setDialogState(() => tempProductType = type.$1),
                      ),
                  ],
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),

                // Categories
                if (categories.isNotEmpty) ...[
                  _filterSectionLabel('Categories'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (category) => _filterMultiChip(
                            label: category.name,
                            selected: tempCategories.contains(category.id),
                            onSelected: (selected) => setDialogState(() {
                              if (selected) {
                                tempCategories.add(category.id);
                              } else {
                                tempCategories.remove(category.id);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Brands
                if (brands.isNotEmpty) ...[
                  _filterSectionLabel('Brands'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: brands
                        .map(
                          (brand) => _filterMultiChip(
                            label: brand,
                            selected: tempBrands.contains(brand),
                            onSelected: (selected) => setDialogState(() {
                              if (selected) {
                                tempBrands.add(brand);
                              } else {
                                tempBrands.remove(brand);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Sort By
                _filterSectionLabel('Sort By'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sort in const [
                      ('name_asc', 'Name (A-Z)'),
                      ('name_desc', 'Name (Z-A)'),
                      ('recent', 'Recently Added'),
                    ])
                      _filterChoiceChip(
                        label: sort.$2,
                        selected: tempSortBy == sort.$1,
                        onSelected: () =>
                            setDialogState(() => tempSortBy = sort.$1),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              appDialogCancelButton(context),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              appDialogPrimaryButton(
                label: 'Apply Filters',
                onPressed: () {
                  setState(() {
                    _selectedCategories = tempCategories;
                    _selectedBrands = tempBrands;
                    _selectedProductType = tempProductType;
                    _retailSortBy = tempSortBy;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRestaurantFilterDialog(List<Items> items) async {
    // Get unique categories from items
    final categories =
        items
            .map((i) => i.categoryOfItem)
            .where((c) => c != null && c.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

    final tempCategories = Set<String>.from(_selectedCategories);
    String tempVegFilter = _selectedVegFilter ?? 'all';
    String tempStatusFilter = _selectedStatusFilter ?? 'all';
    String tempSortBy = _restaurantSortBy;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasActiveFilters =
              tempCategories.isNotEmpty ||
              tempVegFilter != 'all' ||
              tempStatusFilter != 'all' ||
              tempSortBy != 'name_asc';

          return AppDialogShell(
            title: 'Filter Items',
            subtitle: 'Narrow down the list',
            accent: AppColors.primary,
            icon: Icons.filter_list_rounded,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterClearAllRow(
                  hasActiveFilters: hasActiveFilters,
                  onClear: () => setDialogState(() {
                    tempCategories.clear();
                    tempVegFilter = 'all';
                    tempStatusFilter = 'all';
                    tempSortBy = 'name_asc';
                  }),
                ),
                const SizedBox(height: 4),

                // Food Type — semantic colours retained (veg green / non-veg red)
                _filterSectionLabel('Food Type'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final food in [
                      ('all', 'All', AppColors.primary),
                      ('veg', 'Veg', AppColors.success),
                      ('non-veg', 'Non-Veg', AppColors.danger),
                    ])
                      _filterChoiceChip(
                        label: food.$2,
                        accent: food.$3,
                        selected: tempVegFilter == food.$1,
                        onSelected: () =>
                            setDialogState(() => tempVegFilter = food.$1),
                      ),
                  ],
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),

                // Status — semantic colours retained (active green / disabled orange)
                _filterSectionLabel('Status'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in [
                      ('all', 'All', AppColors.primary),
                      ('active', 'Active', AppColors.success),
                      ('disabled', 'Disabled', Colors.orange),
                    ])
                      _filterChoiceChip(
                        label: status.$2,
                        accent: status.$3,
                        selected: tempStatusFilter == status.$1,
                        onSelected: () =>
                            setDialogState(() => tempStatusFilter = status.$1),
                      ),
                  ],
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),

                // Categories
                if (categories.isNotEmpty) ...[
                  _filterSectionLabel('Categories'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (category) => _filterMultiChip(
                            label: category,
                            selected: tempCategories.contains(category),
                            onSelected: (selected) => setDialogState(() {
                              if (selected) {
                                tempCategories.add(category);
                              } else {
                                tempCategories.remove(category);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Sort By
                _filterSectionLabel('Sort By'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sort in const [
                      ('name_asc', 'Name (A-Z)'),
                      ('name_desc', 'Name (Z-A)'),
                      ('price_asc', 'Price (Low-High)'),
                      ('price_desc', 'Price (High-Low)'),
                    ])
                      _filterChoiceChip(
                        label: sort.$2,
                        selected: tempSortBy == sort.$1,
                        onSelected: () =>
                            setDialogState(() => tempSortBy = sort.$1),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              appDialogCancelButton(context),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              appDialogPrimaryButton(
                label: 'Apply Filters',
                onPressed: () {
                  setState(() {
                    _selectedCategories = tempCategories;
                    _selectedVegFilter = tempVegFilter;
                    _selectedStatusFilter = tempStatusFilter;
                    _restaurantSortBy = tempSortBy;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== SETUP WIZARD NAVIGATION ====================

  Widget _buildSetupWizardNavigation() {
    return Container(
      padding: EdgeInsets.all(
        AppResponsive.getValue(
          context,
          mobile: 20.0,
          tablet: 24.0,
          desktop: 28.0,
        ),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                child: Text(
                  'Back',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.buttonFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: widget.onNext,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  'Next: Payment Setup',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.buttonFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
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
