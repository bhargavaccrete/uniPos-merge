import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/util/common/pin_attempt_guard.dart';

/// AND-12: five wrong PINs in a row lock PIN login on this device for 30 s,
/// then 60, 120, 240 and at most 300 s; any successful login clears it.
void main() {
  final t0 = DateTime(2026, 11, 20, 10);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// [n] wrong PINs at [at]; returns the lock the last one started, if any.
  Future<Duration?> fail(int n, DateTime at) async {
    Duration? lock;
    for (var i = 0; i < n; i++) {
      lock = await PinAttemptGuard.recordFailure(now: at);
    }
    return lock;
  }

  test('4 wrong PINs do not lock; the 5th locks for 30 s', () async {
    expect(await fail(4, t0), isNull);
    expect(await PinAttemptGuard.remainingLock(now: t0), isNull);
    expect(await fail(1, t0), const Duration(seconds: 30));
    expect(await PinAttemptGuard.remainingLock(now: t0),
        const Duration(seconds: 30));
    expect(
        await PinAttemptGuard.remainingLock(
            now: t0.add(const Duration(seconds: 10))),
        const Duration(seconds: 20));
  });

  test('locks grow 30, 60, 120, 240, then stay at 300 s', () async {
    var at = t0;
    final seen = <int>[];
    for (var i = 0; i < 7; i++) {
      final lock = (await fail(5, at))!;
      seen.add(lock.inSeconds);
      at = at.add(lock + const Duration(seconds: 1));
    }
    expect(seen, [30, 60, 120, 240, 300, 300, 300]);
  });

  test('a wrong PIN during a lock neither counts nor extends it', () async {
    await fail(5, t0);
    expect(await fail(3, t0.add(const Duration(seconds: 5))), isNull);
    final after = t0.add(const Duration(seconds: 31));
    expect(await PinAttemptGuard.remainingLock(now: after), isNull);
    expect(await fail(4, after), isNull,
        reason: 'the count starts again from 0 after the lock');
  });

  test('a successful login clears the count and the lock length', () async {
    var at = t0;
    for (var i = 0; i < 3; i++) {
      final lock = (await fail(5, at))!;
      at = at.add(lock + const Duration(seconds: 1));
    }
    await fail(4, at);
    await PinAttemptGuard.recordSuccess();
    expect(await fail(4, at), isNull, reason: '4 is under the limit again');
    expect(await fail(1, at), const Duration(seconds: 30),
        reason: 'back to the first lock length');
  });

  test('a lock survives a restart and reopening the login screen', () async {
    await fail(5, t0);
    final prefs = await SharedPreferences.getInstance();
    final saved = {
      for (final k in [
        PinAttemptGuard.failuresKey,
        PinAttemptGuard.levelKey,
        PinAttemptGuard.untilKey,
      ])
        if (prefs.get(k) != null) k: prefs.get(k)!,
    };
    // A new process: only what was written to disk remains.
    SharedPreferences.setMockInitialValues(saved);
    expect(
        await PinAttemptGuard.remainingLock(
            now: t0.add(const Duration(seconds: 12))),
        const Duration(seconds: 18));
  });

  test('a clock set backwards never means a wait over 5 minutes', () async {
    await fail(5, t0);
    final earlier = t0.subtract(const Duration(days: 2));
    expect(await PinAttemptGuard.remainingLock(now: earlier),
        PinAttemptGuard.maxLock);
    expect(
        await PinAttemptGuard.remainingLock(
            now: earlier.add(const Duration(minutes: 5, seconds: 1))),
        isNull,
        reason: 'the lock is re-anchored, so it does end');
  });

  test('the message shows minutes and seconds, rounded up', () {
    expect(PinAttemptGuard.lockedMessage(const Duration(milliseconds: 29001)),
        'Too many incorrect PINs. Try again in 0:30');
    expect(PinAttemptGuard.lockedMessage(const Duration(seconds: 300)),
        'Too many incorrect PINs. Try again in 5:00');
  });

  test('lockout keys are never backed up or restored', () {
    for (final k in [
      PinAttemptGuard.failuresKey,
      PinAttemptGuard.levelKey,
      PinAttemptGuard.untilKey,
    ]) {
      expect(UnifiedBackupService.prefTravelsWithBackup(k), isFalse, reason: k);
    }
    expect(UnifiedBackupService.prefTravelsWithBackup('restaurant_admin_password'),
        isTrue,
        reason: 'the admin PIN itself still travels with a backup');
  });
}
