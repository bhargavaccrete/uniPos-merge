// The test drives print on purpose: it checks where print output goes.
// ignore_for_file: avoid_print
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/core/init/release_logging.dart';

/// AND-34: release builds write no app logs; debug/profile keep them.
void main() {
  /// Runs [body] the way main.dart runs the app: an outer zone with the
  /// release rules, around runZonedGuarded. Returns every line that reached
  /// the real `print`.
  Future<List<String>> printedBy(void Function() body,
      {required bool release}) async {
    final out = <String>[];
    final done = Completer<void>();
    runZoned(
      () => runZoned(
        () {
          runZonedGuarded(() {
            body();
            done.complete();
          }, (error, stack) {
            print('zone error: $error');
            if (!done.isCompleted) done.complete();
          });
        },
        zoneSpecification: releaseLogZone(release: release),
      ),
      // Captures what would have reached the console.
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => out.add(line),
      ),
    );
    await done.future;
    await Future<void>.delayed(Duration.zero);
    return out;
  }

  test('release: print inside the app zone is dropped', () async {
    expect(await printedBy(() => print('licence key ABC'), release: true),
        isEmpty);
  });

  test('release: the zone error handler\'s print is dropped too', () async {
    final out = await printedBy(() => throw StateError('boom'), release: true);
    expect(out, isEmpty);
  });

  test('debug/profile: print still reaches the console', () async {
    expect(await printedBy(() => print('hello'), release: false), ['hello']);
  });

  test('debug/profile: the zone error handler still logs', () async {
    final out = await printedBy(() => throw StateError('boom'), release: false);
    expect(out.single, contains('boom'));
  });

  group('debugPrint', () {
    final original = debugPrint;
    tearDown(() => debugPrint = original);

    test('release: debugPrint is replaced by a no-op', () {
      silenceDebugPrintInRelease(release: true);
      expect(identical(debugPrint, original), isFalse);
      debugPrint('OTP 123456'); // must not throw
    });

    test('debug/profile: debugPrint is left as it was', () {
      silenceDebugPrintInRelease(release: false);
      expect(identical(debugPrint, original), isTrue);
    });
  });
}
