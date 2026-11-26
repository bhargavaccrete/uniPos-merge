import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';

/// Why a retail money action cannot run right now.
enum RetailDayBlock { eodPending, dayNotStarted }

/// The one retail rule for "is the day open for money to move?".
///
/// Billing (POS), returns, exchanges and credit collections all go through
/// this. Retail End of Day counts sales and cash movements from the moment the
/// day was STARTED until it is closed, so anything done while no day is open
/// falls outside every EOD — and while an EOD is pending the drawer refuses
/// new cash movements, so a collection would update the balance with no Cash
/// In row.
class RetailDayGate {
  RetailDayGate._();

  /// Null when the day is open; otherwise why not.
  ///
  /// Both pending checks, because they answer different questions:
  /// `isEodStrictlyPending` is a DURATION rule (session older than the
  /// auto-close window), `hasPendingEOD` a CALENDAR rule (the open session
  /// belongs to an earlier day).
  static Future<RetailDayBlock?> check() async {
    if (await DayManagementService.isEodStrictlyPending() ||
        await DayManagementService.hasPendingEOD()) {
      return RetailDayBlock.eodPending;
    }
    if (!await DayManagementService.isDayStarted()) {
      return RetailDayBlock.dayNotStarted;
    }
    return null;
  }

  static String messageFor(RetailDayBlock block) => switch (block) {
        RetailDayBlock.eodPending =>
          'Complete End of Day for the previous day first.',
        RetailDayBlock.dayNotStarted => 'Start the day first.',
      };

  /// Throws with the reason when the day is not open. For services, where
  /// the check must run before anything is written.
  static Future<void> ensureOpen() async {
    final block = await check();
    if (block != null) throw Exception(messageFor(block));
  }
}
