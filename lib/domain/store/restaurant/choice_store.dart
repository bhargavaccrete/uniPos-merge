import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../data/models/restaurant/db/choiceoptionmodel_307.dart';
import '../../../data/repositories/restaurant/choice_repository.dart';

part 'choice_store.g.dart';

class ChoiceStore = _ChoiceStore with _$ChoiceStore;

abstract class _ChoiceStore with Store {
  final ChoiceRepository _repository;

  _ChoiceStore(this._repository);

  @observable
  ObservableList<ChoicesModel> choices = ObservableList<ChoicesModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  // Computed properties
  @computed
  List<ChoicesModel> get filteredChoices {
    if (searchQuery.isEmpty) return choices;
    final lowercaseQuery = searchQuery.toLowerCase();
    return choices
        .where((choice) => choice.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  @computed
  int get totalChoices => choices.length;

  // Actions
  @action
  Future<void> loadChoices() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedChoices = await _repository.getAllChoices();
      choices = ObservableList.of(loadedChoices);
    } catch (e) {
      errorMessage = 'Failed to load choices: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadChoices();
  }

  @action
  Future<bool> addChoice(ChoicesModel choice) async {
    try {
      await _repository.addChoice(choice);
      choices.add(choice);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add choice: $e';
      return false;
    }
  }

  @action
  Future<ChoicesModel?> getChoiceById(String id) async {
    try {
      return await _repository.getChoiceById(id);
    } catch (e) {
      errorMessage = 'Failed to get choice: $e';
      return null;
    }
  }

  @action
  Future<bool> updateChoice(ChoicesModel updatedChoice) async {
    try {
      await _repository.updateChoice(updatedChoice);
      final index = choices.indexWhere((c) => c.id == updatedChoice.id);
      if (index != -1) {
        choices[index] = updatedChoice;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update choice: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteChoice(String id) async {
    try {
      await _repository.deleteChoice(id);
      choices.removeWhere((c) => c.id == id);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete choice: $e';
      return false;
    }
  }

  @action
  Future<bool> addOption(String choiceId, ChoiceOption option) async {
    try {
      final result = await _repository.addOption(choiceId, option);
      if (result) {
        await loadChoices(); // Reload to reflect changes
      }
      return result;
    } catch (e) {
      errorMessage = 'Failed to add option: $e';
      return false;
    }
  }

  @action
  Future<bool> removeOption(String choiceId, int optionIndex) async {
    try {
      final result = await _repository.removeOption(choiceId, optionIndex);
      if (result) {
        await loadChoices(); // Reload to reflect changes
      }
      return result;
    } catch (e) {
      errorMessage = 'Failed to remove option: $e';
      return false;
    }
  }

  @action
  Future<bool> updateOption(
      String choiceId, int optionIndex, ChoiceOption updatedOption) async {
    try {
      final result =
          await _repository.updateOption(choiceId, optionIndex, updatedOption);
      if (result) {
        await loadChoices(); // Reload to reflect changes
      }
      return result;
    } catch (e) {
      errorMessage = 'Failed to update option: $e';
      return false;
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}