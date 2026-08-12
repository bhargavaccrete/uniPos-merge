import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../store/retail/attribute_store.dart';

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
class SimpleProductFieldsService {
  static const String _key = 'simple_product_fields';

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

  /// Forget the configuration entirely, so the base fields are seeded again.
  Future<bool> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_key);
  }

  /// The configured fields as attribute models, ready to render.
  ///
  /// Ensures the base attributes exist, loads the attribute cache, then
  /// resolves the saved ids — falling back to Size/Color/Weight when the shop
  /// has never configured them, so the out-of-the-box form is unchanged.
  /// Attributes deleted since being configured drop out silently.
  ///
  /// One definition, shared by every form that renders variant descriptors.
  Future<List<AttributeModel>> resolveFields() async {
    await attributeStore.ensureBaseAttributes();
    await attributeStore.loadAttributes();

    final savedIds = await getFieldIds();
    if (savedIds == null) {
      return kBaseAttributeNames
          .map(attributeStore.getAttributeByName)
          .whereType<AttributeModel>()
          .toList();
    }
    return attributeStore.attributesByIds(savedIds);
  }
}
