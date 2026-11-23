import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/core/init/crash_reporting.dart';

class _FakeSink implements CrashSink {
  bool? collectionEnabled;
  final errors = <({Object error, bool fatal, String? reason})>[];
  final flutterErrors = <({FlutterErrorDetails details, bool fatal})>[];
  final keys = <String, String>{};
  bool throwOnEnable = false;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (throwOnEnable) throw StateError('no firebase');
    collectionEnabled = enabled;
  }

  @override
  Future<void> recordError(Object error, StackTrace? stack,
          {required bool fatal, String? reason}) async =>
      errors.add((error: error, fatal: fatal, reason: reason));

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details,
          {required bool fatal}) async =>
      flutterErrors.add((details: details, fatal: fatal));

  @override
  Future<void> setCustomKey(String key, String value) async =>
      keys[key] = value;
}

/// Crashlytics: release-only, Android/iOS only, safe metadata only.
void main() {
  late _FakeSink sink;

  setUp(() {
    CrashReporting.resetForTesting();
    sink = _FakeSink();
  });

  tearDown(CrashReporting.resetForTesting);

  group('release build', () {
    setUp(() => CrashReporting.init(release: true, supported: true, sink: sink));

    test('collection is switched on', () {
      expect(sink.collectionEnabled, isTrue);
      expect(CrashReporting.isCollecting, isTrue);
    });

    test('an uncaught error is recorded as fatal', () {
      CrashReporting.recordError(StateError('boom'), StackTrace.current,
          fatal: true);
      expect(sink.errors.single.fatal, isTrue);
    });

    test('a recovered startup error is non-fatal with a fixed reason', () {
      CrashReporting.recordError(StateError('box'), null,
          fatal: false, reason: 'hive_startup_blocked');
      expect(sink.errors.single.fatal, isFalse);
      expect(sink.errors.single.reason, 'hive_startup_blocked');
    });

    test('a Flutter framework error is recorded as fatal', () {
      CrashReporting.recordFlutterError(
          FlutterErrorDetails(exception: StateError('layout')));
      expect(sink.flutterErrors.single.fatal, isTrue);
    });

    test('only business mode, plan and app version are attached', () async {
      await CrashReporting.setContext(
          businessMode: 'restaurant', plan: 'Premium', appVersion: '1.2.0+7');
      expect(sink.keys, {
        CrashReporting.businessModeKey: 'restaurant',
        CrashReporting.planKey: 'Premium',
        CrashReporting.appVersionKey: '1.2.0+7',
      });
    });
  });

  group('debug and profile builds', () {
    setUp(() =>
        CrashReporting.init(release: false, supported: true, sink: sink));

    test('collection is switched off and nothing is recorded', () async {
      expect(sink.collectionEnabled, isFalse);
      expect(CrashReporting.isCollecting, isFalse);
      CrashReporting.recordError(StateError('x'), null, fatal: true);
      CrashReporting.recordFlutterError(
          FlutterErrorDetails(exception: StateError('y')));
      await CrashReporting.setContext(
          businessMode: 'retail', plan: 'Free', appVersion: '1.0.0+1');
      expect(sink.errors, isEmpty);
      expect(sink.flutterErrors, isEmpty);
      expect(sink.keys, isEmpty);
    });
  });

  test('Windows / web: nothing is initialised or recorded', () async {
    await CrashReporting.init(release: true, supported: false, sink: sink);
    expect(sink.collectionEnabled, isNull);
    expect(CrashReporting.isCollecting, isFalse);
    CrashReporting.recordError(StateError('x'), null, fatal: true);
    expect(sink.errors, isEmpty);
  });

  test('a Firebase failure never throws and turns reporting off', () async {
    sink.throwOnEnable = true;
    await CrashReporting.init(release: true, supported: true, sink: sink);
    expect(CrashReporting.isCollecting, isFalse);
    CrashReporting.recordError(StateError('x'), null, fatal: true);
    expect(sink.errors, isEmpty);
  });
}
