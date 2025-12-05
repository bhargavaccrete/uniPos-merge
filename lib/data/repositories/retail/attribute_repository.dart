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

  Future<Box<AttributeModel>> get attributesBox async {
    _attributesBox ??= await Hive.openBox<AttributeModel>(_attributesBoxName);
    return _attributesBox!;
  }

  Future<Box<AttributeValueModel>> get valuesBox async {
    _valuesBox ??= await Hive.openBox<AttributeValueModel>(_attributeValuesBoxName);
    return _valuesBox!;
  }

  Future<Box<ProductAttributeModel>> get productAttributesBox async {
    _productAttributesBox ??= await Hive.openBox<ProductAttributeModel>(_productAttributesBoxName);
    return _productAttributesBox!;
  }

  // ==================== ATTRIBUTES ====================

  /// Get all global attributes
  Future<List<AttributeModel>> getAllAttributes() async {
    final box = await attributesBox;
    return box.values.where((a) => a.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get attribute by ID
  Future<AttributeModel?> getAttributeById(String attributeId) async {
    final box = await attributesBox;
    try {
      return box.values.firstWhere((a) => a.attributeId == attributeId);
    } catch (_) {
      return null;
    }
  }

  /// Get attribute by slug
  Future<AttributeModel?> getAttributeBySlug(String slug) async {
    final box = await attributesBox;
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
    final box = await attributesBox;
    await box.put(attribute.attributeId, attribute);
  }

  /// Update an attribute
  Future<void> updateAttribute(AttributeModel attribute) async {
    final box = await attributesBox;
    await box.put(attribute.attributeId, attribute);
  }

  /// Delete an attribute and its values
  Future<void> deleteAttribute(String attributeId) async {
    final box = await attributesBox;
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
    final box = await valuesBox;
    return box.values
        .where((v) => v.attributeId == attributeId && v.isActive)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get value by ID
  Future<AttributeValueModel?> getValueById(String valueId) async {
    final box = await valuesBox;
    try {
      return box.values.firstWhere((v) => v.valueId == valueId);
    } catch (_) {
      return null;
    }
  }

  /// Get multiple values by IDs
  Future<List<AttributeValueModel>> getValuesByIds(List<String> valueIds) async {
    final box = await valuesBox;
    return box.values.where((v) => valueIds.contains(v.valueId)).toList();
  }

  /// Add a value to an attribute
  Future<void> addValue(AttributeValueModel value) async {
    final box = await valuesBox;
    await box.put(value.valueId, value);
  }

  /// Update a value
  Future<void> updateValue(AttributeValueModel value) async {
    final box = await valuesBox;
    await box.put(value.valueId, value);
  }

  /// Delete a value
  Future<void> deleteValue(String valueId) async {
    final box = await valuesBox;
    await box.delete(valueId);
  }

  /// Delete all values for an attribute
  Future<void> deleteValuesForAttribute(String attributeId) async {
    final box = await valuesBox;
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
    final box = await valuesBox;
    for (final value in values) {
      await box.put(value.valueId, value);
    }
  }

  // ==================== PRODUCT ATTRIBUTES ====================

  /// Get all attributes assigned to a product
  Future<List<ProductAttributeModel>> getProductAttributes(String productId) async {
    final box = await productAttributesBox;
    return box.values.where((pa) => pa.productId == productId).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Assign an attribute to a product
  Future<void> assignAttributeToProduct(ProductAttributeModel productAttribute) async {
    final box = await productAttributesBox;
    await box.put(productAttribute.id, productAttribute);
  }

  /// Update product attribute assignment
  Future<void> updateProductAttribute(ProductAttributeModel productAttribute) async {
    final box = await productAttributesBox;
    await box.put(productAttribute.id, productAttribute);
  }

  /// Remove an attribute from a product
  Future<void> removeAttributeFromProduct(String productId, String attributeId) async {
    final box = await productAttributesBox;
    final toRemove = box.values.where(
      (pa) => pa.productId == productId && pa.attributeId == attributeId,
    ).toList();

    for (final pa in toRemove) {
      await box.delete(pa.id);
    }
  }

  /// Remove all attributes from a product
  Future<void> removeAllAttributesFromProduct(String productId) async {
    final box = await productAttributesBox;
    final toRemove = box.values.where((pa) => pa.productId == productId).toList();

    for (final pa in toRemove) {
      await box.delete(pa.id);
    }
  }

  /// Remove an attribute from all products
  Future<void> removeAttributeFromAllProducts(String attributeId) async {
    final box = await productAttributesBox;
    final toRemove = box.values.where((pa) => pa.attributeId == attributeId).toList();

    for (final pa in toRemove) {
      await box.delete(pa.id);
    }
  }

  /// Get products using a specific attribute
  Future<List<String>> getProductsUsingAttribute(String attributeId) async {
    final box = await productAttributesBox;
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
    final box = await attributesBox;
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
    final box = await attributesBox;
    return box.values.any((a) =>
        a.name.toLowerCase() == name.toLowerCase() &&
        (excludeId == null || a.attributeId != excludeId));
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