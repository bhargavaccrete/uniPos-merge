import 'package:hive/hive.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/util/retail/sale_revenue_filter.dart';
import '../../models/common/shift_model.dart';
import '../../models/common/shift_txn.dart';
import '../../models/restaurant/db/pastordermodel_313.dart';

/// Repository layer for Shift data access — SHARED restaurant + retail.
/// Handles all Hive database operations for staff shifts.
///
/// The shift box itself is mode-agnostic; only the revenue transactions a
/// shift is measured by differ, and that fork is contained in [getAllTxns].
class ShiftRepository {
  late Box<ShiftModel> _shiftBox;

  ShiftRepository() {
    _shiftBox = Hive.box<ShiftModel>(HiveBoxNames.shift);
  }

  /// Save (insert or update) a shift
  Future<void> saveShift(ShiftModel shift) async {
    await _shiftBox.put(shift.id, shift);
  }

  /// Get shift by ID
  Future<ShiftModel?> getShiftById(String id) async {
    return _shiftBox.get(id);
  }

  /// Get all shifts, sorted newest first
  Future<List<ShiftModel>> getAllShifts() async {
    final list = _shiftBox.values.toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  /// Get open shift for a specific staff member, or null if none
  Future<ShiftModel?> getOpenShiftForStaff(String staffId) async {
    try {
      return _shiftBox.values.firstWhere(
        (s) => s.staffId == staffId && s.status == 'open',
      );
    } catch (_) {
      return null;
    }
  }

  /// Get shifts within a date range (filter by startTime)
  Future<List<ShiftModel>> getShiftsByDateRange(
      DateTime start, DateTime end) async {
    return _shiftBox.values
        .where((s) =>
            s.startTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
            s.startTime.isBefore(end.add(const Duration(seconds: 1))))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Delete a shift by ID
  Future<void> deleteShift(String id) async {
    await _shiftBox.delete(id);
  }

  /// Get total shift count
  Future<int> getShiftCount() async {
    return _shiftBox.length;
  }

  /// Check if a shift exists
  Future<bool> shiftExists(String id) async {
    return _shiftBox.containsKey(id);
  }

  /// Every revenue transaction on this device, normalised to [ShiftTxn].
  ///
  /// This is the ONE place the two verticals' sale shapes diverge. Rows that
  /// must not count as revenue at all are dropped here, so every consumer can
  /// treat what it gets as already-eligible.
  Future<List<ShiftTxn>> getAllTxns() async {
    return AppConfig.isRetail ? _retailTxns() : _restaurantTxns();
  }

  /// Restaurant: one row per order, refund netted off the same row.
  ///
  /// The exclusion list is deliberately VOID / VOIDED / FULLY_REFUNDED and NOT
  /// `OrderStatusFilter.isExcludedFromRevenue` — that one also drops
  /// CANCELLED, which the shift aggregates have never excluded. Widening it
  /// here would silently move every historical shift total.
  List<ShiftTxn> _restaurantTxns() {
    final box = Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    final out = <ShiftTxn>[];
    for (final o in box.values) {
      final status = (o.orderStatus ?? '').toUpperCase();
      if (status == 'VOID' || status == 'VOIDED' || status == 'FULLY_REFUNDED') {
        continue;
      }
      final at = o.orderAt;
      if (at == null) continue;
      final refund = o.refundAmount ?? 0.0;
      out.add(ShiftTxn(
        id: o.id,
        at: at,
        shiftId: o.shiftId,
        amount: o.totalPrice - refund,
        discount: o.Discount ?? 0.0,
        refund: refund,
        typeLabel: o.orderType ?? 'Unknown',
      ));
    }
    return out;
  }

  /// Retail: a refund is its own `SaleModel` with negated header amounts, so
  /// `totalAmount` nets on a plain sum — do NOT apply `revenueSign` on top,
  /// that is a line-level rule and would double-negate here.
  List<ShiftTxn> _retailTxns() {
    final box = Hive.box<SaleModel>(HiveBoxNames.sales);
    final out = <ShiftTxn>[];
    for (final sale in box.values) {
      if (RetailSaleFilter.isExcludedFromRevenue(sale)) continue;
      final at = DateTime.tryParse(sale.createdAt);
      if (at == null) continue;
      final isReturn = RetailSaleFilter.isReturn(sale);
      out.add(ShiftTxn(
        id: sale.saleId,
        at: at,
        shiftId: sale.shiftId,
        amount: sale.totalAmount,
        // Already negated on a return; report the magnitude discounted.
        discount: sale.discountAmount.abs(),
        // A return's totalAmount is negative — flip it to a positive magnitude.
        refund: isReturn ? -sale.totalAmount : 0.0,
        // Retail has no dine-in/takeaway split.
        typeLabel: null,
      ));
    }
    return out;
  }

  /// Transactions belonging to the given shift.
  ///
  /// Strategy (no global flag — per-transaction decision):
  ///   • shiftId == shift.id      → always included (direct link).
  ///   • a different shiftId      → always excluded (belongs elsewhere).
  ///   • shiftId == null          → included only if `at` falls inside this
  ///     shift's time window (legacy / missed-assignment fallback).
  ///
  /// This avoids the bug where a single linked row would silently exclude ALL
  /// null-shiftId rows from every shift report.
  Future<List<ShiftTxn>> getTxnsForShift(ShiftModel shift) async {
    final all = await getAllTxns();
    return all.where((t) => txnBelongsToShift(t, shift)).toList();
  }

  /// The shared membership rule, exposed so Staff Performance attributes
  /// transactions exactly the way the shift totals do.
  static bool txnBelongsToShift(ShiftTxn t, ShiftModel shift) {
    if (t.shiftId == shift.id) return true;
    if (t.shiftId != null) return false;
    final end = shift.endTime ?? DateTime.now();
    return t.at.isAfter(shift.startTime.subtract(const Duration(seconds: 1))) &&
        t.at.isBefore(end.add(const Duration(seconds: 1)));
  }
}
