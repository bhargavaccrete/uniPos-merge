import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Loads the bundled country → state → city dataset (shipped by the
/// `country_state_city_picker` package as an asset) and exposes clean,
/// alphabetically-sorted name lists for cascading dropdowns.
///
/// The JSON is decoded once and cached. Names are returned WITHOUT the emoji
/// prefix the picker widget adds, so what we store stays clean ("India", not
/// "🇮🇳    India").
class CountryStateCityData {
  CountryStateCityData._();
  static final CountryStateCityData instance = CountryStateCityData._();

  // Same asset the country_state_city_picker widget reads. Bundled because the
  // package is a dependency (declares this asset in its own pubspec).
  static const _assetPath =
      'packages/country_state_city_picker/lib/assets/country.json';

  List<dynamic>? _raw;

  Future<void> _ensureLoaded() async {
    if (_raw != null) return;
    final jsonStr = await rootBundle.loadString(_assetPath);
    _raw = jsonDecode(jsonStr) as List<dynamic>;
  }

  /// All country names, sorted & de-duplicated.
  Future<List<String>> countries() async {
    await _ensureLoaded();
    return _cleanSorted(_raw!.map((c) => c['name'] as String?));
  }

  /// States within [country], sorted & de-duplicated. Empty if not found.
  Future<List<String>> states(String country) async {
    await _ensureLoaded();
    final c = _findCountry(country);
    if (c == null) return [];
    final states = (c['state'] as List?) ?? const [];
    return _cleanSorted(states.map((s) => s['name'] as String?));
  }

  /// Cities within [country] → [state], sorted & de-duplicated. Empty if not found.
  Future<List<String>> cities(String country, String state) async {
    await _ensureLoaded();
    final c = _findCountry(country);
    if (c == null) return [];
    final states = (c['state'] as List?) ?? const [];
    final st = states.firstWhere(
      (s) => (s['name'] as String?)?.trim() == state.trim(),
      orElse: () => null,
    );
    if (st == null) return [];
    final cities = (st['city'] as List?) ?? const [];
    return _cleanSorted(cities.map((ci) => ci['name'] as String?));
  }

  /// Trims, drops blanks, removes case-insensitive duplicates (the source
  /// dataset repeats some names — e.g. "Gandhinagar" twice under Gujarat), sorts.
  List<String> _cleanSorted(Iterable<String?> names) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in names) {
      final name = raw?.trim() ?? '';
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) out.add(name);
    }
    out.sort();
    return out;
  }

  dynamic _findCountry(String country) => _raw!.firstWhere(
        (e) => (e['name'] as String?)?.trim() == country.trim(),
        orElse: () => null,
      );
}
