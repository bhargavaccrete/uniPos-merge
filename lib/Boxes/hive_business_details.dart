import 'dart:typed_data';
import 'package:hive/hive.dart';
import '../data/models/common/business_details.dart';

class BusinessDetailsBox {
  static const String _boxName = 'businessDetailsBox';
  static const String _key = 'businessDetails';

  static Future<Box<BusinessDetails>> openBox() async {
    return await Hive.openBox<BusinessDetails>(_boxName);
  }

  static Box<BusinessDetails> getBox() {
    return Hive.box<BusinessDetails>(_boxName);
  }

  // Save business details
  static Future<void> saveBusinessDetails(BusinessDetails details) async {
    final box = getBox();
    await box.put(_key, details);
  }

  // Get business details
  static BusinessDetails? getBusinessDetails() {
    final box = getBox();
    return box.get(_key);
  }

  // Update business details
  static Future<void> updateBusinessDetails({
    String? businessTypeId,
    String? businessTypeName,
    String? storeName,
    String? ownerName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    String? pan,
    String? city,
    String? state,
    String? country,
    String? pincode,
    Uint8List? logo,
    bool? isSetupComplete,
  }) async {
    final existing = getBusinessDetails();
    final updated = (existing ?? BusinessDetails()).copyWith(
      businessTypeId: businessTypeId,
      businessTypeName: businessTypeName,
      storeName: storeName,
      ownerName: ownerName,
      phone: phone,
      email: email,
      address: address,
      gstin: gstin,
      pan: pan,
      city: city,
      state: state,
      country: country,
      pincode: pincode,
      logo: logo,
      isSetupComplete: isSetupComplete,
    );
    await saveBusinessDetails(updated);
  }

  // Delete business details
  static Future<void> deleteBusinessDetails() async {
    final box = getBox();
    await box.delete(_key);
  }

  // Clear all data
  static Future<void> clearBox() async {
    final box = getBox();
    await box.clear();
  }

  // Check if setup is complete
  static bool isSetupComplete() {
    final details = getBusinessDetails();
    return details?.isSetupComplete ?? false;
  }

  // Check if business details exist
  static bool hasBusinessDetails() {
    return getBusinessDetails() != null;
  }

  // Mark setup as complete
  static Future<void> markSetupComplete() async {
    await updateBusinessDetails(isSetupComplete: true);
  }
}