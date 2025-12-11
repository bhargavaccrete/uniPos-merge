
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
part 'extramodel_303.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantExtra)
class Extramodel extends HiveObject{

  @HiveField(0)
  final String Id;
  @HiveField(1)
  final String Ename;

  @HiveField(2)
  bool? isEnabled;

  @HiveField(3)
  List<Topping>? topping;

  // --- AUDIT TRAIL FIELDS ---
  @HiveField(4)
  DateTime? createdTime;

  @HiveField(5)
  DateTime? lastEditedTime;

  @HiveField(6)
  String? editedBy;

  @HiveField(7)
  int editCount;

  @HiveField(8)
  int? minimum;

  @HiveField(9)
  int? maximum;

  Extramodel({
    required this.Id,
    required this.Ename,
    this.isEnabled= true,
    this.topping = const [],
    this.createdTime,
    this.lastEditedTime,
    this.editedBy,
    this.editCount = 0,
    this.minimum,
    this.maximum,
  });


  Extramodel copyWith({
    String? id,
    String ? name,
    List<Topping> ? topping,
    DateTime? createdTime,
    DateTime? lastEditedTime,
    String? editedBy,
    int? editCount,
    int? minimum,
    int? maximum,
  }){
    return Extramodel(
      Id: id?? this.Id,
      Ename: name ?? this.Ename,
      isEnabled: isEnabled ?? this.isEnabled,
      topping: topping?? this.topping,
      createdTime: createdTime ?? this.createdTime,
      lastEditedTime: lastEditedTime ?? this.lastEditedTime,
      editedBy: editedBy ?? this.editedBy,
      editCount: editCount ?? this.editCount,
      minimum: minimum ?? this.minimum,
      maximum: maximum ?? this.maximum,
    );
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'Id': Id,
      'Ename': Ename,
      'isEnabled': isEnabled,
      'topping': topping?.map((t) => t.toMap()).toList(),
      'createdTime': createdTime?.toIso8601String(),
      'lastEditedTime': lastEditedTime?.toIso8601String(),
      'editedBy': editedBy,
      'editCount': editCount,
      'minimum': minimum,
      'maximum': maximum,
    };
  }

  /// Create from Map
  factory Extramodel.fromMap(Map<String, dynamic> map) {
    return Extramodel(
      Id: map['Id'] as String,
      Ename: map['Ename'] as String,
      isEnabled: map['isEnabled'] as bool?,
      topping: (map['topping'] as List<dynamic>?)
          ?.map((t) => Topping.fromMap(t as Map<String, dynamic>))
          .toList(),
      createdTime: map['createdTime'] != null ? DateTime.parse(map['createdTime']) : null,
      lastEditedTime: map['lastEditedTime'] != null ? DateTime.parse(map['lastEditedTime']) : null,
      editedBy: map['editedBy'],
      editCount: map['editCount'] ?? 0,
      minimum: map['minimum'] as int?,
      maximum: map['maximum'] as int?,
    );
  }
}