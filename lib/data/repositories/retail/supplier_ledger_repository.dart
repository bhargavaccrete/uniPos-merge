import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/retail/hive_model/supplier_ledger_entry_model_179.dart';

/// Hive I/O for the supplier balance journal.
///
/// Deliberately thin — no derivation lives here. Bucketing and running totals
/// belong to `SupplierStore`, and the rows themselves are only ever written by
/// `SupplierStore.recordBalanceMovement`, never from a screen.
class SupplierLedgerRepository {
  Box<SupplierLedgerEntryModel> get _box =>
      Hive.box<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger);

  Future<void> save(SupplierLedgerEntryModel entry) async {
    await _box.put(entry.entryId, entry);
  }

  /// Oldest first — the order a running balance reads in.
  Future<List<SupplierLedgerEntryModel>> getBySupplier(
    String supplierId,
  ) async {
    return _box.values.where((e) => e.supplierId == supplierId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<List<SupplierLedgerEntryModel>> getAll() async {
    return _box.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Rows recorded against a supplier, without materialising them — used to
  /// tell "no history yet" apart from "history that nets to zero".
  bool hasEntries(String supplierId) =>
      _box.values.any((e) => e.supplierId == supplierId);

  /// Only for deleting a supplier, which is already blocked once any purchase
  /// history exists — so in practice this only ever clears an unused account.
  Future<void> deleteBySupplier(String supplierId) async {
    final keys = _box.values
        .where((e) => e.supplierId == supplierId)
        .map((e) => e.entryId)
        .toList();
    await _box.deleteAll(keys);
  }
}
