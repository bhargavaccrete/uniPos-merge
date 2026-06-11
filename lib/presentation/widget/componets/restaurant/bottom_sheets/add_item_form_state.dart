import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/di/service_locator.dart';

import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../data/models/restaurant/db/itemvariantemodel_312.dart';

enum SellingMethod { byUnit, byWeight }

/// Manages the form state for adding/editing items
class AddItemFormState extends ChangeNotifier {
  // Controllers
  final itemNameController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();
  final stockController = TextEditingController();
  final lowStockThresholdController = TextEditingController();
  final itemCodeController = TextEditingController();

  AddItemFormState() {
    // Pre-fill next available numeric item code
    itemCodeController.text = itemStore.generateNextItemCode();
  }

  // Image
  Uint8List? selectedImage;

  // Selling method
  SellingMethod sellingMethod = SellingMethod.byUnit;
  String selectedUnit = 'kg';

  // Category
  String? selectedCategoryId;
  String? selectedCategoryName;

  // Veg/Non-Veg
  String vegCategory = 'Veg';

  // Tax — multiple taxes allowed; selectedTaxRate is their SUMMED decimal total.
  List<String> selectedTaxIds = [];
  double? selectedTaxRate;

  // Inventory
  bool trackInventory = false;
  bool allowOrderWhenOutOfStock = true;
  bool lowStockAlertEnabled = false;

  // Variants, Choices, Extras
  List<Map<String, dynamic>> selectedVariants = [];
  List<String> selectedChoiceIds = [];
  List<String> selectedExtraIds = [];
  List<String> defaultChoiceOptionIds = []; // per-item default-selected choice options

  /// Reset all form fields to default values
  void reset() {
    itemNameController.clear();
    priceController.clear();
    descriptionController.clear();
    stockController.clear();
    lowStockThresholdController.clear();
    lowStockAlertEnabled = false;
    selectedImage = null;
    sellingMethod = SellingMethod.byUnit;
    selectedUnit = 'kg';
    selectedCategoryId = null;
    selectedCategoryName = null;
    vegCategory = 'Veg';
    selectedTaxIds = [];
    selectedTaxRate = null;
    trackInventory = false;
    allowOrderWhenOutOfStock = true;
    selectedVariants.clear();
    selectedChoiceIds.clear();
    selectedExtraIds.clear();
    defaultChoiceOptionIds.clear();
    itemCodeController.text = itemStore.generateNextItemCode();
    notifyListeners();
  }

  /// Validate required fields
  ValidationResult validate() {
    final errors = <String>[];

    if (itemNameController.text.trim().isEmpty) {
      errors.add('Item Name');
    }

    if (priceController.text.trim().isEmpty) {
      errors.add('Price');
    } else {
      final price = double.tryParse(priceController.text.trim());
      if (price == null || price <= 0) {
        errors.add('Valid Price (greater than 0)');
      }
    }

    if (selectedCategoryId == null || selectedCategoryId!.isEmpty) {
      errors.add('Category');
    }

    // Item Code validation
    final code = itemCodeController.text.trim();
    if (code.isEmpty) {
      errors.add('Item Code');
    } else if (!RegExp(r'^\d{4,5}$').hasMatch(code)) {
      errors.add('Item Code (must be 4-5 digits)');
    } else {
      final duplicateCode = itemStore.items.any((i) => i.itemCode == code);
      if (duplicateCode) {
        errors.add('Unique Item Code (this code already exists)');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      missingFields: errors,
    );
  }

  /// Convert form state to Items model
  Future<Items> toItem() async {
    final itemVariants = selectedVariants
        .map((v) => ItemVariante(
              variantId: v['variantId'],
              price: v['price'],
              stockQuantity: (v['stockQuantity'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();

    return Items(
      id: const Uuid().v4(),
      name: itemNameController.text.trim(),
      price: double.tryParse(priceController.text.trim()),
      description: descriptionController.text.trim(),
      categoryOfItem: selectedCategoryId ?? "",
      imageBytes: selectedImage,
      isVeg: vegCategory,
      isSoldByWeight: sellingMethod == SellingMethod.byWeight,
      unit: sellingMethod == SellingMethod.byWeight ? selectedUnit : null,
      // Item-level stock only for simple items; variant items track per variant.
      stockQuantity: (trackInventory && selectedVariants.isEmpty)
          ? (double.tryParse(stockController.text.trim()) ?? 0.0)
          : 0.0,
      taxRate: selectedTaxRate,
      taxIds: selectedTaxIds,
      lowStockAlertEnabled: trackInventory && lowStockAlertEnabled,
      lowStockThreshold: (trackInventory && lowStockAlertEnabled)
          ? double.tryParse(lowStockThresholdController.text.trim())
          : null,
      trackInventory: trackInventory,
      allowOrderWhenOutOfStock: allowOrderWhenOutOfStock,
      variant: itemVariants,
      choiceIds: selectedChoiceIds,
      extraId: selectedExtraIds,
      defaultChoiceOptionIds: defaultChoiceOptionIds,
      itemCode: itemCodeController.text.trim(),
      createdTime: DateTime.now(),
      editCount: 0,
    );
  }

  /// Get current form data as a map (for passing to AddMoreInfo screen)
  Map<String, dynamic> toMap() {
    return {
      'itemName': itemNameController.text.trim(),
      'price': priceController.text.trim(),
      'description': descriptionController.text.trim(),
      'selectedVegCategory': vegCategory,
      'selectedCategory': selectedCategoryId,
      'selectedCategoryname': selectedCategoryName,
      'taxIds': selectedTaxIds,
      'taxRate': selectedTaxRate,
      'trackInventory': trackInventory,
      'variants': selectedVariants,
      'choiceIds': selectedChoiceIds,
      'extraIds': selectedExtraIds,
      'defaultChoiceOptionIds': defaultChoiceOptionIds,
    };
  }

  /// Update variants, choices, extras and tax from AddMoreInfo result
  void updateFromMoreInfo(Map<String, dynamic> result) {
    selectedVariants = List<Map<String, dynamic>>.from(result['variants'] ?? []);
    selectedChoiceIds = List<String>.from(result['choiceIds'] ?? []);
    selectedExtraIds = List<String>.from(result['extraIds'] ?? []);
    defaultChoiceOptionIds = List<String>.from(result['defaultChoiceOptionIds'] ?? []);
    // More Info can also set the tax — keep it in sync so it isn't lost.
    if (result.containsKey('taxIds') || result.containsKey('taxRate')) {
      selectedTaxIds = List<String>.from(result['taxIds'] ?? selectedTaxIds);
      selectedTaxRate = (result['taxRate'] as num?)?.toDouble();
    }
    notifyListeners();
  }

  /// Set the applied taxes. [ids] are the tax IDs, [rate] their summed decimal
  /// total (e.g. 0.17 for 5% + 12%). Empty list / 0 = "No Tax".
  void setTaxes(List<String> ids, double? rate) {
    selectedTaxIds = ids;
    selectedTaxRate = (rate == null || rate == 0) ? null : rate;
    notifyListeners();
  }

  /// Set selling method
  void setSellingMethod(SellingMethod method) {
    sellingMethod = method;
    notifyListeners();
  }

  /// Set selected unit for weight-based selling
  void setUnit(String unit) {
    selectedUnit = unit;
    notifyListeners();
  }

  /// Set category
  void setCategory(String id, String name) {
    selectedCategoryId = id;
    selectedCategoryName = name;
    notifyListeners();
  }

  /// Set veg/non-veg category
  void setVegCategory(String category) {
    vegCategory = category;
    notifyListeners();
  }

  /// Set track inventory
  void setTrackInventory(bool value) {
    trackInventory = value;
    notifyListeners();
  }

  /// Set per-item low-stock alert opt-in
  void setLowStockAlert(bool value) {
    lowStockAlertEnabled = value;
    notifyListeners();
  }

  /// Set allow order when out of stock
  void setAllowOrderWhenOutOfStock(bool value) {
    allowOrderWhenOutOfStock = value;
    notifyListeners();
  }

  /// Set selected image
  void setImage(Uint8List? image) {
    selectedImage = image;
    notifyListeners();
  }

  @override
  void dispose() {
    itemNameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    stockController.dispose();
    lowStockThresholdController.dispose();
    itemCodeController.dispose();
    super.dispose();
  }
}

/// Result of form validation
class ValidationResult {
  final bool isValid;
  final List<String> missingFields;

  ValidationResult({
    required this.isValid,
    required this.missingFields,
  });

  String get errorMessage {
    if (isValid) return '';
    return 'Please fill the following required fields:\n\n• ${missingFields.join('\n• ')}';
  }
}