import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/cash_movement_model.dart';

class DayManagementService {
  static const String _boxName = 'dayManagementBox';
  static const String _openingBalanceKey = 'openingBalance';
  static const String _dayStartedKey = 'dayStarted';
  static const String _lastDayDateKey = 'lastDayDate';
  static const String _dayStartTimestampKey = 'dayStartTimestamp'; // NEW: Track exact start time
  static const String _closingBalanceKey = 'closingBalance'; // Persists last day's closing cash
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
    final now = DateTime.now();

    debugPrint('🆕 Starting new day...');
    debugPrint('   Opening balance: $balance');
    debugPrint('   Timestamp: $now');

    await box.put(_openingBalanceKey, balance);
    await box.put(_dayStartedKey, true);
    await box.put(_lastDayDateKey, now.toIso8601String());
    await box.put(_dayStartTimestampKey, now.toIso8601String()); // Store exact start timestamp

    // Reset daily bill number counter for the new day
    await orderStore.resetDailyBillNumber();

    // Clear the last EOD completion date when starting a new day
    // This ensures End Day screen shows data for the new day
    final prefs = await SharedPreferences.getInstance();

    // Check if last_eod_date exists before removal
    final existingEODDate = prefs.getString('last_eod_date');
    debugPrint('   Existing last_eod_date before removal: $existingEODDate');

    final removed = await prefs.remove('last_eod_date');
    debugPrint('   Cleared last_eod_date: $removed');

    // Verify it was actually removed
    final afterRemoval = prefs.getString('last_eod_date');
    debugPrint('   last_eod_date after removal: $afterRemoval (should be null)');

    // Persist opening balance as an immutable ledger entry so the cash drawer
    // history is self-contained and does not depend on the dayManagementBox scalar.
    if (Hive.isBoxOpen(HiveBoxNames.restaurantCashMovements)) {
      final cashBox = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
      final entry = CashMovementModel(
        id: const Uuid().v4(),
        timestamp: now,
        type: 'opening',
        amount: balance,
        reason: 'Day Start — Carry Forward',
        note: null,
        staffName: 'System',
      );
      await cashBox.put(entry.id, entry);
      debugPrint('   Opening balance transaction recorded: Rs.$balance');
    }

    debugPrint('✅ New day started successfully!');
  }

  /// Get the current opening balance
  static Future<double> getOpeningBalance() async {
    final box = _getBox();
    final balance = box.get(_openingBalanceKey, defaultValue: 0.0);
    return (balance as num?)?.toDouble() ?? 0.0;
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

      // If calendar date changed AND the day was already ended (started=false),
      // then it's truly a new day needing Start Day.
      // BUT if started=true and date changed, there's a PENDING EOD from yesterday.
      if (lastDayDate.day != today.day ||
          lastDayDate.month != today.month ||
          lastDayDate.year != today.year) {
        // If previous day was still "started" (EOD never completed), keep it started
        // so the user can complete EOD before starting a new day.
        if (started == true) {
          return true; // Pending EOD — allow completing it
        }
        return false;
      }
    }

    return started == true;
  }

  /// Check if there is a pending EOD from a previous day (midnight crossed without EOD)
  static Future<bool> hasPendingEOD() async {
    final box = _getBox();
    final started = box.get(_dayStartedKey, defaultValue: false);
    if (started != true) return false;

    final lastDayDateStr = box.get(_lastDayDateKey);
    if (lastDayDateStr == null) return false;

    final lastDayDate = DateTime.parse(lastDayDateStr);
    final today = DateTime.now();
    return lastDayDate.day != today.day ||
        lastDayDate.month != today.month ||
        lastDayDate.year != today.year;
  }

  /// Reset the day (called automatically when a NEW calendar day is detected).
  /// Clears all balance/timestamp data so the next day starts fresh.
  static Future<void> resetDay() async {
    final box = _getBox();
    await box.put(_openingBalanceKey, 0.0);
    await box.put(_dayStartedKey, false);
    await box.delete(_dayStartTimestampKey);

    // Reset daily bill number counter
    await orderStore.resetDailyBillNumber();

    debugPrint('Day reset - opening balance cleared, bill counter reset');
  }

  /// Mark the current day as ended (called from End Day screen).
  /// Preserves opening balance and timestamp so Cash Drawer can still display
  /// today's totals in read-only mode until the next day's Start Day.
  /// [closingBalance] is the actual cash counted — persisted as opening suggestion for next day.
  static Future<void> markDayEnded({double closingBalance = 0.0}) async {
    final box = _getBox();
    await box.put(_dayStartedKey, false);
    await box.put(_closingBalanceKey, closingBalance);
    // Reset daily bill number counter
    await orderStore.resetDailyBillNumber();
    debugPrint('Day ended - closing balance: $closingBalance, balance/timestamp preserved');
  }

  /// Get the closing balance from the last ended day (used to pre-fill next day's opening).
  static Future<double> getLastClosingBalance() async {
    final box = _getBox();
    final balance = box.get(_closingBalanceKey, defaultValue: 0.0);
    // Use num cast — Hive can return whole-number doubles as int on some platforms
    return (balance as num?)?.toDouble() ?? 0.0;
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

  /// Get the day start timestamp (when "Start Day" was clicked)
  static Future<DateTime?> getDayStartTimestamp() async {
    final box = _getBox();
    final timestampStr = box.get(_dayStartTimestampKey);
    if (timestampStr != null) {
      return DateTime.parse(timestampStr);
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