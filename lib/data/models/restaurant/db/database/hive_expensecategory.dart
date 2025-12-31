


import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/data/models/restaurant/db/expensemodel_315.dart';


class HiveExpenseCat{

  static Box<ExpenseCategory>? _box;

  /// Get the correct box name based on business mode
  static String get _boxname => AppConfig.isRetail ? 'expenseCategory' : 'restaurant_expenseCategory';


  static Box<ExpenseCategory> getECategory(){
    final boxName = _boxname;

    // Box is already opened during app startup in HiveInit
    if(_box == null || !_box!.isOpen){
      if (!Hive.isBoxOpen(boxName)) {
        throw Exception('ExpenseCategory box ($boxName) not initialized. Please ensure Hive boxes were opened during app startup.');
      }
      _box = Hive.box<ExpenseCategory>(boxName);
    }
    return _box!;
  }


  static Future<void> addECategory(ExpenseCategory eCategory)async{
    final box = getECategory();
    await box.put(eCategory.id, eCategory );
  }

  static Future<void>updateECategory(ExpenseCategory eCategory)async{
    final box = getECategory();
    await box.put(eCategory.id, eCategory);
  }


  static Future<void>deleteECategory(String id)async{
    final box = getECategory();
    await box.delete(id);
  }



  static Future<List<ExpenseCategory>>getAllECategory()async{
    final box = getECategory();
    return box.values.toList();
  }





}


class HiveExpenceL{
  static Box<Expense>? _box;

  /// Get the correct box name based on business mode
  static String get _boxName => AppConfig.isRetail ? 'expenseBox' : 'restaurant_expenseBox';


  static Box<Expense> getexpenseBox(){
    final boxName = _boxName;

    // Box is already opened during app startup in HiveInit
    if(_box == null || !_box!.isOpen){
      if (!Hive.isBoxOpen(boxName)) {
        throw Exception('Expense box ($boxName) not initialized. Please ensure Hive boxes were opened during app startup.');
      }
      _box = Hive.box<Expense>(boxName);
    }
    return _box!;
  }


  static Future<void> addItem(Expense expense) async{
    final box = getexpenseBox();
    await box.put(expense.id, expense); /// add without key insert the item

  }
  static Future<List<Expense>> getAllItems() async {
    final box = getexpenseBox();
    return box.values.toList();
  }
  static Future<void> deleteItem(String id) async {
    final box = getexpenseBox();
    await box.delete(id);
  }
  static Future<void> updateItem(Expense expense) async {
    final box = getexpenseBox();
    await box.put(expense.id, expense);
  }

}