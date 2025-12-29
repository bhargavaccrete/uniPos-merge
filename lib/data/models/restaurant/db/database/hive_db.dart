import 'package:hive/hive.dart';

import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';

import '../itemmodel_302.dart';

class HiveBoxes {
  static const _boxName = 'categories';

  /// Get the category box (already opened in main.dart)
  static Box<Category> getCategory() {
    return Hive.box<Category>(_boxName);
  }

  static Future<void> addCategory(Category category) async {
    final box = getCategory();
    await box.put(category.id, category);
  }

  static Future<void> updateCategory(Category category) async {
    final box = getCategory();
    await box.put(category.id, category);
  }

  static Future<void> deleteCategory(String id) async {
    final box = getCategory();
    await box.delete(id);

    // Now delete items associated with this category
    final itemBox = itemsBoxes.getItemBox();
    final itemsToDelete = itemBox.values.where((item) => item.categoryOfItem == id).toList();

    for (var item in itemsToDelete) {
      await item.delete();
    }
  }

  static Future<List<Category>> getAllCategories() async {
    final box = getCategory();
    return box.values.toList();
  }
}


class itemsBoxes{
  static const _boxName = 'itemBoxs';

  /// Get the items box (already opened in main.dart)
  static Box<Items> getItemBox() {
    return Hive.box<Items>(_boxName);
  }

  static Future<void> addItem(Items item) async {
    final box = getItemBox();
    await box.put(item.id, item);
  }

  static Future<List<Items>> getAllItems() async {
    final box = getItemBox();
    return box.values.toList();
  }

  static Future<void> deleteItem(String id) async {
    final box = getItemBox();
    await box.delete(id);
  }

  static Future<void> updateItem(Items items) async {
    final box = getItemBox();
    await box.put(items.id, items);
  }
}