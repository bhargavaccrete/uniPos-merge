import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';
import 'itemvariantemodel_312.dart';
import 'product_type.dart';

part 'itemmodel_302.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantItem)
class Items extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final Uint8List? imageBytes; // Image stored as bytes for web+mobile compatibility

  @HiveField(3)
  final double? price;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final String? categoryOfItem; // category id

  @HiveField(6)
  final String? isVeg;

  @HiveField(7)
  final String? unit;

  @HiveField(8)
  final List<ItemVariante>? variant;

  @HiveField(9)
  final List<String>? choiceIds;

  @HiveField(10)
  final List<String>? extraId;

  @HiveField(11)
  double? taxRate;

  @HiveField(12)
  bool isEnabled;

  // --- IMPROVED INVENTORY FIELDS ---
  @HiveField(13)
  bool trackInventory; // RENAMED: from istrackInventory for convention

  @HiveField(14)
  double stockQuantity; // IMPROVEMENT: Made non-nullable for safety

  @HiveField(15)
  bool allowOrderWhenOutOfStock; // Allow ordering when stock is 0 or negative


  @HiveField(16)
  final bool isSoldByWeight;

  // --- AUDIT TRAIL FIELDS ---
  @HiveField(17)
  DateTime? createdTime;

  @HiveField(18)
  DateTime? lastEditedTime;

  @HiveField(19)
  String? editedBy;

  @HiveField(20)
  int editCount;

  @HiveField(21)
  Map<String, Map<String, int>>? extraConstraints; // Map of extraId to {min, max}

  @HiveField(22)
  double? lowStockThreshold; // Per-item override; null = use global default

  @HiveField(23, defaultValue: false)
  bool lowStockAlertEnabled; // Per-item opt-in for low-stock alerts (the YES/NO toggle)

  @HiveField(24, defaultValue: false)
  bool isFavorite; // Pinned to the "Favorites" tab in the POS menu

  @HiveField(25)
  String? itemCode;

  @HiveField(26)
  List<String>? defaultChoiceOptionIds; // per-item default-selected choice option IDs

  @HiveField(27)
  List<String>? taxIds; // IDs of the taxes applied; taxRate holds their summed total

  // --- RECIPE / BOM FIELDS (docs/inventory_recipe_system_plan.md) ---
  @HiveField(28)
  String? productType; // ProductType.{rawMaterial,semiFinished,finishedGood,recipeBased}; null = finishedGood

  @HiveField(29)
  String? recipeId; // links to RecipeModel; set when productType is semiFinished or recipeBased

  @HiveField(30)
  double? lastPurchaseCost; // most recent GRN unit cost — feeds recipe cost calculation

  @HiveField(31)
  bool? sellDirectlyAtPos; // null = use the per-product-type default (see sellsAtPos)

  Items({
    required this.id,
    required this.name,
    this.price,
    this.description,
    this.categoryOfItem,
    this.imageBytes, // Image bytes for cross-platform compatibility
    this.isVeg,
    this.unit,
    this.isSoldByWeight = false,
    this.variant = const [],
    this.choiceIds = const [],
    this.extraId = const [],
    this.taxRate,
    this.isEnabled = true,
    this.trackInventory = false, //
    this.stockQuantity = 0.0,
    this.allowOrderWhenOutOfStock = true, // Default: allow ordering when out of stock
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount = 0,
    this.extraConstraints,
    this.lowStockThreshold,
    this.lowStockAlertEnabled = false,
    this.isFavorite = false,
    this.itemCode,
    this.defaultChoiceOptionIds,
    this.taxIds,
    this.productType,
    this.recipeId,
    this.lastPurchaseCost,
    this.sellDirectlyAtPos,
  });

// --- ADJUSTED HELPER LOGIC ---
  bool get hasVariants => variant?.isNotEmpty ?? false;

  /// Never null — pre-existing items with no [productType] read as Finished
  /// Good, today's only behavior, so no migration is needed.
  String get effectiveProductType => ProductType.effective(productType);

  bool get isRawMaterial => effectiveProductType == ProductType.rawMaterial;
  bool get isSemiFinished => effectiveProductType == ProductType.semiFinished;
  bool get isFinishedGood => effectiveProductType == ProductType.finishedGood;
  bool get isRecipeBased => effectiveProductType == ProductType.recipeBased;

  /// True when this item has (or should have) a [RecipeModel] attached.
  bool get hasRecipe => ProductType.hasRecipe(effectiveProductType);

  /// True when this item's stock is derived from its recipe's ingredients
  /// rather than stored on `stockQuantity` — see §5/§7 of the design doc.
  bool get isStockDerivedFromRecipe =>
      ProductType.isStockDerived(effectiveProductType);

  /// Whether this item appears in the POS sale grid.
  ///
  /// Raw Materials are ingredients, not menu items, so they're hidden by
  /// default; every other product type shows, which is exactly how every
  /// pre-existing item behaved (they all read as Finished Good). The default
  /// is overridable per item via [sellDirectlyAtPos] for the rare directly
  /// sellable raw material — a canned drink bought by the case, say.
  /// See docs/inventory_recipe_system_plan.md §8.1/§9.1.
  bool get sellsAtPos => sellDirectlyAtPos ?? !isRawMaterial;

  /// NOTE: [isInStock]/[isLowStock] read the *stored* [stockQuantity], which
  /// Recipe-Based items never populate. Callers that must be correct for every
  /// product type should go through `InventoryService.effectiveAvailableStock`
  /// (or `stockStatusOf`), which resolves recipe availability from ingredients.
  /// These getters stay stock-field-based so this model has no dependency on
  /// the service locator.
  bool get isInStock {
    // For variant items, the ITEM's trackInventory governs; stock is read from
    // each variant's own quantity (a variant's own trackInventory flag is
    // unreliable — variants added later leave it null).
    if (hasVariants) {
      if (!trackInventory) return true; // not tracking → always available
      return variant!.any((v) => (v.stockQuantity ?? 0) > 0);
    }
    // If there are no variants, check the parent item.
    return !trackInventory || stockQuantity > 0;
  }

  /// Effective threshold: per-item override if set, else the global default.
  double get effectiveLowStockThreshold =>
      lowStockThreshold ?? AppSettings.lowStockThreshold;

  /// True when stock is running low. Requires: inventory tracking on, the
  /// global master switch on, this item opted-in, the item still in stock, and
  /// the level at/below the effective threshold. For variant items, low if ANY
  /// in-stock variant is at/below the threshold.
  bool get isLowStock {
    if (!trackInventory ||
        !lowStockAlertEnabled ||
        !AppSettings.lowStockAlertsEnabled) {
      return false;
    }
    final threshold = effectiveLowStockThreshold;
    if (threshold <= 0) return false;
    if (hasVariants) {
      return variant!.any((v) {
        final qty = v.stockQuantity ?? 0;
        return qty > 0 && qty <= threshold;
      });
    }
    return stockQuantity > 0 && stockQuantity <= threshold;
  }




  double get finalPrice => price ?? 0;

  double get basePrice {
    if (taxRate == null || taxRate == 0) {
      return finalPrice;
    }
    return finalPrice / (1 + taxRate!);
  }

  double get taxAmount {
    return finalPrice - basePrice;
  }

  /// Adds tax [taxId] (decimal [rate], e.g. 0.05) to this item — max 2 taxes.
  /// taxRate is kept as the SUM of the applied taxes (same as the multi-select
  /// item editor). Returns true if applied, false if skipped (already applied,
  /// or the item is already at the 2-tax limit).
  bool applyTax(String taxId, double rate) {
    final ids = List<String>.from(taxIds ?? const <String>[]);
    if (ids.contains(taxId)) return false; // already applied
    if (ids.length >= 2) return false; // cap at 2 taxes per item
    ids.add(taxId);
    taxIds = ids;
    taxRate = (taxRate ?? 0) + rate;
    save();
    return true;
  }

  /// Removes tax [taxId] (decimal [rate]) and lowers taxRate by that amount.
  void removeTax(String taxId, double rate) {
    final ids = List<String>.from(taxIds ?? const <String>[]);
    if (!ids.remove(taxId)) return; // wasn't applied
    if (ids.isEmpty) {
      taxIds = null;
      taxRate = null;
    } else {
      taxIds = ids;
      final r = (taxRate ?? 0) - rate;
      taxRate = r > 0 ? r : null;
    }
    save();
  }

  Items copyWith({
    String? id,
    String? name,
    double? price,
    String? categoryOfItem,
    String? description,
    Uint8List? imageBytes,
    String? isVeg,
    String? unit,
    bool? isSoldByWeight,
    List<ItemVariante>? variant,
    List<String>? choiceIds,
    List<String>? extraId,
    bool? isEnabled,
    double? taxRate,
    bool? trackInventory,
    double? stockQuantity,
    bool? allowOrderWhenOutOfStock,
    DateTime? createdTime,
    DateTime? lastEditedTime,
    String? editedBy,
    int? editCount,
    Map<String, Map<String, int>>? extraConstraints,
    double? lowStockThreshold,
    bool? lowStockAlertEnabled,
    bool? isFavorite,
    String? itemCode,
    List<String>? defaultChoiceOptionIds,
    List<String>? taxIds,
    String? productType,
    String? recipeId,
    double? lastPurchaseCost,
    bool? sellDirectlyAtPos,
  }) {
    return Items(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      categoryOfItem: categoryOfItem ?? this.categoryOfItem,
      imageBytes: imageBytes ?? this.imageBytes,
      description: description ?? this.description,
      isVeg: isVeg ?? this.isVeg,
      unit: unit ?? this.unit,
      isSoldByWeight: isSoldByWeight ?? this.isSoldByWeight,
      variant: variant ?? this.variant,
      choiceIds: choiceIds ?? this.choiceIds,
      extraId: extraId ?? this.extraId,
      isEnabled: isEnabled ?? this.isEnabled,
      taxRate: taxRate ?? this.taxRate,
      trackInventory: trackInventory ?? this.trackInventory,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      allowOrderWhenOutOfStock: allowOrderWhenOutOfStock ?? this.allowOrderWhenOutOfStock,
      createdTime: createdTime ?? this.createdTime,
      lastEditedTime: lastEditedTime ?? this.lastEditedTime,
      editedBy: editedBy ?? this.editedBy,
      editCount: editCount ?? this.editCount,
      extraConstraints: extraConstraints ?? this.extraConstraints,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      lowStockAlertEnabled: lowStockAlertEnabled ?? this.lowStockAlertEnabled,
      isFavorite: isFavorite ?? this.isFavorite,
      itemCode: itemCode ?? this.itemCode,
      defaultChoiceOptionIds: defaultChoiceOptionIds ?? this.defaultChoiceOptionIds,
      taxIds: taxIds ?? this.taxIds,
      productType: productType ?? this.productType,
      recipeId: recipeId ?? this.recipeId,
      lastPurchaseCost: lastPurchaseCost ?? this.lastPurchaseCost,
      sellDirectlyAtPos: sellDirectlyAtPos ?? this.sellDirectlyAtPos,
    );
  }

  /// Convert to map for export
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageBytes': imageBytes?.toList(), // Convert Uint8List to List<int> for JSON serialization
      'price': price,
      'description': description,
      'categoryOfItem': categoryOfItem,
      'isVeg': isVeg,
      'unit': unit,
      'isSoldByWeight': isSoldByWeight,
      'variant': variant?.map((v) => v.toMap()).toList(),
      'choiceIds': choiceIds,
      'extraId': extraId,
      'taxRate': taxRate,
      'isEnabled': isEnabled,
      'trackInventory': trackInventory,
      'stockQuantity': stockQuantity,
      'allowOrderWhenOutOfStock': allowOrderWhenOutOfStock,
      'createdTime': createdTime?.toIso8601String(),
      'lastEditedTime': lastEditedTime?.toIso8601String(),
      'editedBy': editedBy,
      'editCount': editCount,
      'extraConstraints': extraConstraints,
      'lowStockThreshold': lowStockThreshold,
      'lowStockAlertEnabled': lowStockAlertEnabled,
      'isFavorite': isFavorite,
      'itemCode': itemCode,
      'defaultChoiceOptionIds': defaultChoiceOptionIds,
      'taxIds': taxIds,
      'productType': productType,
      'recipeId': recipeId,
      'lastPurchaseCost': lastPurchaseCost,
      'sellDirectlyAtPos': sellDirectlyAtPos,
    };
  }

  /// Create from map for import
  factory Items.fromMap(Map<String, dynamic> map) {
    // Helper logic to safely parse the price from the map
    final priceValue = map['price'];
    double? parsedPrice;
    if (priceValue is String) {
      parsedPrice = double.tryParse(priceValue);
    } else if (priceValue is num) {
      parsedPrice = priceValue.toDouble();
    }

    // Helper function to safely parse boolean values
    bool _parseBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == 'yes' || lower == '1') return true;
        if (lower == 'false' || lower == 'no' || lower == '0') return false;
      }
      if (value is int) return value != 0;
      return defaultValue;
    }

    // 🖼️ Handle image bytes
    Uint8List? parsedImageBytes;

    // First, try to get imageBytes from map (new format)
    if (map['imageBytes'] != null) {
      if (map['imageBytes'] is Uint8List) {
        parsedImageBytes = map['imageBytes'] as Uint8List;
      } else if (map['imageBytes'] is List) {
        // Convert List<int> back to Uint8List
        parsedImageBytes = Uint8List.fromList(List<int>.from(map['imageBytes']));
      }
    }
    // Backward compatibility: if no imageBytes but imagePath exists, try to load from file
    else if (map['imagePath'] != null && map['imagePath'].toString().isNotEmpty) {
      try {
        final imagePath = map['imagePath'].toString();
        final file = File(imagePath);
        if (file.existsSync()) {
          parsedImageBytes = file.readAsBytesSync();
        }
      } catch (e) {
      }
    }

    return Items(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      imageBytes: parsedImageBytes,
      price: parsedPrice,
      description: map['description'],
      categoryOfItem: map['categoryOfItem'],
      isVeg: map['isVeg'],
      isSoldByWeight: _parseBool(map['isSoldByWeight'], false),
      unit: map['unit'],
      variant: (map['variant'] as List?)?.map((v) => ItemVariante.fromMap(v as Map<String, dynamic>)).toList(),
      choiceIds: (map['choiceIds'] as List?)?.map((e) => e.toString()).toList(),
      extraId: (map['extraId'] as List?)?.map((e) => e.toString()).toList(),
      taxRate: map['taxRate']?.toDouble(),
      isEnabled: _parseBool(map['isEnabled'], true),
      trackInventory: _parseBool(map['trackInventory'], false),
      stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      allowOrderWhenOutOfStock: _parseBool(map['allowOrderWhenOutOfStock'], true),
      createdTime: map['createdTime'] != null ? DateTime.parse(map['createdTime']) : null,
      lastEditedTime: map['lastEditedTime'] != null ? DateTime.parse(map['lastEditedTime']) : null,
      editedBy: map['editedBy'],
      editCount: map['editCount'] ?? 0,
      extraConstraints: map['extraConstraints'] != null
          ? Map<String, Map<String, int>>.from(
        (map['extraConstraints'] as Map).map(
              (key, value) => MapEntry(
            key.toString(),
            Map<String, int>.from(value as Map),
          ),
        ),
      )
          : null,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toDouble(),
      lowStockAlertEnabled: (map['lowStockAlertEnabled'] as bool?) ?? false,
      isFavorite: (map['isFavorite'] as bool?) ?? false,
      itemCode: map['itemCode']?.toString(),
      defaultChoiceOptionIds:
          (map['defaultChoiceOptionIds'] as List?)?.map((e) => e.toString()).toList(),
      taxIds: (map['taxIds'] as List?)?.map((e) => e.toString()).toList(),
      productType: map['productType'] as String?,
      recipeId: map['recipeId'] as String?,
      lastPurchaseCost: (map['lastPurchaseCost'] as num?)?.toDouble(),
      sellDirectlyAtPos: map['sellDirectlyAtPos'] as bool?,
    );
  }
}
