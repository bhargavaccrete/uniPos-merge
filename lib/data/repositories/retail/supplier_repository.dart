
import 'package:hive/hive.dart';
import '../../models/retail/hive_model/supplier_model_205.dart';

class SupplierRepository {
  late Box<SupplierModel> _supplierBox;

  SupplierRepository() {
    _supplierBox = Hive.box<SupplierModel>('suppliers');
  }

  // Get All Suppliers
  Future<List<SupplierModel>> getAllSuppliers() async {
    return _supplierBox.values.toList();
  }

  // Get Supplier by ID
  SupplierModel? getSupplierById(String supplierId) {
    return _supplierBox.get(supplierId);
  }

  // Add new Supplier
  Future<void> addSupplier(SupplierModel supplier) async {
    await _supplierBox.put(supplier.supplierId, supplier);
  }

  // Update Supplier
  Future<void> updateSupplier(SupplierModel supplier) async {
    await _supplierBox.put(supplier.supplierId, supplier);
  }

  // Delete Supplier
  Future<void> deleteSupplier(String supplierId) async {
    await _supplierBox.delete(supplierId);
  }

  // Search Suppliers by name
  Future<List<SupplierModel>> searchSuppliers(String query) async {
    if (query.isEmpty) return getAllSuppliers();

    final allSuppliers = _supplierBox.values.toList();
    return allSuppliers.where((supplier) {
      return supplier.name.toLowerCase().contains(query.toLowerCase()) ||
          (supplier.phone?.contains(query) ?? false) ||
          (supplier.gstNumber?.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();
  }

  // Update Supplier Balance
  Future<void> updateSupplierBalance(String supplierId, double amount) async {
    final supplier = _supplierBox.get(supplierId);
    if (supplier != null) {
      final updatedSupplier = SupplierModel(
        supplierId: supplier.supplierId,
        name: supplier.name,
        phone: supplier.phone,
        address: supplier.address,
        gstNumber: supplier.gstNumber,
        openingBalance: supplier.openingBalance,
        currentBalance: supplier.currentBalance + amount,
        createdAt: supplier.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _supplierBox.put(supplierId, updatedSupplier);
    }
  }

  // Get Total Outstanding Balance
  double getTotalOutstanding() {
    return _supplierBox.values.fold(0.0, (sum, supplier) => sum + supplier.currentBalance);
  }
}
