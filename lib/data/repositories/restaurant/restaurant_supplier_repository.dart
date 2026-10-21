import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/restaurant_supplier_model.dart';

class RestaurantSupplierRepository {
  Box<RestaurantSupplierModel> get _box =>
      Hive.box<RestaurantSupplierModel>(HiveBoxNames.restaurantSuppliers);

  List<RestaurantSupplierModel> getAllSuppliers() => _box.values.toList();

  RestaurantSupplierModel? getSupplierById(String id) => _box.get(id);

  Future<void> saveSupplier(RestaurantSupplierModel supplier) async {
    await _box.put(supplier.supplierId, supplier);
  }

  Future<void> deleteSupplier(String id) async {
    await _box.delete(id);
  }
}
