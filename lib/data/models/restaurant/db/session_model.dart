import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'session_model.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantSession)
class RestaurantSessionModel extends HiveObject {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  DateTime? endTime;

  @HiveField(3)
  final double openingCash;

  @HiveField(4)
  double? closingCash;

  @HiveField(5)
  bool isClosed;

  RestaurantSessionModel({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.openingCash,
    this.closingCash,
    this.isClosed = false,
  });

  RestaurantSessionModel copyWith({
    String? sessionId,
    DateTime? startTime,
    DateTime? endTime,
    double? openingCash,
    double? closingCash,
    bool? isClosed,
  }) {
    return RestaurantSessionModel(
      sessionId: sessionId ?? this.sessionId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      openingCash: openingCash ?? this.openingCash,
      closingCash: closingCash ?? this.closingCash,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'openingCash': openingCash,
      'closingCash': closingCash,
      'isClosed': isClosed,
    };
  }

  factory RestaurantSessionModel.fromMap(Map<String, dynamic> map) {
    return RestaurantSessionModel(
      sessionId: map['sessionId'] ?? '',
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      openingCash: (map['openingCash'] ?? 0.0).toDouble(),
      closingCash: map['closingCash'] != null ? (map['closingCash'] as num).toDouble() : null,
      isClosed: map['isClosed'] ?? false,
    );
  }
}
