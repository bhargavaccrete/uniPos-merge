import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';

/// Opens a restaurant business session the way Start Day does: a session
/// record plus `currentSessionId` in the day-management box.
///
/// Refunds require an open session (SB-2b-M8), so tests that issue refunds
/// call this in their setup. Needs `dayManagementBox` already open and the
/// restaurant adapters registered.
Future<void> openRestaurantSessionForTest({
  String sessionId = 'test-session',
  bool closed = false,
  DateTime? startTime,
}) async {
  final sessions = Hive.isBoxOpen(HiveBoxNames.restaurantSessions)
      ? Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions)
      : await Hive.openBox<RestaurantSessionModel>(
          HiveBoxNames.restaurantSessions);
  await sessions.put(
    sessionId,
    RestaurantSessionModel(
      sessionId: sessionId,
      startTime: startTime ?? DateTime.now().subtract(const Duration(hours: 1)),
      openingCash: 0,
      isClosed: closed,
    ),
  );
  await Hive.box(HiveBoxNames.dayManagementBox)
      .put('currentSessionId', sessionId);
}
