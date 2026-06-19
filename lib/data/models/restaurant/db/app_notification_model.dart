import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'app_notification_model.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantAppNotification)
class AppNotificationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String eventCode; // stable code: low_stock, pending_eod, ...

  @HiveField(2)
  final String? subjectType; // item | session | license | system

  @HiveField(3)
  final String? subjectId;

  @HiveField(4)
  String? data; // JSON context, e.g. {"remaining":3,"unit":"kg"}

  @HiveField(5)
  DateTime timestamp;

  @HiveField(6)
  bool isRead;

  @HiveField(7)
  bool isResolved; // true once the fact is no longer true (e.g. restocked)

  @HiveField(8)
  final String source; // 'local' | 'remote'

  AppNotificationModel({
    required this.id,
    required this.eventCode,
    this.subjectType,
    this.subjectId,
    this.data,
    required this.timestamp,
    this.isRead = false,
    this.isResolved = false,
    this.source = 'local',
  });

  Map<String, dynamic> get dataMap {
    if (data == null || data!.isEmpty) return {};
    try {
      final decoded = jsonDecode(data!);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'eventCode': eventCode,
        'subjectType': subjectType,
        'subjectId': subjectId,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'isResolved': isResolved,
        'source': source,
      };

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) =>
      AppNotificationModel(
        id: map['id'] ?? '',
        eventCode: map['eventCode'] ?? '',
        subjectType: map['subjectType'] as String?,
        subjectId: map['subjectId'] as String?,
        data: map['data'] as String?,
        timestamp: DateTime.parse(map['timestamp']),
        isRead: map['isRead'] ?? false,
        isResolved: map['isResolved'] ?? false,
        source: map['source'] ?? 'local',
      );
}
