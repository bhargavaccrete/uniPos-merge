import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:billberrylite/firebase_options.dart';

/// Where crash reports go. [FirebaseCrashSink] in the app; a fake in tests.
abstract class CrashSink {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> recordError(Object error, StackTrace? stack,
      {required bool fatal, String? reason});
  Future<void> recordFlutterError(FlutterErrorDetails details,
      {required bool fatal});
  Future<void> setCustomKey(String key, String value);
}

class FirebaseCrashSink implements CrashSink {
  FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _c.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> recordError(Object error, StackTrace? stack,
          {required bool fatal, String? reason}) =>
      _c.recordError(error, stack, fatal: fatal, reason: reason);

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details,
          {required bool fatal}) =>
      fatal
          ? _c.recordFlutterFatalError(details)
          : _c.recordFlutterError(details);

  @override
  Future<void> setCustomKey(String key, String value) =>
      _c.setCustomKey(key, value);
}

/// Firebase Crashlytics for release builds on Android/iOS.
///
/// * Debug and profile builds never send a report (collection disabled).
/// * Windows and web: nothing is initialised; every call is a no-op.
/// * Never throws — a reporting failure must not break startup.
/// * Privacy: the only custom keys are [setContext]'s business mode, plan
///   label and app version. Nothing here attaches licence data, phone
///   numbers, customer/staff data, PINs, passwords or payment details, and no
///   logs or breadcrumbs are sent.
class CrashReporting {
  CrashReporting._();

  static const String businessModeKey = 'business_mode';
  static const String planKey = 'plan';
  static const String appVersionKey = 'app_version';

  static CrashSink? _sink;
  static bool _collecting = false;

  /// True when reports from this process are sent (release, supported).
  static bool get isCollecting => _sink != null && _collecting;

  static bool get _platformSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Starts Firebase and Crashlytics. Call before anything that can fail at
  /// startup (Hive). Firebase init is local — no network wait.
  static Future<void> init({
    bool release = kReleaseMode,
    bool? supported,
    CrashSink? sink,
  }) async {
    if (!(supported ?? _platformSupported)) return;
    try {
      if (sink == null) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform);
        }
        sink = FirebaseCrashSink();
      }
      await sink.setCollectionEnabled(release);
      _sink = sink;
      _collecting = release;
    } catch (_) {
      _sink = null;
      _collecting = false;
    }
  }

  /// A Flutter framework error (FlutterError.onError).
  static void recordFlutterError(FlutterErrorDetails details) {
    if (!isCollecting) return;
    _sink!.recordFlutterError(details, fatal: true).catchError((_) {});
  }

  /// An uncaught error ([fatal]) or one the app recovered from (non-fatal).
  /// [reason] must be a fixed label, never user or business data.
  static void recordError(Object error, StackTrace? stack,
      {required bool fatal, String? reason}) {
    if (!isCollecting) return;
    _sink!
        .recordError(error, stack, fatal: fatal, reason: reason)
        .catchError((_) {});
  }

  /// The only metadata attached to reports.
  static Future<void> setContext({
    required String businessMode,
    required String plan,
    required String appVersion,
  }) async {
    if (!isCollecting) return;
    try {
      await _sink!.setCustomKey(businessModeKey, businessMode);
      await _sink!.setCustomKey(planKey, plan);
      await _sink!.setCustomKey(appVersionKey, appVersion);
    } catch (_) {}
  }

  @visibleForTesting
  static void resetForTesting() {
    _sink = null;
    _collecting = false;
  }
}
