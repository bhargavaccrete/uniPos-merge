
import 'package:uuid/uuid.dart';

import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/attribute_value_model_220.dart';
import '../../../data/models/retail/hive_model/product_attribute_model_221.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';

/// Service for generating product variants from attribute combinations
/// Similar to WooCommerce's variant generation system
class VariantGeneratorService {
  final _uuid = const Uuid();

  /// Generate all possible variant combinations from selected attributes
  ///
  /// Takes a list of attribute assignments with their selected values
  /// and generates a Cartesian product of all combinations.
  ///
  /// Example:
  /// Input:
  /// - Color: [Red, Blue]
  /// - Size: [S, M, L]
  ///
  /// Output: 6 variants
  /// - Red-S, Red-M, Red-L, Blue-S, Blue-M, Blue-L
  List<VariantCombination> generateCombinations({
    required List<AttributeWithValues> attributesWithValues,
  }) {
    if (attributesWithValues.isEmpty) {
      return [];
    }

    // Filter only attributes used for variants with selected values
    final effectiveAttributes = attributesWithValues
        .where((a) => a.selectedValues.isNotEmpty && a.usedForVariants)
        .toList();

    if (effectiveAttributes.isEmpty) {
      return [];
    }

    // Generate Cartesian product
    List<List<AttributeValuePair>> combinations = [[]];

    for (final attrWithValues in effectiveAttributes) {
      final newCombinations = <List<AttributeValuePair>>[];

      for (final existingCombination in combinations) {
        for (final value in attrWithValues.selectedValues) {
          newCombinations.add([
            ...existingCombination,
            AttributeValuePair(
              attribute: attrWithValues.attribute,
              value: value,
            ),
          ]);
        }
      }

      combinations = newCombinations;
    }

    // Convert to VariantCombination objects
    return combinations
        .map((combo) => VariantCombination(attributeValuePairs: combo))
        .toList();
  }

  /// Generate VarianteModel instances from combinations
  ///
  /// Parameters:
  /// - [productId]: The ID of the product these variants belong to
  /// - [combinations]: List of attribute combinations
  /// - [defaultPrice]: Default selling price for all variants
  /// - [defaultMrp]: Default MRP for all variants
  /// - [defaultCostPrice]: Default cost price for all variants
  /// - [existingVariants]: Existing variants to preserve data from
  List<VarianteModel> generateVariants({
    required String productId,
    required List<VariantCombination> combinations,
    double? defaultPrice,
    double? defaultMrp,
    double? defaultCostPrice,
    int defaultStock = 0,
    List<VarianteModel>? existingVariants,
  }) {
    final variants = <VarianteModel>[];
    final now = DateTime.now().toIso8601String();

    for (var i = 0; i < combinations.length; i++) {
      final combo = combinations[i];

      // Check if a variant with this combination already exists
      final existingVariant = _findExistingVariant(
        combo,
        existingVariants ?? [],
      );

      // Build attribute value IDs map
      final attributeValueIds = <String, String>{};
      for (final pair in combo.attributeValuePairs) {
        attributeValueIds[pair.attribute.attributeId] = pair.value.valueId;
      }

      // Build custom attributes map (attribute name -> value)
      final customAttributes = <String, String>{};
      String? size, color, weight;

      for (final pair in combo.attributeValuePairs) {
        final attrName = pair.attribute.name.toLowerCase();
        final attrValue = pair.value.value;

        // Map to standard fields if applicable
        if (attrName == 'size') {
          size = attrValue;
        } else if (attrName == 'color' || attrName == 'colour') {
          color = attrValue;
        } else if (attrName == 'weight') {
          weight = attrValue;
        } else {
          // Store in custom attributes
          customAttributes[pair.attribute.name] = attrValue;
        }
      }

      // Generate variant
      final variant = VarianteModel(
        varianteId: existingVariant?.varianteId ?? _uuid.v4(),
        productId: productId,
        size: size,
        color: color,
        weight: weight,
        sku: existingVariant?.sku ?? _generateSku(productId, combo),
        barcode: existingVariant?.barcode,
        mrp: existingVariant?.mrp ?? defaultMrp,
        costPrice: existingVariant?.costPrice ?? defaultCostPrice,
        sellingPrice: existingVariant?.sellingPrice ?? defaultPrice,
        stockQty: existingVariant?.stockQty ?? defaultStock,
        minStock: existingVariant?.minStock,
        taxRate: existingVariant?.taxRate,
        hsnCode: existingVariant?.hsnCode,
        customAttributes: customAttributes.isNotEmpty ? customAttributes : null,
        attributeValueIds: attributeValueIds,
        imagePath: existingVariant?.imagePath,
        isDefault: i == 0 && existingVariant?.isDefault != true
            ? true
            : (existingVariant?.isDefault ?? false),
        status: existingVariant?.status ?? 'active',
        createdAt: existingVariant?.createdAt ?? now,
        updateAt: now,
      );

      variants.add(variant);
    }

    return variants;
  }

  /// Find an existing variant that matches the given combination
  VarianteModel? _findExistingVariant(
    VariantCombination combo,
    List<VarianteModel> existingVariants,
  ) {
    for (final variant in existingVariants) {
      if (variant.attributeValueIds == null) continue;

      // Check if all attribute values match
      bool matches = true;
      for (final pair in combo.attributeValuePairs) {
        final existingValueId = variant.attributeValueIds![pair.attribute.attributeId];
        if (existingValueId != pair.value.valueId) {
          matches = false;
          break;
        }
      }

      if (matches && combo.attributeValuePairs.length == variant.attributeValueIds!.length) {
        return variant;
      }
    }
    return null;
  }

  /// Generate a SKU from product ID and combination
  String _generateSku(String productId, VariantCombination combo) {
    final parts = <String>[productId.substring(0, 4).toUpperCase()];
    for (final pair in combo.attributeValuePairs) {
      final valueSlug = pair.value.slug.toUpperCase();
      parts.add(valueSlug.length > 3 ? valueSlug.substring(0, 3) : valueSlug);
    }
    return parts.join('-');
  }

  /// Calculate the total number of variants that would be generated
  int calculateVariantCount(List<AttributeWithValues> attributesWithValues) {
    final effective = attributesWithValues
        .where((a) => a.selectedValues.isNotEmpty && a.usedForVariants)
        .toList();

    if (effective.isEmpty) return 0;

    int count = 1;
    for (final attr in effective) {
      count *= attr.selectedValues.length;
    }
    return count;
  }

  /// Get a description of what variants will be generated
  String describeVariants(List<AttributeWithValues> attributesWithValues) {
    final effective = attributesWithValues
        .where((a) => a.selectedValues.isNotEmpty && a.usedForVariants)
        .toList();

    if (effective.isEmpty) {
      return 'No variants will be generated';
    }

    final parts = <String>[];
    for (final attr in effective) {
      parts.add('${attr.attribute.name} (${attr.selectedValues.length} values)');
    }

    final count = calculateVariantCount(attributesWithValues);
    return '${parts.join(' × ')} = $count variants';
  }
}

/// Represents an attribute with its available and selected values
class AttributeWithValues {
  final AttributeModel attribute;
  final List<AttributeValueModel> availableValues;
  final List<AttributeValueModel> selectedValues;
  final bool usedForVariants;

  AttributeWithValues({
    required this.attribute,
    required this.availableValues,
    required this.selectedValues,
    this.usedForVariants = true,
  });

  AttributeWithValues copyWith({
    AttributeModel? attribute,
    List<AttributeValueModel>? availableValues,
    List<AttributeValueModel>? selectedValues,
    bool? usedForVariants,
  }) {
    return AttributeWithValues(
      attribute: attribute ?? this.attribute,
      availableValues: availableValues ?? this.availableValues,
      selectedValues: selectedValues ?? this.selectedValues,
      usedForVariants: usedForVariants ?? this.usedForVariants,
    );
  }
}

/// Represents a single attribute-value pair
class AttributeValuePair {
  final AttributeModel attribute;
  final AttributeValueModel value;

  AttributeValuePair({
    required this.attribute,
    required this.value,
  });

  @override
  String toString() => '${attribute.name}: ${value.value}';
}

/// Represents a complete variant combination
class VariantCombination {
  final List<AttributeValuePair> attributeValuePairs;

  VariantCombination({required this.attributeValuePairs});

  /// Get a display name for this combination
  String get displayName {
    return attributeValuePairs.map((p) => p.value.value).join(' - ');
  }

  /// Get a short description
  String get shortDescription {
    return attributeValuePairs.map((p) => p.value.value).join(' • ');
  }

  /// Get a detailed description with attribute names
  String get detailedDescription {
    return attributeValuePairs
        .map((p) => '${p.attribute.name}: ${p.value.value}')
        .join(', ');
  }

  /// Get attribute value IDs map
  Map<String, String> get attributeValueIds {
    final map = <String, String>{};
    for (final pair in attributeValuePairs) {
      map[pair.attribute.attributeId] = pair.value.valueId;
    }
    return map;
  }

  @override
  String toString() => displayName;
}

/// Helper class for managing product attribute assignments during form editing
class ProductAttributeAssignment {
  String attributeId;
  List<String> selectedValueIds;
  bool usedForVariants;
  bool isVisible;

  ProductAttributeAssignment({
    required this.attributeId,
    this.selectedValueIds = const [],
    this.usedForVariants = true,
    this.isVisible = true,
  });

  /// Create from ProductAttributeModel
  factory ProductAttributeAssignment.fromModel(ProductAttributeModel model) {
    return ProductAttributeAssignment(
      attributeId: model.attributeId,
      selectedValueIds: List.from(model.selectedValueIds),
      usedForVariants: model.usedForVariants,
      isVisible: model.isVisible,
    );
  }

  /// Convert to map for saving
  Map<String, dynamic> toMap() {
    return {
      'attributeId': attributeId,
      'valueIds': selectedValueIds,
      'usedForVariants': usedForVariants,
      'isVisible': isVisible,
    };
  }
}