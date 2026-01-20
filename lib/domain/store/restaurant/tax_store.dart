import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../data/repositories/restaurant/tax_repository.dart';

part 'tax_store.g.dart';

class TaxStore = _TaxStore with _$TaxStore;

abstract class _TaxStore with Store {
  final TaxRepository _repository;

  _TaxStore(this._repository);

  @observable
  ObservableList<Tax> taxes = ObservableList<Tax>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  // Computed properties
  @computed
  List<Tax> get filteredTaxes {
    if (searchQuery.isEmpty) return taxes;
    final lowercaseQuery = searchQuery.toLowerCase();
    return taxes
        .where((tax) => tax.taxname.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  @computed
  int get totalTaxes => taxes.length;

  // Actions
  @action
  Future<void> loadTaxes() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedTaxes = await _repository.getAllTaxes();
      taxes = ObservableList.of(loadedTaxes);
    } catch (e) {
      errorMessage = 'Failed to load taxes: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadTaxes();
  }

  @action
  Future<bool> addTax(Tax tax) async {
    try {
      await _repository.addTax(tax);
      taxes.add(tax);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add tax: $e';
      return false;
    }
  }

  @action
  Future<Tax?> getTaxById(String id) async {
    try {
      return await _repository.getTaxById(id);
    } catch (e) {
      errorMessage = 'Failed to get tax: $e';
      return null;
    }
  }

  @action
  Future<bool> updateTax(Tax updatedTax) async {
    try {
      await _repository.updateTax(updatedTax);
      final index = taxes.indexWhere((t) => t.id == updatedTax.id);
      if (index != -1) {
        taxes[index] = updatedTax;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update tax: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteTax(String id) async {
    try {
      await _repository.deleteTax(id);
      taxes.removeWhere((t) => t.id == id);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete tax: $e';
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