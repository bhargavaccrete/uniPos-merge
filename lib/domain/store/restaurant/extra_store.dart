import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../data/models/restaurant/db/toppingmodel_304.dart';
import '../../../data/repositories/restaurant/extra_repository.dart';

part 'extra_store.g.dart';

class ExtraStore = _ExtraStore with _$ExtraStore;

abstract class _ExtraStore with Store {
  final ExtraRepository _repository;

  _ExtraStore(this._repository) {
    loadExtras();
  }

  @observable
  ObservableList<Extramodel> extras = ObservableList<Extramodel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  // Computed properties
  @computed
  List<Extramodel> get filteredExtras {
    if (searchQuery.isEmpty) return extras;
    final lowercaseQuery = searchQuery.toLowerCase();
    return extras
        .where((extra) => extra.Ename.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  @computed
  int get totalExtras => extras.length;

  // Actions
  @action
  Future<void> loadExtras() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedExtras = await _repository.getAllExtras();
      extras = ObservableList.of(loadedExtras);
      print('✅ ExtraStore: Loaded ${extras.length} extras');
    } catch (e) {
      errorMessage = 'Failed to load extras: $e';
      print('❌ ExtraStore: Error loading extras - $e');
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadExtras();
  }

  @action
  Future<bool> addExtra(Extramodel extra) async {
    try {
      print('📝 ExtraStore: Adding extra "${extra.Ename}" with ID: ${extra.Id}');
      await _repository.addExtra(extra);
      extras.add(extra);
      print('✅ ExtraStore: Added successfully. Total extras now: ${extras.length}');
      return true;
    } catch (e) {
      errorMessage = 'Failed to add extra: $e';
      print('❌ ExtraStore: Failed to add extra - $e');
      return false;
    }
  }

  @action
  Future<Extramodel?> getExtraById(String id) async {
    try {
      return await _repository.getExtraById(id);
    } catch (e) {
      errorMessage = 'Failed to get extra: $e';
      return null;
    }
  }

  @action
  Future<bool> updateExtra(Extramodel updatedExtra) async {
    try {
      await _repository.updateExtra(updatedExtra);
      final index = extras.indexWhere((e) => e.Id == updatedExtra.Id);
      if (index != -1) {
        extras[index] = updatedExtra;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update extra: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteExtra(String id) async {
    try {
      await _repository.deleteExtra(id);
      extras.removeWhere((e) => e.Id == id);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete extra: $e';
      return false;
    }
  }

  @action
  Future<bool> addTopping(String extraId, Topping topping) async {
    try {
      final result = await _repository.addTopping(extraId, topping);
      if (result) {
        await loadExtras(); // Reload to reflect changes
      }
      return result;
    } catch (e) {
      errorMessage = 'Failed to add topping: $e';
      return false;
    }
  }

  @action
  Future<bool> removeTopping(String extraId, int toppingIndex) async {
    try {
      final result = await _repository.removeTopping(extraId, toppingIndex);
      if (result) {
        await loadExtras(); // Reload to reflect changes
      }
      return result;
    } catch (e) {
      errorMessage = 'Failed to remove topping: $e';
      return false;
    }
  }

  @action
  Future<bool> updateTopping(
      String extraId, int toppingIndex, Topping updatedTopping) async {
    try {
      final result =
          await _repository.updateTopping(extraId, toppingIndex, updatedTopping);
      if (result) {
        await loadExtras(); // Reload to reflect changes
      }
      return result;
    } catch (e) {
      errorMessage = 'Failed to update topping: $e';
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