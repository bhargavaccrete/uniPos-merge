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

  // Inventory
  bool trackInventory = false;
  bool allowOrderWhenOutOfStock = true;

  // Variants, Choices, Extras
  List<Map<String, dynamic>> selectedVariants = [];
  List<String> selectedChoiceIds = [];
  List<String> selectedExtraIds = [];

  /// Reset all form fields to default values
  void reset() {
    itemNameController.clear();
    priceController.clear();
    descriptionController.clear();
    selectedImage = null;
    sellingMethod = SellingMethod.byUnit;
    selectedUnit = 'kg';
    selectedCategoryId = null;
    selectedCategoryName = null;
    vegCategory = 'Veg';
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
            ))
        .toList();

    return Items(
      id: const Uuid().v4(),
      name: itemNameController.text.trim(),
      price: double.tryParse(priceController.text.trim()),
      categoryOfItem: selectedCategoryId ?? "",
      imageBytes: selectedImage,
      isVeg: vegCategory,
      isSoldByWeight: sellingMethod == SellingMethod.byWeight,
      unit: sellingMethod == SellingMethod.byWeight ? selectedUnit : null,
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
      'variants': selectedVariants,
      'choiceIds': selectedChoiceIds,
      'extraIds': selectedExtraIds,
    };
  }

  /// Update variants, choices, extras from AddMoreInfo result
  void updateFromMoreInfo(Map<String, dynamic> result) {
    selectedVariants = List<Map<String, dynamic>>.from(result['variants'] ?? []);
    selectedChoiceIds = List<String>.from(result['choiceIds'] ?? []);
    selectedExtraIds = List<String>.from(result['extraIds'] ?? []);
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