import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../data/repositories/restaurant/tax_repository.dart';

part 'tax_store.g.dart';

class TaxStore = _TaxStore with _$TaxStore;

abstract class _TaxStore with Store {
  final TaxRepository _taxRepository = locator<TaxRepository>();

  final ObservableList<Tax> taxes = ObservableList<Tax>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  _TaxStore() {
    _init();
  }

  Future<void> _init() async {
    await loadTaxes();
  }

  @computed
  int get totalTaxCount => taxes.length;

  @action
  Future<void> loadTaxes() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = _taxRepository.getAllTaxes();
      taxes.clear();
      taxes.addAll(loaded);
    } catch (e) {
      errorMessage = 'Failed to load taxes: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addTax(Tax tax) async {
    try {
      await _taxRepository.addTax(tax);
      taxes.add(tax);
    } catch (e) {
      errorMessage = 'Failed to add tax: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateTax(Tax tax) async {
    try {
      await _taxRepository.updateTax(tax);
      final index = taxes.indexWhere((t) => t.id == tax.id);
      if (index != -1) {
        taxes[index] = tax;
      }
    } catch (e) {
      errorMessage = 'Failed to update tax: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteTax(String id) async {
    try {
      await _taxRepository.deleteTax(id);
      taxes.removeWhere((tax) => tax.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete tax: $e';
      rethrow;
    }
  }

  Tax? getTaxById(String id) {
    try {
      return taxes.firstWhere((tax) => tax.id == id);
    } catch (e) {
      return null;
    }
  }
}