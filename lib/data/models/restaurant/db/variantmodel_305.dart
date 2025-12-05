import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'variantmodel_305.g.dart';



@HiveType(typeId: HiveTypeIds.restaurantVariant)
class VariantModel{
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  // --- AUDIT TRAIL FIELDS ---
  @HiveField(2)
  DateTime? createdTime;

  @HiveField(3)
  DateTime? lastEditedTime;

  @HiveField(4)
  String? editedBy;

  @HiveField(5)
  int editCount;

  VariantModel({
    required this.id,
    required this.name,
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount = 0,
});

  VariantModel copyWith({
    String? id,
    String? name,
    DateTime? createdTime,
    DateTime? lastEditedTime,
    String? editedBy,
    int? editCount,
}){
    return VariantModel(
      id: id?? this.id,
      name: name ?? this.name,
      createdTime: createdTime ?? this.createdTime,
      lastEditedTime: lastEditedTime ?? this.lastEditedTime,
      editedBy: editedBy ?? this.editedBy,
      editCount: editCount ?? this.editCount,
    );
  }

  /// Convert this object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdTime': createdTime?.toIso8601String(),
      'lastEditedTime': lastEditedTime?.toIso8601String(),
      'editedBy': editedBy,
      'editCount': editCount,
    };
  }

  /// Create an object from a Map
  factory VariantModel.fromMap(Map<String, dynamic> map) {
    return VariantModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      createdTime: map['createdTime'] != null ? DateTime.parse(map['createdTime']) : null,
      lastEditedTime: map['lastEditedTime'] != null ? DateTime.parse(map['lastEditedTime']) : null,
      editedBy: map['editedBy'],
      editCount: map['editCount'] ?? 0,
    );
  }

}