import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'staffModel_310.g.dart';

@HiveType(typeId:HiveTypeIds.restaurantStaff)
class StaffModel extends HiveObject{

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userName;

  @HiveField(2)
  final String firstName;

  @HiveField(3)
  final String lastName;

  @HiveField(4)
  final String isCashier;


  @HiveField(5)
  final String mobileNo;
  @HiveField(6)
  final String emailId;
  @HiveField(7)
  final String  pinNo;
  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final bool isActive;



  StaffModel({
    required this.id,
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this. isCashier,
    required this.mobileNo,
    required this.emailId,
    required this.pinNo,
    required this.createdAt,
    this.isActive = true,
  });


  StaffModel copyWith({
    String? id,
    String? userName,
    String? firstName,
    String? lastName,
    String? isCashier,
    String? mobileNo,
    String? emailId,
    String? pinNo,
    DateTime? dateTime,
    bool? isActive,
  }){
    return StaffModel(
        id: id ?? this.id,
        userName: userName ?? this.userName,
        firstName: firstName ??  this.firstName,
        lastName: lastName ?? this.lastName,
        isCashier: isCashier ?? this.isCashier,
        mobileNo: mobileNo??this.mobileNo,
        emailId: emailId ??this.emailId,
        pinNo: pinNo ?? this.pinNo,
        createdAt: dateTime ?? this.createdAt,
        isActive: isActive ?? this.isActive);
  }

  /// Convert object to Map (for JSON export)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userName': userName,
      'firstName': firstName,
      'lastName': lastName,
      'isCashier': isCashier,
      'mobileNo': mobileNo,
      'emailId': emailId,
      'pinNo': pinNo,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Create object from Map (for JSON import)
  factory StaffModel.fromMap(Map<String, dynamic> map) {
    return StaffModel(
      id: map['id'] ?? '',
      userName: map['userName'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      isCashier: map['isCashier'] ?? '',
      mobileNo: map['mobileNo'] ?? '',
      emailId: map['emailId'] ?? '',
      pinNo: map['pinNo'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }
// factory StaffModel.fromMap(Map<String, dynamic>map){
//   return StaffModel(
//       id: map['id'],
//       userName: map['userName'],
//       firstName: map['firstName'],
//       lastName: map['lastName'],
//       isCashier: map['isCashier'],
//       mobileNo: map['mobileNo'],
//       emailId: map['emailId'],
//       pinNo: map['pinNo']);
// }




}
