import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'companymodel_301.g.dart';
@HiveType(typeId: HiveTypeIds.restaurantCompany)
class Company extends HiveObject{
  @HiveField(0)
  String comapanyName;

  @HiveField(1)
  String ownerName;

  @HiveField(2)
  String mobileNumber;

  @HiveField(3)
  String mobilenumberaltr;

  @HiveField(4)
  String email;

  @HiveField(5)
  String btype;

  @HiveField(6)
  String gst;
  @HiveField(7)
  String fssai;

  @HiveField(8)
  String country;
  @HiveField(9)
  String state;

  @HiveField(10)
  String city;

  @HiveField(11)
  String address;

  @HiveField(12)
  String pincode;

  @HiveField(13)
  String? imagePath;

  @HiveField(14)
  String dateofreg;
  @HiveField(15)
  String pass;

  Company({
   required this.comapanyName,
  required this.ownerName,
  required this.mobileNumber,
  required this.mobilenumberaltr,
  required this.email,
    required this.btype,
    required this.gst,
  required this.fssai,
  required this.country,
    required this.state,
  required this.city,
    required this.pincode,
    this.imagePath,
  required this.dateofreg,
    required this.pass,
    required this.address

});

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'comapanyName': comapanyName,
      'ownerName': ownerName,
      'mobileNumber': mobileNumber,
      'mobilenumberaltr': mobilenumberaltr,
      'email': email,
      'btype': btype,
      'gst': gst,
      'fssai': fssai,
      'country': country,
      'state': state,
      'city': city,
      'address': address,
      'pincode': pincode,
      'imagePath': imagePath,
      'dateofreg': dateofreg,
      'pass': pass,
    };
  }

  /// Create from Map
  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      comapanyName: map['comapanyName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      mobilenumberaltr: map['mobilenumberaltr'] ?? '',
      email: map['email'] ?? '',
      btype: map['btype'] ?? '',
      gst: map['gst'] ?? '',
      fssai: map['fssai'] ?? '',
      country: map['country'] ?? '',
      state: map['state'] ?? '',
      city: map['city'] ?? '',
      address: map['address'] ?? '',
      pincode: map['pincode'] ?? '',
      imagePath: map['imagePath'],
      dateofreg: map['dateofreg'] ?? '',
      pass: map['pass'] ?? '',
    );
  }

}