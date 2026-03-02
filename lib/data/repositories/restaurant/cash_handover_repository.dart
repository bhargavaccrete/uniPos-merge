import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/cash_handover_model.dart';

/// Data access layer for [CashHandoverModel].
///
/// The handover lifecycle is:
///   createHandover() → status PENDING
///   updateHandover() → status MATCHED or DISCREPANCY
///
/// Both save operations use [id] as the Hive key (upsert pattern).
class CashHandoverRepository {
  late Box<CashHandoverModel> _box;

  CashHandoverRepository() {
    _box = Hive.box<CashHandoverModel>(HiveBoxNames.restaurantCashHandovers);
  }

  /// Persist a handover record (insert or update).
  Future<void> saveHandover(CashHandoverModel handover) async {
    await _box.put(handover.id, handover);
  }

  /// Returns the first PENDING handover, or null if none.
  ///
  /// In normal operation there should never be more than one PENDING
  /// handover at a time — but we take the newest if multiple exist.
  Future<CashHandoverModel?> getPendingHandover() async {
    final pending = _box.values
        .where((h) => h.status == 'PENDING')
        .toList()
      ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
    return pending.isEmpty ? null : pending.first;
  }

  /// All handovers, newest first.
  Future<List<CashHandoverModel>> getAllHandovers() async {
    final all = _box.values.toList();
    all.sort((a, b) => b.closedAt.compareTo(a.closedAt));
    return all;
  }

  /// Replace a handover record (used when completing Step 2).
  Future<void> updateHandover(CashHandoverModel handover) async {
    await _box.put(handover.id, handover);
  }
}
