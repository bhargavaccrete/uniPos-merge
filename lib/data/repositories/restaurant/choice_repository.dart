import 'package:hive/hive.dart';
import '../../models/restaurant/db/choicemodel_306.dart';
import '../../models/restaurant/db/choiceoptionmodel_307.dart';

/// Repository layer for Choice data access (Restaurant)
/// Handles all Hive database operations for choices and their options
class ChoiceRepository {
  late Box<ChoicesModel> _choiceBox;

  ChoiceRepository() {
    _choiceBox = Hive.box<ChoicesModel>('choice');
  }

  /// Add a new choice
  Future<void> addChoice(ChoicesModel choice) async {
    await _choiceBox.put(choice.id, choice);
  }

  /// Get all choices
  Future<List<ChoicesModel>> getAllChoices() async {
    return _choiceBox.values.toList();
  }

  /// Get choice by ID
  Future<ChoicesModel?> getChoiceById(String id) async {
    return _choiceBox.get(id);
  }

  /// Update choice
  Future<void> updateChoice(ChoicesModel choice) async {
    await _choiceBox.put(choice.id, choice);
  }

  /// Delete choice
  Future<void> deleteChoice(String id) async {
    await _choiceBox.delete(id);
  }

  /// Add option to choice
  Future<bool> addOption(String choiceId, ChoiceOption option) async {
    try {
      final choice = _choiceBox.get(choiceId);
      if (choice != null) {
        final updateList = [...choice.choiceOption, option];
        final updatedChoice = choice.copyWith(option: updateList);
        await _choiceBox.put(choice.id, updatedChoice);
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding option: $e');
      return false;
    }
  }

  /// Remove option from choice
  Future<bool> removeOption(String choiceId, int optionIndex) async {
    try {
      final choice = _choiceBox.get(choiceId);
      if (choice != null && optionIndex < choice.choiceOption.length) {
        final updatedList = [...choice.choiceOption]..removeAt(optionIndex);
        final updatedChoice = choice.copyWith(option: updatedList);
        await _choiceBox.put(choice.id, updatedChoice);
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing option: $e');
      return false;
    }
  }

  /// Update option in choice
  Future<bool> updateOption(
      String choiceId, int optionIndex, ChoiceOption updatedOption) async {
    try {
      final choice = _choiceBox.get(choiceId);
      if (choice != null && optionIndex < choice.choiceOption.length) {
        final updatedList = [...choice.choiceOption];
        updatedList[optionIndex] = updatedOption;
        final updatedChoice = choice.copyWith(option: updatedList);
        await _choiceBox.put(choice.id, updatedChoice);
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating option: $e');
      return false;
    }
  }

  /// Search choices by name
  Future<List<ChoicesModel>> searchChoices(String query) async {
    if (query.isEmpty) return getAllChoices();

    final lowercaseQuery = query.toLowerCase();
    return _choiceBox.values
        .where((choice) => choice.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get choice count
  Future<int> getChoiceCount() async {
    return _choiceBox.length;
  }
}