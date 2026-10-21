import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/common/business_details.dart';

void main() {
  group('BusinessDetails.retailStoreType', () {
    test('defaults to null so restaurant records are unaffected', () {
      expect(BusinessDetails(businessTypeId: 'restaurant').retailStoreType,
          isNull);
    });

    test('survives a toMap/fromMap round trip', () {
      final restored = BusinessDetails.fromMap(
        BusinessDetails(
          businessTypeId: 'retail',
          storeName: 'Trend Threads',
          retailStoreType: 'garment',
        ).toMap(),
      );
      expect(restored.retailStoreType, equals('garment'));
    });

    test('fromMap tolerates a payload saved before the field existed', () {
      final legacy = {
        'businessTypeId': 'retail',
        'storeName': 'Old Shop',
        'isSetupComplete': true,
      };
      expect(BusinessDetails.fromMap(legacy).retailStoreType, isNull);
    });

    test('copyWith updates the store type', () {
      final updated = BusinessDetails(retailStoreType: 'garment')
          .copyWith(retailStoreType: 'footwear');
      expect(updated.retailStoreType, equals('footwear'));
    });

    test('copyWith preserves the store type when not passed', () {
      final updated =
          BusinessDetails(retailStoreType: 'sports').copyWith(storeName: 'X');
      expect(updated.retailStoreType, equals('sports'));
    });

    // The reason clearRetailStoreType exists: `x ?? this.x` cannot null a
    // field, so switching retail -> restaurant would keep the stale type.
    test('copyWith cannot clear the store type by passing null', () {
      final updated = BusinessDetails(retailStoreType: 'garment')
          .copyWith(retailStoreType: null);
      expect(updated.retailStoreType, equals('garment'));
    });

    test('clearRetailStoreType nulls it', () {
      final updated = BusinessDetails(retailStoreType: 'garment')
          .copyWith(clearRetailStoreType: true);
      expect(updated.retailStoreType, isNull);
    });

    test('clearRetailStoreType wins over a passed value', () {
      final updated = BusinessDetails(retailStoreType: 'garment').copyWith(
        retailStoreType: 'footwear',
        clearRetailStoreType: true,
      );
      expect(updated.retailStoreType, isNull);
    });
  });
}
