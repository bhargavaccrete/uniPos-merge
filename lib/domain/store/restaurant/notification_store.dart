import 'dart:convert';

import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/data/models/restaurant/dashboard_alert.dart';
import 'package:unipos/data/models/restaurant/db/app_notification_model.dart';
import 'package:unipos/data/models/restaurant/notification_presenter.dart';
import 'package:unipos/data/repositories/restaurant/notification_repository.dart';
import 'package:unipos/domain/services/common/local_notification_service.dart';

part 'notification_store.g.dart';

class NotificationStore = _NotificationStore with _$NotificationStore;

abstract class _NotificationStore with Store {
  final NotificationRepository _repository;

  _NotificationStore(this._repository) {
    load();
  }

  @observable
  ObservableList<AppNotificationModel> notifications =
      ObservableList<AppNotificationModel>();

  @computed
  List<AppNotificationModel> get active =>
      notifications.where((n) => !n.isResolved).toList();

  @computed
  int get unreadCount =>
      notifications.where((n) => !n.isRead && !n.isResolved).length;

  @computed
  List<AppNotificationModel> get critical => _bySeverity(AlertSeverity.critical);

  @computed
  List<AppNotificationModel> get warning => _bySeverity(AlertSeverity.warning);

  @computed
  List<AppNotificationModel> get info => _bySeverity(AlertSeverity.info);

  List<AppNotificationModel> _bySeverity(AlertSeverity s) => active
      .where((n) => NotificationPresenter.present(n).severity == s)
      .toList();

  @action
  Future<void> load() async {
    final all = await _repository.getAll();
    _emit(all);
  }

  /// The single entry point every trigger feeds (and a future FCM layer).
  @action
  Future<void> raiseEvent({
    required String eventCode,
    String? subjectType,
    String? subjectId,
    Map<String, dynamic>? data,
    String source = 'local',
    bool fireOs = true,
  }) async {
    final now = DateTime.now();
    final encoded = data != null ? jsonEncode(data) : null;
    final existing = _repository.findActive(eventCode, subjectType, subjectId);

    if (existing == null) {
      final n = AppNotificationModel(
        id: const Uuid().v4(),
        eventCode: eventCode,
        subjectType: subjectType,
        subjectId: subjectId,
        data: encoded,
        timestamp: now,
        source: source,
      );
      await _repository.add(n);
      _emit([...notifications, n]);
      if (fireOs) _fireOs(n);
      return;
    }

    // Same business fact — update in place; re-notify at most once per day.
    final alreadyToday = _isSameDay(existing.timestamp, now);
    if (encoded != null) existing.data = encoded;
    if (!alreadyToday) {
      existing.timestamp = now;
      existing.isRead = false;
    }
    await _repository.update(existing);
    _emit(notifications.toList());
    if (fireOs && !alreadyToday) _fireOs(existing);
  }

  /// Retire an event once its underlying fact is no longer true.
  @action
  Future<void> resolve(
    String eventCode,
    String? subjectType,
    String? subjectId,
  ) async {
    final existing = _repository.findActive(eventCode, subjectType, subjectId);
    if (existing == null) return;
    existing.isResolved = true;
    await _repository.update(existing);
    LocalNotificationService.instance.cancelBySeed(_seed(existing));
    _emit(notifications.toList());
  }

  @action
  Future<void> markRead(String id) async {
    final n = notifications.firstWhere((e) => e.id == id, orElse: () => _none);
    if (identical(n, _none) || n.isRead) return;
    n.isRead = true;
    await _repository.update(n);
    _emit(notifications.toList());
  }

  @action
  Future<void> markAllRead() async {
    for (final n in notifications) {
      if (!n.isRead) {
        n.isRead = true;
        await _repository.update(n);
      }
    }
    _emit(notifications.toList());
  }

  @action
  Future<void> clearAll() async {
    await _repository.clearAll();
    _emit([]);
  }

  void _fireOs(AppNotificationModel n) {
    final view = NotificationPresenter.present(n);
    LocalNotificationService.instance.showNow(
      idSeed: _seed(n),
      title: view.title,
      body: view.body,
      channelId: view.channelId,
      payload: view.route,
    );
  }

  void _emit(List<AppNotificationModel> list) {
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifications = ObservableList.of(list);
  }

  String _seed(AppNotificationModel n) =>
      '${n.eventCode}:${n.subjectType}:${n.subjectId}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static final AppNotificationModel _none = AppNotificationModel(
    id: '__none__',
    eventCode: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
