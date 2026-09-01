import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/attribute_value_model_220.dart';
import '../../../data/models/retail/hive_model/product_attribute_model_221.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/repositories/retail/attribute_repository.dart';


part 'attribute_store.g.dart';

/// Attribute names a retail store starts with — the same three the Simple
/// product form used to hardcode. Top-level (not a class static) because the
/// MobX `class AttributeStore = _AttributeStoreBase with ...` form does not
/// expose the base class's statics.
const List<String> kBaseAttributeNames = ['Size', 'Color', 'Weight'];

/// Human-readable descriptor for a stored attribute map, falling back to the
/// legacy `size`/`color`/`weight` columns for records saved before generic
/// attributes existed.
///
/// [labelled] true → `Size: L · Color: Red`; false → `L · Red`. Returns an
/// empty string when there is nothing to show, so callers can decide whether to
/// render a line at all.
///
/// **Top-level, not a store method, on purpose.** It reads nothing off
/// `AttributeStore` — only its arguments — and the receipt builders that call it
/// run in BOTH modes: restaurant's bill/KOT print reuses retail's
/// `ReceiptPdfService` and `PrintService`. `AttributeStore` is registered only
/// by `_registerRetailDependencies()`, so going through the store crashed
/// restaurant printing with "GetIt: Object/factory with type AttributeStore is
/// not registered". Restaurant items carry no attribute map and fall through to
/// the legacy columns, which needs no store at all.
String describeAttributeMap(
  Map<String, String>? attributes, {
  String? size,
  String? color,
  String? weight,
  bool labelled = true,
  String separator = ' · ',
}) {
  final source = <String, String>{};

  if (attributes != null) {
    attributes.forEach((key, value) {
      if (key.trim().isNotEmpty && value.trim().isNotEmpty) {
        source[key] = value.trim();
      }
    });
  }

  if (source.isEmpty) {
    // Legacy fallback — pre-migration records carry only these three.
    if (size != null && size.trim().isNotEmpty) source['Size'] = size.trim();
    if (color != null && color.trim().isNotEmpty) source['Color'] = color.trim();
    if (weight != null && weight.trim().isNotEmpty) {
      source['Weight'] = weight.trim();
    }
  }

  if (source.isEmpty) return '';

  return source.entries
      .map((e) => labelled ? '${e.key}: ${e.value}' : e.value)
      .join(separator);
}

/// Starter values for every attribute the app knows how to seed, keyed by
/// attribute name. A name absent from here is still created by
/// [_AttributeStoreBase.ensureBaseAttributes] — just with no values, which the
/// user then fills in.
///
/// One dictionary shared by all store types on purpose: a garment shop and a
/// sports shop that both start with "Size" get the SAME Size attribute, so a
/// product can move between them and reports stay comparable. Per-store-type
/// value sets (UK/EU shoe sizes vs S–XXL) are deliberately NOT here — that is a
/// separate feature, not a default.
const Map<String, List<String>> kSeedAttributeValues = <String, List<String>>{
  'Size': ['Small', 'Medium', 'Large', 'Extra Large'],
  'Color': ['Red', 'Blue', 'Green', 'Black', 'White'],
  'Weight': ['250g', '500g', '1kg'],
  // Cosmetics: shade families, not brand shade names — those are per-brand and
  // belong to the shop, not to us.
  'Shade': ['Nude', 'Pink', 'Red', 'Berry', 'Brown'],
  'Volume': ['30ml', '50ml', '100ml', '200ml'],
  'Pack Size': ['Pack of 5', 'Pack of 10', 'Pack of 12', 'Box of 12', 'Ream (500)'],
  // Apparel / footwear / sports descriptors.
  'Material': ['Cotton', 'Polyester', 'Silk', 'Denim', 'Leather'],
  'Pattern': ['Solid', 'Printed', 'Striped', 'Checked', 'Floral'],
  'Sole Type': ['Rubber', 'EVA', 'PU', 'Leather', 'TPR'],
  'Sport Type': ['Cricket', 'Football', 'Badminton', 'Gym', 'Running'],
  // Cosmetics: how a product suits the buyer and how it sits on the skin.
  'Skin Type': ['Normal', 'Dry', 'Oily', 'Combination', 'Sensitive'],
  'Finish': ['Matte', 'Glossy', 'Satin', 'Dewy', 'Shimmer'],
  // Stationery. GSM values are bare numbers — the attribute name supplies the
  // unit, so a variant reads "GSM: 80" rather than "GSM: 80 GSM".
  'Paper Type': ['Ruled', 'Unruled', 'Graph', 'Art Paper'],
  'GSM': ['70', '80', '100', '120', '150'],
  'Binding Type': ['Spiral', 'Perfect', 'Stapled', 'Hardbound'],
};

/// Hex swatches for the attributes whose values are colours, index-aligned with
/// [kSeedAttributeValues]. Any attribute not listed here seeds without swatches.
const Map<String, List<String?>> kSeedAttributeColorCodes = <String, List<String?>>{
  'Color': ['#FF0000', '#0000FF', '#00FF00', '#000000', '#FFFFFF'],
  'Shade': ['#E3BC9A', '#F4A6C0', '#C62828', '#8E2A5B', '#6D4C41'],
};

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
      // Auto-fix corruption if detected
      await _repository.checkAndFixCorruption();

      final loadedAttributes = await _repository.getAllAttributes();
      attributes = ObservableList.of(loadedAttributes);

      // Load values for each attribute
      for (final attr in loadedAttributes) {
        try {
          await loadValuesForAttribute(attr.attributeId);
        } catch (e) {
          print('⚠️ Error loading values for attribute ${attr.name}: $e');
          // Continue with other attributes
        }
      }
    } catch (e) {
      print('❌ Error loading attributes: $e');
      errorMessage = 'Failed to load attributes: $e';
      // Initialize with empty list on error
      attributes = ObservableList<AttributeModel>();
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
      // Auto-fix corruption before checking
      final wasCorrupted = await _repository.checkAndFixCorruption();
      if (wasCorrupted) {
        print('🔧 Fixed corrupted data, reloading attributes...');
        await loadAttributes();
      }

      // Check for duplicate
      final exists = await _repository.attributeNameExists(name);
      if (exists) {
        errorMessage = 'Attribute "$name" already exists from imported data';
        print('ℹ️ Attribute "$name" already exists, skipping creation');
        return false;
      }

      final attribute = AttributeModel(
        attributeId: _uuid.v4(),
        name: name.trim(),
        slug: AttributeModel.generateSlug(name),
        sortOrder: sortOrder,
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: null,
      );

      await _repository.addAttribute(attribute);
      attributes.add(attribute);
      attributeValues[attribute.attributeId] = ObservableList<AttributeValueModel>();

      print('✅ Created attribute: $name');
      return true;
    } catch (e) {
      print('❌ Error adding attribute "$name": $e');
      errorMessage = 'Failed to add attribute "$name": ${e.toString()}';
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
        updatedAt: null,
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
          updatedAt: null,
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

  /// Resolve attribute ids to models, preserving the given order and skipping
  /// ids that no longer exist.
  ///
  /// Used by stored configuration that holds only ids (e.g. Simple Product
  /// Fields) — a deleted attribute must drop out quietly rather than surface a
  /// phantom entry or throw. Call after [loadAttributes].
  List<AttributeModel> attributesByIds(List<String> attributeIds) {
    final result = <AttributeModel>[];
    for (final id in attributeIds) {
      final attribute = getAttributeById(id);
      if (attribute != null) result.add(attribute);
    }
    return result;
  }

  /// Create the given attributes and their starter values if they don't exist.
  ///
  /// [names] defaults to [kBaseAttributeNames]. Retail passes its store type's
  /// defaults instead (see `SimpleProductFieldsService.defaultFieldNames`) —
  /// this method stays store-type-agnostic and only seeds what it is told to.
  ///
  /// Idempotent and non-destructive: [addAttribute] returns false for a name
  /// that already exists, so values are only seeded alongside a freshly created
  /// attribute and a user's edits are never overwritten. Passing an empty list
  /// is valid and seeds nothing.
  ///
  /// New attributes are given an increasing [AttributeModel.sortOrder] starting
  /// after the highest already in use, so they list in the order [names]
  /// declares them (Size before Pattern) instead of the arbitrary order a
  /// shared `sortOrder: 0` produces, and so a later seed appends rather than
  /// interleaving with what is already there.
  @action
  Future<void> ensureBaseAttributes({List<String>? names}) async {
    // Read the box, not the `attributes` observable: callers seed BEFORE
    // loadAttributes(), so on a cold start the observable is still empty while
    // the box already holds the shop's attributes.
    final existing = await _repository.getAllAttributes();
    var sortOrder = existing.isEmpty
        ? 0
        : existing.map((a) => a.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    for (final name in names ?? kBaseAttributeNames) {
      final created = await addAttribute(name, sortOrder: sortOrder);
      if (!created) continue; // already present — leave the user's edits alone
      sortOrder++;

      final attribute = getAttributeByName(name);
      if (attribute == null) continue;

      final values = kSeedAttributeValues[name];
      if (values == null || values.isEmpty) continue; // created, values are the user's to add

      await addMultipleValues(
        attribute.attributeId,
        values,
        colorCodes: kSeedAttributeColorCodes[name],
      );
    }
  }

  // ==================== CANONICAL DESCRIPTORS ====================

  /// A variant's descriptors as `{attributeName: value}`.
  ///
  /// Precedence, richest source first:
  ///   1. `attributeValueIds` — the real attribute system
  ///   2. `customAttributes` — free-text pairs
  ///   3. legacy `size` / `color` / `weight` columns
  ///
  /// Later sources never overwrite an earlier one, so a variant carrying both
  /// keeps the authoritative value.
  ///
  /// Use this for CATALOGUE display and when populating a cart line. Do NOT use
  /// it to render a completed sale — read that sale's own stored map instead,
  /// or editing a variant would rewrite history.
  Map<String, String> attributesOf(VarianteModel variant) {
    final result = <String, String>{};

    final valueIds = variant.attributeValueIds;
    if (valueIds != null) {
      for (final entry in valueIds.entries) {
        final attribute = getAttributeById(entry.key);
        final value = getValueById(entry.value);
        if (attribute != null && value != null) {
          result[attribute.name] = value.value;
        }
      }
    }

    variant.customAttributes?.forEach((key, value) {
      if (key.trim().isEmpty || value.trim().isEmpty) return;
      result.putIfAbsent(key, () => value);
    });


    // addLegacy('Size', variant.size);
    // addLegacy('Color', variant.color);
    // addLegacy('Weight', variant.weight);

    return result;
  }

  /// Human-readable descriptor for a stored attribute map, falling back to the
  /// legacy columns for records saved before generic attributes existed.
  ///
  /// [labelled] true → `Size: L · Color: Red`; false → `L · Red`.
  /// Returns an empty string when there is nothing to show, so callers can
  /// decide whether to render a line at all.
  ///
  /// Thin delegate to [describeAttributeMap] — the logic reads nothing off this
  /// store, and **code that can run in restaurant mode must call the top-level
  /// function instead**, because `AttributeStore` is only registered for
  /// retail. See that function's doc.
  String describeAttributes(
    Map<String, String>? attributes, {
    String? size,
    String? color,
    String? weight,
    bool labelled = true,
    String separator = ' · ',
  }) =>
      describeAttributeMap(
        attributes,
        size: size,
        color: color,
        weight: weight,
        labelled: labelled,
        separator: separator,
      );

  /// Case-insensitive lookup by name.
  AttributeModel? getAttributeByName(String name) {
    final lower = name.toLowerCase();
    for (final attribute in attributes) {
      if (attribute.name.toLowerCase() == lower) return attribute;
    }
    return null;
  }
}