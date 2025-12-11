
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/staffModel_310.dart';

/// A repository class to manage all database operations for StaffModel.
/// This ensures that all interactions with the Hive box are centralized and consistent.
class StaffBox {
  static Box<StaffModel>? _box;
  static const String _boxName = 'staffBox';

  /// Lazily opens and returns the singleton instance of the 'staffBox'.
  /// Includes error handling for robustness.
  static Future<Box<StaffModel>> getStaffBox() async {
    if(_box == null || !_box!.isOpen){
      try{
        _box = await Hive.openBox<StaffModel>(_boxName);
      }catch(e){
        print("Error opening '$_boxName' Hive Box: $e");
      }
    }
    return _box!;
  }

  /// Adds or updates a staff member in the box.
  ///
  /// FIX: Uses put() with the staff's own unique ID as the key.
  /// This ensures a unique, predictable key for every staff member.
  static Future<void> addStaff(StaffModel staff, ) async {
    final box = await getStaffBox();
    await box.put(staff.id, staff);
  }

  /// Retrieves a list of all staff members from the box.
  static Future<List<StaffModel>> getAllStaff() async {
    final box = await getStaffBox();
    return box.values.toList();
  }

  /// Deletes a staff member from the box using their unique ID.
  ///
  /// FIX: Deletes by the unique string ID, not an integer index.
  /// This is reliable even after other items have been deleted.
  static Future<void> deleteStaff(String id) async {
    final box = await getStaffBox();
    await box.delete(id);
  }

  /// Updates an existing staff member.
  ///
  /// Because this uses put() with the staff.id, it works for both
  /// creating a new entry and overwriting an existing one.
  /// This makes it a perfect alias for addStaff.
  static Future<void> updateStaff(StaffModel staff) async {
    // This logic is identical to addStaff, as put() handles both
    // creation and updates.
    // await addStaff( staff);
 final box = await getStaffBox();
 await box.put(staff.id, staff);

  }

}