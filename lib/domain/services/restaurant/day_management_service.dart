import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_order.dart';

class DayManagementService {
  static const String _boxName = 'dayManagementBox';
  static const String _openingBalanceKey = 'openingBalance';
  static const String _dayStartedKey = 'dayStarted';
  static const String _lastDayDateKey = 'lastDayDate';
  static Box? _box;

  static Box _getBox() {
    // Box is already opened during app startup in HiveInit
    if (_box == null || !_box!.isOpen) {
      _box = Hive.box(_boxName);
    }
    return _box!;
  }

  /// Set the opening balance for the current day
  static Future<void> setOpeningBalance(double balance) async {
    final box = _getBox();
    await box.put(_openingBalanceKey, balance);
    await box.put(_dayStartedKey, true);
    await box.put(_lastDayDateKey, DateTime.now().toIso8601String());
    debugPrint('Opening balance set to: $balance');
  }

  /// Get the current opening balance
  static Future<double> getOpeningBalance() async {
    final box = _getBox();
    final balance = box.get(_openingBalanceKey, defaultValue: 0.0);
    return balance is double ? balance : 0.0;
  }

  /// Check if the day has been started (opening balance set)
  static Future<bool> isDayStarted() async {
    final box = _getBox();
    final started = box.get(_dayStartedKey, defaultValue: false);

    // Check if it's a new day
    final lastDayDateStr = box.get(_lastDayDateKey);
    if (lastDayDateStr != null) {
      final lastDayDate = DateTime.parse(lastDayDateStr);
      final today = DateTime.now();

      // If it's a new day, reset the flag
      if (lastDayDate.day != today.day ||
          lastDayDate.month != today.month ||
          lastDayDate.year != today.year) {
        await resetDay();
        return false;
      }
    }

    return started == true;
  }

  /// Reset the day (called after End of Day)
  static Future<void> resetDay() async {
    final box = _getBox();
    await box.put(_openingBalanceKey, 0.0);
    await box.put(_dayStartedKey, false);

    // Reset daily bill number counter
    await HiveOrders.resetDailyBillNumber();

    debugPrint('Day reset - opening balance cleared, bill counter reset');
  }

  /// Get the last day's date
  static Future<DateTime?> getLastDayDate() async {
    final box = _getBox();
    final dateStr = box.get(_lastDayDateKey);
    if (dateStr != null) {
      return DateTime.parse(dateStr);
    }
    return null;
  }

  /// Clear all day management data
  static Future<void> clearAll() async {
    final box = _getBox();
    await box.clear();
    debugPrint('All day management data cleared');
  }
}