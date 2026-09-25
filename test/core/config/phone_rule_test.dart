import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/core/config/phone_rule.dart';

/// Pure tests — only the `*For(country, …)` forms are exercised. The zero-arg
/// getters read Hive via the service locator and belong to an integration test.
void main() {
  group('PhoneRule.validateFor — country not chosen yet', () {
    // The reason this API exists. Onboarding's phone box sits ABOVE the
    // country dropdown, so it is validated before the country is known. It
    // must not fall back to India and demand 10 digits for a number the user
    // has every right to be typing.
    test('a 9-digit number is accepted while the country is blank', () {
      expect(PhoneRule.validateFor('', '123456789'), isNull);
      expect(PhoneRule.validateFor(null, '123456789'), isNull);
      expect(PhoneRule.validateFor('   ', '123456789'), isNull);
    });

    test('the permissive E.164 range still applies at both ends', () {
      expect(PhoneRule.validateFor('', '1234567'), isNull); // 7 — min
      expect(PhoneRule.validateFor('', '123456789012345'), isNull); // 15 — max
      expect(PhoneRule.validateFor('', '123456'), isNotNull); // 6 — too short
      expect(
        PhoneRule.validateFor('', '1234567890123456'), // 16 — too long
        isNotNull,
      );
    });
  });

  group('PhoneRule.validateFor — India', () {
    test('exactly 10 digits passes', () {
      expect(PhoneRule.validateFor('India', '9876543210'), isNull);
      expect(PhoneRule.validateFor('india', '9876543210'), isNull);
      expect(PhoneRule.validateFor('  India  ', '9876543210'), isNull);
    });

    test('9 or 11 digits is rejected with the exact-length message', () {
      expect(
        PhoneRule.validateFor('India', '987654321'),
        'Phone number must be exactly 10 digits',
      );
      expect(
        PhoneRule.validateFor('India', '98765432101'),
        'Phone number must be exactly 10 digits',
      );
    });
  });

  group('PhoneRule.validateFor — rest of world', () {
    test('lengths India would reject are accepted elsewhere', () {
      for (final country in ['Germany', 'United States', 'Japan']) {
        expect(PhoneRule.validateFor(country, '123456789'), isNull); // 9
        expect(PhoneRule.validateFor(country, '12345678901'), isNull); // 11
      }
    });

    test('still bounded by 7–15', () {
      expect(PhoneRule.validateFor('Germany', '123456'), isNotNull);
      expect(PhoneRule.validateFor('Germany', '1234567890123456'), isNotNull);
    });
  });

  group('PhoneRule.validateFor — empty value', () {
    test('required by default', () {
      expect(PhoneRule.validateFor('India', ''), 'Please enter phone number');
      expect(PhoneRule.validateFor('', ''), 'Please enter phone number');
    });

    test('optional when asked', () {
      expect(PhoneRule.validateFor('India', '', required: false), isNull);
      expect(PhoneRule.validateFor(null, null, required: false), isNull);
    });
  });

  group('PhoneRule.maxLengthFor', () {
    test('India caps at 10', () {
      expect(PhoneRule.maxLengthFor('India'), 10);
    });

    test('elsewhere caps at 15', () {
      expect(PhoneRule.maxLengthFor('Germany'), 15);
    });

    test('unchosen country uses the WIDEST cap, not India\'s', () {
      // Capping at 10 before the country is known would physically stop a
      // German user typing their number.
      expect(PhoneRule.maxLengthFor(''), 15);
      expect(PhoneRule.maxLengthFor(null), 15);
    });
  });

  group('PhoneRule.hintFor', () {
    test('names the exact length for India', () {
      expect(PhoneRule.hintFor('India'), 'Enter 10-digit mobile number');
    });

    test('names the range elsewhere', () {
      expect(PhoneRule.hintFor('Germany'), 'Enter 7–15 digit mobile number');
    });

    test('stays neutral while the country is unchosen', () {
      expect(PhoneRule.hintFor(''), 'Enter mobile number');
    });
  });

  group('PhoneRule.lengthLabelFor', () {
    // Used by optional fields that compose their own hint, e.g. the wizard's
    // staff phone: "Optional, 10 digits" / "Optional, 7–15 digits".
    test('India names the exact count', () {
      expect(PhoneRule.lengthLabelFor('India'), '10 digits');
    });

    test('elsewhere names the range', () {
      expect(PhoneRule.lengthLabelFor('Germany'), '7–15 digits');
    });

    test('unchosen country stays unqualified', () {
      expect(PhoneRule.lengthLabelFor(''), 'digits');
      expect(PhoneRule.lengthLabelFor(null), 'digits');
    });
  });

  group('PhoneRule.isIndiaFor', () {
    test('case and padding insensitive', () {
      expect(PhoneRule.isIndiaFor('India'), isTrue);
      expect(PhoneRule.isIndiaFor(' india '), isTrue);
      expect(PhoneRule.isIndiaFor('INDIA'), isTrue);
    });

    test('blank is NOT India — that is the whole point of this API', () {
      expect(PhoneRule.isIndiaFor(''), isFalse);
      expect(PhoneRule.isIndiaFor(null), isFalse);
    });
  });
}
