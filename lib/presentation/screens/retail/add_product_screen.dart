import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/domain/services/retail/simple_product_fields_service.dart';
import 'package:billberrylite/domain/services/retail/variant_attribute_mapper.dart';
import 'package:billberrylite/presentation/screens/retail/category_management_screen.dart';
import 'package:billberrylite/presentation/screens/retail/scanner_screen.dart';
import 'package:billberrylite/presentation/screens/retail/simple_product_fields_screen.dart';
import 'package:billberrylite/presentation/widget/retail/product_attribute_selector.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/universal_image_picker.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/config/tax_feature.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

const _uuid = Uuid();

/// Money input — digits with at most two decimals, the same rule the checkout,
/// expense and cash-drawer screens apply.
final _moneyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

/// Whole-number input (stock counts).
final _qtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

/// Single entry point for "Add Product" so the inventory list, its empty state
/// and the Products hub all open the form the same way.
Future<void> openAddProductScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddProductScreen()),
  );
}

/// Reopens the same form pre-filled, for changing a product's name, category,
/// brand, description, HSN or tax. Variants keep their own screen.
Future<void> openEditProductScreen(BuildContext context, ProductModel product) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AddProductScreen(product: product)),
  );
}

class AddProductScreen extends StatefulWidget {
  /// Null creates a new product; non-null reopens that product for editing.
  final ProductModel? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

// Custom attribute data for form
class CustomAttributeData {
  final String id;
  final TextEditingController keyController;
  final TextEditingController valueController;

  CustomAttributeData({required this.id})
    : keyController = TextEditingController(),
      valueController = TextEditingController();

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

// Variant data model for form
class VariantFormData {
  final String id;
  final TextEditingController barcodeController;
  final TextEditingController costPriceController;
  final TextEditingController priceController;
  final TextEditingController mrpController;
  final TextEditingController stockController;
  final TextEditingController skuController;
  final List<CustomAttributeData> customAttributes;

  /// Configurable descriptor fields (Settings → Simple Product Fields), keyed
  /// by attributeId. Replaces the previously hardcoded size/color/weight
  /// controllers so a shop can use Flavour, Volume, Capacity instead.
  final Map<String, TextEditingController> fieldControllers = {};

  VariantFormData({required this.id})
    : barcodeController = TextEditingController(),
      costPriceController = TextEditingController(),
      priceController = TextEditingController(),
      mrpController = TextEditingController(),
      stockController = TextEditingController(),
      skuController = TextEditingController(),
      customAttributes = [];

  /// Controller for a configured field, created on first use.
  TextEditingController fieldController(String attributeId) =>
      fieldControllers.putIfAbsent(attributeId, () => TextEditingController());

  void addCustomAttribute() {
    customAttributes.add(
      CustomAttributeData(id: DateTime.now().millisecondsSinceEpoch.toString()),
    );
  }

  void removeCustomAttribute(int index) {
    customAttributes[index].dispose();
    customAttributes.removeAt(index);
  }

  Map<String, String>? getCustomAttributesMap() {
    final map = <String, String>{};
    for (var attr in customAttributes) {
      final key = attr.keyController.text.trim();
      final value = attr.valueController.text.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        map[key] = value;
      }
    }
    return map.isEmpty ? null : map;
  }

  void dispose() {
    barcodeController.dispose();
    costPriceController.dispose();
    priceController.dispose();
    mrpController.dispose();
    stockController.dispose();
    skuController.dispose();
    for (final controller in fieldControllers.values) {
      controller.dispose();
    }
    for (var attr in customAttributes) {
      attr.dispose();
    }
  }
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hsnCodeController = TextEditingController();
  String? _selectedTaxId;
  // Once the user manually picks a tax, an HSN-based suggestion should never
  // silently overwrite that choice again for this product.
  bool _taxManuallyChanged = false;
  Timer? _hsnLookupDebounce;
  final _defaultPriceController = TextEditingController();
  final _defaultCostController = TextEditingController();
  final _defaultMrpController = TextEditingController();
  final _defaultStockController = TextEditingController();

  Category? _selectedCategoryModel;
  List<Category> _categories = [];

  /// Product photo. Bytes rather than a path so it works on web too — the same
  /// convention the restaurant Items model uses.
  Uint8List? _imageBytes;

  /// Distinguishes "never touched the image" from "removed it", which
  /// copyWith cannot express on its own.
  bool _imageCleared = false;

  // Whether the bulk generator is expanded. Purely a UI toggle — there is no
  // "variable product" mode any more, so revealing it never discards manually
  // entered variants. The selector below stays mounted while collapsed so the
  // attributes and values already picked survive a fold.
  bool _showAttributeGenerator = false;

  /// Stable id for this draft, used only for the SKUs the generator mints.
  ///
  /// It used to be `DateTime.now()...` evaluated inside build, so every rebuild
  /// handed the selector a different product and regenerating produced a fresh
  /// SKU prefix each time. The real productId is stamped on at save.
  final String _draftProductId = _uuid.v4();

  // Generated variants from attributes
  List<VarianteModel> _generatedVariants = [];

  // Track selected variants for bulk operations (by variantId)
  final Set<String> _selectedVariantsForBulk = {};

  // Key for attribute selector to allow refresh
  final GlobalKey<ProductAttributeSelectorState> _attributeSelectorKey =
      GlobalKey<ProductAttributeSelectorState>();

  // List of variants (manual entry)
  final List<VariantFormData> _variants = [];

  // Descriptor fields shown on each simple-product variant, from
  // Settings → Simple Product Fields. Replaces the old hardcoded
  // Color / Size / Weight boxes.
  List<AttributeModel> _simpleFields = [];

  /// Editing an existing product rather than creating one.
  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) {
      // Add first variant by default
      _addVariant();
    } else {
      _nameController.text = product.productName;
      _brandController.text = product.brandName ?? '';
      _descriptionController.text = product.description ?? '';
      _hsnCodeController.text = product.hsnCode ?? '';
      _selectedTaxId = product.taxId;
      // A saved tax is a deliberate choice — never let the HSN lookup
      // silently replace it while editing.
      _taxManuallyChanged = true;
      _imageBytes = product.imageBytes;
    }
    _loadCategories();
    // Load attributes
    attributeStore.loadAttributes();
    taxStore.loadTaxes();
    _loadSimpleFields();
  }

  Future<void> _loadSimpleFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() => _simpleFields = fields);
  }

  /// Opens the shared Simple Product Fields configurator, then re-resolves the
  /// list. Controllers for fields the user removed are disposed; their values
  /// already stop being saved, since [_mapFieldValues] only reads
  /// [_simpleFields].
  Future<void> _openSimpleFieldSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SimpleProductFieldsScreen()),
    );
    if (!mounted) return;

    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;

    final keptIds = fields.map((a) => a.attributeId).toSet();
    for (final variant in _variants) {
      for (final id in variant.fieldControllers.keys.toList()) {
        if (!keptIds.contains(id))
          variant.fieldControllers.remove(id)?.dispose();
      }
    }

    setState(() => _simpleFields = fields);
  }

  Future<void> _loadCategories() async {
    await categoryStore.loadCategories();
    if (!mounted) return;
    _categories = categoryStore.categories.toList();

    // The dropdown holds a Category object, so the product's stored id can only
    // be resolved once the list has arrived.
    final product = widget.product;
    if (product != null && _selectedCategoryModel == null) {
      for (final category in _categories) {
        if (category.id == product.category) {
          _selectedCategoryModel = category;
          break;
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _hsnLookupDebounce?.cancel();
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _hsnCodeController.dispose();
    _defaultPriceController.dispose();
    _defaultCostController.dispose();
    _defaultMrpController.dispose();
    _defaultStockController.dispose();
    for (var variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  /// Looks up the tax previously used with this HSN code (debounced so it
  /// only fires once the user pauses typing) and pre-fills the Tax dropdown.
  /// Never overrides a tax the user has already picked manually.
  void _onHsnCodeChanged(String value) {
    _hsnLookupDebounce?.cancel();
    _hsnLookupDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_taxManuallyChanged || !mounted) return;
      final suggestedTaxId = productStore.findTaxIdByHsnCode(value);
      if (suggestedTaxId != null && suggestedTaxId != _selectedTaxId) {
        setState(() => _selectedTaxId = suggestedTaxId);
        NotificationService.instance.showInfo(
          'Tax rate auto-filled from HSN $value',
        );
      }
    });
  }

  void _addVariant() {
    setState(() {
      _variants.add(
        VariantFormData(id: DateTime.now().millisecondsSinceEpoch.toString()),
      );
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants[index].dispose();
      _variants.removeAt(index);
    });
  }

  Future<void> _scanBarcode(VariantFormData variant) async {
    final String? barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (barcode != null) {
      variant.barcodeController.text = barcode;
    }
  }

  /// Product-level fields only. Variants already exist and are managed by
  /// [ProductDetailScreen], so nothing here touches them.
  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.catalogProductsEdit,
      featureName: 'Edit Products',
    )) {
      return;
    }

    final existing = widget.product!;
    final taxRate = _taxRateFor(_selectedTaxId);
    final brand = _brandController.text.trim();
    final description = _descriptionController.text.trim();
    final hsnCode = _hsnCodeController.text.trim();

    // MUST go through copyWith — productId, createdAt, imagePath, productType
    // and the default* prices are carried over untouched. Hand-building the
    // model is what used to silently wipe fields on the variant side.
    final updated = existing.copyWith(
      productName: _nameController.text.trim(),
      brandName: brand.isEmpty ? null : brand,
      clearBrandName: brand.isEmpty,
      category: _selectedCategoryModel?.id ?? existing.category,
      description: description.isEmpty ? null : description,
      clearDescription: description.isEmpty,
      hsnCode: hsnCode.isEmpty ? null : hsnCode,
      clearHsnCode: hsnCode.isEmpty,
      gstRate: taxRate,
      taxId: _selectedTaxId,
      clearTax: _selectedTaxId == null,
      imageBytes: _imageBytes,
      clearImage: _imageCleared,
    );

    await productStore.updateProduct(updated);
    if (!mounted) return;
    NotificationService.instance.showSuccess('${updated.productName} updated');
    Navigator.pop(context);
  }

  /// Percentage behind a tax id, or null when nothing is picked.
  double? _taxRateFor(String? taxId) {
    if (taxId == null) return null;
    return taxStore.taxes
        .firstWhere(
          (t) => t.id == taxId,
          orElse: () => Tax(id: '', taxname: '', taxperecentage: null),
        )
        .taxperecentage;
  }

  /// A manual variant row the user actually put something in. The form seeds one
  /// empty row, which must not become a phantom variant for someone who only
  /// generates from attributes.
  bool _isVariantRowFilled(VariantFormData variant) =>
      variant.priceController.text.trim().isNotEmpty ||
      variant.costPriceController.text.trim().isNotEmpty ||
      variant.mrpController.text.trim().isNotEmpty ||
      variant.stockController.text.trim().isNotEmpty ||
      variant.barcodeController.text.trim().isNotEmpty ||
      variant.skuController.text.trim().isNotEmpty;

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final manualVariants = _variants.where(_isVariantRowFilled).toList();

    if (manualVariants.isEmpty && _generatedVariants.isEmpty) {
      NotificationService.instance.showError(
        'Add at least one variant, or generate them from attributes',
      );
      return;
    }

    // Selling price and stock are what the POS needs; cost is bookkeeping and
    // stays optional, matching the variant screen.
    final seenBarcodes = <String>{};
    for (final variant in manualVariants) {
      if (variant.priceController.text.trim().isEmpty) {
        NotificationService.instance.showError(
          'Please enter selling price for all variants',
        );
        return;
      }
      if (variant.stockController.text.trim().isEmpty) {
        NotificationService.instance.showError(
          'Please enter stock for all variants',
        );
        return;
      }
      // Against the catalogue AND against the other rows in this same form —
      // neither is caught by the other.
      final barcode = variant.barcodeController.text.trim();
      if (barcode.isEmpty) continue;
      if (productStore.isBarcodeTaken(barcode) || !seenBarcodes.add(barcode)) {
        NotificationService.instance.showError(
          'Barcode "$barcode" is already used by another variant',
        );
        return;
      }
    }

    // GST rate is set per product/variant, not inherited from category.
    // taxRate is resolved once from the selected shared Tax entity and kept
    // as a cached percentage on the model, exactly like before — only the
    // source of the number changed, from free-typed to a named picklist.
    final taxRate = _selectedTaxId == null
        ? null
        : taxStore.taxes
              .firstWhere(
                (t) => t.id == _selectedTaxId,
                orElse: () => Tax(id: '', taxname: '', taxperecentage: null),
              )
              .taxperecentage;

    // Plan gate — block a NEW product once the products cap is reached.
    // No-op until a retail manifest is present (see PlanEnforce).
    if (!productStore.canAddProduct) {
      final max = productStore.productLimit;
      NotificationService.instance.showError(
        'Product limit reached${max != null ? ' (max $max)' : ''}. Upgrade your plan to add more.',
      );
      return;
    }

    // Create ProductModel
    final productId = _uuid.v4();
    final variantCount = manualVariants.length + _generatedVariants.length;

    // Derived, never asked. Nothing at runtime reads productType — the POS
    // decides how to behave by counting variants — so these exist only to keep
    // stored data meaningful.
    final product = ProductModel.fromProduct(
      productId: productId,
      productName: _nameController.text.trim(),
      brandName: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      category: _selectedCategoryModel?.id ?? '',
      imagePath: null,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      hasVariants: variantCount > 1,
      productType: variantCount > 1 ? 'variable' : 'simple',
      gstRate: taxRate,
      hsnCode: _hsnCodeController.text.trim().isEmpty
          ? null
          : _hsnCodeController.text.trim(),
      taxId: _selectedTaxId,
      imageBytes: _imageBytes,
    );

    await productStore.addProduct(product);

    // Attribute-generated variants.
    for (final variant in _generatedVariants) {
      // Point them at the id we just created.
      await productStore.addVariant(
        variant.copyWith(
          productId: productId,
          taxRate: taxRate,
          taxId: _selectedTaxId,
        ),
      );
    }

    // Manually entered variants.
    for (final variantData in manualVariants) {
      final fieldValues = _mapFieldValues(variantData);

      await productStore.addVariant(
        VarianteModel.create(
          varianteId: _uuid.v4(),
          productId: productId,
          sku: variantData.skuController.text.trim().isEmpty
              ? null
              : variantData.skuController.text.trim(),
          barcode: variantData.barcodeController.text.trim().isEmpty
              ? null
              : variantData.barcodeController.text.trim(),
          // The field labelled "Selling Price" must land in sellingPrice — that
          // is what the cart bills (cart_store: sellingPrice ?? mrp ?? 0). It
          // used to be written to mrp, leaving sellingPrice null and the MRP box
          // discarded entirely.
          sellingPrice:
              double.tryParse(variantData.priceController.text.trim()) ?? 0.0,
          mrp: variantData.mrpController.text.trim().isEmpty
              ? null
              : double.tryParse(variantData.mrpController.text.trim()),
          costPrice: variantData.costPriceController.text.trim().isEmpty
              ? null
              : double.tryParse(variantData.costPriceController.text.trim()),
          stockQty: int.tryParse(variantData.stockController.text.trim()) ?? 0,
          taxRate: taxRate,
          taxId: _selectedTaxId,
          customAttributes: fieldValues,
        ),
      );
    }

    if (mounted) {
      NotificationService.instance.showSuccess(
        '${product.productName} with $variantCount variant(s) added',
      );
      Navigator.pop(context);
    }
  }

  /// Descriptor inputs for one variant, laid out two per row like the fields
  /// they replaced. Empty when the shop has configured no fields — price,
  /// stock, barcode and SKU are always shown regardless.
  List<Widget> _buildConfiguredFields(VariantFormData variant) {
    if (_simpleFields.isEmpty) return const [];

    final rows = <Widget>[];
    for (var i = 0; i < _simpleFields.length; i += 2) {
      final left = _simpleFields[i];
      final right = i + 1 < _simpleFields.length ? _simpleFields[i + 1] : null;

      rows.add(
        Row(
          children: [
            Expanded(child: _buildFieldInput(variant, left)),
            const SizedBox(width: 12),
            if (right != null)
              Expanded(child: _buildFieldInput(variant, right))
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      rows.add(const SizedBox(height: 12));
    }
    return rows;
  }

  /// A single descriptor input. Offers the attribute's preset values as a
  /// dropdown while still allowing free text, so the shared vocabulary is
  /// reused without blocking one-off values.
  Widget _buildFieldInput(VariantFormData variant, AttributeModel attribute) {
    final controller = variant.fieldController(attribute.attributeId);
    final values = attributeStore.getValues(attribute.attributeId);

    return _buildTextField(
      controller: controller,
      label: attribute.name,
      hint: values.isEmpty ? null : 'e.g. ${values.first.value}',
      suffixIcon: values.isEmpty
          ? null
          : PopupMenuButton<String>(
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Choose ${attribute.name}',
              // M3 tints menu surfaces by default; keep them plain white.
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) => setState(() => controller.text = value),
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

  /// Fold the configured descriptor fields (plus any ad-hoc custom attribute
  /// rows) into what VarianteModel stores.
  ///
  /// A field named Size / Color / Colour / Weight still writes the legacy
  /// column, so receipts and reports that read `variant.size` keep working —
  /// the same rule VariantGeneratorService applies for variable products.
  /// Everything else goes to `customAttributes`.
  Map<String, String>? _mapFieldValues(VariantFormData variantData) {
    final entered = <String, String>{};
    for (final attribute in _simpleFields) {
      final value =
          variantData.fieldControllers[attribute.attributeId]?.text.trim() ??
          '';
      if (value.isNotEmpty) entered[attribute.name] = value;
    }

    // Ad-hoc per-variant rows stay supported alongside configured fields.
    return mergeVariantAttributes(
      entered,
      extraCustomAttributes: variantData.getCustomAttributesMap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: _isEditing ? 'Edit Product' : 'Add Product',
      ),
      body: Observer(
        builder: (context) => Form(
          key: _formKey,
          // A single column of form fields stretched across a laptop is
          // unreadable — cap it at the form width like the other retail forms.
          child: AppResponsive.constrainedContent(
            context: context,
            alignment: Alignment.topCenter,
            maxWidth: AppResponsive.maxCardWidth(context),
            child: ListView(
              padding: AppResponsive.screenPadding(context),
              children: [
                // Product Information Section
                _buildSectionHeader('Product Information'),
                const SizedBox(height: 12),
                UniversalImageUploader(
                  imageBytes: _imageBytes,
                  height: 160,
                  uploadLabel: 'Add Product Photo',
                  sizeHint: 'Optional • shown on the billing screen',
                  onTap: () async {
                    final bytes = await UniversalImagePicker.showPicker(
                      context,
                    );
                    if (bytes == null || !mounted) return;
                    setState(() {
                      _imageBytes = bytes;
                      _imageCleared = false;
                    });
                  },
                  onDelete: _imageBytes == null
                      ? null
                      : () => setState(() {
                          _imageBytes = null;
                          _imageCleared = true;
                        }),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nameController,
                  label: 'Product Name',
                  hint: 'e.g., Puma T-Shirt',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _brandController,
                  label: 'Brand Name (Optional)',
                  hint: 'e.g., Puma, Nike',
                ),
                const SizedBox(height: 12),
                _buildCategoryDropdown(),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'Enter product description',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _hsnCodeController,
                  label: 'HSN Code (Optional)',
                  hint: 'e.g., 6109',
                  onChanged: _onHsnCodeChanged,
                ),
                if (TaxFeature.enabled) ...[
                  const SizedBox(height: 12),
                  _buildTaxDropdown(),
                ],
                const SizedBox(height: 16),

                // Editing touches product fields only — variants are managed on
                // the product's own screen, which is where you came from.
                if (!_isEditing) ...[
                  const SizedBox(height: 8),

                  // ── One Variants section for every product ──────────────
                  // There is no Simple/Variable mode: a product simply has
                  // variants. Type them in, generate them from attributes, or
                  // both. The POS already decides how to behave by counting
                  // them (posscreen: variants.length == 1 → straight to cart).
                  _buildSectionHeader(
                    'Variants (${_variants.length + _generatedVariants.length})',
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.tune,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Choose which detail fields appear',
                      visualDensity: VisualDensity.compact,
                      onPressed: _openSimpleFieldSettings,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Manually entered variants.
                  ..._variants.asMap().entries.map((entry) {
                    final index = entry.key;
                    final variant = entry.value;
                    return _buildVariantCard(variant, index);
                  }),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addVariant,
                      icon: const Icon(
                        Icons.add,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        'Add variant',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  // ── Bulk add: many variants at once, from attributes ─────
                  const SizedBox(height: 16),
                  _buildBulkAddPanel(),

                  if (_generatedVariants.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'Generated Variants (${_generatedVariants.length})',
                    ),
                    const SizedBox(height: 12),
                    _buildBulkEditBar(),
                    const SizedBox(height: 12),
                    _buildGeneratedVariantsList(),
                  ],
                ],

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isEditing ? _updateProduct : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _isEditing
                          ? 'Save Changes'
                          : 'Add Product with ${_variants.length + _generatedVariants.length} Variant(s)',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bulk add: pick attributes (Size, Colour…) and get one variant per
  /// combination, the same accelerator the setup wizard offers.
  ///
  /// This used to hide behind a button labelled only "Generate", sitting beside
  /// "Add variant" as if it were an alternative to it — so the whole bulk path
  /// went unnoticed. The header now says what it does and stays on screen; only
  /// the picker folds away.
  Widget _buildBulkAddPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _showAttributeGenerator
              ? AppColors.info.withValues(alpha: 0.5)
              : AppColors.divider,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(
              () => _showAttributeGenerator = !_showAttributeGenerator,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulk add variants',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _generatedVariants.isEmpty
                              ? 'Pick Size, Colour… and get one variant per combination'
                              : '${_generatedVariants.length} generated — tap to change',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showAttributeGenerator
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // maintainState keeps the picked attributes and values alive while
          // folded — collapsing the panel used to dispose the selector and
          // throw the whole selection away.
          Visibility(
            visible: _showAttributeGenerator,
            maintainState: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),
                  _buildAttributeSelector(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantCard(VariantFormData variant, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        // Same soft lift the POS and report cards use.
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Variant ${index + 1}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_variants.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  onPressed: () => _removeVariant(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Configurable descriptor fields (Settings → Simple Product Fields).
          ..._buildConfiguredFields(variant),

          _buildTextField(
            controller: variant.barcodeController,
            label: 'Barcode',
            hint: 'Scan or enter',
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.qr_code_scanner,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: () => _scanBarcode(variant),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: variant.costPriceController,
                  label: 'Cost Price*',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                  inputFormatters: _moneyFormatters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: variant.priceController,
                  label: 'Selling Price*',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                  inputFormatters: _moneyFormatters,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: variant.mrpController,
                  label: 'MRP',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                  inputFormatters: _moneyFormatters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: variant.skuController,
                  label: 'SKU',
                  hint: 'Optional',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: variant.stockController,
                  label: 'Stock*',
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: _qtyFormatters,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),

          // Custom Attributes Section
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'One-off details (this product only)',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    variant.addCustomAttribute();
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (variant.customAttributes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...variant.customAttributes.asMap().entries.map((entry) {
              final attrIndex = entry.key;
              final attr = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      // Suggests existing global attributes so repeated
                      // free-text keys don't fragment the vocabulary
                      // ("Flavour" vs "Flavor" vs "flavor").
                      child: Autocomplete<String>(
                        optionsBuilder: (value) {
                          final query = value.text.trim().toLowerCase();
                          if (query.isEmpty)
                            return const Iterable<String>.empty();
                          return attributeStore.attributes
                              .map((a) => a.name)
                              .where((n) => n.toLowerCase().contains(query));
                        },
                        onSelected: (selection) =>
                            attr.keyController.text = selection,
                        fieldViewBuilder:
                            (context, controller, focusNode, onSubmitted) {
                              // Mirror the shared controller so save-time reads
                              // still see what was typed.
                              controller.value = attr.keyController.value;
                              return _buildTextField(
                                controller: controller,
                                focusNode: focusNode,
                                label: 'Detail',
                                hint: 'e.g., Material',
                                onChanged: (v) => attr.keyController.text = v,
                              );
                            },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(
                        controller: attr.valueController,
                        label: 'Value',
                        hint: 'e.g., Cotton',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          variant.removeCustomAttribute(attrIndex);
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'For details you record just this once. Fields you use on every '
              'product belong in Settings → Simple Product Fields.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Section heading. [trailing] holds a secondary action (small icon, right
  /// aligned) — never a second full-width button.
  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    final text = Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.subheadingFontSize(context) - 2,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );

    if (trailing == null) return text;
    return Row(children: [text, const Spacer(), trailing]);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    // Shared field styling, same as the POS and inventory screens.
    return AppTextField(
      controller: controller,
      focusNode: focusNode,
      label: label,
      hint: hint,
      keyboardType: keyboardType ?? TextInputType.text,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      suffixIcon: suffixIcon,
    );
  }

  /// Dropdown chrome matching [AppTextField], so the pickers sit flush with
  /// the text fields around them instead of using Material defaults.
  InputDecoration _pickerDecoration(String label) => InputDecoration(
    labelText: label,
    // Matches AppTextField: a 13px label and NO isDense. With isDense and a
    // 14px label the floated label collided with the top border, and the
    // picker sat shorter than the text fields stacked above it.
    labelStyle: GoogleFonts.poppins(
      fontSize: AppResponsive.smallFontSize(context),
      color: AppColors.textSecondary,
    ),
    filled: true,
    fillColor: AppColors.surfaceLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );

  /// Category picker.
  ///
  /// A tappable field plus a bottom sheet, rather than a native dropdown —
  /// the platform overlay covered the whole form and ignored the app's
  /// surface styling. Wrapped in a [FormField] so validation still runs with
  /// the rest of the form.
  Widget _buildCategoryDropdown() {
    return FormField<String>(
      initialValue: _selectedCategoryModel?.id,
      validator: (_) =>
          _selectedCategoryModel == null ? 'Please select a category' : null,
      builder: (state) {
        final selected = _selectedCategoryModel;
        final hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                await _showCategoryPicker();
                state.didChange(_selectedCategoryModel?.id);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError ? AppColors.danger : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: selected == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected?.name ?? 'Select category',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: selected == null
                              ? FontWeight.w400
                              : FontWeight.w500,
                          color: selected == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 6),
                child: Text(
                  state.errorText!,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.danger,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Bottom sheet listing the categories, with Manage pinned at the bottom.
  Future<void> _showCategoryPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Text(
                      'Select Category',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: _categories.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No categories yet.',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _categories.length,
                        itemBuilder: (_, i) {
                          final category = _categories[i];
                          final isSelected =
                              _selectedCategoryModel?.id == category.id;
                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                            title: Text(
                              category.name,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            onTap: () {
                              setState(() => _selectedCategoryModel = category);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                leading: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: Text(
                  'Manage Categories',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
                    ),
                  );
                  await _loadCategories();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxDropdown() {
    final taxes = taxStore.taxes;
    return DropdownButtonFormField<String>(
      value: taxes.any((t) => t.id == _selectedTaxId) ? _selectedTaxId : null,
      isExpanded: true,
      decoration: _pickerDecoration('Tax Rate (Optional)'),
      dropdownColor: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      menuMaxHeight: 320,
      elevation: 3,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.textSecondary,
      ),
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
        _selectedTaxId = value;
        _taxManuallyChanged = true;
      }),
    );
  }

  /// Optional accelerator: pick attributes and values, get one variant per
  /// combination. Available to any product — it is a bulk-create tool, not a
  /// product mode.
  Widget _buildAttributeSelector() {
    // Chrome lives on _buildBulkAddPanel now — a second bordered card here
    // just nested one box inside another.
    return ProductAttributeSelector(
      key: _attributeSelectorKey,
      productId: _draftProductId,
      defaultPrice: double.tryParse(_defaultPriceController.text),
      defaultCostPrice: double.tryParse(_defaultCostController.text),
      existingVariants: _generatedVariants.isNotEmpty
          ? _generatedVariants
          : null,
      // Attribute picks are owned by the selector; the parent only needs a
      // rebuild so the sections below stay in sync.
      onAttributesChanged: (_) => setState(() {}),
      onVariantsGenerated: (variants) {
        setState(() {
          _generatedVariants = variants;
        });
      },
    );
  }

  /// Bulk Edit Bar - WooCommerce-style "Set prices for all"
  Widget _buildBulkEditBar() {
    final allSelected =
        _selectedVariantsForBulk.length == _generatedVariants.length;
    final noneSelected = _selectedVariantsForBulk.isEmpty;
    final selectedCount = _selectedVariantsForBulk.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Select All / Unselect All
          Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bulk Edit - $selectedCount / ${_generatedVariants.length} selected',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
              // Select All button
              TextButton(
                onPressed: allSelected
                    ? null
                    : () {
                        setState(() {
                          _selectedVariantsForBulk.clear();
                          for (var v in _generatedVariants) {
                            _selectedVariantsForBulk.add(v.varianteId);
                          }
                        });
                      },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Select All',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: allSelected
                        ? AppColors.textSecondary
                        : AppColors.warning,
                  ),
                ),
              ),
              Text(
                ' | ',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
              // Unselect All button
              TextButton(
                onPressed: noneSelected
                    ? null
                    : () {
                        setState(() {
                          _selectedVariantsForBulk.clear();
                        });
                      },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Unselect All',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: noneSelected
                        ? AppColors.textSecondary
                        : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // First Row: Cost Price, Selling Price
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _defaultCostController,
                  label: 'Cost Price',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                  inputFormatters: _moneyFormatters,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  controller: _defaultPriceController,
                  label: 'Selling Price',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                  inputFormatters: _moneyFormatters,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          // Second Row: MRP, Stock
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _defaultMrpController,
                  label: 'MRP',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                  inputFormatters: _moneyFormatters,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  controller: _defaultStockController,
                  label: 'Stock',
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: _qtyFormatters,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyBulkPricesAndStock,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Apply',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Enter values and click Apply to update all variants at once',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Apply bulk prices to all variants
  void _applyBulkPricesAndStock() {
    final costPrice = double.tryParse(_defaultCostController.text);
    final sellingPrice = double.tryParse(_defaultPriceController.text);
    final mrp = double.tryParse(_defaultMrpController.text);
    final stock = int.tryParse(_defaultStockController.text);

    if (costPrice == null && sellingPrice == null) {
      NotificationService.instance.showWarning(
        'Please enter at least one price value',
      );
      return;
    }

    _applyToAllVariants(costPrice: costPrice, sellingPrice: sellingPrice);
    _applyToAllVariants(mrp: mrp, stock: stock);

    final appliedCount = _selectedVariantsForBulk.isEmpty
        ? _generatedVariants.length
        : _selectedVariantsForBulk.length;

    NotificationService.instance.showSuccess(
      'Applied to $appliedCount variant(s)',
    );
  }

  /// Apply values to selected variants only
  void _applyToAllVariants({
    double? costPrice,
    double? sellingPrice,
    double? mrp,
    int? stock,
  }) {
    setState(() {
      for (var i = 0; i < _generatedVariants.length; i++) {
        final variant = _generatedVariants[i];
        // Only apply to selected variants (or all if none selected)
        if (_selectedVariantsForBulk.isEmpty ||
            _selectedVariantsForBulk.contains(variant.varianteId)) {
          _generatedVariants[i] = variant.copyWith(
            costPrice: costPrice ?? variant.costPrice,
            sellingPrice: sellingPrice ?? variant.sellingPrice,
            mrp: mrp ?? variant.mrp,
            stockQty: stock ?? variant.stockQty,
          );
        }
      }
    });
  }

  /// List of generated variants with editing capability
  Widget _buildGeneratedVariantsList() {
    return Column(
      children: _generatedVariants.asMap().entries.map((entry) {
        final index = entry.key;
        final variant = entry.value;
        return _buildGeneratedVariantCard(variant, index);
      }).toList(),
    );
  }

  Widget _buildGeneratedVariantCard(VarianteModel variant, int index) {
    final isSelected = _selectedVariantsForBulk.contains(variant.varianteId);

    // Use Key to force rebuild when variant data changes
    return Container(
      key: ValueKey(
        '${variant.varianteId}_${variant.costPrice}_${variant.sellingPrice}_${variant.mrp}_${variant.stockQty}_$isSelected',
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.warning.withOpacity(0.10)
            : AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppColors.warning : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with checkbox and variant name
          Row(
            children: [
              // Checkbox for bulk selection
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedVariantsForBulk.remove(variant.varianteId);
                    } else {
                      _selectedVariantsForBulk.add(variant.varianteId);
                    }
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.warning : AppColors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? AppColors.warning : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  variant.shortDescription,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (variant.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Default',
                    style: GoogleFonts.poppins(
                      color: Colors.green,
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'SKU: ${variant.sku ?? "Auto"}',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Editable fields - using key to force rebuild on value change
          Row(
            children: [
              Expanded(
                child: _buildVariantTextField(
                  key: 'cost_$index',
                  value: variant.costPrice?.toString() ?? '',
                  label: 'Cost Price',
                  onChanged: (value) {
                    _updateGeneratedVariant(
                      index,
                      costPrice: double.tryParse(value),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVariantTextField(
                  key: 'sell_$index',
                  value: variant.sellingPrice?.toString() ?? '',
                  label: 'Selling Price',
                  onChanged: (value) {
                    _updateGeneratedVariant(
                      index,
                      sellingPrice: double.tryParse(value),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVariantTextField(
                  key: 'stock_$index',
                  value: variant.stockQty.toString(),
                  label: 'Stock',
                  inputFormatters: _qtyFormatters,
                  onChanged: (value) {
                    _updateGeneratedVariant(
                      index,
                      stockQty: int.tryParse(value),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  key: ValueKey('barcode_${index}_${variant.barcode}'),
                  initialValue: variant.barcode ?? '',
                  label: 'Barcode',
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: () async {
                      final barcode = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScannerScreen(),
                        ),
                      );
                      if (barcode != null) {
                        _updateGeneratedVariant(index, barcode: barcode);
                      }
                    },
                  ),
                  onChanged: (value) {
                    _updateGeneratedVariant(index, barcode: value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVariantTextField(
                  key: 'mrp_$index',
                  value: variant.mrp?.toString() ?? '',
                  label: 'MRP',
                  onChanged: (value) {
                    _updateGeneratedVariant(index, mrp: double.tryParse(value));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a text field for variant that properly updates when value changes
  Widget _buildVariantTextField({
    required String key,
    required String value,
    required String label,
    required Function(String) onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return AppTextField(
      key: ValueKey('${key}_$value'),
      initialValue: value,
      label: label,
      keyboardType: TextInputType.number,
      inputFormatters: inputFormatters ?? _moneyFormatters,
      onChanged: onChanged,
    );
  }

  void _updateGeneratedVariant(
    int index, {
    double? costPrice,
    double? sellingPrice,
    double? mrp,
    int? stockQty,
    String? barcode,
  }) {
    setState(() {
      final variant = _generatedVariants[index];
      _generatedVariants[index] = variant.copyWith(
        costPrice: costPrice ?? variant.costPrice,
        sellingPrice: sellingPrice ?? variant.sellingPrice,
        mrp: mrp ?? variant.mrp,
        stockQty: stockQty ?? variant.stockQty,
        barcode: barcode ?? variant.barcode,
      );
    });
  }
}
