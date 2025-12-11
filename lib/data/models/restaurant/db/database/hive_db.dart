import 'package:hive/hive.dart';

import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';

import '../itemmodel_302.dart';

class HiveBoxes {
  static Box<Category>? _box;
  static const _boxName = 'categories';

  static Future<Box<Category>> getCategory() async {
    if (_box == null || !_box!.isOpen) {
      try {
        _box = await Hive.openBox<Category>(_boxName);
      } catch (e) {
        print("Error opening '$_boxName' Hive Box: $e");
        rethrow;
      }
    }
    if(_box == null){
      throw HiveError("Hive box '$_boxName' could not be opened");
    }
    return _box!;
  }


  static Future<void> addCategory(Category category) async {
    final box = await getCategory();
    await box.put(category.id, category);
  }

  static Future<void> updateCategory(Category category) async {
    final box = await getCategory();
    await box.put(category.id, category);
  }

  static Future<void> deleteCategory(String id) async {
    // final categoryBox = await Hive.openBox<Category>('category')
    final box = await getCategory();
    await box.delete(id);

  //   Now delete items associated with this category
    final itemBox = await itemsBoxes.getItemBox();
    final itemsToDelete = itemBox.values.where((item) => item.categoryOfItem == id).toList();

for(var item in itemsToDelete){
  await item.delete();
}

  }

  static Future<List<Category>> getAllCategories() async {
    final box = await getCategory();
    return box.values.toList();
  }
}


class itemsBoxes{
  static Box<Items>? _box;
  static const _boxName = 'itemBoxs';

  static Future<Box<Items>> getItemBox() async{
    if(_box == null || !_box!.isOpen){
      try{
        _box = await Hive.openBox<Items>(_boxName);
      }catch(e){
        print("Error opening '$_boxName' Hive Box: $e");
      }
    }
    return _box!;
  }

  static Future<void> addItem(Items item) async{
    final box = await getItemBox();
    await box.put(item.id, item); /// add without key insert the item

  }
  static Future<List<Items>> getAllItems() async {
    final box = await getItemBox();
    return box.values.toList();
  }
  static Future<void> deleteItem(String id) async {
    final box = await getItemBox();
    await box.delete(id);
  }
  static Future<void> updateItem(Items items) async {
    final box = await getItemBox();
    await box.put(items.id, items);
  }
}