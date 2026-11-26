import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-wide lockout for PIN login (restaurant and retail).
///
/// Login is PIN-only, so a wrong PIN belongs to nobody: one counter per
/// device. Five wrong PINs in a row lock login for 30 s, then 60, 120, 240
/// and at most 300 s. Any successful admin or staff login clears it. State
/// lives in SharedPreferences so a restart or reopening the login screen
/// cannot clear it; the keys are excluded from backup and restore.
class PinAttemptGuard {
  PinAttemptGuard._();

  static const String failuresKey = 'pin_lockout_failures';
  static const String levelKey = 'pin_lockout_level';
  static const String untilKey = 'pin_lockout_until';

  static const int maxAttempts = 5;
  static const Duration baseLock = Duration(seconds: 30);
  static const Duration maxLock = Duration(minutes: 5);
  static const int _maxLevel = 10;

  /// Lock length for the [level]-th lock since the last success (0-based).
  static Duration lockFor(int level) {
    final seconds = baseLock.inSeconds * (1 << level.clamp(0, _maxLevel));
    return seconds >= maxLock.inSeconds ? maxLock : Duration(seconds: seconds);
  }

  /// Time left on an active lock, or null. Check BEFORE verifying a PIN.
  static Future<Duration?> remainingLock({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(untilKey);
    if (until == null) return null;
    final at = now ?? DateTime.now();
    final left = until - at.millisecondsSinceEpoch;
    if (left <= 0) {
      await prefs.remove(untilKey);
      return null;
    }
    if (left > maxLock.inMilliseconds) {
      // Clock moved backwards: never wait longer than the longest lock.
      await prefs.setInt(untilKey, at.add(maxLock).millisecondsSinceEpoch);
      return maxLock;
    }
    return Duration(milliseconds: left);
  }

  /// Records a PIN that matched nobody. Returns the lock length when this
  /// failure starts a lock, otherwise null.
  static Future<Duration?> recordFailure({DateTime? now}) async {
    final at = now ?? DateTime.now();
    if (await remainingLock(now: at) != null) return null;
    final prefs = await SharedPreferences.getInstance();
    final failures = (prefs.getInt(failuresKey) ?? 0) + 1;
    if (failures < maxAttempts) {
      await prefs.setInt(failuresKey, failures);
      return null;
    }
    final level = prefs.getInt(levelKey) ?? 0;
    final lock = lockFor(level);
    await prefs.setInt(untilKey, at.add(lock).millisecondsSinceEpoch);
    await prefs.setInt(levelKey, level >= _maxLevel ? _maxLevel : level + 1);
    await prefs.setInt(failuresKey, 0);
    return lock;
  }

  /// Clears the counter and lock length after a successful login.
  static Future<void> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(failuresKey);
    await prefs.remove(levelKey);
    await prefs.remove(untilKey);
  }

  static String lockedMessage(Duration left) {
    final total = (left.inMilliseconds / 1000).ceil();
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return 'Too many incorrect PINs. Try again in $m:$s';
  }
}

/// Countdown for a login screen while [PinAttemptGuard] is locked.
mixin PinLockoutCountdown<T extends StatefulWidget> on State<T> {
  Timer? _lockTimer;
  DateTime? _lockEnds;
  Duration? pinLockRemaining;

  bool get isPinLocked => pinLockRemaining != null;

  /// Reads the stored lock (call from initState) so a lock survives reopening.
  Future<void> loadPinLock() async {
    final left = await PinAttemptGuard.remainingLock();
    if (mounted) startPinLockCountdown(left);
  }

  void startPinLockCountdown(Duration? left) {
    _lockTimer?.cancel();
    _lockEnds = left == null ? null : DateTime.now().add(left);
    setState(() => pinLockRemaining = left);
    if (left == null) return;
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final rest = _lockEnds!.difference(DateTime.now());
      if (rest <= Duration.zero) {
        _lockTimer?.cancel();
        setState(() => pinLockRemaining = null);
      } else {
        setState(() => pinLockRemaining = rest);
      }
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }
}
