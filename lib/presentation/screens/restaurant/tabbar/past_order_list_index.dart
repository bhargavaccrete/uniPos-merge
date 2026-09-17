import 'package:flutter/material.dart';

import '../../../../data/models/restaurant/db/pastordermodel_313.dart';

/// The Past Orders tab's sorted list and search text, built once per change
/// to the orders list instead of on every rebuild and keystroke.
///
/// Sorting, search-text composition and the date rule are the tab's original
/// logic unchanged — only when they run has moved.
class PastOrderListIndex {
  PastOrderListIndex(Iterable<PastOrderModel> source)
      : sorted = source.toList()..sort(newestFirst) {
    _searchText = List<String?>.filled(sorted.length, null);
  }

  /// Newest first. Same input order + same comparator as before, so orders
  /// sharing an `orderAt` keep the relative order they always had.
  final List<PastOrderModel> sorted;

  late final List<String?> _searchText;

  static int newestFirst(PastOrderModel a, PastOrderModel b) =>
      (b.orderAt ?? DateTime(2000)).compareTo(a.orderAt ?? DateTime(2000));

  /// Lower-cased customer, KOTs, bill, type, payment and table, space-joined.
  static String searchTextOf(PastOrderModel o) {
    final kotStr = o.kotNumbers.map((k) => k.toString()).join(' ');
    final billStr = o.billNumber != null
        ? 'inv${o.billNumber} ${o.billNumber}'
        : '';
    return <String?>[
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
  }

  /// Orders matching every filter, in [sorted] order.
  ///
  /// Date range is inclusive on both ends, 00:00:00 to 23:59:59 of the picked
  /// days; an order without `orderAt` always passes it.
  List<PastOrderModel> filter({
    required String orderType,
    required DateTimeRange? dateRange,
    required String rawQuery,
  }) {
    final q = rawQuery.trim().toLowerCase();
    final typeLower = orderType.toLowerCase();

    DateTime? start;
    DateTime? end;
    if (dateRange != null) {
      start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
        0,
        0,
        0,
      );
      end = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );
    }

    final out = <PastOrderModel>[];
    for (var i = 0; i < sorted.length; i++) {
      final o = sorted[i];

      final typeOk =
          orderType == 'All' || (o.orderType ?? '').toLowerCase() == typeLower;
      if (!typeOk) continue;

      final dt = o.orderAt;
      final dateOk = dt == null ||
          start == null ||
          ((dt.isAfter(start) || dt.isAtSameMomentAs(start)) &&
              (dt.isBefore(end!) || dt.isAtSameMomentAs(end)));
      if (!dateOk) continue;

      if (q.isNotEmpty &&
          !(_searchText[i] ??= searchTextOf(o)).contains(q)) {
        continue;
      }
      out.add(o);
    }
    return out;
  }
}
