


import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/data/models/restaurant/db/expensemodel_315.dart';


class HiveExpenseCat{

  static Box<ExpenseCategory>? _box;
  static const _boxname = 'expenseCategory';


  static Future<Box<ExpenseCategory>>getECategory()async{
    if(_box == null || !_box!.isOpen){
      try{
        // Get the same encryption cipher used in main.dart
        const secureStorage = FlutterSecureStorage();
        final storedKey = await secureStorage.read(key: 'hive_key');
        if (storedKey != null) {
          final encryptionKey = base64Url.decode(storedKey);
          final cipher = HiveAesCipher(encryptionKey);
          _box = await Hive.openBox<ExpenseCategory>(_boxname, encryptionCipher: cipher);
        } else {
          _box = await Hive.openBox<ExpenseCategory>(_boxname);
        }
      }catch(e){
        print("Error Opening $_boxname Hive box: $e");
        // If there's a corruption issue, try to delete and recreate the box
        try {
          await Hive.deleteBoxFromDisk(_boxname);
          const secureStorage = FlutterSecureStorage();
          final storedKey = await secureStorage.read(key: 'hive_key');
          if (storedKey != null) {
            final encryptionKey = base64Url.decode(storedKey);
            final cipher = HiveAesCipher(encryptionKey);
            _box = await Hive.openBox<ExpenseCategory>(_boxname, encryptionCipher: cipher);
          } else {
            _box = await Hive.openBox<ExpenseCategory>(_boxname);
          }
          print("Successfully recreated $_boxname box after corruption");
        } catch (e2) {
          print("Failed to recreate box: $e2");
          rethrow;
        }
      }
    }
    if(_box == null){
      throw HiveError("Hive box '$_boxname' could not be opened");
    }
    return _box!;
  }


  static Future<void> addECategory(ExpenseCategory eCategory)async{
    final box = await getECategory();
    await box.put(eCategory.id, eCategory );
  }

  static Future<void>updateECategory(ExpenseCategory eCategory)async{
    final box = await getECategory();
    await box.put(eCategory.id, eCategory);
  }


  static Future<void>deleteECategory(String id)async{
    final box = await getECategory();
    await box.delete(id);
  }



  static Future<List<ExpenseCategory>>getAllECategory()async{
    final box = await getECategory();
    return box.values.toList();
  }





}


class HiveExpenceL{
  static Box<Expense>? _box;
  static const _boxName = 'expenseBox';


  static Future<Box<Expense>> getexpenseBox()async{
    if(_box == null || !_box!.isOpen){
      try{
        // Get the same encryption cipher used in main.dart
        const secureStorage = FlutterSecureStorage();
        final storedKey = await secureStorage.read(key: 'hive_key');
        if (storedKey != null) {
          final encryptionKey = base64Url.decode(storedKey);
          final cipher = HiveAesCipher(encryptionKey);
          _box = await Hive.openBox<Expense>(_boxName, encryptionCipher: cipher);
        } else {
          _box = await Hive.openBox<Expense>(_boxName);
        }
      }catch(e){
        print("Error opening '$_boxName' Hive Box: $e");
        // If there's a corruption issue, try to delete and recreate the box
        try {
          await Hive.deleteBoxFromDisk(_boxName);
          const secureStorage = FlutterSecureStorage();
          final storedKey = await secureStorage.read(key: 'hive_key');
          if (storedKey != null) {
            final encryptionKey = base64Url.decode(storedKey);
            final cipher = HiveAesCipher(encryptionKey);
            _box = await Hive.openBox<Expense>(_boxName, encryptionCipher: cipher);
          } else {
            _box = await Hive.openBox<Expense>(_boxName);
          }
          print("Successfully recreated $_boxName box after corruption");
        } catch (e2) {
          print("Failed to recreate box: $e2");
          rethrow;
        }
      }
    }
    return _box!;
  }


  static Future<void> addItem(Expense expense) async{
    final box = await getexpenseBox();
    await box.put(expense.id, expense); /// add without key insert the item

  }
  static Future<List<Expense>> getAllItems() async {
    final box = await getexpenseBox();
    return box.values.toList();
  }
  static Future<void> deleteItem(String id) async {
    final box = await getexpenseBox();
    await box.delete(id);
  }
  static Future<void> updateItem(Expense expense) async {
    final box = await getexpenseBox();
    await box.put(expense.id, expense);
  }

}