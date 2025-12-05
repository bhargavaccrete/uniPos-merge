import 'package:hive/hive.dart';
import '../../models/retail/hive_model/grn_model_213.dart';

class GRNRepository {
  late Box<GRNModel> _grnBox;

  GRNRepository() {
    _grnBox = Hive.box<GRNModel>('grns');
  }

  // Get All GRNs
  Future<List<GRNModel>> getAllGRNs() async {
    return _grnBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get GRN by ID
  GRNModel? getGRNById(String grnId) {
    return _grnBox.get(grnId);
  }

  // Add new GRN
  Future<void> addGRN(GRNModel grn) async {
    await _grnBox.put(grn.grnId, grn);
  }

  // Update GRN
  Future<void> updateGRN(GRNModel grn) async {
    final updatedGRN = grn.copyWith(updatedAt: DateTime.now().toIso8601String());
    await _grnBox.put(grn.grnId, updatedGRN);
  }

  // Delete GRN
  Future<void> deleteGRN(String grnId) async {
    await _grnBox.delete(grnId);
  }

  // Get GRNs by PO ID
  Future<List<GRNModel>> getGRNsByPOId(String poId) async {
    final allGRNs = _grnBox.values.toList();
    return allGRNs.where((grn) => grn.poId == poId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get GRNs by Supplier
  Future<List<GRNModel>> getGRNsBySupplier(String supplierId) async {
    final allGRNs = _grnBox.values.toList();
    return allGRNs.where((grn) => grn.supplierId == supplierId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get GRNs by Status
  Future<List<GRNModel>> getGRNsByStatus(GRNStatus status) async {
    final allGRNs = _grnBox.values.toList();
    return allGRNs.where((grn) => grn.status == status.name).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Draft GRNs (pending confirmation)
  Future<List<GRNModel>> getDraftGRNs() async {
    return getGRNsByStatus(GRNStatus.draft);
  }

  // Get Confirmed GRNs
  Future<List<GRNModel>> getConfirmedGRNs() async {
    return getGRNsByStatus(GRNStatus.confirmed);
  }

  // Search GRNs by GRN Number or PO Number
  Future<List<GRNModel>> searchGRNs(String query) async {
    if (query.isEmpty) return getAllGRNs();

    final allGRNs = _grnBox.values.toList();
    final lowerQuery = query.toLowerCase();
    return allGRNs.where((grn) {
      return grn.grnNumber.toLowerCase().contains(lowerQuery) ||
          grn.poNumber.toLowerCase().contains(lowerQuery) ||
          (grn.supplierName?.toLowerCase().contains(lowerQuery) ?? false) ||
          (grn.invoiceNumber?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get GRNs by Date Range
  Future<List<GRNModel>> getGRNsByDateRange(DateTime startDate, DateTime endDate) async {
    final allGRNs = _grnBox.values.toList();
    return allGRNs.where((grn) {
      final receivedDate = DateTime.parse(grn.receivedDate);
      return receivedDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          receivedDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
  }

  // Generate next GRN number (format: GRN-YYYYMMDD-XXX)
  String generateGRNNumber() {
    final now = DateTime.now();
    final datePrefix = 'GRN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final todayGRNs = _grnBox.values.where((grn) {
      return grn.grnNumber.startsWith(datePrefix);
    }).toList();

    final nextNumber = todayGRNs.length + 1;
    return '$datePrefix-${nextNumber.toString().padLeft(3, '0')}';
  }

  // Update GRN Status
  Future<void> updateGRNStatus(String grnId, GRNStatus newStatus) async {
    final grn = getGRNById(grnId);
    if (grn != null) {
      final updatedGRN = grn.copyWith(
        status: newStatus.name,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _grnBox.put(grnId, updatedGRN);
    }
  }

  // Get GRN Count
  int getGRNCount() {
    return _grnBox.length;
  }

  // Get Count by Status
  int getCountByStatus(GRNStatus status) {
    return _grnBox.values.where((grn) => grn.status == status.name).length;
  }

  // Get Total Received Amount (from confirmed GRNs)
  double getTotalReceivedAmount() {
    return _grnBox.values
        .where((grn) => grn.statusEnum == GRNStatus.confirmed)
        .fold(0.0, (sum, grn) => sum + (grn.totalAmount ?? 0));
  }

  // Check if PO has any GRNs
  Future<bool> hasPOBeenReceived(String poId) async {
    final grns = await getGRNsByPOId(poId);
    return grns.any((grn) => grn.statusEnum == GRNStatus.confirmed);
  }

  // Get total received quantity for a PO (across all confirmed GRNs)
  Future<int> getTotalReceivedQtyForPO(String poId) async {
    final grns = await getGRNsByPOId(poId);
    return grns
        .where((grn) => grn.statusEnum == GRNStatus.confirmed)
        .fold<int>(0, (sum, grn) => sum + grn.totalReceivedQty);
  }
}