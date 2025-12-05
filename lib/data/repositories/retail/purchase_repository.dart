import 'package:hive/hive.dart';
import '../../models/retail/hive_model/purchase_model_207.dart';

class PurchaseRepository {
  late Box<PurchaseModel> _purchaseBox;

  PurchaseRepository() {
    _purchaseBox = Hive.box<PurchaseModel>('purchases');
  }

  // Get All Purchases
  Future<List<PurchaseModel>> getAllPurchases() async {
    return _purchaseBox.values.toList()
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }

  // Get Purchase by ID
  PurchaseModel? getPurchaseById(String purchaseId) {
    return _purchaseBox.get(purchaseId);
  }

  // Add new Purchase
  Future<void> addPurchase(PurchaseModel purchase) async {
    await _purchaseBox.put(purchase.purchaseId, purchase);
  }

  // Update Purchase
  Future<void> updatePurchase(PurchaseModel purchase) async {
    final updatedPurchase = PurchaseModel(
      purchaseId: purchase.purchaseId,
      supplierId: purchase.supplierId,
      invoiceNumber: purchase.invoiceNumber,
      totalItems: purchase.totalItems,
      totalAmount: purchase.totalAmount,
      purchaseDate: purchase.purchaseDate,
      createdAt: purchase.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _purchaseBox.put(purchase.purchaseId, updatedPurchase);
  }

  // Delete Purchase
  Future<void> deletePurchase(String purchaseId) async {
    await _purchaseBox.delete(purchaseId);
  }

  // Get Purchases by Supplier
  Future<List<PurchaseModel>> getPurchasesBySupplier(String supplierId) async {
    final allPurchases = _purchaseBox.values.toList();
    return allPurchases
        .where((purchase) => purchase.supplierId == supplierId)
        .toList()
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }

  // Get Purchases by Date Range
  Future<List<PurchaseModel>> getPurchasesByDateRange(
      DateTime startDate, DateTime endDate) async {
    final allPurchases = _purchaseBox.values.toList();
    return allPurchases.where((purchase) {
      final purchaseDate = DateTime.parse(purchase.purchaseDate);
      return purchaseDate.isAfter(startDate) &&
          purchaseDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }

  // Search Purchases by Invoice Number
  Future<List<PurchaseModel>> searchPurchases(String query) async {
    if (query.isEmpty) return getAllPurchases();

    final allPurchases = _purchaseBox.values.toList();
    return allPurchases.where((purchase) {
      return (purchase.invoiceNumber?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
          purchase.purchaseId.contains(query);
    }).toList()
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }

  // Get Total Purchase Amount
  double getTotalPurchaseAmount() {
    return _purchaseBox.values.fold(0.0, (sum, purchase) => sum + purchase.totalAmount);
  }

  // Get Purchase Count
  int getPurchaseCount() {
    return _purchaseBox.length;
  }
}