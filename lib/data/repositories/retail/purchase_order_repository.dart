import 'package:hive/hive.dart';
import '../../models/retail/hive_model/purchase_order_model_211.dart';

class PurchaseOrderRepository {
  late Box<PurchaseOrderModel> _poBox;

  PurchaseOrderRepository() {
    _poBox = Hive.box<PurchaseOrderModel>('purchaseOrders');
  }

  // Get All Purchase Orders
  Future<List<PurchaseOrderModel>> getAllPurchaseOrders() async {
    return _poBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Purchase Order by ID
  PurchaseOrderModel? getPurchaseOrderById(String poId) {
    return _poBox.get(poId);
  }

  // Add new Purchase Order
  Future<void> addPurchaseOrder(PurchaseOrderModel po) async {
    await _poBox.put(po.poId, po);
  }

  // Update Purchase Order
  Future<void> updatePurchaseOrder(PurchaseOrderModel po) async {
    final updatedPO = po.copyWith(updatedAt: DateTime.now().toIso8601String());
    await _poBox.put(po.poId, updatedPO);
  }

  // Delete Purchase Order
  Future<void> deletePurchaseOrder(String poId) async {
    await _poBox.delete(poId);
  }

  // Get Purchase Orders by Status
  Future<List<PurchaseOrderModel>> getPurchaseOrdersByStatus(POStatus status) async {
    final allPOs = _poBox.values.toList();
    return allPOs
        .where((po) => po.status == status.name)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Purchase Orders by Supplier
  Future<List<PurchaseOrderModel>> getPurchaseOrdersBySupplier(String supplierId) async {
    final allPOs = _poBox.values.toList();
    return allPOs
        .where((po) => po.supplierId == supplierId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Active Purchase Orders (Draft, Sent, Partially Completed)
  Future<List<PurchaseOrderModel>> getActivePurchaseOrders() async {
    final allPOs = _poBox.values.toList();
    return allPOs.where((po) {
      final status = po.statusEnum;
      return status == POStatus.draft ||
          status == POStatus.sent ||
          status == POStatus.partiallyCompleted;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Completed Purchase Orders
  Future<List<PurchaseOrderModel>> getCompletedPurchaseOrders() async {
    final allPOs = _poBox.values.toList();
    return allPOs.where((po) {
      final status = po.statusEnum;
      return status == POStatus.fullyCompleted || status == POStatus.cancelled;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Search Purchase Orders by PO Number
  Future<List<PurchaseOrderModel>> searchPurchaseOrders(String query) async {
    if (query.isEmpty) return getAllPurchaseOrders();

    final allPOs = _poBox.values.toList();
    final lowerQuery = query.toLowerCase();
    return allPOs.where((po) {
      return po.poNumber.toLowerCase().contains(lowerQuery) ||
          (po.supplierName?.toLowerCase().contains(lowerQuery) ?? false) ||
          po.poId.contains(query);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Purchase Orders by Date Range
  Future<List<PurchaseOrderModel>> getPurchaseOrdersByDateRange(
      DateTime startDate, DateTime endDate) async {
    final allPOs = _poBox.values.toList();
    return allPOs.where((po) {
      final createdDate = DateTime.parse(po.createdAt);
      return createdDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          createdDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Generate next PO number (format: PO-YYYYMMDD-XXX)
  String generatePONumber() {
    final now = DateTime.now();
    final datePrefix = 'PO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // Get all POs from today
    final todayPOs = _poBox.values.where((po) {
      return po.poNumber.startsWith(datePrefix);
    }).toList();

    final nextNumber = todayPOs.length + 1;
    return '$datePrefix-${nextNumber.toString().padLeft(3, '0')}';
  }

  // Get Purchase Order Count
  int getPurchaseOrderCount() {
    return _poBox.length;
  }

  // Get Count by Status
  int getCountByStatus(POStatus status) {
    return _poBox.values.where((po) => po.status == status.name).length;
  }

  // Get Total Estimated Value of Active POs
  double getTotalEstimatedValue() {
    return _poBox.values
        .where((po) {
          final status = po.statusEnum;
          return status == POStatus.draft ||
              status == POStatus.sent ||
              status == POStatus.partiallyCompleted;
        })
        .fold(0.0, (sum, po) => sum + po.estimatedTotal);
  }

  // Update PO Status
  Future<void> updatePOStatus(String poId, POStatus newStatus) async {
    final po = getPurchaseOrderById(poId);
    if (po != null) {
      final updatedPO = po.copyWith(
        status: newStatus.name,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _poBox.put(poId, updatedPO);
    }
  }
}