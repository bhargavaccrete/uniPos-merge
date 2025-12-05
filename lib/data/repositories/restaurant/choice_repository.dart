import 'package:hive/hive.dart';

import '../../models/restaurant/db/choicemodel_306.dart';
import '../../models/restaurant/db/choiceoptionmodel_307.dart';

/// Repository layer for Choice data access
class ChoiceRepository {
  static const String _boxName = 'choice';
  late Box<ChoicesModel> _choiceBox;

  ChoiceRepository() {
    _choiceBox = Hive.box<ChoicesModel>(_boxName);
  }

  List<ChoicesModel> getAllChoices() {
    return _choiceBox.values.toList();
  }

  Future<void> addChoice(ChoicesModel choice) async {
    await _choiceBox.put(choice.id, choice);
  }

  Future<void> updateChoice(ChoicesModel choice) async {
    await _choiceBox.put(choice.id, choice);
  }

  Future<void> deleteChoice(String id) async {
    await _choiceBox.delete(id);
  }

  ChoicesModel? getChoiceById(String id) {
    return _choiceBox.get(id);
  }

  Future<void> addOption(String choiceId, ChoiceOption option) async {
    final choice = _choiceBox.get(choiceId);
    if (choice != null) {
      final updatedList = [...choice.choiceOption, option];
      final updatedChoice = choice.copyWith(option: updatedList);
      await _choiceBox.put(choice.id, updatedChoice);
    }
  }

  Future<void> removeOption(String choiceId, int optionIndex) async {
    final choice = _choiceBox.get(choiceId);
    if (choice != null && optionIndex < choice.choiceOption.length) {
      final updatedList = [...choice.choiceOption]..removeAt(optionIndex);
      final updatedChoice = choice.copyWith(option: updatedList);
      await _choiceBox.put(choice.id, updatedChoice);
    }
  }

  int getChoiceCount() {
    return _choiceBox.length;
  }

  Future<void> clearAll() async {
    await _choiceBox.clear();
  }
}