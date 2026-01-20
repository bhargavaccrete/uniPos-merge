import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/staffModel_310.dart';
import '../../../data/repositories/restaurant/staff_repository.dart';

part 'staff_store.g.dart';

class StaffStore = _StaffStore with _$StaffStore;

abstract class _StaffStore with Store {
  final StaffRepository _repository;

  _StaffStore(this._repository);

  @observable
  ObservableList<StaffModel> staff = ObservableList<StaffModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  String? selectedCashierStatus;

  @observable
  bool showActiveOnly = false;

  // Computed properties
  @computed
  List<StaffModel> get filteredStaff {
    var result = staff.toList();

    if (searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      result = result
          .where((s) =>
              s.firstName.toLowerCase().contains(lowercaseQuery) ||
              s.lastName.toLowerCase().contains(lowercaseQuery) ||
              s.userName.toLowerCase().contains(lowercaseQuery))
          .toList();
    }

    if (selectedCashierStatus != null && selectedCashierStatus!.isNotEmpty) {
      result = result
          .where((s) => s.isCashier == selectedCashierStatus)
          .toList();
    }

    if (showActiveOnly) {
      result = result.where((s) => s.isActive == true).toList();
    }

    return result;
  }

  @computed
  List<StaffModel> get activeStaff =>
      staff.where((s) => s.isActive == true).toList();

  @computed
  int get totalStaff => staff.length;

  @computed
  int get activeStaffCount => activeStaff.length;

  // Actions
  @action
  Future<void> loadStaff() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedStaff = await _repository.getAllStaff();
      staff = ObservableList.of(loadedStaff);
    } catch (e) {
      errorMessage = 'Failed to load staff: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadStaff();
  }

  @action
  Future<bool> addStaff(StaffModel newStaff) async {
    try {
      await _repository.addStaff(newStaff);
      staff.add(newStaff);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add staff: $e';
      return false;
    }
  }

  @action
  Future<StaffModel?> getStaffById(String id) async {
    try {
      return await _repository.getStaffById(id);
    } catch (e) {
      errorMessage = 'Failed to get staff: $e';
      return null;
    }
  }

  @action
  Future<bool> updateStaff(StaffModel updatedStaff) async {
    try {
      await _repository.updateStaff(updatedStaff);
      final index = staff.indexWhere((s) => s.id == updatedStaff.id);
      if (index != -1) {
        staff[index] = updatedStaff;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update staff: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteStaff(String id) async {
    try {
      await _repository.deleteStaff(id);
      staff.removeWhere((s) => s.id == id);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete staff: $e';
      return false;
    }
  }

  @action
  Future<List<StaffModel>> searchStaff(String query) async {
    try {
      return await _repository.searchStaff(query);
    } catch (e) {
      errorMessage = 'Failed to search staff: $e';
      return [];
    }
  }

  @action
  Future<List<StaffModel>> getStaffByCashierStatus(String isCashier) async {
    try {
      return await _repository.getStaffByCashierStatus(isCashier);
    } catch (e) {
      errorMessage = 'Failed to get staff by cashier status: $e';
      return [];
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void setCashierStatusFilter(String? status) {
    selectedCashierStatus = status;
  }

  @action
  void setShowActiveOnly(bool value) {
    showActiveOnly = value;
  }

  @action
  void clearFilters() {
    searchQuery = '';
    selectedCashierStatus = null;
    showActiveOnly = false;
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}