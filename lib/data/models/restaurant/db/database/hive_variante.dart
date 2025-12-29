
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';

class HiveVariante{
  static const _boxName = 'variante';

  /// Get the variante box (already opened in main.dart)
  static Box<VariantModel> getVariante() {
    return Hive.box<VariantModel>(_boxName);
  }

  static Future<void> addVariante(VariantModel variantmodel) async {
    final box = getVariante();
    await box.put(variantmodel.id, variantmodel);
  }

  static Future<void> updateVariante(VariantModel variantemodel) async {
    final box = getVariante();
    await box.put(variantemodel.id, variantemodel);
  }

  static Future<void> deleteVariante(String id) async {
    final box = getVariante();
    await box.delete(id);
  }

  static Future<List<VariantModel>> getAllVariante() async {
    final box = getVariante();
    return box.values.toList();
  }
}