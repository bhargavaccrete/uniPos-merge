import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'attendance_model.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantAttendance)
class AttendanceModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String staffName;

  @HiveField(2)
  final String staffRole;

  @HiveField(3)
  DateTime clockIn;

  @HiveField(4)
  DateTime? clockOut;

  @HiveField(5)
  int? totalMinutes; // filled on clock-out

  @HiveField(6)
  final String date; // "2026-04-08" — for day filtering

  @HiveField(7)
  final String? sessionId;

  @HiveField(8)
  DateTime? breakStartTime;

  @HiveField(9)
  int? breakTotalMinutes;

  AttendanceModel({
    required this.id,
    required this.staffName,
    required this.staffRole,
    required this.clockIn,
    this.clockOut,
    this.totalMinutes,
    required this.date,
    this.sessionId,
    this.breakStartTime,
    this.breakTotalMinutes,
  });

  bool get isOpen => clockOut == null;
  bool get isOnBreak => breakStartTime != null && clockOut == null;

  String get formattedClockIn =>
      '${clockIn.hour.toString().padLeft(2, '0')}:${clockIn.minute.toString().padLeft(2, '0')}';

  String get formattedClockOut {
    if (clockOut == null) return '—';
    final t = '${clockOut!.hour.toString().padLeft(2, '0')}:${clockOut!.minute.toString().padLeft(2, '0')}';
    // Cross-day shift: show date prefix so it's clear the checkout was next day
    if (clockOut!.day != clockIn.day ||
        clockOut!.month != clockIn.month ||
        clockOut!.year != clockIn.year) {
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[clockOut!.month - 1]} ${clockOut!.day}, $t';
    }
    return t;
  }

  String get formattedDuration {
    if (totalMinutes == null) return 'In progress';
    final h = totalMinutes! ~/ 60;
    final m = totalMinutes! % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'staffName': staffName,
        'staffRole': staffRole,
        'clockIn': clockIn.toIso8601String(),
        'clockOut': clockOut?.toIso8601String(),
        'totalMinutes': totalMinutes,
        'date': date,
        'sessionId': sessionId,
        'breakStartTime': breakStartTime?.toIso8601String(),
        'breakTotalMinutes': breakTotalMinutes,
      };

  factory AttendanceModel.fromMap(Map<String, dynamic> map) => AttendanceModel(
        id: map['id'] ?? '',
        staffName: map['staffName'] ?? '',
        staffRole: map['staffRole'] ?? '',
        clockIn: DateTime.parse(map['clockIn']),
        clockOut: map['clockOut'] != null ? DateTime.parse(map['clockOut']) : null,
        totalMinutes: map['totalMinutes'] as int?,
        date: map['date'] ?? '',
        sessionId: map['sessionId'] as String?,
        breakStartTime: map['breakStartTime'] != null ? DateTime.parse(map['breakStartTime']) : null,
        breakTotalMinutes: map['breakTotalMinutes'] as int?,
      );
}