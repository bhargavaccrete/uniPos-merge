import 'package:hive/hive.dart';
part 'itemvariantemodel_312.g.dart';

@HiveType(typeId: 312)
class ItemVariante extends HiveObject {
  @HiveField(0)
  final String variantId;

  @HiveField(1)
  final double price;

  @HiveField(2)
  bool?trackInventory;

  @HiveField(3)
  double? stockQuantity;

  ItemVariante({
    required this.variantId,
    required this.price,
    this.trackInventory,
    this.stockQuantity
  });


  // --- ADD THIS GETTER ---
  bool get isInStock => !(trackInventory ?? false) || (stockQuantity ?? 0) > 0;

  void updateStock(double quantityChange) {
    if (trackInventory == true) {
      stockQuantity = (stockQuantity ?? 0) + quantityChange;
      save();
    }
  }


  // Convert from Map to ItemVariante
  factory ItemVariante.fromMap(Map<String, dynamic> map) {
    // Helper function to safely parse boolean values
    bool? _parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == 'yes' || lower == '1') return true;
        if (lower == 'false' || lower == 'no' || lower == '0') return false;
      }
      if (value is int) return value != 0;
      return null;
    }

    return ItemVariante(
      variantId: map['variantId'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      trackInventory: _parseBool(map['trackInventory']),
      stockQuantity: (map['stockQuantity']as num?)?.toDouble()  ??  0.0,
    );
  }

  // Convert ItemVariante to Map
  Map<String, dynamic> toMap() {
    return {
      'variantId': variantId,
      'price': price,
      'trackInventory':trackInventory,
      'stockQuantity': stockQuantity,
    };
  }
}
