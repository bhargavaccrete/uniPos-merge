import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/retail/hive_model/kit_assembly_model.dart';

/// Data access layer for [RetailKitAssemblyModel] — the append-only "batch
/// assembled" log for repack/kit variants. See
/// docs/retail_inventory_system_plan.md §3.2.
class KitAssemblyRepository {
  Box<RetailKitAssemblyModel> get _box =>
      Hive.box<RetailKitAssemblyModel>(HiveBoxNames.kitAssemblies);

  List<RetailKitAssemblyModel> getAllAssemblies() =>
      _box.values.toList()..sort((a, b) => b.assembledTime.compareTo(a.assembledTime));

  List<RetailKitAssemblyModel> getAssembliesForVariant(String variantId) =>
      getAllAssemblies().where((a) => a.variantId == variantId).toList();

  Future<void> saveAssembly(RetailKitAssemblyModel assembly) async {
    await _box.put(assembly.id, assembly);
  }
}
