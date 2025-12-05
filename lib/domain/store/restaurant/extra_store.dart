import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../data/models/restaurant/db/toppingmodel_304.dart';
import '../../../data/repositories/restaurant/extra_repository.dart';

part 'extra_store.g.dart';

class ExtraStore = _ExtraStore with _$ExtraStore;

abstract class _ExtraStore with Store {
  final ExtraRepository _extraRepository = locator<ExtraRepository>();

  final ObservableList<Extramodel> extras = ObservableList<Extramodel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  _ExtraStore() {
    _init();
  }

  Future<void> _init() async {
    await loadExtras();
  }

  @computed
  int get extraCount => extras.length;

  @action
  Future<void> loadExtras() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = _extraRepository.getAllExtras();
      extras.clear();
      extras.addAll(loaded);
    } catch (e) {
      errorMessage = 'Failed to load extras: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addExtra(Extramodel extra) async {
    try {
      await _extraRepository.addExtra(extra);
      extras.add(extra);
    } catch (e) {
      errorMessage = 'Failed to add extra: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateExtra(Extramodel extra) async {
    try {
      await _extraRepository.updateExtra(extra);
      final index = extras.indexWhere((e) => e.Id == extra.Id);
      if (index != -1) {
        extras[index] = extra;
      }
    } catch (e) {
      errorMessage = 'Failed to update extra: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteExtra(String id) async {
    try {
      await _extraRepository.deleteExtra(id);
      extras.removeWhere((extra) => extra.Id == id);
    } catch (e) {
      errorMessage = 'Failed to delete extra: $e';
      rethrow;
    }
  }

  @action
  Future<void> addToppingToExtra(String extraId, Topping topping) async {
    try {
      final success = await _extraRepository.addToppingToExtra(extraId, topping);
      if (success) {
        await loadExtras(); // Reload to get updated data
      }
    } catch (e) {
      errorMessage = 'Failed to add topping: $e';
      rethrow;
    }
  }

  @action
  Future<void> removeToppingFromExtra(String extraId, int toppingIndex) async {
    try {
      final success = await _extraRepository.removeToppingFromExtra(extraId, toppingIndex);
      if (success) {
        await loadExtras(); // Reload to get updated data
      }
    } catch (e) {
      errorMessage = 'Failed to remove topping: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateToppingInExtra(String extraId, int toppingIndex, Topping updatedTopping) async {
    try {
      final success = await _extraRepository.updateToppingInExtra(extraId, toppingIndex, updatedTopping);
      if (success) {
        await loadExtras(); // Reload to get updated data
      }
    } catch (e) {
      errorMessage = 'Failed to update topping: $e';
      rethrow;
    }
  }

  Extramodel? getExtraById(String id) {
    try {
      return extras.firstWhere((extra) => extra.Id == id);
    } catch (e) {
      return null;
    }
  }
}