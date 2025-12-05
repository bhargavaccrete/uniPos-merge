import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/attribute_value_model_220.dart';
import '../../../data/models/retail/hive_model/product_attribute_model_221.dart';
import '../../../data/repositories/retail/attribute_repository.dart';


part 'attribute_store.g.dart';

class AttributeStore = _AttributeStoreBase with _$AttributeStore;

abstract class _AttributeStoreBase with Store {
  late final AttributeRepository _repository;
  final _uuid = const Uuid();

  @observable
  ObservableList<AttributeModel> attributes = ObservableList<AttributeModel>();

  @observable
  ObservableMap<String, ObservableList<AttributeValueModel>> attributeValues =
      ObservableMap<String, ObservableList<AttributeValueModel>>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  AttributeModel? selectedAttribute;

  _AttributeStoreBase() {
    _repository = AttributeRepository();
  }

  // ==================== INITIALIZATION ====================

  @action
  Future<void> loadAttributes() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loadedAttributes = await _repository.getAllAttributes();
      attributes = ObservableList.of(loadedAttributes);

      // Load values for each attribute
      for (final attr in loadedAttributes) {
        await loadValuesForAttribute(attr.attributeId);
      }
    } catch (e) {
      errorMessage = 'Failed to load attributes: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> loadValuesForAttribute(String attributeId) async {
    try {
      final values = await _repository.getValuesForAttribute(attributeId);
      attributeValues[attributeId] = ObservableList.of(values);
    } catch (e) {
      errorMessage = 'Failed to load values for attribute: $e';
    }
  }

  // ==================== ATTRIBUTE CRUD ====================

  @action
  Future<bool> addAttribute(String name, {int sortOrder = 0}) async {
    try {
      // Check for duplicate
      if (await _repository.attributeNameExists(name)) {
        errorMessage = 'Attribute "$name" already exists';
        return false;
      }

      final attribute = AttributeModel(
        attributeId: _uuid.v4(),
        name: name.trim(),
        slug: AttributeModel.generateSlug(name),
        sortOrder: sortOrder,
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _repository.addAttribute(attribute);
      attributes.add(attribute);
      attributeValues[attribute.attributeId] = ObservableList<AttributeValueModel>();

      return true;
    } catch (e) {
      errorMessage = 'Failed to add attribute: $e';
      return false;
    }
  }

  @action
  Future<bool> updateAttribute(
    String attributeId, {
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final index = attributes.indexWhere((a) => a.attributeId == attributeId);
      if (index == -1) {
        errorMessage = 'Attribute not found';
        return false;
      }

      // Check for duplicate name if updating name
      if (name != null &&
          await _repository.attributeNameExists(name, excludeId: attributeId)) {
        errorMessage = 'Attribute "$name" already exists';
        return false;
      }

      final updated = attributes[index].copyWith(
        name: name,
        slug: name != null ? AttributeModel.generateSlug(name) : null,
        sortOrder: sortOrder,
        isActive: isActive,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _repository.updateAttribute(updated);
      attributes[index] = updated;

      return true;
    } catch (e) {
      errorMessage = 'Failed to update attribute: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteAttribute(String attributeId) async {
    try {
      // Check if attribute is in use
      if (await _repository.isAttributeInUse(attributeId)) {
        errorMessage = 'Cannot delete attribute that is in use by products';
        return false;
      }

      await _repository.deleteAttribute(attributeId);
      attributes.removeWhere((a) => a.attributeId == attributeId);
      attributeValues.remove(attributeId);

      return true;
    } catch (e) {
      errorMessage = 'Failed to delete attribute: $e';
      return false;
    }
  }

  // ==================== ATTRIBUTE VALUE CRUD ====================

  @action
  Future<bool> addValue(
    String attributeId,
    String value, {
    String? colorCode,
    int sortOrder = 0,
  }) async {
    try {
      // Check for duplicate
      if (await _repository.valueExistsForAttribute(attributeId, value)) {
        errorMessage = 'Value "$value" already exists for this attribute';
        return false;
      }

      final attributeValue = AttributeValueModel(
        valueId: _uuid.v4(),
        attributeId: attributeId,
        value: value.trim(),
        slug: AttributeValueModel.generateSlug(value),
        colorCode: colorCode,
        sortOrder: sortOrder,
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _repository.addValue(attributeValue);

      if (attributeValues.containsKey(attributeId)) {
        attributeValues[attributeId]!.add(attributeValue);
      } else {
        attributeValues[attributeId] = ObservableList.of([attributeValue]);
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to add value: $e';
      return false;
    }
  }

  @action
  Future<bool> addMultipleValues(
    String attributeId,
    List<String> values, {
    List<String?>? colorCodes,
  }) async {
    try {
      for (var i = 0; i < values.length; i++) {
        final value = values[i].trim();
        if (value.isEmpty) continue;

        // Skip if duplicate
        if (await _repository.valueExistsForAttribute(attributeId, value)) {
          continue;
        }

        final attributeValue = AttributeValueModel(
          valueId: _uuid.v4(),
          attributeId: attributeId,
          value: value,
          slug: AttributeValueModel.generateSlug(value),
          colorCode: colorCodes != null && i < colorCodes.length ? colorCodes[i] : null,
          sortOrder: i,
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        );

        await _repository.addValue(attributeValue);

        if (attributeValues.containsKey(attributeId)) {
          attributeValues[attributeId]!.add(attributeValue);
        } else {
          attributeValues[attributeId] = ObservableList.of([attributeValue]);
        }
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to add values: $e';
      return false;
    }
  }

  @action
  Future<bool> updateValue(
    String valueId, {
    String? value,
    String? colorCode,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final attrValue = await _repository.getValueById(valueId);
      if (attrValue == null) {
        errorMessage = 'Value not found';
        return false;
      }

      // Check for duplicate name if updating value
      if (value != null &&
          await _repository.valueExistsForAttribute(
            attrValue.attributeId,
            value,
            excludeId: valueId,
          )) {
        errorMessage = 'Value "$value" already exists for this attribute';
        return false;
      }

      final updated = attrValue.copyWith(
        value: value,
        slug: value != null ? AttributeValueModel.generateSlug(value) : null,
        colorCode: colorCode,
        sortOrder: sortOrder,
        isActive: isActive,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _repository.updateValue(updated);

      // Update in observable list
      final values = attributeValues[attrValue.attributeId];
      if (values != null) {
        final index = values.indexWhere((v) => v.valueId == valueId);
        if (index != -1) {
          values[index] = updated;
        }
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update value: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteValue(String valueId) async {
    try {
      final value = await _repository.getValueById(valueId);
      if (value == null) {
        errorMessage = 'Value not found';
        return false;
      }

      await _repository.deleteValue(valueId);

      // Remove from observable list
      final values = attributeValues[value.attributeId];
      if (values != null) {
        values.removeWhere((v) => v.valueId == valueId);
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to delete value: $e';
      return false;
    }
  }

  // ==================== PRODUCT ATTRIBUTES ====================

  @action
  Future<List<ProductAttributeModel>> getProductAttributes(String productId) async {
    return await _repository.getProductAttributes(productId);
  }

  @action
  Future<bool> assignAttributesToProduct(
    String productId,
    List<Map<String, dynamic>> attributeAssignments,
  ) async {
    try {
      // Remove existing assignments
      await _repository.removeAllAttributesFromProduct(productId);

      // Add new assignments
      for (var i = 0; i < attributeAssignments.length; i++) {
        final assignment = attributeAssignments[i];
        final productAttribute = ProductAttributeModel(
          id: _uuid.v4(),
          productId: productId,
          attributeId: assignment['attributeId'] as String,
          selectedValueIds: List<String>.from(assignment['valueIds'] ?? []),
          usedForVariants: assignment['usedForVariants'] ?? true,
          isVisible: assignment['isVisible'] ?? true,
          position: i,
          createdAt: DateTime.now().toIso8601String(),
        );

        await _repository.assignAttributeToProduct(productAttribute);
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to assign attributes: $e';
      return false;
    }
  }

  @action
  Future<bool> removeAttributesFromProduct(String productId) async {
    try {
      await _repository.removeAllAttributesFromProduct(productId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to remove attributes: $e';
      return false;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Get attribute by ID from cache
  AttributeModel? getAttributeById(String attributeId) {
    try {
      return attributes.firstWhere((a) => a.attributeId == attributeId);
    } catch (_) {
      return null;
    }
  }

  /// Get values for attribute from cache
  List<AttributeValueModel> getValues(String attributeId) {
    return attributeValues[attributeId]?.toList() ?? [];
  }

  /// Alias for getValues - used in AddProductScreen
  List<AttributeValueModel> getValuesForAttribute(String attributeId) {
    return getValues(attributeId);
  }

  /// Get all attribute values across all attributes
  @computed
  List<AttributeValueModel> get allValues {
    final result = <AttributeValueModel>[];
    for (final values in attributeValues.values) {
      result.addAll(values);
    }
    return result;
  }

  /// Get value by ID
  AttributeValueModel? getValueById(String valueId) {
    for (final values in attributeValues.values) {
      for (final value in values) {
        if (value.valueId == valueId) return value;
      }
    }
    return null;
  }

  /// Get values by IDs
  List<AttributeValueModel> getValuesByIds(List<String> valueIds) {
    final result = <AttributeValueModel>[];
    for (final values in attributeValues.values) {
      for (final value in values) {
        if (valueIds.contains(value.valueId)) {
          result.add(value);
        }
      }
    }
    return result;
  }

  /// Clear error message
  @action
  void clearError() {
    errorMessage = null;
  }

  /// Select an attribute for editing
  @action
  void selectAttribute(AttributeModel? attribute) {
    selectedAttribute = attribute;
  }

  /// Get all attributes with their values (for product form)
  List<Map<String, dynamic>> getAllAttributesWithValues() {
    return attributes.map((attr) {
      return {
        'attribute': attr,
        'values': getValues(attr.attributeId),
      };
    }).toList();
  }
}