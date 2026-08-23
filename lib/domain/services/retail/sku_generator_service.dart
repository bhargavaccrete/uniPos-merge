import 'package:hive/hive.dart';
import '../../../core/constants/hive_box_names.dart';

/// Generates SKUs as `<CATEGORY_PREFIX>-<GLOBAL_6_DIGIT_SEQUENCE>`, e.g.
/// "APP-000042". The sequence is a single counter shared across every
/// category (not per-category) so every generated SKU is unique app-wide,
/// without needing to check existing records for collisions.
///
/// Callers are responsible for only invoking [generate] when the SKU field
/// is blank — this service never overwrites anything, it only produces a
/// new value.
class SkuGeneratorService {
  static const _sequenceKey = 'lastSkuSequence';

  Box get _box => Hive.box(HiveBoxNames.appCounters);

  String _categoryPrefix(String? categoryName) {
    final clean = (categoryName ?? '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (clean.isEmpty) return 'GEN';
    return clean.length >= 3 ? clean.substring(0, 3) : clean;
  }

  Future<String> generate(String? categoryName) async {
    final prefix = _categoryPrefix(categoryName);
    final last = _box.get(_sequenceKey, defaultValue: 0) as int;
    final next = last + 1;
    await _box.put(_sequenceKey, next);
    return '$prefix-${next.toString().padLeft(6, '0')}';
  }
}
