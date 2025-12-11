
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';

class HiveExtra {
  static Box<Extramodel>? _box;
  static const _boxName = 'extra';

  static Future<Box<Extramodel>> getextra() async {
    if (_box == null || !_box!.isOpen) {
      try {
        _box = await Hive.openBox<Extramodel>(_boxName);
      } catch (e) {
        print("Error opening '$_boxName' Hive Box: $e");
        rethrow; // Re-throw so UI can handle the error
      }
    }
    return _box!;
  }

  static Future<void> addextra(Extramodel extraModel) async {
    final box = await getextra();
    await box.put(extraModel.Id, extraModel);
  }

  static Future<void> updateExtra(Extramodel extraModel) async {
    final box = await getextra();
    await box.put(extraModel.Id, extraModel);
  }

  static Future<void> deleteExtra(Extramodel extraModel) async {
    final box = await getextra();
    await box.delete(extraModel.Id);
  }

  static Future<List<Extramodel>> getAllExtra() async {
    final box = await getextra();
    return box.values.toList();
  }

  // Fixed method - uses proper copyWith approach
  static Future<bool> addToppingToExtra(String extraId, Topping topping) async {
    try {
      final box = await getextra();
      final extra = box.get(extraId);

      if (extra != null) {
        // Create new list with the added topping
        final toppings = List<Topping>.from(extra.topping ?? []);
        toppings.add(topping);

        // Create updated extra with new toppings
        final updatedExtra = extra.copyWith(topping: toppings);
        await box.put(extraId, updatedExtra);
        return true;
      }
      return false;
    } catch (e) {
      print("Error adding topping: $e");
      return false;
    }
  }

  // Fixed method - uses proper copyWith approach
  static Future<bool> removeToppingFromExtra(String extraId, int toppingIndex) async {
    try {
      final box = await getextra();
      final extra = box.get(extraId);

      if (extra != null && extra.topping != null) {
        if (toppingIndex >= 0 && toppingIndex < extra.topping!.length) {
          // Create new list without the removed topping
          final toppings = List<Topping>.from(extra.topping!);
          toppings.removeAt(toppingIndex);

          // Create updated extra with modified toppings
          final updatedExtra = extra.copyWith(topping: toppings);
          await box.put(extraId, updatedExtra);
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error removing topping: $e");
      return false;
    }
  }

  // New method needed by the optimized UI
  static Future<bool> updateToppingInExtra(String extraId, int toppingIndex, Topping updatedTopping) async {
    try {
      final box = await getextra();
      final extra = box.get(extraId);

      if (extra != null && extra.topping != null) {
        if (toppingIndex >= 0 && toppingIndex < extra.topping!.length) {
          // Create new list with updated topping
          final toppings = List<Topping>.from(extra.topping!);
          toppings[toppingIndex] = updatedTopping;

          // Create updated extra with modified toppings
          final updatedExtra = extra.copyWith(topping: toppings);
          await box.put(extraId, updatedExtra);
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error updating topping: $e");
      return false;
    }
  }
}