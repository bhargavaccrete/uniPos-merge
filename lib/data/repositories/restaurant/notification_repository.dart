import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/data/models/restaurant/db/app_notification_model.dart';

class NotificationRepository {
  Box<AppNotificationModel> get _box =>
      Hive.box<AppNotificationModel>(HiveBoxNames.restaurantNotifications);

  /// All records, newest first.
  Future<List<AppNotificationModel>> getAll() async {
    return _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  AppNotificationModel? getById(String id) => _box.get(id);

  /// The unresolved record matching this business identity, if any.
  AppNotificationModel? findActive(
    String eventCode,
    String? subjectType,
    String? subjectId,
  ) {
    try {
      return _box.values.firstWhere((n) =>
          !n.isResolved &&
          n.eventCode == eventCode &&
          n.subjectType == subjectType &&
          n.subjectId == subjectId);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(AppNotificationModel record) async {
    await _box.put(record.id, record);
  }

  Future<void> update(AppNotificationModel record) async {
    await record.save();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
