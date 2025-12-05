
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';
part 'choicemodel_306.g.dart';

@HiveType(typeId:HiveTypeIds.restaurantChoice)
class ChoicesModel extends HiveObject{
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
   List<ChoiceOption> choiceOption;

  // --- AUDIT TRAIL FIELDS ---
  @HiveField(3)
  DateTime? createdTime;

  @HiveField(4)
  DateTime? lastEditedTime;

  @HiveField(5)
  String? editedBy;

  @HiveField(6)
  int editCount;

  ChoicesModel({
    required this.id,
    required this.name,
     this.choiceOption= const [],
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount = 0,
  });

  ChoicesModel copyWith({
    String? id,
    String? name,
    List<ChoiceOption> ? option,
    DateTime? createdTime,
    DateTime? lastEditedTime,
    String? editedBy,
    int? editCount,
  }){
    return ChoicesModel(
        id: id?? this.id,
        name: name?? this.name,
       choiceOption:  choiceOption?? this.choiceOption,
        createdTime: createdTime ?? this.createdTime,
        lastEditedTime: lastEditedTime ?? this.lastEditedTime,
        editedBy: editedBy ?? this.editedBy,
        editCount: editCount ?? this.editCount,
    );
  }


  /// Convert to Map (for JSON export)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'choiceOption': choiceOption.map((opt) => opt.toMap()).toList(),
      'createdTime': createdTime?.toIso8601String(),
      'lastEditedTime': lastEditedTime?.toIso8601String(),
      'editedBy': editedBy,
      'editCount': editCount,
    };
  }

  /// Create from Map (for JSON import)
  factory ChoicesModel.fromMap(Map<String, dynamic> map) {
    return ChoicesModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      choiceOption: map['choiceOption'] != null
          ? List<ChoiceOption>.from(
        map['choiceOption'].map((opt) => ChoiceOption.fromMap(opt)),
      )
          : [],
      createdTime: map['createdTime'] != null ? DateTime.parse(map['createdTime']) : null,
      lastEditedTime: map['lastEditedTime'] != null ? DateTime.parse(map['lastEditedTime']) : null,
      editedBy: map['editedBy'],
      editCount: map['editCount'] ?? 0,
    );
  }
}

// option