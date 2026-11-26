import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/domain/services/restaurant/order_line_diff.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  CartItem l(String id, int qty, {String? title}) => makeCartItem(
      id: id, productId: 'p-$id', title: title ?? id, price: 10, quantity: qty);

  test('qty raise yields one increased delta', () {
    final d = OrderLineDiff.between(baseline: [l('a', 2)], current: [l('a', 3)]);
    expect(d.increased.single.quantity, 1);
    expect(d.added, isEmpty);
    expect(d.hasCancellations, isFalse);
  });

  test('qty drop yields one reduced delta', () {
    final d = OrderLineDiff.between(baseline: [l('a', 3)], current: [l('a', 1)]);
    expect(d.reduced.single.quantity, 2);
    expect(d.hasCancellations, isTrue);
  });

  test('remove and add of equal count yields one removed and one added', () {
    final d = OrderLineDiff.between(
        baseline: [l('a', 1), l('b', 1)], current: [l('a', 1), l('c', 1)]);
    expect(d.removed.single.id, 'b');
    expect(d.added.single.id, 'c');
  });

  test('unchanged lines yield an empty diff', () {
    final d = OrderLineDiff.between(
        baseline: [l('a', 2), l('b', 1)], current: [l('a', 2), l('b', 1)]);
    expect(d.isEmpty, isTrue);
  });

  test('same title on two lines is diffed by id, not by title', () {
    final d = OrderLineDiff.between(
      baseline: [l('a', 1, title: 'Tea')],
      current: [l('a', 1, title: 'Tea'), l('b', 1, title: 'Tea')],
    );
    expect(d.added.single.id, 'b');
    expect(d.increased, isEmpty);
  });
}
