import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../data/models/restaurant/db/choiceoptionmodel_307.dart';
import '../../../data/repositories/restaurant/choice_repository.dart';

part 'choice_store.g.dart';

class ChoiceStore = _ChoiceStore with _$ChoiceStore;

abstract class _ChoiceStore with Store {
  final ChoiceRepository _choiceRepository = locator<ChoiceRepository>();

  final ObservableList<ChoicesModel> choices = ObservableList<ChoicesModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  _ChoiceStore() {
    _init();
  }

  Future<void> _init() async {
    await loadChoices();
  }

  @computed
  int get choiceCount => choices.length;

  @action
  Future<void> loadChoices() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = _choiceRepository.getAllChoices();
      choices.clear();
      choices.addAll(loaded);
    } catch (e) {
      errorMessage = 'Failed to load choices: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addChoice(ChoicesModel choice) async {
    try {
      await _choiceRepository.addChoice(choice);
      choices.add(choice);
    } catch (e) {
      errorMessage = 'Failed to add choice: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateChoice(ChoicesModel choice) async {
    try {
      await _choiceRepository.updateChoice(choice);
      final index = choices.indexWhere((c) => c.id == choice.id);
      if (index != -1) {
        choices[index] = choice;
      }
    } catch (e) {
      errorMessage = 'Failed to update choice: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteChoice(String id) async {
    try {
      await _choiceRepository.deleteChoice(id);
      choices.removeWhere((choice) => choice.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete choice: $e';
      rethrow;
    }
  }

  @action
  Future<void> addOption(String choiceId, ChoiceOption option) async {
    try {
      await _choiceRepository.addOption(choiceId, option);
      await loadChoices(); // Reload to get updated data
    } catch (e) {
      errorMessage = 'Failed to add option: $e';
      rethrow;
    }
  }

  @action
  Future<void> removeOption(String choiceId, int optionIndex) async {
    try {
      await _choiceRepository.removeOption(choiceId, optionIndex);
      await loadChoices(); // Reload to get updated data
    } catch (e) {
      errorMessage = 'Failed to remove option: $e';
      rethrow;
    }
  }

  ChoicesModel? getChoiceById(String id) {
    try {
      return choices.firstWhere((choice) => choice.id == id);
    } catch (e) {
      return null;
    }
  }
}