import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:billberrylite/data/models/common/notification_presenter.dart';
import 'package:billberrylite/domain/services/common/local_notification_service.dart';
import 'package:billberrylite/main.dart' show navigatorKey;

/// Handles messages that arrive while the app is **backgrounded or terminated**.
///
/// This MUST be a top-level (or static) function annotated with
/// `@pragma('vm:entry-point')`: the plugin runs it in a separate background
/// isolate that shares no state with the running app, so it re-initializes
/// Firebase itself. We deliberately do NOT show a notification here — for
/// *notification* messages the OS already renders the system-tray notification
/// automatically; this handler exists so data-only messages can still be
/// processed (extend below if/when we send data-only pushes).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Intentionally minimal — see doc comment above.
}

/// Firebase Cloud Messaging (push notifications) wrapper.
///
/// Mirrors the singleton style of [LocalNotificationService] and reuses that
/// service's plugin + Android channels to render **foreground** pushes (Android
/// does not auto-display a tray notification while the app is in the
/// foreground, so we show one ourselves).
///
/// Platform notes:
///  * Only Android/iOS are supported — desktop/web have no `google-services`
///    config in this project, so [init] is a no-op there and can't crash them.
///  * Android 13+ POST_NOTIFICATIONS permission is handled elsewhere, on the
///    first resumed frame (see `_NotificationPermissionRequester` in main.dart),
///    so we skip requesting it here to preserve that reliable cold-start flow.
///    Only iOS requests permission from within [init].
class FirebaseMessagingService {
  FirebaseMessagingService._();
  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  bool _ready = false;
  String? _token;

  /// The current FCM registration token (null until [init] completes, or on
  /// unsupported platforms). Send this to your server to target this device.
  String? get token => _token;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> init() async {
    if (!_supported || _ready) return;

    // Reads credentials from android/app/google-services.json on Android.
    await Firebase.initializeApp();

    final messaging = FirebaseMessaging.instance;

    // Register the background/terminated handler before wiring foreground.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // iOS needs an explicit prompt; Android's is handled on first resume.
    if (Platform.isIOS) {
      await messaging.requestPermission();
    }

    // Let iOS show heads-up alerts while the app is foregrounded.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _token = await messaging.getToken();
    debugPrint('📲 FCM token: $_token');
    messaging.onTokenRefresh.listen((t) {
      _token = t;
      debugPrint('📲 FCM token refreshed: $t');
      // TODO: forward the refreshed token to your backend when one exists.
    });

    // Foreground messages: render via the local-notifications plugin so the
    // user actually sees them (the OS suppresses tray notifications here).
    FirebaseMessaging.onMessage.listen(_showForeground);

    // App opened by tapping a notification while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App cold-started by tapping a notification while terminated.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    _ready = true;
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return; // data-only message: nothing to display.
    LocalNotificationService.instance.showNow(
      idSeed: message.messageId ?? '${n.title}|${n.body}',
      title: n.title ?? 'Notification',
      body: n.body ?? '',
      // Optional server-provided channel/route via the message `data` map.
      channelId: message.data['channel'] ?? NotificationChannels.appAlerts,
      payload: message.data['route'],
    );
  }

  void _handleTap(RemoteMessage message) {
    final route = message.data['route'];
    if (route == null || route.isEmpty) return;
    navigatorKey.currentState?.pushNamed(route);
  }

  /// Subscribe this device to a broadcast [topic] (e.g. `all-restaurants`).
  Future<void> subscribeToTopic(String topic) async {
    if (!_supported) return;
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_supported) return;
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  }
}
