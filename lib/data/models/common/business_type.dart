import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'business_type.g.dart';

@HiveType(typeId: HiveTypeIds.businessType)
class BusinessType extends HiveObject {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String? iconName;

  @HiveField(4)
  final bool isSelected;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  BusinessType({
    this.id,
    this.name,
    this.description,
    this.iconName,
    this.isSelected = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  BusinessType copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    bool? isSelected,
  }) {
    return BusinessType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'isSelected': isSelected,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BusinessType.fromMap(Map<String, dynamic> map) {
    return BusinessType(
      id: map['id'] as String?,
      name: map['name'] as String?,
      description: map['description'] as String?,
      iconName: map['iconName'] as String?,
      isSelected: map['isSelected'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? ''),
    );
  }
}