import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// Signs in the way the PIN screen does: [role] null is the admin, otherwise
/// a staff member with that role ('Manager', 'Cashier', 'Waiter').
///
/// Restaurant refunds and voids check the role (BLK-14), and
/// `RestaurantSession.canAccess` denies everything when nobody is signed in,
/// so tests that refund or void sign in first. Resets SharedPreferences to an
/// empty mock store.
Future<void> signInForTest({String? role}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  if (role == null) return RestaurantSession.saveAdminSession();
  return RestaurantSession.saveStaffSession(StaffModel(
    id: 'staff-$role',
    userName: role.toLowerCase(),
    firstName: role,
    lastName: 'Tester',
    isCashier: role,
    mobileNo: '',
    emailId: '',
    pinNo: '',
    createdAt: DateTime(2026, 1, 1),
  ));
}
