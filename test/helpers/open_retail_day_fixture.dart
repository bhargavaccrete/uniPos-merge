import 'open_session_fixture.dart';

/// Opens a retail day the way Start Day does (retail shares the restaurant
/// session store).
///
/// Returns, exchanges and credit collections need an open day (BLK-16), so
/// tests that run them call this in their setup. Started TODAY — an hour ago,
/// or at midnight if that is later — so the "session belongs to an earlier
/// day" (pending End of Day) rule can never trip just after midnight. Needs
/// `dayManagementBox` open and the retail adapters registered.
Future<void> openRetailDayForTest() {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  final hourAgo = now.subtract(const Duration(hours: 1));
  return openRestaurantSessionForTest(
    startTime: hourAgo.isBefore(midnight) ? midnight : hourAgo,
  );
}
