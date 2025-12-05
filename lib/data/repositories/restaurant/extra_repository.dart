import 'package:hive/hive.dart';

import '../../models/restaurant/db/extramodel_303.dart';
import '../../models/restaurant/db/toppingmodel_304.dart';

/// Repository layer for Extra data access
class ExtraRepository {
  static const String _boxName = 'extra';
  late Box<Extramodel> _extraBox;

  ExtraRepository() {
    _extraBox = Hive.box<Extramodel>(_boxName);
  }

  List<Extramodel> getAllExtras() {
    return _extraBox.values.toList();
  }

  Future<void> addExtra(Extramodel extra) async {
    await _extraBox.put(extra.Id, extra);
  }

  Future<void> updateExtra(Extramodel extra) async {
    await _extraBox.put(extra.Id, extra);
  }

  Future<void> deleteExtra(String id) async {
    await _extraBox.delete(id);
  }

  Extramodel? getExtraById(String id) {
    return _extraBox.get(id);
  }

  Future<bool> addToppingToExtra(String extraId, Topping topping) async {
    try {
      final extra = _extraBox.get(extraId);
      if (extra != null) {
        final toppings = List<Topping>.from(extra.topping ?? []);
        toppings.add(topping);
        final updatedExtra = extra.copyWith(topping: toppings);
        await _extraBox.put(extraId, updatedExtra);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeToppingFromExtra(String extraId, int toppingIndex) async {
    try {
      final extra = _extraBox.get(extraId);
      if (extra != null && extra.topping != null) {
        if (toppingIndex >= 0 && toppingIndex < extra.topping!.length) {
          final toppings = List<Topping>.from(extra.topping!);
          toppings.removeAt(toppingIndex);
          final updatedExtra = extra.copyWith(topping: toppings);
          await _extraBox.put(extraId, updatedExtra);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateToppingInExtra(String extraId, int toppingIndex, Topping updatedTopping) async {
    try {
      final extra = _extraBox.get(extraId);
      if (extra != null && extra.topping != null) {
        if (toppingIndex >= 0 && toppingIndex < extra.topping!.length) {
          final toppings = List<Topping>.from(extra.topping!);
          toppings[toppingIndex] = updatedTopping;
          final updatedExtra = extra.copyWith(topping: toppings);
          await _extraBox.put(extraId, updatedExtra);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  int getExtraCount() {
    return _extraBox.length;
  }

  Future<void> clearAll() async {
    await _extraBox.clear();
  }
}