// import 'package:BillBerry/model/db/variantmodel_305.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:hive/hive.dart';
part 'toppingmodel_304.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantTopping)
class Topping extends HiveObject{
  @HiveField(0)
  String name;

  @HiveField(1)
  bool isveg;

  @HiveField(2)
  double price;

  @HiveField(3)
  bool? isContainSize;

  @HiveField(4)
  List<VariantModel>? variantion;

  @HiveField(5)
  Map<String, double>? variantPrices;

  // --- AUDIT TRAIL FIELDS ---
  @HiveField(6)
  DateTime? createdTime;

  @HiveField(7)
  DateTime? lastEditedTime;

  @HiveField(8)
  String? editedBy;

  @HiveField(9)
  int editCount;

  Topping({
    required this.name,
    required this.isveg,
    required this.price,
    this.isContainSize,
    this.variantion,
    this.variantPrices,
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount = 0,
  });


  Topping copyWith({
    String? name,
    bool? isveg ,
    double? price,
    bool? isContainSize,
    List<VariantModel>? variantion,
    Map<String, double>? variantPrices,
    DateTime? createdTime,
    DateTime? lastEditedTime,
    String? editedBy,
    int? editCount,
  }){
    return Topping(
      name: name?? this.name,
      isveg: isveg?? this.isveg,
      price: price ?? this.price,
      isContainSize: isContainSize ?? this.isContainSize,
      variantion: variantion ?? this.variantion,
      variantPrices: variantPrices ?? this.variantPrices,
      createdTime: createdTime ?? this.createdTime,
      lastEditedTime: lastEditedTime ?? this.lastEditedTime,
      editedBy: editedBy ?? this.editedBy,
      editCount: editCount ?? this.editCount,
    );
  }

  /// Convert Topping to Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isveg': isveg,
      'price': price,
      'isContainSize':isContainSize,
      'variantion':variantion,
      'variantPrices': variantPrices,
      'createdTime': createdTime?.toIso8601String(),
      'lastEditedTime': lastEditedTime?.toIso8601String(),
      'editedBy': editedBy,
      'editCount': editCount,
    };
  }

  /// Create Topping from Map
  factory Topping.fromMap(Map<String, dynamic> map) {
    return Topping(
      name: map['name'] as String,
      isveg: map['isveg'] as bool,
      // price: map['price'] as String,
      price: map['price'] is String? double.parse(map['price']):map['price'],
      isContainSize: map['isContainSize'] as bool?,
      variantion: map['variantion'] as List<VariantModel>?,
      variantPrices: map['variantPrices'] != null
          ? Map<String, double>.from(map['variantPrices'])
          : null,
      createdTime: map['createdTime'] != null ? DateTime.parse(map['createdTime']) : null,
      lastEditedTime: map['lastEditedTime'] != null ? DateTime.parse(map['lastEditedTime']) : null,
      editedBy: map['editedBy'],
      editCount: map['editCount'] ?? 0,
    );
  }

  /// Get price for a specific variant
  double getPriceForVariant(String? variantId) {
    if (variantId != null && variantPrices != null && variantPrices!.containsKey(variantId)) {
      return variantPrices![variantId]!;
    }
    return price;
  }
}


