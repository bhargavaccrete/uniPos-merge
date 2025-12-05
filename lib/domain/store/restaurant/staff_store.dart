import 'package:mobx/mobx.dart';


import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/staffModel_310.dart';
import '../../../data/repositories/restaurant/staff_repository.dart';

part 'staff_store.g.dart';

class StaffStore = _StaffStore with _$StaffStore;

abstract class _StaffStore with Store {
  final StaffRepository _staffRepository = locator<StaffRepository>();

  final ObservableList<StaffModel> staffMembers = ObservableList<StaffModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  StaffModel? currentLoggedInStaff;

  _StaffStore() {
    _init();
  }

  Future<void> _init() async {
    await loadStaff();
  }

  @computed
  List<StaffModel> get activeStaff {
    return staffMembers.where((staff) => staff.isActive == true).toList();
  }

  @computed
  int get totalStaffCount => staffMembers.length;

  @action
  Future<void> loadStaff() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = _staffRepository.getAllStaff();
      staffMembers.clear();
      staffMembers.addAll(loaded);
    } catch (e) {
      errorMessage = 'Failed to load staff: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addStaff(StaffModel staff) async {
    try {
      await _staffRepository.addStaff(staff);
      staffMembers.add(staff);
    } catch (e) {
      errorMessage = 'Failed to add staff: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateStaff(StaffModel staff) async {
    try {
      await _staffRepository.updateStaff(staff);
      final index = staffMembers.indexWhere((s) => s.id == staff.id);
      if (index != -1) {
        staffMembers[index] = staff;
      }
    } catch (e) {
      errorMessage = 'Failed to update staff: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteStaff(String id) async {
    try {
      await _staffRepository.deleteStaff(id);
      staffMembers.removeWhere((staff) => staff.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete staff: $e';
      rethrow;
    }
  }

  @action
  bool loginWithPin(String pin) {
    final staff = _staffRepository.getStaffByPin(pin);
    if (staff != null && staff.isActive == true) {
      currentLoggedInStaff = staff;
      return true;
    }
    return false;
  }

  @action
  void logout() {
    currentLoggedInStaff = null;
  }

  StaffModel? getStaffById(String id) {
    try {
      return staffMembers.firstWhere((staff) => staff.id == id);
    } catch (e) {
      return null;
    }
  }
}