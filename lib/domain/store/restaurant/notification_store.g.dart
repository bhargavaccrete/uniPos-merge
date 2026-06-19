// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$NotificationStore on _NotificationStore, Store {
  Computed<List<AppNotificationModel>>? _$activeComputed;

  @override
  List<AppNotificationModel> get active => (_$activeComputed ??=
          Computed<List<AppNotificationModel>>(() => super.active,
              name: '_NotificationStore.active'))
      .value;
  Computed<int>? _$unreadCountComputed;

  @override
  int get unreadCount =>
      (_$unreadCountComputed ??= Computed<int>(() => super.unreadCount,
              name: '_NotificationStore.unreadCount'))
          .value;
  Computed<List<AppNotificationModel>>? _$criticalComputed;

  @override
  List<AppNotificationModel> get critical => (_$criticalComputed ??=
          Computed<List<AppNotificationModel>>(() => super.critical,
              name: '_NotificationStore.critical'))
      .value;
  Computed<List<AppNotificationModel>>? _$warningComputed;

  @override
  List<AppNotificationModel> get warning => (_$warningComputed ??=
          Computed<List<AppNotificationModel>>(() => super.warning,
              name: '_NotificationStore.warning'))
      .value;
  Computed<List<AppNotificationModel>>? _$infoComputed;

  @override
  List<AppNotificationModel> get info =>
      (_$infoComputed ??= Computed<List<AppNotificationModel>>(() => super.info,
              name: '_NotificationStore.info'))
          .value;

  late final _$notificationsAtom =
      Atom(name: '_NotificationStore.notifications', context: context);

  @override
  ObservableList<AppNotificationModel> get notifications {
    _$notificationsAtom.reportRead();
    return super.notifications;
  }

  @override
  set notifications(ObservableList<AppNotificationModel> value) {
    _$notificationsAtom.reportWrite(value, super.notifications, () {
      super.notifications = value;
    });
  }

  late final _$loadAsyncAction =
      AsyncAction('_NotificationStore.load', context: context);

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$raiseEventAsyncAction =
      AsyncAction('_NotificationStore.raiseEvent', context: context);

  @override
  Future<void> raiseEvent(
      {required String eventCode,
      String? subjectType,
      String? subjectId,
      Map<String, dynamic>? data,
      String source = 'local',
      bool fireOs = true}) {
    return _$raiseEventAsyncAction.run(() => super.raiseEvent(
        eventCode: eventCode,
        subjectType: subjectType,
        subjectId: subjectId,
        data: data,
        source: source,
        fireOs: fireOs));
  }

  late final _$resolveAsyncAction =
      AsyncAction('_NotificationStore.resolve', context: context);

  @override
  Future<void> resolve(
      String eventCode, String? subjectType, String? subjectId) {
    return _$resolveAsyncAction
        .run(() => super.resolve(eventCode, subjectType, subjectId));
  }

  late final _$markReadAsyncAction =
      AsyncAction('_NotificationStore.markRead', context: context);

  @override
  Future<void> markRead(String id) {
    return _$markReadAsyncAction.run(() => super.markRead(id));
  }

  late final _$markAllReadAsyncAction =
      AsyncAction('_NotificationStore.markAllRead', context: context);

  @override
  Future<void> markAllRead() {
    return _$markAllReadAsyncAction.run(() => super.markAllRead());
  }

  late final _$clearAllAsyncAction =
      AsyncAction('_NotificationStore.clearAll', context: context);

  @override
  Future<void> clearAll() {
    return _$clearAllAsyncAction.run(() => super.clearAll());
  }

  @override
  String toString() {
    return '''
notifications: ${notifications},
active: ${active},
unreadCount: ${unreadCount},
critical: ${critical},
warning: ${warning},
info: ${info}
    ''';
  }
}
