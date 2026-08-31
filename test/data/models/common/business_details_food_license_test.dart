import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/common/business_details.dart';

/// Mirrors business_details_store_type_test.dart — same contract, new field.
void main() {
  group('BusinessDetails.foodLicenseNo', () {
    test('defaults to null when not supplied', () {
      expect(BusinessDetails(storeName: 'Cafe').foodLicenseNo, isNull);
    });

    test('survives a toMap/fromMap round trip', () {
      final original = BusinessDetails(
        storeName: 'Cafe',
        country: 'India',
        foodLicenseNo: '12345678901234',
      );
      final restored = BusinessDetails.fromMap(original.toMap());
      expect(restored.foodLicenseNo, '12345678901234');
      expect(restored.country, 'India');
    });

    test('a legacy map without the key reads back null', () {
      final legacy = BusinessDetails(storeName: 'Cafe').toMap()
        ..remove('foodLicenseNo');
      expect(BusinessDetails.fromMap(legacy).foodLicenseNo, isNull);
    });

    test('copyWith updates the value', () {
      final updated = BusinessDetails(storeName: 'Cafe')
          .copyWith(foodLicenseNo: '99999999999999');
      expect(updated.foodLicenseNo, '99999999999999');
    });

    test('copyWith preserves the value when not passed', () {
      final original =
          BusinessDetails(storeName: 'Cafe', foodLicenseNo: '12345678901234');
      expect(original.copyWith(storeName: 'Bistro').foodLicenseNo,
          '12345678901234');
    });

    test('copyWith cannot null the value — pass empty string to clear', () {
      final original =
          BusinessDetails(storeName: 'Cafe', foodLicenseNo: '12345678901234');
      expect(original.copyWith(foodLicenseNo: null).foodLicenseNo,
          '12345678901234');
      expect(original.copyWith(foodLicenseNo: '').foodLicenseNo, '');
    });

    test('does not disturb the neighbouring field 19', () {
      final d = BusinessDetails(
        storeName: 'Shop',
        retailStoreType: 'garment',
        foodLicenseNo: 'ABC-123',
      );
      final restored = BusinessDetails.fromMap(d.toMap());
      expect(restored.retailStoreType, 'garment');
      expect(restored.foodLicenseNo, 'ABC-123');
    });
  });
}
