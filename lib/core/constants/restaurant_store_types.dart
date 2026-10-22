/// Canonical catalogue of restaurant store types — the single source of truth
/// for the setup wizard's restaurant sub-selection and anything that later
/// reads the stored value back. Mirrors [RetailStoreTypes] for retail.
///
/// [key] is the stable identifier that gets persisted (`BusinessDetails
/// .restaurantStoreType`) and sent to the License Management System as
/// `businesssubtype`. It MUST match the server's `businesssubtypemaster.code`
/// verbatim (see that project's `db/CHANGES.md`). Display text is presentation
/// only and may be reworded at any time, so never compare against [name] —
/// match on [key].
///
/// Deliberately pure Dart (no Flutter import), matching the other files in this
/// folder. [iconName] is a string the UI maps to an `IconData`, the same
/// convention the retail store-type picker uses.
class RestaurantStoreType {
  final String key;
  final String name;
  final String description;
  final String iconName;

  const RestaurantStoreType({
    required this.key,
    required this.name,
    required this.description,
    required this.iconName,
  });
}

/// The restaurant store types currently supported. Codes match the server's
/// `businesssubtypemaster` rows under the `restaurant` type.
class RestaurantStoreTypes {
  const RestaurantStoreTypes._();

  static const RestaurantStoreType cafe = RestaurantStoreType(
    key: 'cafe',
    name: 'Cafe',
    description: 'Coffee shop or cafe',
    iconName: 'cafe',
  );

  static const RestaurantStoreType qsr = RestaurantStoreType(
    key: 'qsr',
    name: 'QSR / Quick Service',
    description: 'Counter-service / quick service',
    iconName: 'qsr',
  );

  static const RestaurantStoreType restaurant = RestaurantStoreType(
    key: 'restaurant',
    name: 'Restaurant (Dine-in)',
    description: 'Full-service dine-in restaurant',
    iconName: 'restaurant',
  );

  static const RestaurantStoreType foodTruck = RestaurantStoreType(
    key: 'food_truck',
    name: 'Food Truck',
    description: 'Mobile food truck',
    iconName: 'food_truck',
  );

  static const RestaurantStoreType foodCart = RestaurantStoreType(
    key: 'food_cart',
    name: 'Food Cart',
    description: 'Street food cart or stall',
    iconName: 'food_cart',
  );

  static const RestaurantStoreType other = RestaurantStoreType(
    key: 'other',
    name: 'Other / General',
    description: 'Something else — set up your own',
    iconName: 'other',
  );

  /// Display order in the setup wizard. `other` sits last — the answer for a
  /// business that recognised itself in none of the above.
  static const List<RestaurantStoreType> all = [
    cafe,
    qsr,
    restaurant,
    foodTruck,
    foodCart,
    other,
  ];

  /// Resolve a persisted key back to its entry, or null when the key is
  /// absent/unknown — a store type retired in a later release must not crash a
  /// device that still has it saved.
  static RestaurantStoreType? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final type in all) {
      if (type.key == key) return type;
    }
    return null;
  }

  /// True when [key] is one this build still offers. Used to validate a value
  /// restored from storage before treating the selection as made.
  static bool isKnown(String? key) => byKey(key) != null;

  /// Display name for a persisted key, or null when unknown.
  static String? nameFor(String? key) => byKey(key)?.name;
}
