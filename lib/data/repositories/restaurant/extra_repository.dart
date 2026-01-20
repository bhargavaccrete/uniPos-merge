import 'package:hive/hive.dart';
import '../../models/restaurant/db/extramodel_303.dart';
import '../../models/restaurant/db/toppingmodel_304.dart';

/// Repository layer for Extra data access (Restaurant)
/// Handles all Hive database operations for extras and their toppings
class ExtraRepository {
  late Box<Extramodel> _extraBox;

  ExtraRepository() {
    _extraBox = Hive.box<Extramodel>('extra');
  }

  /// Add a new extra
  Future<void> addExtra(Extramodel extra) async {
    await _extraBox.put(extra.Id, extra);
  }

  /// Get all extras
  Future<List<Extramodel>> getAllExtras() async {
    return _extraBox.values.toList();
  }

  /// Get extra by ID
  Future<Extramodel?> getExtraById(String id) async {
    return _extraBox.get(id);
  }

  /// Update extra
  Future<void> updateExtra(Extramodel extra) async {
    await _extraBox.put(extra.Id, extra);
  }

  /// Delete extra
  Future<void> deleteExtra(String id) async {
    await _extraBox.delete(id);
  }

  /// Add topping to extra
  Future<bool> addTopping(String extraId, Topping topping) async {
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
      print("Error adding topping: $e");
      return false;
    }
  }

  /// Remove topping from extra
  Future<bool> removeTopping(String extraId, int toppingIndex) async {
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
      print("Error removing topping: $e");
      return false;
    }
  }

  /// Update topping in extra
  Future<bool> updateTopping(
      String extraId, int toppingIndex, Topping updatedTopping) async {
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
      print("Error updating topping: $e");
      return false;
    }
  }

  /// Search extras by name
  Future<List<Extramodel>> searchExtras(String query) async {
    if (query.isEmpty) return getAllExtras();

    final lowercaseQuery = query.toLowerCase();
    return _extraBox.values
        .where((extra) => extra.Ename.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get extra count
  Future<int> getExtraCount() async {
    return _extraBox.length;
  }
}