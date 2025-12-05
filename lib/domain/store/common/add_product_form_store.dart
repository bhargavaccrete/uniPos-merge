import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';

// Retail Models
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/attribute_value_model_220.dart';

// Restaurant Models
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/itemvariantemodel_312.dart';

// Stores
import '../retail/product_store.dart';
import '../restaurant/item_store.dart';

part 'add_product_form_store.g.dart';

class AddProductFormStore = _AddProductFormStore with _$AddProductFormStore;

/// Unified form store for adding products/items
/// Adapts fields based on AppConfig.businessMode
abstract class _AddProductFormStore with Store {
  final _uuid = const Uuid();

  // ==================== COMMON FIELDS ====================

  @observable
  String name = '';

  @observable
  String description = '';

  @observable
  String? imagePath;

  @observable
  String? selectedCategoryId;

  @observable
  double price = 0.0;

  @observable
  double taxRate = 0.0;

  @observable
  bool isEnabled = true;

  // ==================== RETAIL-SPECIFIC FIELDS ====================

  @observable
  String? brandName;

  @observable
  String? subCategory;

  @observable
  double mrp = 0.0;

  @observable
  double costPrice = 0.0;

  @observable
  String? hsnCode;

  @observable
  String sku = '';

  @observable
  String barcode = '';

  @observable
  int stockQuantity = 0;

  @observable
  int minStock = 0;

  @observable
  String productType = 'simple'; // 'simple' or 'variable'

  @observable
  ObservableList<String> selectedAttributeIds = ObservableList<String>();

  @observable
  ObservableMap<String, List<String>> selectedAttributeValues = ObservableMap<String, List<String>>();

  @observable
  ObservableList<VariantFormData> retailVariants = ObservableList<VariantFormData>();

  // ==================== RESTAURANT-SPECIFIC FIELDS ====================

  @observable
  String isVeg = 'veg'; // 'veg' or 'non-veg'

  @observable
  String? unit;

  @observable
  bool trackInventory = false;

  @observable
  double restaurantStockQuantity = 0.0;

  @observable
  bool allowOrderWhenOutOfStock = false;

  @observable
  bool isSoldByWeight = false;

  @observable
  bool hasPortionSizes = false;

  @observable
  ObservableList<PortionSizeFormData> portionSizes = ObservableList<PortionSizeFormData>();

  @observable
  ObservableList<String> selectedChoiceIds = ObservableList<String>();

  @observable
  ObservableList<String> selectedExtraIds = ObservableList<String>();

  @observable
  ObservableMap<String, ExtraConstraint> extraConstraints = ObservableMap<String, ExtraConstraint>();

  // ==================== FORM STATE ====================

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  bool isSubmitted = false;

  // ==================== COMPUTED ====================

  @computed
  bool get isRetail => AppConfig.isRetail;

  @computed
  bool get isRestaurant => AppConfig.isRestaurant;

  @computed
  bool get isVariableProduct => productType == 'variable';

  @computed
  bool get isSimpleProduct => productType == 'simple';

  @computed
  bool get hasVariants => isRetail ? retailVariants.isNotEmpty : portionSizes.isNotEmpty;

  @computed
  bool get isValid {
    // Common validation
    if (name.trim().isEmpty) return false;
    if (selectedCategoryId == null) return false;

    if (isRetail) {
      // Retail validation
      if (isSimpleProduct && price <= 0) return false;
      if (isVariableProduct && retailVariants.isEmpty) return false;
    } else {
      // Restaurant validation
      if (!hasPortionSizes && price <= 0) return false;
      if (hasPortionSizes && portionSizes.isEmpty) return false;
    }

    return true;
  }

  @computed
  String get validationMessage {
    if (name.trim().isEmpty) return 'Product name is required';
    if (selectedCategoryId == null) return 'Please select a category';

    if (isRetail) {
      if (isSimpleProduct && price <= 0) return 'Price must be greater than 0';
      if (isVariableProduct && retailVariants.isEmpty) {
        return 'Please add at least one variant';
      }
    } else {
      if (!hasPortionSizes && price <= 0) return 'Price must be greater than 0';
      if (hasPortionSizes && portionSizes.isEmpty) {
        return 'Please add at least one portion size';
      }
    }

    return '';
  }

  @computed
  double get profitMargin {
    if (costPrice <= 0 || price <= 0) return 0;
    return ((price - costPrice) / costPrice) * 100;
  }

  @computed
  double get profitAmount {
    if (costPrice <= 0 || price <= 0) return 0;
    return price - costPrice;
  }

  // ==================== ACTIONS - COMMON ====================

  @action
  void setName(String value) => name = value;

  @action
  void setDescription(String value) => description = value;

  @action
  void setImagePath(String? value) => imagePath = value;

  @action
  void setSelectedCategoryId(String? value) => selectedCategoryId = value;

  @action
  void setPrice(double value) => price = value;

  @action
  void setTaxRate(double value) => taxRate = value;

  @action
  void setIsEnabled(bool value) => isEnabled = value;

  // ==================== ACTIONS - RETAIL ====================

  @action
  void setBrandName(String? value) => brandName = value;

  @action
  void setSubCategory(String? value) => subCategory = value;

  @action
  void setMrp(double value) => mrp = value;

  @action
  void setCostPrice(double value) => costPrice = value;

  @action
  void setHsnCode(String? value) => hsnCode = value;

  @action
  void setSku(String value) => sku = value;

  @action
  void setBarcode(String value) => barcode = value;

  @action
  void setStockQuantity(int value) => stockQuantity = value;

  @action
  void setMinStock(int value) => minStock = value;

  @action
  void setProductType(String value) {
    productType = value;
    if (value == 'simple') {
      retailVariants.clear();
      selectedAttributeIds.clear();
      selectedAttributeValues.clear();
    }
  }

  @action
  void toggleAttribute(String attributeId) {
    if (selectedAttributeIds.contains(attributeId)) {
      selectedAttributeIds.remove(attributeId);
      selectedAttributeValues.remove(attributeId);
    } else {
      selectedAttributeIds.add(attributeId);
      selectedAttributeValues[attributeId] = [];
    }
  }

  @action
  void toggleAttributeValue(String attributeId, String valueId) {
    if (!selectedAttributeValues.containsKey(attributeId)) {
      selectedAttributeValues[attributeId] = [];
    }

    final values = selectedAttributeValues[attributeId]!;
    if (values.contains(valueId)) {
      values.remove(valueId);
    } else {
      values.add(valueId);
    }
    selectedAttributeValues[attributeId] = values.toList(); // Trigger reactivity
  }

  @action
  void generateRetailVariants(
    List<AttributeModel> attributes,
    List<AttributeValueModel> allValues,
  ) {
    retailVariants.clear();

    // Get selected attribute values
    final selectedAttrs = <String, List<AttributeValueModel>>{};
    for (final attrId in selectedAttributeIds) {
      final valueIds = selectedAttributeValues[attrId] ?? [];
      if (valueIds.isNotEmpty) {
        final attr = attributes.firstWhere((a) => a.attributeId == attrId);
        final values = allValues
            .where((v) => v.attributeId == attrId && valueIds.contains(v.valueId))
            .toList();
        if (values.isNotEmpty) {
          selectedAttrs[attr.name] = values;
        }
      }
    }

    if (selectedAttrs.isEmpty) return;

    // Generate combinations
    final combinations = _generateCombinations(selectedAttrs);

    for (final combo in combinations) {
      final variantName = combo.values.map((v) => v.value).join(' - ');
      retailVariants.add(VariantFormData(
        id: _uuid.v4(),
        name: variantName,
        attributes: Map.fromEntries(
          combo.entries.map((e) => MapEntry(e.key, e.value.value)),
        ),
        attributeValueIds: Map.fromEntries(
          combo.entries.map((e) => MapEntry(e.key, e.value.valueId)),
        ),
        price: price,
        costPrice: costPrice,
        mrp: mrp,
        stockQuantity: stockQuantity,
      ));
    }
  }

  List<Map<String, AttributeValueModel>> _generateCombinations(
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

  @action
  void addRetailVariant() {
    retailVariants.add(VariantFormData(
      id: _uuid.v4(),
      name: '',
      attributes: {},
      attributeValueIds: {},
      price: price,
      costPrice: costPrice,
      mrp: mrp,
      stockQuantity: 0,
    ));
  }

  @action
  void updateRetailVariant(int index, VariantFormData variant) {
    if (index >= 0 && index < retailVariants.length) {
      retailVariants[index] = variant;
    }
  }

  @action
  void removeRetailVariant(int index) {
    if (index >= 0 && index < retailVariants.length) {
      retailVariants.removeAt(index);
    }
  }

  // ==================== ACTIONS - RESTAURANT ====================

  @action
  void setIsVeg(String value) => isVeg = value;

  @action
  void setUnit(String? value) => unit = value;

  @action
  void setTrackInventory(bool value) => trackInventory = value;

  @action
  void setRestaurantStockQuantity(double value) => restaurantStockQuantity = value;

  @action
  void setAllowOrderWhenOutOfStock(bool value) => allowOrderWhenOutOfStock = value;

  @action
  void setIsSoldByWeight(bool value) => isSoldByWeight = value;

  @action
  void setHasPortionSizes(bool value) {
    hasPortionSizes = value;
    if (!value) {
      portionSizes.clear();
    }
  }

  @action
  void addPortionSize() {
    portionSizes.add(PortionSizeFormData(
      id: _uuid.v4(),
      name: '',
      price: 0.0,
      stockQuantity: 0.0,
      trackInventory: trackInventory,
    ));
  }

  @action
  void updatePortionSize(int index, PortionSizeFormData size) {
    if (index >= 0 && index < portionSizes.length) {
      portionSizes[index] = size;
    }
  }

  @action
  void removePortionSize(int index) {
    if (index >= 0 && index < portionSizes.length) {
      portionSizes.removeAt(index);
    }
  }

  @action
  void toggleChoiceGroup(String choiceId) {
    if (selectedChoiceIds.contains(choiceId)) {
      selectedChoiceIds.remove(choiceId);
    } else {
      selectedChoiceIds.add(choiceId);
    }
  }

  @action
  void toggleExtraGroup(String extraId) {
    if (selectedExtraIds.contains(extraId)) {
      selectedExtraIds.remove(extraId);
      extraConstraints.remove(extraId);
    } else {
      selectedExtraIds.add(extraId);
      extraConstraints[extraId] = ExtraConstraint(min: 0, max: 5);
    }
  }

  @action
  void setExtraConstraint(String extraId, int min, int max) {
    extraConstraints[extraId] = ExtraConstraint(min: min, max: max);
  }

  // ==================== FORM SUBMISSION ====================

  @action
  Future<bool> submit() async {
    if (!isValid) {
      errorMessage = validationMessage;
      return false;
    }

    isLoading = true;
    errorMessage = null;

    try {
      if (isRetail) {
        await _submitRetailProduct();
      } else {
        await _submitRestaurantItem();
      }

      isSubmitted = true;
      return true;
    } catch (e) {
      errorMessage = 'Failed to save: $e';
      return false;
    } finally {
      isLoading = false;
    }
  }

  Future<void> _submitRetailProduct() async {
    final productStore = locator<ProductStore>();
    final productId = _uuid.v4();

    // Create product
    final product = ProductModel.fromProduct(
      productId: productId,
      productName: name.trim(),
      category: selectedCategoryId!,
      subCategory: subCategory,
      brandName: brandName,
      imagePath: imagePath,
      description: description.isNotEmpty ? description : null,
      hasVariants: isVariableProduct,
      productType: productType,
      defaultPrice: isSimpleProduct ? price : null,
      defaultMrp: isSimpleProduct ? mrp : null,
      defaultCostPrice: isSimpleProduct ? costPrice : null,
      gstRate: taxRate > 0 ? taxRate : null,
      hsnCode: hsnCode,
    );

    await productStore.addProduct(product);

    // Create variants
    if (isVariableProduct) {
      for (final variantData in retailVariants) {
        final variant = VarianteModel.create(
          varianteId: variantData.id,
          productId: productId,
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
          minStock: minStock,
          taxRate: taxRate > 0 ? taxRate : null,
        );
        await productStore.addVariant(variant);
      }
    } else {
      // Create default variant for simple product
      final variant = VarianteModel.create(
        varianteId: _uuid.v4(),
        productId: productId,
        sku: sku,
        barcode: barcode,
        mrp: mrp,
        costPrice: costPrice,
        sellingPrice: price,
        stockQty: stockQuantity,
        minStock: minStock,
        isDefault: true,
        taxRate: taxRate > 0 ? taxRate : null,
      );
      await productStore.addVariant(variant);
    }
  }

  Future<void> _submitRestaurantItem() async {
    final itemStore = locator<ItemStore>();
    final itemId = _uuid.v4();

    // Create item variants if has portion sizes
    List<ItemVariante>? variants;
    if (hasPortionSizes && portionSizes.isNotEmpty) {
      variants = portionSizes.map((ps) => ItemVariante(
        variantId: ps.id,
        price: ps.price,
        trackInventory: ps.trackInventory,
        stockQuantity: ps.stockQuantity,
      )).toList();
    }

    // Create extra constraints map
    Map<String, Map<String, int>>? constraintsMap;
    if (extraConstraints.isNotEmpty) {
      constraintsMap = {};
      for (final entry in extraConstraints.entries) {
        constraintsMap[entry.key] = {
          'min': entry.value.min,
          'max': entry.value.max,
        };
      }
    }

    final item = Items(
      id: itemId,
      name: name.trim(),
      price: hasPortionSizes ? null : price,
      description: description.isNotEmpty ? description : null,
      imagePath: imagePath,
      categoryOfItem: selectedCategoryId,
      isVeg: isVeg,
      unit: unit,
      variant: variants,
      choiceIds: selectedChoiceIds.isNotEmpty ? selectedChoiceIds.toList() : null,
      extraId: selectedExtraIds.isNotEmpty ? selectedExtraIds.toList() : null,
      extraConstraints: constraintsMap,
      trackInventory: trackInventory,
      stockQuantity: restaurantStockQuantity,
      allowOrderWhenOutOfStock: allowOrderWhenOutOfStock,
      isSoldByWeight: isSoldByWeight,
      taxRate: taxRate > 0 ? taxRate : null,
      isEnabled: isEnabled,
      createdTime: DateTime.now(),
    );

    await itemStore.addItem(item);
  }

  // ==================== RESET ====================

  @action
  void reset() {
    // Common
    name = '';
    description = '';
    imagePath = null;
    selectedCategoryId = null;
    price = 0.0;
    taxRate = 0.0;
    isEnabled = true;

    // Retail
    brandName = null;
    subCategory = null;
    mrp = 0.0;
    costPrice = 0.0;
    hsnCode = null;
    sku = '';
    barcode = '';
    stockQuantity = 0;
    minStock = 0;
    productType = 'simple';
    selectedAttributeIds.clear();
    selectedAttributeValues.clear();
    retailVariants.clear();

    // Restaurant
    isVeg = 'veg';
    unit = null;
    trackInventory = false;
    restaurantStockQuantity = 0.0;
    allowOrderWhenOutOfStock = false;
    isSoldByWeight = false;
    hasPortionSizes = false;
    portionSizes.clear();
    selectedChoiceIds.clear();
    selectedExtraIds.clear();
    extraConstraints.clear();

    // Form state
    isLoading = false;
    errorMessage = null;
    isSubmitted = false;
  }
}

// ==================== HELPER CLASSES ====================

class VariantFormData {
  final String id;
  String name;
  Map<String, String> attributes;
  Map<String, String> attributeValueIds;
  String sku;
  String barcode;
  double price;
  double costPrice;
  double mrp;
  int stockQuantity;

  VariantFormData({
    required this.id,
    required this.name,
    required this.attributes,
    required this.attributeValueIds,
    this.sku = '',
    this.barcode = '',
    this.price = 0.0,
    this.costPrice = 0.0,
    this.mrp = 0.0,
    this.stockQuantity = 0,
  });

  VariantFormData copyWith({
    String? name,
    Map<String, String>? attributes,
    Map<String, String>? attributeValueIds,
    String? sku,
    String? barcode,
    double? price,
    double? costPrice,
    double? mrp,
    int? stockQuantity,
  }) {
    return VariantFormData(
      id: id,
      name: name ?? this.name,
      attributes: attributes ?? this.attributes,
      attributeValueIds: attributeValueIds ?? this.attributeValueIds,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      mrp: mrp ?? this.mrp,
      stockQuantity: stockQuantity ?? this.stockQuantity,
    );
  }
}

class PortionSizeFormData {
  final String id;
  String name;
  double price;
  double stockQuantity;
  bool trackInventory;

  PortionSizeFormData({
    required this.id,
    required this.name,
    required this.price,
    this.stockQuantity = 0.0,
    this.trackInventory = false,
  });

  PortionSizeFormData copyWith({
    String? name,
    double? price,
    double? stockQuantity,
    bool? trackInventory,
  }) {
    return PortionSizeFormData(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      trackInventory: trackInventory ?? this.trackInventory,
    );
  }
}

class ExtraConstraint {
  final int min;
  final int max;

  ExtraConstraint({required this.min, required this.max});
}