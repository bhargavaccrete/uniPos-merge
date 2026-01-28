

import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';

class HiveChoice{
  static const _boxName = 'choice';

  /// Get the choice box (already opened in main.dart)
  static Box<ChoicesModel> getchoice() {
    return Hive.box<ChoicesModel>(_boxName);
  }

  static Future<void> addChoice(ChoicesModel choicemodel) async {
    final box = getchoice();
    await box.put(choicemodel.id, choicemodel);
  }

  static Future<void> updateChoice(ChoicesModel choicemodel) async {
    final box = getchoice();
    await box.put(choicemodel.id, choicemodel);
  }

  static Future<void> deleteChoice(ChoicesModel choicemodel) async {
    final box = getchoice();
    await box.delete(choicemodel.id);
  }

  static Future<List<ChoicesModel>> getAllChoice() async {
    final box = getchoice();
    return box.values.toList();
  }

  static Future<void> addOption(String optionId, ChoiceOption choicemodel) async {
    final box = getchoice();
    final option = box.get(optionId);
    if (option != null) {
      final updateList = [...option.choiceOption, choicemodel];
      final updatedChoice = option.copyWith(option: updateList);
      await box.put(option.id, updatedChoice);
    }
  }

  static Future<void> removeOption(String optionId, int optionIndex) async {
    final box = getchoice();
    final choice = box.get(optionId);

    if (choice != null && optionIndex < choice.choiceOption.length) {
      final updatedList = [...choice.choiceOption]..removeAt(optionIndex);
      final updatedChoice = choice.copyWith(option: updatedList);
      await box.put(choice.id, updatedChoice);
    }
  }
}
