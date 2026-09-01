import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/retail_store_types.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../store/retail/attribute_store.dart';
import 'store_type_attribute_defaults_service.dart';

/// Which descriptor fields appear on a **Simple** product's variant card.
///
/// Stores only attribute IDs, resolved against the existing global attribute
/// system (`AttributeStore`). This replaces the hardcoded Color / Size / Weight
/// boxes so a shop that doesn't sell apparel can swap them for Flavour, Volume,
/// Capacity, or anything else.
///
/// Deliberately unrelated to Settings → Product Attributes, which configures
/// attributes for **Variable** products and variant generation.
///
/// Universal commerce fields — Barcode, Cost Price, Selling Price, MRP, SKU,
/// Stock — are not configurable and are unaffected by this.
///
/// The INITIAL set comes from the business's retail store type
/// (`BusinessDetails.retailStoreType` → `RetailStoreTypes`). That is a default
/// only: once the user saves a selection it wins forever, and no other code
/// branches on store type.
class SimpleProductFieldsService {
  static const String _key = 'simple_product_fields';

  final StoreTypeAttributeDefaultsService _storeTypeDefaults =
      StoreTypeAttributeDefaultsService();

  /// Configured attribute ids, in display order.
  ///
  /// Returns null when the user has never configured them — the caller then
  /// seeds the base fields. An explicitly saved empty list returns `[]`, which
  /// legitimately means "no descriptor fields".
  Future<List<String>?> getFieldIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<String>().toList();
    } catch (e) {
      debugPrint('SimpleProductFieldsService: unreadable config, ignoring — $e');
      return null;
    }
  }

  /// Persists the configured ids. An empty list is saved as such, so "I removed
  /// every field" is remembered rather than re-seeded on next open.
  Future<bool> setFieldIds(List<String> attributeIds) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_key, jsonEncode(attributeIds));
  }

  /// Forget the configuration entirely, so the default fields are seeded again.
  ///
  /// Also clears the store-type seed marker, so an explicit Reset genuinely
  /// restores defaults the merchant had deleted. This is the ONLY path that
  /// re-seeds, and it is user-initiated — no silent path may clear that marker.
  Future<bool> resetToDefaults() async {
    await _storeTypeDefaults.clearSeedMarker();
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_key);
  }

  /// Which descriptor fields a simple product RENDERS by default.
  ///
  /// Falls back to [kBaseAttributeNames] when there is no store type on record
  /// — an older retail install, or a restaurant — so behaviour for existing
  /// data is unchanged. A store type that genuinely wants none (`other`)
  /// correctly returns an empty list rather than falling back.
  ///
  /// **Not the seeding decision.** Which attributes get CREATED is
  /// [StoreTypeAttributeDefaultsService.ensureStoreTypeDefaults]'s call, and it
  /// never uses this fallback. This method only answers "which boxes does the
  /// form show", and also names the defaults in the Reset confirm message.
  ///
  /// Never throws: this sits on the product-form hot path, so an unreadable
  /// business record degrades to the fallback instead of breaking product
  /// creation.
  List<String> defaultFieldNames() {
    try {
      final storeType = businessDetailsRepository.get()?.retailStoreType;
      return RetailStoreTypes.defaultAttributeNamesFor(storeType) ??
          kBaseAttributeNames;
    } catch (e) {
      debugPrint('SimpleProductFieldsService: no store type available — $e');
      return kBaseAttributeNames;
    }
  }

  /// Seed this business's default attributes, then resolve them to models.
  ///
  /// The one definition of "the defaults", shared by [resolveFields] and by the
  /// Simple Product Fields screen's initial load and Reset action — so all
  /// three can never disagree.
  Future<List<AttributeModel>> resolveDefaultFields() async {
    await _ensureDefaultsExist();
    return defaultFieldNames()
        .map(attributeStore.getAttributeByName)
        .whereType<AttributeModel>()
        .toList();
  }

  /// Make sure this business's default attributes exist, then load the cache.
  ///
  /// Two sources, deliberately kept apart:
  ///
  /// 1. **Store-type defaults** — seeded exactly once for a KNOWN store type by
  ///    [StoreTypeAttributeDefaultsService], so a default the merchant deletes
  ///    is never resurrected.
  /// 2. **The legacy app-wide fallback** — unchanged behaviour for an older
  ///    retail install that predates store types. Gated on the store type being
  ///    unknown/absent, so a known type (including `other`, which wants no
  ///    attributes at all) can never be handed Size/Color/Weight.
  ///
  /// A name that resolves to nothing afterwards has been deleted by the
  /// merchant, and correctly drops out of the returned fields.
  Future<void> _ensureDefaultsExist() async {
    await _storeTypeDefaults.ensureStoreTypeDefaults();

    if (!RetailStoreTypes.isKnown(_storeTypeDefaults.storeTypeKey())) {
      await attributeStore.ensureBaseAttributes(names: kBaseAttributeNames);
    }

    await attributeStore.loadAttributes();
  }

  /// The configured fields as attribute models, ready to render.
  ///
  /// Ensures this business's default attributes exist, loads the attribute
  /// cache, then resolves the saved ids — falling back to
  /// [resolveDefaultFields] when the shop has never configured them.
  /// Attributes deleted since being configured drop out silently.
  ///
  /// One definition, shared by every form that renders variant descriptors.
  Future<List<AttributeModel>> resolveFields() async {
    final savedIds = await getFieldIds();
    if (savedIds == null) return resolveDefaultFields();

    // Still seed + load: the saved ids must resolve against a populated store,
    // and a shop that removed every field still needs its attributes to exist.
    await _ensureDefaultsExist();
    return attributeStore.attributesByIds(savedIds);
  }
}
