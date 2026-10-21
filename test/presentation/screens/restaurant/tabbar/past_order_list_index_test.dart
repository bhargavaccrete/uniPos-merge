import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/past_order_list_index.dart';

import '../../../../helpers/test_helpers.dart';

/// The Past Orders tab now sorts and builds search text once per data change.
/// These pin that [PastOrderListIndex] yields exactly the rows, in exactly the
/// order, the old per-rebuild Observer code produced.

// ── Pre-change Observer logic, verbatim except that `_orderType`, `_dateRange`,
//    `_searchCtrl.text` and the store list are parameters.
List<PastOrderModel> legacyVisible(
  List<PastOrderModel> storeList,
  String orderType,
  DateTimeRange? dateRange,
  String searchText,
) {
  bool withinRange(DateTime? dt) {
    if (dt == null) return true;
    if (dateRange == null) return true;
    final start = DateTime(
      dateRange.start.year,
      dateRange.start.month,
      dateRange.start.day,
      0,
      0,
      0,
    );
    final end = DateTime(
      dateRange.end.year,
      dateRange.end.month,
      dateRange.end.day,
      23,
      59,
      59,
    );
    return (dt.isAfter(start) || dt.isAtSameMomentAs(start)) &&
        (dt.isBefore(end) || dt.isAtSameMomentAs(end));
  }

  final all = storeList.toList();

  all.sort(
    (a, b) => (b.orderAt ?? DateTime(2000)).compareTo(
      a.orderAt ?? DateTime(2000),
    ),
  );

  final q = searchText.trim().toLowerCase();
  return all.where((o) {
    final typeOk =
        orderType == 'All' ||
        (o.orderType ?? '').toLowerCase() ==
            orderType.toLowerCase();
    final dateOk = withinRange(o.orderAt);
    final kotStr = o.kotNumbers.map((k) => k.toString()).join(' ');
    final billStr = o.billNumber != null
        ? 'inv${o.billNumber} ${o.billNumber}'
        : '';
    final text =
        <String?>[
              o.customerName,
              kotStr,
              billStr,
              o.orderType,
              o.paymentmode,
              o.tableNo,
            ]
            .where((e) => e != null && e.isNotEmpty)
            .map((e) => e!.toLowerCase())
            .join(' ');
    final searchOk = q.isEmpty || text.contains(q);
    return typeOk && dateOk && searchOk;
  }).toList();
}

int _seq = 0;

PastOrderModel pastOrder({
  required DateTime? at,
  String customer = '',
  String? type = 'Take Away',
  String? payment = 'cash',
  String? table,
  int? bill,
  List<int>? kots,
}) {
  _seq++;
  final kotNumbers = kots ?? [_seq];
  return PastOrderModel(
    id: 'po-$_seq',
    customerName: customer,
    totalPrice: 10,
    items: [makeCartItem(price: 10)],
    orderAt: at,
    orderType: type,
    paymentmode: payment,
    tableNo: table,
    billNumber: bill,
    kotNumbers: kotNumbers,
    kotBoundaries: List.filled(kotNumbers.length, 1),
  );
}

List<String> ids(List<PastOrderModel> orders) => [for (final o in orders) o.id];

void main() {
  final day = DateTime(2026, 9, 16);
  final shared = DateTime(2026, 9, 16, 12, 30); // one instant shared by many orders

  final orders = <PastOrderModel>[
    pastOrder(at: DateTime(2026, 9, 16), customer: 'John Smith', bill: 12, kots: [3]),
    pastOrder(at: DateTime(2026, 9, 16, 23, 59, 59), customer: 'Asha', type: 'Delivery', bill: 5, kots: [12]),
    pastOrder(at: DateTime(2026, 9, 16, 23, 59, 59, 500), customer: 'late half second', type: 'Dine In', table: 'T4'),
    pastOrder(at: DateTime(2026, 9, 17), customer: 'Next Day', type: 'dine in', payment: 'UPI', table: '12'),
    pastOrder(at: DateTime(2026, 9, 15, 23, 59, 59, 999), customer: 'johnny', type: 'TAKE AWAY'),
    pastOrder(at: null, customer: 'No Date', type: null, payment: null, bill: 120),
    pastOrder(at: DateTime(2026, 9, 14, 8), customer: '', type: 'Delivery', payment: 'card', kots: [7, 8]),
    pastOrder(at: DateTime(1999, 1, 1), customer: 'Ancient', payment: ''),
    // 30 orders at the same instant → >32 elements with ties, so the list is
    // sorted by the non-insertion algorithm and equal-date order is exercised.
    for (var i = 0; i < 30; i++)
      pastOrder(
        at: shared,
        customer: i.isEven ? 'Tie $i' : 'JOHN tie $i',
        type: ['Take Away', 'Delivery', 'Dine In'][i % 3],
        payment: i % 4 == 0 ? 'cash' : 'upi',
        bill: i % 5 == 0 ? null : 100 + i,
        table: i % 3 == 2 ? 'T$i' : null,
      ),
    pastOrder(at: DateTime(2026, 9, 16, 9), customer: 'Priya', type: 'Take Away', bill: 7, kots: [120]),
  ];

  const types = ['All', 'Take Away', 'Delivery', 'Dine In'];
  final ranges = <DateTimeRange?>[
    null,
    DateTimeRange(start: day, end: day),
    DateTimeRange(start: DateTime(2026, 9, 14), end: DateTime(2026, 9, 16)),
    DateTimeRange(start: DateTime(2026, 9, 17, 15), end: DateTime(2026, 9, 17, 15)),
  ];
  const queries = [
    '',
    '   ',
    'john', // customer, case-insensitive, several matches
    '  JOHN ',
    'inv12',
    '12', // bill 12, KOT 12, table 12, bills 112…
    '7', // KOT / bill digits
    't4',
    'upi',
    'delivery',
    'no such order',
  ];

  test('visible ids match the legacy Observer for every filter combination', () {
    final index = PastOrderListIndex(orders);
    var combos = 0;
    for (final type in types) {
      for (final range in ranges) {
        for (final query in queries) {
          expect(
            ids(index.filter(orderType: type, dateRange: range, rawQuery: query)),
            ids(legacyVisible(orders, type, range, query)),
            reason: 'type=$type range=$range query="$query"',
          );
          combos++;
        }
      }
    }
    expect(combos, types.length * ranges.length * queries.length);
  });

  test('fixture actually hits the edge cases', () {
    final index = PastOrderListIndex(orders);
    final today = DateTimeRange(start: day, end: day);

    // 23:59:59.500 is outside a same-day range (end is 23:59:59), both then and now.
    final visibleToday = ids(index.filter(orderType: 'All', dateRange: today, rawQuery: ''));
    expect(visibleToday, isNot(contains(orders[2].id)));
    expect(visibleToday, contains(orders[1].id));
    expect(visibleToday, contains(orders[0].id));
    // Null orderAt passes any date range.
    expect(visibleToday, contains(orders[5].id));

    // Stored 'dine in' matches the 'Dine In' option.
    expect(ids(index.filter(orderType: 'Dine In', dateRange: null, rawQuery: 'next day')), [orders[3].id]);

    // Equal-orderAt rows keep the exact legacy relative order.
    final tie = index.sorted.where((o) => o.orderAt == shared).map((o) => o.id).toList();
    final legacyTie = legacyVisible(orders, 'All', null, '')
        .where((o) => o.orderAt == shared)
        .map((o) => o.id)
        .toList();
    expect(tie, legacyTie);
    expect(tie, hasLength(30));
  });

  test('search text composition is unchanged', () {
    final o = pastOrder(
      at: day,
      customer: 'Mixed Case',
      type: 'Dine In',
      payment: 'CASH',
      table: 'T9',
      bill: 42,
      kots: [4, 5],
    );
    expect(PastOrderListIndex.searchTextOf(o), 'mixed case 4 5 inv42 42 dine in cash t9');

    final bare = pastOrder(at: day, customer: '', type: null, payment: '', kots: [1]);
    expect(PastOrderListIndex.searchTextOf(bare), '1');
  });

  test('one index serves every keystroke without re-sorting', () {
    final index = PastOrderListIndex(orders);
    final sorted = index.sorted;
    for (final q in ['j', 'jo', 'joh', 'john', 'joh', '']) {
      index.filter(orderType: 'All', dateRange: null, rawQuery: q);
      expect(identical(index.sorted, sorted), isTrue);
    }
    expect(ids(index.sorted), ids(legacyVisible(orders, 'All', null, '')));
  });

  // The tab drops its cached index from an ObservableList.observe listener.
  // That is only sound if every mutation the Observer reacts to also notifies
  // listeners, synchronously.
  test('ObservableList notifies observe() listeners on every store mutation', () {
    final list = ObservableList<PastOrderModel>();
    var notified = 0;
    final dispose = list.observe((_) => notified++);

    final a = pastOrder(at: day);
    final b = pastOrder(at: day);

    list.add(a);
    expect(notified, 1);
    list.addAll([b]);
    expect(notified, 2);
    list[0] = pastOrder(at: day); // updateOrder / processRefund / voidOrder
    expect(notified, 3);
    list.removeWhere((o) => o.id == b.id); // deleteOrder
    expect(notified, 4);
    runInAction(() {
      // loadPastOrders
      list
        ..clear()
        ..addAll([a, b]);
    });
    expect(notified, 6);

    dispose();
    list.add(pastOrder(at: day));
    expect(notified, 6);
  });
}
