import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/companymodel_301.dart';
import '../../../data/repositories/restaurant/company_repository.dart';

part 'company_store.g.dart';

class CompanyStore = _CompanyStore with _$CompanyStore;

abstract class _CompanyStore with Store {
  final CompanyRepository _repository;

  _CompanyStore(this._repository);

  @observable
  Company? company;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  // Computed properties
  @computed
  bool get hasCompany => company != null;

  // Actions
  @action
  Future<void> loadCompany() async {
    try {
      isLoading = true;
      errorMessage = null;
      company = await _repository.getCompany();
    } catch (e) {
      errorMessage = 'Failed to load company: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadCompany();
  }

  @action
  Future<bool> saveCompany(Company newCompany) async {
    try {
      await _repository.saveCompany(newCompany);
      company = newCompany;
      return true;
    } catch (e) {
      errorMessage = 'Failed to save company: $e';
      return false;
    }
  }

  @action
  Future<bool> updateCompany(Company updatedCompany) async {
    try {
      await _repository.updateCompany(updatedCompany);
      company = updatedCompany;
      return true;
    } catch (e) {
      errorMessage = 'Failed to update company: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteCompany() async {
    try {
      await _repository.deleteCompany();
      company = null;
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete company: $e';
      return false;
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}