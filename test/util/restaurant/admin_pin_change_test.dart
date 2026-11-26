import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/domain/services/retail/stock_alert_service.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';

/// `changeAdminPin` replaced two copies of the PIN-change logic (restaurant's
/// screen and retail's AuthService). These lock the behaviour both had, so
/// existing installs keep logging in.
void main() {
  const key = RestaurantAuthHelper.adminPinKey;

  Future<String?> change(String oldPin, String newPin, [String? confirm]) =>
      RestaurantAuthHelper.changeAdminPin(
        oldPin: oldPin,
        newPin: newPin,
        confirmPin: confirm ?? newPin,
      );

  Future<String?> stored() async =>
      (await SharedPreferences.getInstance()).getString(key);

  group('changeAdminPin — stored formats', () {
    test('hashed stored PIN: changes and stores the new hash', () async {
      SharedPreferences.setMockInitialValues({
        key: RestaurantAuthHelper.hashPassword('1111'),
      });
      expect(await change('1111', '2222'), isNull);
      expect(await stored(), RestaurantAuthHelper.hashPassword('2222'));
    });

    test('legacy plaintext stored PIN still verifies', () async {
      SharedPreferences.setMockInitialValues({key: '4321'});
      expect(await change('4321', '9876'), isNull);
      expect(await stored(), RestaurantAuthHelper.hashPassword('9876'));
    });

    test('missing key falls back to the default PIN', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await change(RestaurantAuthHelper.defaultAdminPin, '555555'),
        isNull,
      );
      expect(await stored(), RestaurantAuthHelper.hashPassword('555555'));
    });

    test('wrong current PIN is rejected and nothing is written', () async {
      final original = RestaurantAuthHelper.hashPassword('1111');
      SharedPreferences.setMockInitialValues({key: original});
      expect(await change('0000', '2222'), 'Current PIN is incorrect');
      expect(await stored(), original);
    });
  });

  group('changeAdminPin — validation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        key: RestaurantAuthHelper.hashPassword('1111'),
      });
    });

    test('rejects non-digits', () async {
      expect(await change('1111', '12ab'), 'PIN must be 4–6 digits');
    });

    test('rejects 3 and 7 digits', () async {
      expect(await change('1111', '123'), 'PIN must be 4–6 digits');
      expect(await change('1111', '1234567'), 'PIN must be 4–6 digits');
    });

    test('rejects a confirmation mismatch', () async {
      expect(await change('1111', '2222', '3333'), 'New PINs do not match');
    });

    test('rejects the same PIN', () async {
      expect(
        await change('1111', '1111'),
        'New PIN must be different from current PIN',
      );
    });

    test('rejects empty fields', () async {
      expect(await change('', '2222'), 'Current PIN is required');
      expect(await change('1111', ''), 'New PIN is required');
    });
  });

  group('StockAlertService.optionsIncluding', () {
    test('a preset returns the presets unchanged', () {
      expect(
        StockAlertService.optionsIncluding(10),
        StockAlertService.thresholdOptions,
      );
    });

    test('a custom value is added in sorted position', () {
      expect(StockAlertService.optionsIncluding(7), [5, 7, 10, 15, 20, 25, 50]);
      expect(StockAlertService.optionsIncluding(3).first, 3);
      expect(StockAlertService.optionsIncluding(80).last, 80);
    });
  });
}
