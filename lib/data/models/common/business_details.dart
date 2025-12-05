import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'business_details.g.dart';

@HiveType(typeId: HiveTypeIds.businessDetails)
class BusinessDetails extends HiveObject {
  @HiveField(0)
  final String? businessTypeId;

  @HiveField(1)
  final String? businessTypeName;

  @HiveField(2)
  final String? storeName;

  @HiveField(3)
  final String? ownerName;

  @HiveField(4)
  final String? phone;

  @HiveField(5)
  final String? email;

  @HiveField(6)
  final String? address;

  @HiveField(7)
  final String? gstin;

  @HiveField(8)
  final String? pan;

  @HiveField(9)
  final String? city;

  @HiveField(10)
  final String? state;

  @HiveField(11)
  final String? country;

  @HiveField(12)
  final String? pincode;

  @HiveField(13)
  final String? logo;

  @HiveField(14)
  final bool isSetupComplete;

  @HiveField(15)
  final DateTime createdAt;

  @HiveField(16)
  final DateTime updatedAt;

  BusinessDetails({
    this.businessTypeId,
    this.businessTypeName,
    this.storeName,
    this.ownerName,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.pan,
    this.city,
    this.state,
    this.country,
    this.pincode,
    this.logo,
    this.isSetupComplete = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  BusinessDetails copyWith({
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
    String? logo,
    bool? isSetupComplete,
  }) {
    return BusinessDetails(
      businessTypeId: businessTypeId ?? this.businessTypeId,
      businessTypeName: businessTypeName ?? this.businessTypeName,
      storeName: storeName ?? this.storeName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      logo: logo ?? this.logo,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}