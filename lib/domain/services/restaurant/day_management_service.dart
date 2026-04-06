import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/cash_movement_model.dart';
import 'package:unipos/data/models/restaurant/db/session_model.dart';

class DayManagementService {
  static const String _boxName = 'dayManagementBox';
  static const String _openingBalanceKey = 'openingBalance';
  static const String _dayStartedKey = 'dayStarted';
  static const String _lastDayDateKey = 'lastDayDate';
  static const String _dayStartTimestampKey = 'dayStartTimestamp';
  static const String _closingBalanceKey = 'closingBalance';
  static const String _currentSessionIdKey = 'currentSessionId';
  static Box? _box;

  static Box _getBox() {
    if (_box == null || !_box!.isOpen) {
      _box = Hive.box(_boxName);
    }
    return _box!;
  }

  static Box<RestaurantSessionModel> _getSessionBox() {
    return Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  }

  /// Start a new POS session
  static Future<String> startSession(double openingCash) async {
    final box = _getBox();
    final sessionBox = _getSessionBox();
    final now = DateTime.now();
    final sessionId = const Uuid().v4();

    final session = RestaurantSessionModel(
      sessionId: sessionId,
      startTime: now,
      openingCash: openingCash,
      isClosed: false,
    );

    await sessionBox.put(sessionId, session);
    await box.put(_currentSessionIdKey, sessionId);
    
    // Maintain legacy flags for UI compatibility
    await box.put(_openingBalanceKey, openingCash);
    await box.put(_dayStartedKey, true);
    await box.put(_lastDayDateKey, now.toIso8601String());
    await box.put(_dayStartTimestampKey, now.toIso8601String());

    await orderStore.resetDailyBillNumber();

    // Clear legacy last_eod_date
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_eod_date');

    // Record opening balance movement
    if (Hive.isBoxOpen(HiveBoxNames.restaurantCashMovements)) {
      final cashBox = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
      final entry = CashMovementModel(
        id: const Uuid().v4(),
        timestamp: now,
        type: 'opening',
        amount: openingCash,
        reason: 'Session Start — Carry Forward',
        note: 'Session ID: $sessionId',
        staffName: 'System',
      );
      await cashBox.put(entry.id, entry);
    }

    debugPrint('🆕 Session started: $sessionId with opening cash: $openingCash');
    return sessionId;
  }

  /// Get the current session ID
  static Future<String?> getCurrentSessionId() async {
    final box = _getBox();
    return box.get(_currentSessionIdKey) as String?;
  }

  /// Get the current session object
  static Future<RestaurantSessionModel?> getCurrentSession() async {
    final sessionId = await getCurrentSessionId();
    if (sessionId == null) return null;
    final sessionBox = _getSessionBox();
    return sessionBox.get(sessionId);
  }

  /// End the current session
  static Future<void> endSession({double closingCash = 0.0}) async {
    final session = await getCurrentSession();
    if (session != null) {
      session.endTime = DateTime.now();
      session.closingCash = closingCash;
      session.isClosed = true;
      await session.save();
    }

    final box = _getBox();
    await box.put(_dayStartedKey, false);
    await box.put(_closingBalanceKey, closingCash);
    await box.delete(_currentSessionIdKey);
    
    await orderStore.resetDailyBillNumber();
    debugPrint('🏁 Session ended: ${session?.sessionId}, closing cash: $closingCash');
  }

  /// Check if a session is currently open
  static Future<bool> isSessionOpen() async {
    final session = await getCurrentSession();
    return session != null && !session.isClosed;
  }

  /// --- LEGACY COMPATIBILITY METHODS ---

  static Future<double> getOpeningBalance() async {
    final session = await getCurrentSession();
    return session?.openingCash ?? 0.0;
  }

  static Future<bool> isDayStarted() async {
    return await isSessionOpen();
  }

  static Future<bool> hasPendingEOD() async {
    final session = await getCurrentSession();
    if (session == null || session.isClosed) return false;

    final today = DateTime.now();
    return session.startTime.day != today.day ||
        session.startTime.month != today.month ||
        session.startTime.year != today.year;
  }

  static Future<double> getLastClosingBalance() async {
    final box = _getBox();
    final balance = box.get(_closingBalanceKey, defaultValue: 0.0);
    return (balance as num?)?.toDouble() ?? 0.0;
  }

  static Future<DateTime?> getDayStartTimestamp() async {
    final session = await getCurrentSession();
    return session?.startTime;
  }

  static Future<void> setOpeningBalance(double balance) async {
    await startSession(balance);
  }

  static Future<void> markDayEnded({double closingBalance = 0.0}) async {
    await endSession(closingCash: closingBalance);
  }

  static Future<void> resetDay() async {
    await endSession();
  }
}
