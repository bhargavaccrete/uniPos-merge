import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'expensemodel_315.g.dart';


@HiveType(typeId:HiveTypeIds.restaurantExpense)

class ExpenseCategory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  bool isEnabled;


  ExpenseCategory({
    required this.id,
    required this.name,
    this.isEnabled = true,
  });


  ExpenseCategory copyWith({
    String? id,
    String? name,
    bool? isEnabled
  }) {
    return ExpenseCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        isEnabled: isEnabled ?? this.isEnabled
    );
  }


  factory ExpenseCategory.fromMap(Map<String, dynamic>map){
    return ExpenseCategory(
      id: map['id'],
      name: map['name'],
      isEnabled: map['isEnabled'],

    );
  }

  Map<String, dynamic> toMap(){
    return{
      'id':id,
      'name':name,
      'isEnabled': isEnabled,
    };
  }


}