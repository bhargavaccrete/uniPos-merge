import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

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
  final Uint8List? logo;

  @HiveField(14)
  final bool isSetupComplete;

  @HiveField(15)
  final DateTime createdAt;

  @HiveField(16)
  final DateTime updatedAt;

  /// Behavioral: does this business use tax features in BillBerry? Billing and
  /// wizard step-gating logic should read this field. Kept separate from
  /// [isRegisteredForTax] (see below) even though V1 onboarding always sets both
  /// identically — a future "Tax Settings" screen could decouple them.
  @HiveField(17)
  final bool taxEnabled;

  /// Legal/business status: is the business registered for GST/VAT/Sales Tax?
  /// Gates whether the registration-number field is shown during onboarding.
  @HiveField(18)
  final bool isRegisteredForTax;

  /// Which kind of retail store this is — a `RetailStoreTypes` key such as
  /// 'garment' or 'cosmetics_beauty'. Null for restaurant businesses, and null
  /// for a retail setup saved before store types existed.
  ///
  /// Stored as the stable key, never the display name, so the wording can
  /// change without orphaning saved data.
  @HiveField(19)
  final String? retailStoreType;

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
    this.taxEnabled = true,
    this.isRegisteredForTax = true,
    this.retailStoreType,
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
    Uint8List? logo,
    bool? isSetupComplete,
    bool? taxEnabled,
    bool? isRegisteredForTax,
    String? retailStoreType,
    /// `logo: null` cannot clear the logo — `??` falls back to the old value.
    /// Pass `clearLogo: true` to remove it.
    bool clearLogo = false,
    /// Same reason as [clearLogo]: switching a business from retail back to
    /// restaurant has to null the store type, which `??` cannot do.
    bool clearRetailStoreType = false,
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
      logo: clearLogo ? null : (logo ?? this.logo),
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      isRegisteredForTax: isRegisteredForTax ?? this.isRegisteredForTax,
      retailStoreType: clearRetailStoreType
          ? null
          : (retailStoreType ?? this.retailStoreType),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessTypeId': businessTypeId,
      'businessTypeName': businessTypeName,
      'storeName': storeName,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      'gstin': gstin,
      'pan': pan,
      'city': city,
      'state': state,
      'country': country,
      'pincode': pincode,
      'logo': logo?.toList(),

      'isSetupComplete': isSetupComplete,
      'taxEnabled': taxEnabled,
      'isRegisteredForTax': isRegisteredForTax,
      'retailStoreType': retailStoreType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BusinessDetails.fromMap(Map<String, dynamic> map) {
    return BusinessDetails(
      businessTypeId: map['businessTypeId'] as String?,
      businessTypeName: map['businessTypeName'] as String?,
      storeName: map['storeName'] as String?,
      ownerName: map['ownerName'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      gstin: map['gstin'] as String?,
      pan: map['pan'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      country: map['country'] as String?,
      pincode: map['pincode'] as String?,
      logo: map['logo'] != null
          ? Uint8List.fromList(List<int>.from(map['logo']))
          : null,

      isSetupComplete: map['isSetupComplete'] as bool? ?? false,
      taxEnabled: map['taxEnabled'] as bool? ?? true,
      isRegisteredForTax: map['isRegisteredForTax'] as bool? ?? true,
      retailStoreType: map['retailStoreType'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? ''),
    );
  }
}