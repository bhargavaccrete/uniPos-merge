


import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'taxmodel_314.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantTax)
class Tax extends HiveObject{

  @HiveField(0)
  String id;

  @HiveField(1)
  String taxname;

  @HiveField(2)
  double? taxperecentage;


  Tax({
    required this.id,
    required this.taxname,
    this.taxperecentage
  });


  Tax copyWith({
    String? id,
    String? taxname,
    double? taxperecentage
  }){
    return Tax(
        id: id ?? this.id,
        taxname: taxname ?? this.taxname,
        taxperecentage: taxperecentage ?? this.taxperecentage);
  }

  // Convert to Map for export
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taxname': taxname,
      'taxperecentage': taxperecentage,
    };
  }

  // Create from Map for import
  factory Tax.fromMap(Map<String, dynamic> map) {
    return Tax(
      id: map['id'] ?? '',
      taxname: map['taxname'] ?? '',
      taxperecentage: map['taxperecentage']?.toDouble(),
    );
  }

}



