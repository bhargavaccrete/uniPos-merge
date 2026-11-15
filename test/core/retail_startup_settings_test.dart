import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/init/retail_startup.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

/// WF-2: Retail never loaded `AppSettings`, so its round-off and refund lock
/// and window fell back to defaults on every restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved round-off and refund settings are restored at startup', () async {
    // What Retail's Settings screen saved before the restart.
    SharedPreferences.setMockInitialValues({
      'Round Off': true,
      'Allow Refunds': false,
      'refundWindowMinutes': 45,
    });
    // A fresh process starts from the defaults.
    expect(AppSettings.roundOff, isFalse);

    await loadRetailStartupSettings();

    expect(AppSettings.roundOff, isTrue);
    expect(AppSettings.refundsEnabled, isFalse);
    expect(AppSettings.refundWindowMinutes, 45);
  });
}
