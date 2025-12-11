

import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';

class HiveChoice{
  static Box<ChoicesModel> ?_box;
  static const _boxName = 'choice';

  static Future <Box<ChoicesModel>> getchoice () async {
    if(_box == null || !_box!.isOpen){
      try{
        _box = await Hive.openBox<ChoicesModel>(_boxName);
      }catch(e){
        print("Error Opening '$_boxName' Hive Box: $e");
      }
    }
    return _box!;
  }

  static Future<void> addChoice(ChoicesModel choicemodel) async{
    final box = await getchoice();
    await box.put(choicemodel.id, choicemodel);
  }
  static Future<void> updateChoice(ChoicesModel choicemodel) async{
    final box = await getchoice();
    await box.put(choicemodel.id, choicemodel);
  }
  static Future<void> deleteChoice(ChoicesModel choicemodel) async{
    final box = await getchoice();
    await box.delete(choicemodel.id);
  }

  static Future<List<ChoicesModel>> getAllChoice ()async{
    final box = await getchoice();
    return box.values.toList();
  }


  static Future<void> addOption(String optionId, ChoiceOption choicemodel)async{
    final box = await getchoice();
    final option = box.get(optionId);
    if(option != null){
     final updateList = [...option.choiceOption, choicemodel];
     final updatedChoice = option.copyWith(option: updateList);
     await box.put(option.id, updatedChoice);
      // await option.save();
    }
  }

  static Future<void> removeOption(String optionId, int optionIndex) async {
    final box = await getchoice();
    final choice = box.get(optionId);

    if (choice != null && optionIndex < choice.choiceOption.length) {
      final updatedList = [...choice.choiceOption]..removeAt(optionIndex);
      final updatedChoice = choice.copyWith(option: updatedList);
      await box.put(choice.id, updatedChoice);
    }
  }



}