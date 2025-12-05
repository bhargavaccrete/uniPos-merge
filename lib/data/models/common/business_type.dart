import 'package:hive/hive.dart';

part 'business_type.g.dart';

@HiveType(typeId: 101)
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
}