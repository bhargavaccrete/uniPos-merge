import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'shift_model.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantShift)
class ShiftModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String staffId;

  @HiveField(2)
  final String staffName;

  @HiveField(3)
  final DateTime startTime;

  @HiveField(4)
  final DateTime? endTime;

  @HiveField(5)
  final String status; // 'open' | 'closed'

  @HiveField(6)
  final int orderCount;

  @HiveField(7)
  final double totalSales;

  ShiftModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.startTime,
    this.endTime,
    this.status = 'open',
    this.orderCount = 0,
    this.totalSales = 0.0,
  });

  bool get isOpen => status == 'open';

  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  ShiftModel copyWith({
    String? id,
    String? staffId,
    String? staffName,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    int? orderCount,
    double? totalSales,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      orderCount: orderCount ?? this.orderCount,
      totalSales: totalSales ?? this.totalSales,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status,
      'orderCount': orderCount,
      'totalSales': totalSales,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] ?? '',
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      startTime: DateTime.tryParse(map['startTime'] ?? '') ?? DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.tryParse(map['endTime']) : null,
      status: map['status'] ?? 'open',
      orderCount: map['orderCount'] ?? 0,
      totalSales: (map['totalSales'] ?? 0).toDouble(),
    );
  }
}