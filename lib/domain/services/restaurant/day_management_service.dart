import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

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

  /// Daily bill numbering lives on the restaurant OrderStore, which is only
  /// registered in restaurant mode. Retail shares this service for its own
  /// day/EOD lifecycle, so skip the reset rather than blowing up on a missing
  /// DI registration.
  static Future<void> _resetDailyBillNumberIfAvailable() async {
    if (!locator.isRegistered<OrderStore>()) return;
    await orderStore.resetDailyBillNumber();
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

    await _resetDailyBillNumberIfAvailable();

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
    
    await _resetDailyBillNumberIfAvailable();
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
    final isOldSession = session.startTime.day != today.day ||
        session.startTime.month != today.month ||
        session.startTime.year != today.year;

    if (!isOldSession) return false;

    // Check if user snoozed the alert for today
    final prefs = await SharedPreferences.getInstance();
    final snoozedDate = prefs.getString('pendingEod_snoozed_date');
    final todayKey = '${today.year}-${today.month}-${today.day}';
    if (snoozedDate == todayKey) return false;

    return true;
  }

  /// Snooze the pending EOD alert for today. Alert returns tomorrow if still not closed.
  static Future<void> snoozeEODAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    await prefs.setString('pendingEod_snoozed_date', todayKey);
  }

  /// Clear the snooze (called when EOD is actually completed).
  static Future<void> clearEODSnooze() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pendingEod_snoozed_date');
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

  static Future<bool> isEodStrictlyPending() async {
    final session = await getCurrentSession();
    if (session == null || session.isClosed) return false;

    // Check configuration from AppSettings
    final isAutoCloseEnabled = AppSettings.autoCloseStaleShift;
    final maxDurationHours = AppSettings.maxSessionDurationHours;

    if (!isAutoCloseEnabled) return false;

    final today = DateTime.now();
    final sessionDuration = today.difference(session.startTime);

    return sessionDuration.inHours >= maxDurationHours;
  }

  static Future<DateTime> calculateLatestBusinessActivity(dynamic shift) async {
    DateTime latestTime = shift.startTime;

    // 1. Orders
    try {
      if (Hive.isBoxOpen(HiveBoxNames.restaurantPastOrders)) {
        final pastOrderBox = Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
        final allOrders = pastOrderBox.values.toList();
        final end = shift.endTime ?? DateTime.now();

        final shiftOrders = allOrders.where((o) {
          if (o.shiftId == shift.id) return true;
          if (o.shiftId != null) return false;
          return o.orderAt != null &&
              o.orderAt!.isAfter(shift.startTime.subtract(const Duration(seconds: 1))) &&
              o.orderAt!.isBefore(end.add(const Duration(seconds: 1)));
        }).toList();

        for (final o in shiftOrders) {
          if (o.orderAt != null && o.orderAt!.isAfter(latestTime)) {
            latestTime = o.orderAt!;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching orders for shift activity: $e');
    }

    // 1b. Active (unsettled) orders — a session frozen with open tables still
    // had recent work; their creation/last-update time counts as activity.
    // (KOT status changes aren't separately timestamped, so timeStamp/completedAt
    // is the available proxy for "last order update".)
    try {
      if (Hive.isBoxOpen(HiveBoxNames.restaurantOrders)) {
        final orderBox = Hive.box<OrderModel>(HiveBoxNames.restaurantOrders);
        final end = shift.endTime ?? DateTime.now();
        final windowStart = shift.startTime.subtract(const Duration(seconds: 1));
        final windowEnd = end.add(const Duration(seconds: 1));
        for (final o in orderBox.values) {
          for (final ts in [o.timeStamp, o.completedAt]) {
            if (ts != null &&
                ts.isAfter(windowStart) &&
                ts.isBefore(windowEnd) &&
                ts.isAfter(latestTime)) {
              latestTime = ts;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching active orders for shift activity: $e');
    }

    // 2. Cash Movements
    try {
      if (Hive.isBoxOpen(HiveBoxNames.restaurantCashMovements)) {
        final cashBox = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
        final end = shift.endTime ?? DateTime.now();
        final movements = cashBox.values.where((m) =>
            m.timestamp.isAfter(shift.startTime) &&
            m.timestamp.isBefore(end)).toList();

        for (final m in movements) {
          if (m.timestamp.isAfter(latestTime)) {
            latestTime = m.timestamp;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching cash movements for shift activity: $e');
    }

    // 3. Expenses
    try {
      if (Hive.isBoxOpen(HiveBoxNames.restaurantExpense)) {
        final expenseBox = Hive.box<Expense>(HiveBoxNames.restaurantExpense);
        final end = shift.endTime ?? DateTime.now();
        final expenses = expenseBox.values.where((e) =>
            e.dateandTime.isAfter(shift.startTime) &&
            e.dateandTime.isBefore(end)).toList();

        for (final e in expenses) {
          if (e.dateandTime.isAfter(latestTime)) {
            latestTime = e.dateandTime;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching expenses for shift activity: $e');
    }

    return latestTime;
  }

  /// Latest business activity across the WHOLE current session (not one shift) —
  /// used to freeze ORPHAN attendance (open records whose shift is already
  /// closed) at the real end of work instead of DateTime.now().
  static Future<DateTime> calculateSessionLastActivity() async {
    final session = await getCurrentSession();
    final start = session?.startTime ?? DateTime.now();
    final now = DateTime.now();
    DateTime latest = start;
    void bump(DateTime? t) {
      if (t != null && t.isAfter(latest) && !t.isAfter(now)) latest = t;
    }

    try {
      if (Hive.isBoxOpen(HiveBoxNames.restaurantPastOrders)) {
        for (final o in Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).values) {
          if (o.orderAt != null && !o.orderAt!.isBefore(start)) bump(o.orderAt);
        }
      }
      if (Hive.isBoxOpen(HiveBoxNames.restaurantOrders)) {
        for (final o in Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).values) {
          bump(o.timeStamp);
          bump(o.completedAt);
        }
      }
      if (Hive.isBoxOpen(HiveBoxNames.restaurantCashMovements)) {
        for (final m in Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements).values) {
          if (!m.timestamp.isBefore(start)) bump(m.timestamp);
        }
      }
      if (Hive.isBoxOpen(HiveBoxNames.restaurantExpense)) {
        for (final e in Hive.box<Expense>(HiveBoxNames.restaurantExpense).values) {
          if (!e.dateandTime.isBefore(start)) bump(e.dateandTime);
        }
      }
    } catch (e) {
      debugPrint('Error computing session last activity: $e');
    }
    return latest;
  }
}
