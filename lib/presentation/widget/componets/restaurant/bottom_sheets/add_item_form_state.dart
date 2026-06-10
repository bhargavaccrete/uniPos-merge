import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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

  // Tax (taxRate is a decimal, e.g. 0.18 for 18%)
  String? selectedTaxId;
  double? selectedTaxRate;

  // Inventory
  bool trackInventory = false;
  bool allowOrderWhenOutOfStock = true;
  bool lowStockAlertEnabled = false;

  // Variants, Choices, Extras
  List<Map<String, dynamic>> selectedVariants = [];
  List<String> selectedChoiceIds = [];
  List<String> selectedExtraIds = [];

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
    selectedTaxId = null;
    selectedTaxRate = null;
    trackInventory = false;
    allowOrderWhenOutOfStock = true;
    selectedVariants.clear();
    selectedChoiceIds.clear();
    selectedExtraIds.clear();
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
      lowStockAlertEnabled: trackInventory && lowStockAlertEnabled,
      lowStockThreshold: (trackInventory && lowStockAlertEnabled)
          ? double.tryParse(lowStockThresholdController.text.trim())
          : null,
      trackInventory: trackInventory,
      allowOrderWhenOutOfStock: allowOrderWhenOutOfStock,
      variant: itemVariants,
      choiceIds: selectedChoiceIds,
      extraId: selectedExtraIds,
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
      'taxId': selectedTaxId,
      'taxRate': selectedTaxRate,
      'trackInventory': trackInventory,
      'variants': selectedVariants,
      'choiceIds': selectedChoiceIds,
      'extraIds': selectedExtraIds,
    };
  }

  /// Update variants, choices, extras and tax from AddMoreInfo result
  void updateFromMoreInfo(Map<String, dynamic> result) {
    selectedVariants = List<Map<String, dynamic>>.from(result['variants'] ?? []);
    selectedChoiceIds = List<String>.from(result['choiceIds'] ?? []);
    selectedExtraIds = List<String>.from(result['extraIds'] ?? []);
    // More Info can also set the tax — keep it in sync so it isn't lost.
    if (result.containsKey('taxId') || result.containsKey('taxRate')) {
      selectedTaxId = result['taxId'] as String?;
      selectedTaxRate = (result['taxRate'] as num?)?.toDouble();
    }
    notifyListeners();
  }

  /// Set tax (taxRate as decimal, e.g. 0.18). Pass nulls for "No Tax".
  void setTax(String? id, double? rate) {
    selectedTaxId = id;
    selectedTaxRate = rate;
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