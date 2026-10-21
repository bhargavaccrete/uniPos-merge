import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/retail_store_types.dart';
import '../../../core/di/service_locator.dart';

/// Seeds the product attributes a retail business STARTS with, chosen by its
/// store type (`BusinessDetails.retailStoreType` → `RetailStoreTypes`).
///
/// A default, never a restriction. Once seeded, the merchant owns the list: they
/// can rename, delete or add attributes in Settings → Product Attributes and
/// nothing here will undo that.
///
/// **This service is driven by the selected store type and nothing else.** It
/// deliberately never references `kBaseAttributeNames` — that app-wide fallback
/// belongs to `SimpleProductFieldsService`, applies only when there is no store
/// type on record, and must not leak into store-type seeding. See
/// [ensureStoreTypeDefaults] for the three cases.
class StoreTypeAttributeDefaultsService {
  /// Which store type we have already seeded for, so seeding runs exactly once
  /// per store type. Stores the store-type KEY rather than a bool: if the type
  /// ever changes, the new type's defaults are seeded once too — additively.
  ///
  /// Same shape as `paymentSetupStep`'s `payment_country_defaults_applied`.
  static const String _seededForKey = 'attribute_defaults_seeded_for';

  /// This business's retail store type key, or null when there is none.
  ///
  /// Never throws: callers sit on the product-form hot path and on screen init,
  /// so an unreadable business record must degrade to "no store type" rather
  /// than break product creation.
  String? storeTypeKey() {
    try {
      return businessDetailsRepository.get()?.retailStoreType;
    } catch (e) {
      debugPrint('StoreTypeAttributeDefaults: no store type available — $e');
      return null;
    }
  }

  /// Create this store type's default attributes, exactly once.
  ///
  /// Three cases, and the differences between them are the whole point:
  ///
  /// - **Known store type** → seed its mapped names, then remember that we did.
  ///   Every later call is a no-op, so an attribute the merchant deletes stays
  ///   deleted.
  /// - **`other`** (anything mapped to `[]`) → genuinely no store-type defaults.
  ///   Seeds nothing and writes no marker.
  /// - **Absent or unknown key** → this feature does not apply. Seeds nothing,
  ///   writes no marker, and leaves `SimpleProductFieldsService`'s legacy
  ///   `kBaseAttributeNames` fallback to behave exactly as it always has.
  ///
  /// No marker is written for the last two: there is no state to remember, and
  /// writing one would wrongly suppress seeding if the merchant later picks a
  /// real store type.
  Future<void> ensureStoreTypeDefaults() async {
    final key = storeTypeKey();
    final names = RetailStoreTypes.defaultAttributeNamesFor(key);

    // Absent or unknown — not our business.
    if (names == null) return;

    // Deliberately none. Returning here rather than calling through with an
    // empty list keeps us clear of `ensureBaseAttributes`' own
    // `names ?? kBaseAttributeNames` fallback, which would seed Size/Color/
    // Weight if a future edit ever let a null reach it.
    if (names.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_seededForKey) == key) return;

    // `names` is proven non-null and non-empty here.
    await attributeStore.ensureBaseAttributes(names: names);
    await prefs.setString(_seededForKey, key!);
  }

  /// Forget the marker so the next [ensureStoreTypeDefaults] seeds again.
  ///
  /// **User-initiated only** — Settings → Simple Product Fields → Reset. Never
  /// call this from a silent path, or deleting a default attribute would stop
  /// meaning anything.
  Future<bool> clearSeedMarker() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_seededForKey);
  }
}
