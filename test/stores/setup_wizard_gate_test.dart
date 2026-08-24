import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/business_type_repository.dart';
import 'package:billberrylite/data/repositories/tax_details_repository.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';

/// Which wizard step demands the retail store type.
///
/// It used to gate **Business Type**; it now gates **Store Details**, because
/// that is where the dropdown lives and where `saveBusinessDetails()` persists
/// the value. These tests are the guard against it silently gating neither —
/// which would let a retail business finish setup with no store type and seed
/// the product form from the app-wide fallback instead of a real answer.
///
/// The store's three repositories open their Hive boxes lazily (a `get _box =>
/// Hive.box(...)` getter), and the `canProceed*` computeds read only observables,
/// so no Hive is needed here.
void main() {
  SetupWizardStore newStore() => SetupWizardStore(
        businessTypeRepo: BusinessTypeRepository(),
        businessDetailsRepo: BusinessDetailsRepository(),
        taxDetailsRepo: TaxDetailsRepository(),
      );

  void fillStoreDetails(SetupWizardStore store) {
    store.storeName = 'Berry Fashion';
    store.ownerName = 'A. Owner';
    store.phone = '9876543210';
  }

  group('Business Type step no longer gates on the store type', () {
    test('retail can move on without having picked a store type', () {
      final store = newStore();
      store.selectedBusinessTypeId = 'retail';

      expect(store.needsRetailStoreType, isTrue);
      expect(store.hasRetailStoreType, isFalse);
      expect(store.canProceedFromBusinessType, isTrue);
    });

    test('but a business type is still required', () {
      final store = newStore();
      expect(store.canProceedFromBusinessType, isFalse);
    });
  });

  group('Store Details step gates on the store type', () {
    test('retail is blocked until a store type is picked', () {
      final store = newStore();
      store.selectedBusinessTypeId = 'retail';
      fillStoreDetails(store);

      expect(store.canProceedFromStoreDetails, isFalse);

      store.selectRetailStoreType('garment');

      expect(store.hasRetailStoreType, isTrue);
      expect(store.canProceedFromStoreDetails, isTrue);
    });

    test('the new Other type satisfies the gate like any other', () {
      final store = newStore();
      store.selectedBusinessTypeId = 'retail';
      fillStoreDetails(store);

      store.selectRetailStoreType('other');

      expect(store.canProceedFromStoreDetails, isTrue);
    });

    test('a retired or misspelled key does NOT satisfy the gate', () {
      final store = newStore();
      store.selectedBusinessTypeId = 'retail';
      fillStoreDetails(store);

      // selectRetailStoreType ignores an unknown key rather than storing it.
      store.selectRetailStoreType('grocery');
      expect(store.selectedRetailStoreType, isNull);
      expect(store.canProceedFromStoreDetails, isFalse);
    });

    test('the store details themselves are still required', () {
      final store = newStore();
      store.selectedBusinessTypeId = 'retail';
      store.selectRetailStoreType('garment');

      // Name/owner/phone still empty.
      expect(store.canProceedFromStoreDetails, isFalse);
    });

    test('restaurant needs no store type at either step', () {
      final store = newStore();
      store.selectedBusinessTypeId = 'restaurant';
      fillStoreDetails(store);

      expect(store.needsRetailStoreType, isFalse);
      expect(store.canProceedFromBusinessType, isTrue);
      expect(store.canProceedFromStoreDetails, isTrue);
    });
  });
}
