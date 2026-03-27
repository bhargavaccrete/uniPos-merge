import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'categorymodel_300.g.dart';

@HiveType(typeId : HiveTypeIds.restaurantCategory)
class Category{
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  // HiveField(2) was imagePath — removed (unused)

  // --- AUDIT TRAIL FIELDS ---
  @HiveField(3)
  DateTime? createdTime;

  @HiveField(4)
  DateTime? lastEditedTime;

  @HiveField(5)
  String? editedBy;

  @HiveField(6)
  int editCount;

  Category({
    required this.id,
    required this.name,
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount = 0,
  });


  Category copyWith({
    String? id,
    String? name,
    DateTime? createdTime,
    DateTime? lastEditedTime,
    String? editedBy,
    int? editCount,
  }){
    return Category(
      id: id?? this.id,
      name: name ?? this.name,
      createdTime: createdTime ?? this.createdTime,
      lastEditedTime: lastEditedTime ?? this.lastEditedTime,
      editedBy: editedBy ?? this.editedBy,
      editCount: editCount ?? this.editCount,
    );
  }
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      createdTime: map['createdTime'] != null ? DateTime.parse(map['createdTime']) : null,
      lastEditedTime: map['lastEditedTime'] != null ? DateTime.parse(map['lastEditedTime']) : null,
      editedBy: map['editedBy'],
      editCount: map['editCount'] ?? 0,
    );
  }

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

}