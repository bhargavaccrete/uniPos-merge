import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// SESSION INACTIVITY AUTO-LOGOUT TESTS — `RestaurantSession`.
///
/// The auto-logout fires when [RestaurantSession.sessionExpiredNotifier] flips
/// to true after the configured idle window passes with no touch. A touch calls
/// [RestaurantSession.resetInactivityTimer], restarting the window.
///
/// These drive the public timer API under a fake clock ([fakeAsync]) so the
/// whole multi-minute window elapses instantly and deterministically — no real
/// waiting, no flakiness.
void main() {
  setUp(() {
    // Reset shared static state to a known baseline before each test.
    RestaurantSession.sessionExpiredNotifier.value = false;
    RestaurantSession.timeoutMinutesNotifier.value = 15; // app default
  });

  test('expires after the configured idle window', () {
    fakeAsync((async) {
      RestaurantSession.timeoutMinutesNotifier.value = 5;
      RestaurantSession.resetInactivityTimer();

      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(RestaurantSession.sessionExpiredNotifier.value, isFalse,
          reason: 'must NOT expire before the window elapses');

      async.elapse(const Duration(seconds: 2));
      expect(RestaurantSession.sessionExpiredNotifier.value, isTrue,
          reason: 'must expire once the full window passes idle');
    });
  });

  test('a touch (resetInactivityTimer) restarts the full window', () {
    fakeAsync((async) {
      RestaurantSession.timeoutMinutesNotifier.value = 5;
      RestaurantSession.resetInactivityTimer();

      async.elapse(const Duration(minutes: 4)); // 4 of 5 in the first window
      RestaurantSession.resetInactivityTimer(); // "touch" → restart the window
      async.elapse(const Duration(minutes: 4)); // 4 of 5 in the NEW window
      expect(RestaurantSession.sessionExpiredNotifier.value, isFalse,
          reason: 'the reset should cancel the original 5-min deadline');

      async.elapse(const Duration(minutes: 1, seconds: 1)); // complete the new window
      expect(RestaurantSession.sessionExpiredNotifier.value, isTrue,
          reason: 'expires 5 min after the LAST touch, not the first');
    });
  });

  test('honours the timeout currently set in settings', () {
    fakeAsync((async) {
      RestaurantSession.timeoutMinutesNotifier.value = 1; // 1-minute setting
      RestaurantSession.resetInactivityTimer();

      async.elapse(const Duration(seconds: 59));
      expect(RestaurantSession.sessionExpiredNotifier.value, isFalse);

      async.elapse(const Duration(seconds: 2));
      expect(RestaurantSession.sessionExpiredNotifier.value, isTrue);
    });
  });
}
