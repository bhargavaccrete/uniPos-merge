import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/domain/services/restaurant/kot_layout.dart';

import '../../../helpers/test_helpers.dart';

/// F3: an immediate cancel must keep the KOT bookkeeping consistent with the
/// remaining lines, or the Active Orders void reads served lines as unserved.
void main() {
  CartItem line(String id, {int qty = 1}) =>
      makeCartItem(id: id, productId: id, title: id, price: 10, quantity: qty);

  /// The void's served/unserved split, as activeorder.dart:200-216 slices it.
  List<String> unservedIds(KotLayout l, {required String orderStatus}) {
    final ids = <String>[];
    var start = 0;
    for (var i = 0; i < l.kotNumbers.length; i++) {
      final end = (i < l.kotBoundaries.length
              ? l.kotBoundaries[i]
              : l.items.length)
          .clamp(start, l.items.length);
      final status = l.kotStatuses[l.kotNumbers[i]] ?? orderStatus;
      if (status != 'Served') {
        ids.addAll(l.items.sublist(start, end).map((c) => c.id));
      }
      start = end;
    }
    return ids;
  }

  // KOT 1 = [A] (Cooking), KOT 2 = [B, C] (Served).
  KotLayout cancel(String id, int qty, {int aQty = 1}) =>
      KotLayout.removeQuantity(
        items: [line('A', qty: aQty), line('B'), line('C')],
        kotNumbers: [1, 2],
        kotBoundaries: [1, 3],
        kotStatuses: {1: 'Cooking', 2: 'Served'},
        lineId: id,
        qty: qty,
      );

  test('full-line cancel decrements itemCountAtLastKot', () {
    final l = cancel('B', 1);
    expect(l.items.map((c) => c.id), ['A', 'C']);
    expect(l.itemCountAtLastKot, 2);
  });

  test('cancel shifts every later boundary down by one', () {
    final l = KotLayout.removeQuantity(
      items: [line('A'), line('B'), line('C'), line('D')],
      kotNumbers: [1, 2, 3],
      kotBoundaries: [2, 3, 4],
      kotStatuses: {},
      lineId: 'A',
      qty: 1,
    );
    expect(l.kotBoundaries, [1, 2, 3]);
    expect(l.kotNumbers, [1, 2, 3]);
  });

  test('cancelling the last line of a KOT removes its number, boundary, status',
      () {
    final l = cancel('A', 1);
    expect(l.kotNumbers, [2]);
    expect(l.kotBoundaries, [2]);
    expect(l.kotStatuses, {2: 'Served'});
  });

  test('a served line is never classified unserved after a cancel', () {
    final l = cancel('A', 1);
    expect(unservedIds(l, orderStatus: 'Cooking'), isEmpty,
        reason: 'B and C were served; only cancelled A was unserved');
  });

  test('partial cancel keeps the line, boundaries and count', () {
    final l = cancel('A', 1, aQty: 3);
    expect(l.items.map((c) => '${c.id}${c.quantity}'), ['A2', 'B1', 'C1']);
    expect(l.kotBoundaries, [1, 3]);
    expect(l.kotNumbers, [1, 2]);
    expect(l.itemCountAtLastKot, 3);
    expect(unservedIds(l, orderStatus: 'Cooking'), ['A']);
  });

  test('cancel in a middle KOT keeps earlier KOTs intact', () {
    final l = cancel('C', 1);
    expect(l.kotBoundaries, [1, 2]);
    expect(l.kotNumbers, [1, 2]);
    expect(unservedIds(l, orderStatus: 'Cooking'), ['A']);
  });

  test('cancelling the only line of the only KOT keeps one empty KOT', () {
    // OrderModel asserts kotNumbers/kotBoundaries are non-empty; the order is
    // kept (not deleted) when new, unplaced items are still pending.
    final l = KotLayout.removeQuantity(
      items: [line('A')],
      kotNumbers: [1],
      kotBoundaries: [1],
      kotStatuses: {1: 'Cooking'},
      lineId: 'A',
      qty: 1,
    );
    expect(l.items, isEmpty);
    expect(l.kotNumbers, [1]);
    expect(l.kotBoundaries, [0]);
    expect(l.itemCountAtLastKot, 0);
  });

  test('partial cancel shrinks the stock stamp, fresh first', () {
    final l = KotLayout.removeQuantity(
      items: [line('A', qty: 5).copyWith(ownStockQty: 2, freshQty: 3)],
      kotNumbers: [1],
      kotBoundaries: [1],
      kotStatuses: {1: 'Cooking'},
      lineId: 'A',
      qty: 4,
    );
    final a = l.items.single;
    expect([a.quantity, a.freshQty, a.ownStockQty], [1, 0, 1]);
  });

  test('unknown line id leaves the layout unchanged', () {
    final l = cancel('Z', 1);
    expect(l.items.length, 3);
    expect(l.kotBoundaries, [1, 3]);
    expect(l.kotNumbers, [1, 2]);
  });
}
