import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:unipos/data/models/restaurant/notification_presenter.dart';
import 'package:unipos/main.dart' show navigatorKey;

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  Future<void> init() async {
    if (!_supported || _ready) return;

    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Fall back to the default (UTC) if the zone can't be resolved.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) => _navigate(resp.payload),
    );

    await _createAndroidChannels();
    _ready = true;

    // Route a cold-start tap once the first frame (and navigator) exists.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _navigate(launch!.notificationResponse?.payload);
    }
  }

  Future<void> requestPermissionIfNeeded() async {
    if (!_supported) return;
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showNow({
    required String idSeed,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    if (!_supported || !_ready) return;
    await _plugin.show(
      _idFromSeed(idSeed),
      title,
      body,
      _detailsFor(channelId),
      payload: payload,
    );
  }

  Future<void> schedule({
    required String idSeed,
    required DateTime when,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    if (!_supported || !_ready) return;
    final fireAt = tz.TZDateTime.from(when, tz.local);
    if (fireAt.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      _idFromSeed(idSeed),
      title,
      body,
      fireAt,
      _detailsFor(channelId),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelBySeed(String idSeed) async {
    if (!_supported) return;
    await _plugin.cancel(_idFromSeed(idSeed));
  }

  /// TEMP diagnostic — reports the real internal state to the UI.
  Future<String> debugProbe() async {
    final b = StringBuffer();
    b.writeln('platform: ${Platform.operatingSystem}');
    b.writeln('supported: $_supported');
    b.writeln('ready (before): $_ready');
    try {
      await init();
      b.writeln('init: OK, ready=$_ready');
    } catch (e) {
      b.writeln('init ERROR: $e');
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      b.writeln('androidImpl: ${android != null}');
      try {
        b.writeln('notifsEnabled: ${await android?.areNotificationsEnabled()}');
      } catch (e) {
        b.writeln('enabledCheck ERROR: $e');
      }
      try {
        b.writeln('permRequest: ${await android?.requestNotificationsPermission()}');
      } catch (e) {
        b.writeln('permRequest ERROR: $e');
      }
    }
    try {
      await _plugin.show(
        999999,
        'Probe',
        'Direct show() test',
        _detailsFor(NotificationChannels.lowStock),
      );
      b.writeln('show(): OK');
    } catch (e) {
      b.writeln('show() ERROR: $e');
    }
    return b.toString();
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
      NotificationChannels.lowStock,
      'Low Stock Alerts',
      importance: Importance.high,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      NotificationChannels.appAlerts,
      'App Alerts',
      importance: Importance.defaultImportance,
    ));
  }

  NotificationDetails _detailsFor(String channelId) {
    final high = channelId == NotificationChannels.lowStock;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        high ? 'Low Stock Alerts' : 'App Alerts',
        importance: high ? Importance.high : Importance.defaultImportance,
        priority: high ? Priority.high : Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  int _idFromSeed(String seed) => seed.hashCode & 0x7fffffff;

  void _navigate(String? route) {
    if (route == null || route.isEmpty) return;
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamed(route);
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => navigatorKey.currentState?.pushNamed(route),
      );
    }
  }
}
