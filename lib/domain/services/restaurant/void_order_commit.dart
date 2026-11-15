import 'package:flutter/foundation.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../util/restaurant/restaurant_session.dart';
import 'day_management_service.dart';
import 'inventory_service.dart';
import 'settle_new_order.dart';
import 'stock_journal.dart';

/// Outcome of a void once its record is saved.
class VoidResult {
  /// Every stock return is applied and nothing waits for a person.
  final bool stockFinished;

  /// Why not, for the user; null when [stockFinished].
  final String? message;

  const VoidResult._(this.stockFinished, this.message);
  static const VoidResult finished = VoidResult._(true, null);
}

enum _RecordState { present, absent, unknown }

/// Exactly-once void of an ACTIVE order (Active Orders, End of Day): the void
/// record, the order's removal and its stock return.
///
/// Voids used to save the record, restore stock with random movement ids and
/// keep no note of either, so a stop part-way could not be told from a
/// finished void: retrying could restore twice, not retrying left stock
/// missing. Now the stock return is planned and persisted as a
/// [StockJournal] void entry BEFORE the record is written:
///
/// 1. entry (every unit `planned`) → 2. void record → 3. remove the active
///    order, free its table → 4. each unit through the journal's states,
///    fixed movement ids → entry deleted.
///
/// The record decides: present → the void happened, so every unit is
/// finished exactly once; absent (confirmed by a read that succeeded) →
/// it never happened, the entry is dropped and the order stays active;
/// unreadable → nothing is decided and the entry is kept. A save that
/// reports failure is never trusted either way — the record is re-read.
class VoidOrderCommit {
  VoidOrderCommit._();

  /// Whether voiding [order] voids money: any payment at all, part payments
  /// included (SALE-6) — End of Day's own rule. Such a void is saved as
  /// 'VOIDED' with its payment kept, so it can be refunded; only an order
  /// with nothing paid is a plain 'VOID'.
  static bool wasPaid(OrderModel order) =>
      order.isPaid == true ||
      order.paymentStatus?.toLowerCase() == 'paid' ||
      order.isFullyPaid ||
      (order.totalPaid ?? 0) > 0;

  static Future<void> _tail = Future.value();

  /// One void or recovery at a time.
  static Future<T> _serial<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Voids [order] with [record] as its past-order entry, returning
  /// [restores] to stock. Throws [OrderSaveFailedException] when the record
  /// is not saved (nothing else happened) or cannot be confirmed (the entry
  /// is kept, so a retry or the next start decides). Once the record is
  /// saved it never throws: a stock return that could not finish stays in
  /// the journal and [VoidResult.message] says so.
  static Future<VoidResult> commit({
    required OrderModel order,
    required PastOrderModel record,
    required List<({CartItem line, int qty})> restores,
  }) =>
      _serial(() async {
        // Earlier entries first — this order's own included, so a retry
        // resumes its first attempt instead of planning a second one.
        await _recoverAllUnlocked();

        final key = StockJournal.voidKey(order.id);
        var entry = StockJournal.get(key);
        if (entry == null) {
          final state = await _recordState(order.id);
          if (state == _RecordState.unknown) {
            throw const OrderSaveFailedException(
                'The void could not be checked. Nothing was changed — try '
                'again.');
          }
          if (state == _RecordState.present) {
            // Already voided and its stock returned; only the order and table
            // were left behind.
            return _finishOrder(order.id, order.tableNo);
          }
          entry = await StockJournal.openVoid(
            orderId: order.id,
            tableNo: order.tableNo,
            staffName:
                RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
            sessionId: await DayManagementService.getCurrentSessionId(),
            units: await InventoryService.planRestoreUnits(restores),
          );
        }

        if (!entry.orderSaved) {
          if (await _recordState(order.id) != _RecordState.present) {
            var saved = false;
            try {
              saved = await pastOrderStore.addOrder(record);
            } catch (_) {
              saved = false;
            }
            if (!saved) {
              // Never trust the failure: the write may have landed.
              final state = await _recordState(order.id);
              if (state == _RecordState.absent) {
                await StockJournal.delete(entry.id);
                throw OrderSaveFailedException(pastOrderStore.errorMessage ??
                    'The void could not be saved. The order is unchanged.');
              }
              if (state == _RecordState.unknown) {
                throw const OrderSaveFailedException(
                    'The void could not be confirmed. It will be checked '
                    'again — do not void this order a second way.');
              }
              // Present: the record is saved, so the stock return must
              // follow.
            }
          }
          await StockJournal.markOrderSaved(entry);
        }
        return _finish(entry);
      });

  /// Resolves every persisted void entry (startup). Never throws; entries
  /// still pending are returned with their reason.
  static Future<Map<String, Object>> recoverAll() =>
      _serial(_recoverAllUnlocked);

  static Future<Map<String, Object>> _recoverAllUnlocked() async {
    final failures = <String, Object>{};
    final List<JournalEntry> entries;
    try {
      entries = StockJournal.voidEntries();
    } catch (e) {
      return {'journal': e};
    }
    for (final entry in entries) {
      try {
        if (!entry.orderSaved) {
          final state = await _recordState(entry.orderId);
          if (state == _RecordState.absent) {
            // The void never happened: nothing was applied before the record.
            await StockJournal.delete(entry.id);
            continue;
          }
          if (state == _RecordState.unknown) {
            failures[entry.id] = 'void record could not be read';
            continue;
          }
          await StockJournal.markOrderSaved(entry);
        }
        final result = await _finish(entry);
        if (!result.stockFinished) failures[entry.id] = result.message!;
      } catch (e) {
        failures[entry.id] = e;
        debugPrint('Void ${entry.orderId} not finished: $e');
      }
    }
    return failures;
  }

  /// Steps 3–4 for an entry whose record is saved.
  static Future<VoidResult> _finish(JournalEntry entry) async {
    final removed = await _finishOrder(entry.orderId, entry.tableNo);
    if (!removed.stockFinished) return removed;
    try {
      await StockJournal.complete(entry);
    } catch (e) {
      return VoidResult._(false,
          'The order is voided, but returning its stock failed ($e). It will '
          'finish automatically on the next start.');
    }
    if (entry.units.any((u) => u.state == StockJournal.review)) {
      return const VoidResult._(false,
          'The order is voided. Some stock could not be returned '
          'automatically — check the Stock Check alert.');
    }
    return VoidResult.finished;
  }

  static Future<VoidResult> _finishOrder(String orderId, String? tableNo) async {
    if (!await orderStore.deleteOrder(orderId)) {
      return const VoidResult._(false,
          'The void is saved, but the order could not be removed from active '
          'orders. It will finish automatically on the next start.');
    }
    await _freeTable(tableNo, orderId);
    return VoidResult.finished;
  }

  /// Frees [tableNo] unless it already holds a different order.
  static Future<void> _freeTable(String? tableNo, String orderId) async {
    if (tableNo == null || tableNo.isEmpty) return;
    if (tableStore.tables.isEmpty) await tableStore.loadTables();
    final table = tableStore.tables.where((t) => t.id == tableNo).firstOrNull;
    final current = table?.currentOrderId;
    if (current != null && current.isNotEmpty && current != orderId) return;
    await tableStore.updateTableStatus(tableNo, 'Available');
  }

  /// Whether the VOID/VOIDED record of [orderId] is on disk. A read that
  /// fails is [_RecordState.unknown] — never taken as absent.
  static Future<_RecordState> _recordState(String orderId) async {
    try {
      final record = await pastOrderRepository.getOrderById(orderId);
      final status = record?.orderStatus;
      return status == 'VOID' || status == 'VOIDED'
          ? _RecordState.present
          : _RecordState.absent;
    } catch (_) {
      return _RecordState.unknown;
    }
  }
}
