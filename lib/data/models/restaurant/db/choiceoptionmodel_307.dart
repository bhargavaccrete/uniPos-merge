// choiceoptionmodel_307.dart
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'choiceoptionmodel_307.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantChoiceOption)
class ChoiceOption extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  ChoiceOption({
    required this.id,
    required this.name,
  });

  ChoiceOption copyWith({
    String? id,
    String? name,
  }) {
    return ChoiceOption(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  /// Convert object to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  /// Create object from Map
  factory ChoiceOption.fromMap(Map<String, dynamic> map) {
    return ChoiceOption(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

}