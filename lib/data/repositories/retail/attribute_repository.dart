import 'package:hive/hive.dart';

import '../../models/retail/hive_model/attribute_model_219.dart';
import '../../models/retail/hive_model/attribute_value_model_220.dart';
import '../../models/retail/hive_model/product_attribute_model_221.dart';


/// Repository for managing global product attributes
class AttributeRepository {
  static const String _attributesBoxName = 'attributes';
  static const String _attributeValuesBoxName = 'attribute_values';
  static const String _productAttributesBoxName = 'product_attributes';

  Box<AttributeModel>? _attributesBox;
  Box<AttributeValueModel>? _valuesBox;
  Box<ProductAttributeModel>? _productAttributesBox;

  Box<AttributeModel> get attributesBox {
    _attributesBox ??= Hive.box<AttributeModel>(_attributesBoxName);
    return _attributesBox!;
  }

  Box<AttributeValueModel> get valuesBox {
    _valuesBox ??= Hive.box<AttributeValueModel>(_attributeValuesBoxName);
    return _valuesBox!;
  }

  Box<ProductAttributeModel> get productAttributesBox {
    _productAttributesBox ??= Hive.box<ProductAttributeModel>(_productAttributesBoxName);
    return _productAttributesBox!;
  }

  /// Check if boxes are corrupted and auto-reset if needed
  Future<bool> checkAndFixCorruption() async {
    try {
      final box = attributesBox;
      // Try to access values - this will throw if corrupted
      box.values.length;
      return false; // Not corrupted
    } catch (e) {
      if (e.toString().contains('Bad state') || e.toString().contains('No element')) {
        print('🔧 Detected corrupted attribute data, auto-resetting...');
        await resetAllBoxes();
        return true; // Was corrupted, now fixed
      }
      return false;
    }
  }

  /// Reset all attribute boxes
  ///
  /// ⚠️ WARNING: This is an administrative operation that closes and deletes boxes.
  /// DO NOT call this while any UI is actively using attributes.
  /// This should only be called from admin/settings screens with user confirmation.
  Future<void> resetAllBoxes() async {
    try {
      // Close boxes
      if (_attributesBox?.isOpen ?? false) await _attributesBox!.close();
      if (_valuesBox?.isOpen ?? false) await _valuesBox!.close();
      if (_productAttributesBox?.isOpen ?? false) await _productAttributesBox!.close();

      // Delete from disk
      await Hive.deleteBoxFromDisk(_attributesBoxName);
      await Hive.deleteBoxFromDisk(_attributeValuesBoxName);
      await Hive.deleteBoxFromDisk(_productAttributesBoxName);

      // Reopen boxes
      _attributesBox = await Hive.openBox<AttributeModel>(_attributesBoxName);
      _valuesBox = await Hive.openBox<AttributeValueModel>(_attributeValuesBoxName);
      _productAttributesBox = await Hive.openBox<ProductAttributeModel>(_productAttributesBoxName);

      print('✅ Attribute boxes reset successfully');
    } catch (e) {
      print('❌ Error resetting boxes: $e');
    }
  }

  // ==================== ATTRIBUTES ====================

  /// Get all global attributes
  Future<List<AttributeModel>> getAllAttributes() async {
    final box = attributesBox;
    try {
      return box.values.where((a) => a.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } catch (e) {
      print('Error loading attributes: $e');
      // Try to recover by loading one by one
      final List<AttributeModel> validAttributes = [];
      for (var key in box.keys) {
        try {
          final attr = box.get(key);
          if (attr != null && attr.isActive) {
            validAttributes.add(attr);
          }
        } catch (itemError) {
          print('Skipping corrupted attribute with key $key: $itemError');
        }
      }
      validAttributes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return validAttributes;
    }
  }

  /// Get attribute by ID
  Future<AttributeModel?> getAttributeById(String attributeId) async {
    final box = attributesBox;
    try {
      return box.values.firstWhere((a) => a.attributeId == attributeId);
    } catch (_) {
      return null;
    }
  }

  /// Get attribute by slug
  Future<AttributeModel?> getAttributeBySlug(String slug) async {
    final box = attributesBox;
    try {
      return box.values.firstWhere(
        (a) => a.slug.toLowerCase() == slug.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Add a new attribute
  Future<void> addAttribute(AttributeModel attribute) async {
    final box = attributesBox;
    await box.put(attribute.attributeId, attribute);
  }

  /// Update an attribute
  Future<void> updateAttribute(AttributeModel attribute) async {
    final box = attributesBox;
    await box.put(attribute.attributeId, attribute);
  }

  /// Delete an attribute and its values
  Future<void> deleteAttribute(String attributeId) async {
    final box = attributesBox;
    await box.delete(attributeId);

    // Also delete all values for this attribute
    await deleteValuesForAttribute(attributeId);

    // Remove from all product assignments
    await removeAttributeFromAllProducts(attributeId);
  }

  /// Soft delete (deactivate) an attribute
  Future<void> deactivateAttribute(String attributeId) async {
    final attribute = await getAttributeById(attributeId);
    if (attribute != null) {
      await updateAttribute(attribute.copyWith(
        isActive: false,
        updatedAt: DateTime.now().toIso8601String(),
      ));
    }
  }

  // ==================== ATTRIBUTE VALUES ====================

  /// Get all values for an attribute
  Future<List<AttributeValueModel>> getValuesForAttribute(String attributeId) async {
    final box = valuesBox;
    try {
      return box.values
          .where((v) => v.attributeId == attributeId && v.isActive)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } catch (e) {
      print('Error loading values for attribute $attributeId: $e');
      // Try to recover by loading one by one
      final List<AttributeValueModel> validValues = [];
      for (var key in box.keys) {
        try {
          final value = box.get(key);
          if (value != null && value.attributeId == attributeId && value.isActive) {
            validValues.add(value);
          }
        } catch (itemError) {
          print('Skipping corrupted value with key $key: $itemError');
        }
      }
      validValues.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return validValues;
    }
  }

  /// Get value by ID
  Future<AttributeValueModel?> getValueById(String valueId) async {
    final box = valuesBox;
    try {
      return box.values.firstWhere((v) => v.valueId == valueId);
    } catch (_) {
      return null;
    }
  }

  /// Get multiple values by IDs
  Future<List<AttributeValueModel>> getValuesByIds(List<String> valueIds) async {
    final box = valuesBox;
    return box.values.where((v) => valueIds.contains(v.valueId)).toList();
  }

  /// Add a value to an attribute
  Future<void> addValue(AttributeValueModel value) async {
    final box = valuesBox;
    await box.put(value.valueId, value);
  }

  /// Update a value
  Future<void> updateValue(AttributeValueModel value) async {
    final box = valuesBox;
    await box.put(value.valueId, value);
  }

  /// Delete a value
  Future<void> deleteValue(String valueId) async {
    final box = valuesBox;
    await box.delete(valueId);
  }

  /// Delete all values for an attribute
  Future<void> deleteValuesForAttribute(String attributeId) async {
    final box = valuesBox;
    final valuesToDelete = box.values
        .where((v) => v.attributeId == attributeId)
        .map((v) => v.valueId)
        .toList();

    for (final valueId in valuesToDelete) {
      await box.delete(valueId);
    }
  }

  /// Add multiple values at once
  Future<void> addValues(List<AttributeValueModel> values) async {
    final box = valuesBox;
    for (final value in values) {
      await box.put(value.valueId, value);
    }
  }

  // ==================== PRODUCT ATTRIBUTES ====================

  /// Get all attributes assigned to a product
  Future<List<ProductAttributeModel>> getProductAttributes(String productId) async {
    final box = productAttributesBox;
    try {
      return box.values.where((pa) => pa.productId == productId).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    } catch (e) {
      print('Error loading product attributes for $productId: $e');
      // Try to recover by loading one by one
      final List<ProductAttributeModel> validProductAttrs = [];
      for (var key in box.keys) {
        try {
          final prodAttr = box.get(key);
          if (prodAttr != null && prodAttr.productId == productId) {
            validProductAttrs.add(prodAttr);
          }
        } catch (itemError) {
          print('Skipping corrupted product attribute with key $key: $itemError');
        }
      }
      validProductAttrs.sort((a, b) => a.position.compareTo(b.position));
      return validProductAttrs;
    }
  }

  /// Assign an attribute to a product
  Future<void> assignAttributeToProduct(ProductAttributeModel productAttribute) async {
    final box = productAttributesBox;
    await box.put(productAttribute.id, productAttribute);
  }

  /// Update product attribute assignment
  Future<void> updateProductAttribute(ProductAttributeModel productAttribute) async {
    final box = productAttributesBox;
    await box.put(productAttribute.id, productAttribute);
  }

  /// Remove an attribute from a product
  Future<void> removeAttributeFromProduct(String productId, String attributeId) async {
    final box = productAttributesBox;
    final toRemove = box.values.where(
      (pa) => pa.productId == productId && pa.attributeId == attributeId,
    ).toList();

    for (final pa in toRemove) {
      await box.delete(pa.id);
    }
  }

  /// Remove all attributes from a product
  Future<void> removeAllAttributesFromProduct(String productId) async {
    final box = productAttributesBox;
    final toRemove = box.values.where((pa) => pa.productId == productId).toList();

    for (final pa in toRemove) {
      await box.delete(pa.id);
    }
  }

  /// Remove an attribute from all products
  Future<void> removeAttributeFromAllProducts(String attributeId) async {
    final box = productAttributesBox;
    final toRemove = box.values.where((pa) => pa.attributeId == attributeId).toList();

    for (final pa in toRemove) {
      await box.delete(pa.id);
    }
  }

  /// Get products using a specific attribute
  Future<List<String>> getProductsUsingAttribute(String attributeId) async {
    final box = productAttributesBox;
    return box.values
        .where((pa) => pa.attributeId == attributeId)
        .map((pa) => pa.productId)
        .toSet()
        .toList();
  }

  /// Check if attribute is in use by any product
  Future<bool> isAttributeInUse(String attributeId) async {
    final products = await getProductsUsingAttribute(attributeId);
    return products.isNotEmpty;
  }

  // ==================== HELPER METHODS ====================

  /// Get attribute with its values
  Future<Map<String, dynamic>> getAttributeWithValues(String attributeId) async {
    final attribute = await getAttributeById(attributeId);
    if (attribute == null) return {};

    final values = await getValuesForAttribute(attributeId);
    return {
      'attribute': attribute,
      'values': values,
    };
  }

  /// Get all attributes with their values
  Future<List<Map<String, dynamic>>> getAllAttributesWithValues() async {
    final attributes = await getAllAttributes();
    final result = <Map<String, dynamic>>[];

    for (final attribute in attributes) {
      final values = await getValuesForAttribute(attribute.attributeId);
      result.add({
        'attribute': attribute,
        'values': values,
      });
    }

    return result;
  }

  /// Search attributes by name
  Future<List<AttributeModel>> searchAttributes(String query) async {
    final box = attributesBox;
    final lowercaseQuery = query.toLowerCase();
    return box.values
        .where((a) =>
            a.isActive &&
            (a.name.toLowerCase().contains(lowercaseQuery) ||
                a.slug.toLowerCase().contains(lowercaseQuery)))
        .toList();
  }

  /// Check if attribute name exists
  Future<bool> attributeNameExists(String name, {String? excludeId}) async {
    try {
      final box = attributesBox;
      return box.values.any((a) =>
          a.name.toLowerCase() == name.toLowerCase() &&
          (excludeId == null || a.attributeId != excludeId));
    } catch (e) {
      print('⚠️ Error checking attribute name exists: $e');
      // If we can't read the box, try to check one by one
      try {
        final box = attributesBox;
        for (var key in box.keys) {
          try {
            final attr = box.get(key);
            if (attr != null &&
                attr.name.toLowerCase() == name.toLowerCase() &&
                (excludeId == null || attr.attributeId != excludeId)) {
              return true;
            }
          } catch (_) {
            // Skip corrupted entry
            continue;
          }
        }
        return false;
      } catch (e2) {
        print('❌ Cannot check attribute existence: $e2');
        return false; // Assume doesn't exist if we can't check
      }
    }
  }

  /// Check if value exists for attribute
  Future<bool> valueExistsForAttribute(
    String attributeId,
    String value, {
    String? excludeId,
  }) async {
    final values = await getValuesForAttribute(attributeId);
    return values.any((v) =>
        v.value.toLowerCase() == value.toLowerCase() &&
        (excludeId == null || v.valueId != excludeId));
  }
}