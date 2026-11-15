import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';

import '../../helpers/test_helpers.dart';

/// Batch 4a (BKP-1, BKP-3, BKP-4) — the backup maps of `OrderModel` and
/// `SaleModel` carry every Hive field, and read them back.
///
/// Field coverage is checked against the model SOURCE: every `@HiveField`
/// declared there must be a key of `toMap()`, and a fully populated record
/// must come back identical through `toMap` → JSON → `fromMap`. A field added
/// to the model later without its map entries fails here.

/// The names of the `@HiveField`s declared in [path], in order.
List<String> hiveFieldNames(String path) {
  final src = File(path).readAsStringSync();
  return [
    for (final m in RegExp(r'@HiveField\(\d+[^)]*\)(?:\s*//[^\n]*)*'
            r'\s*(?:final\s+)?[\w<>?,\s]+?\s+(\w+)\s*;')
        .allMatches(src))
      m.group(1)!,
  ];
}

/// What the export does before JSON (`_deepCleanMap`): map keys become
/// strings, DateTimes ISO strings.
Object? jsonSafe(Object? v) {
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): jsonSafe(e.value)};
  }
  if (v is List) return [for (final e in v) jsonSafe(e)];
  if (v is DateTime) return v.toIso8601String();
  return v;
}

/// The trip a record takes through a backup file.
Map<String, dynamic> throughFile(Map<String, dynamic> map) =>
    jsonDecode(jsonEncode(jsonSafe(map))) as Map<String, dynamic>;

String canon(Map<String, dynamic> m) => jsonEncode(jsonSafe(m));

void main() {
  const orderSource = 'lib/data/models/restaurant/db/ordermodel_309.dart';
  const saleSource = 'lib/data/models/retail/hive_model/sale_model_203.dart';

  // ==========================================================================
  group('OrderModel (BKP-3)', () {
    OrderModel fullOrder() => OrderModel(
          id: 'o1',
          customerName: 'Asha',
          customerNumber: '9876500000',
          customerEmail: 'a@example.com',
          items: [
            makeCartItem(id: 'l1', productId: 'p1', title: 'Paneer',
                price: 100, quantity: 2),
            makeCartItem(id: 'l2', productId: 'p2', title: 'Naan',
                price: 40, quantity: 1),
          ],
          status: 'Cooking',
          timeStamp: DateTime(2026, 11, 12, 12, 30),
          orderType: 'Dine In',
          tableNo: 'T4',
          totalPrice: 252,
          kotNumber: 7,
          discount: 10,
          serviceCharge: 12,
          paymentMethod: 'cash',
          completedAt: DateTime(2026, 11, 12, 13),
          paymentStatus: 'Partially Paid',
          subTotal: 240,
          isPaid: false,
          gstRate: 0.05,
          gstAmount: 12,
          remark: 'no onion',
          kotNumbers: [7, 9],
          itemCountAtLastKot: 2,
          kotBoundaries: [1, 2],
          kotStatuses: {7: 'Ready', 9: 'Cooking'},
          orderNumber: 31,
          customerId: 'c1',
          paymentListJson: '[{"method":"cash","amount":100.0}]',
          isSplitPayment: false,
          totalPaid: 100,
          changeReturn: 0.5,
          isTaxInclusive: true,
          billNumber: 41,
          sessionId: 'sess-2026-11-12',
          lastModifiedBy: 'Ravi',
          lastModifiedAt: DateTime(2026, 11, 12, 12, 45, 10),
          kotTimestamps: {
            7: DateTime(2026, 11, 12, 12, 30, 5),
            9: DateTime(2026, 11, 12, 12, 50, 1),
          },
          loyaltyPointsUsed: 15,
          discountAppliedBy: 'Manager',
          shiftId: 'shift-1',
        );

    test('the source declares the 40 Hive fields this test knows', () {
      final names = hiveFieldNames(orderSource);
      expect(names, hasLength(40));
      expect(names, containsAll(['billNumber', 'sessionId', 'lastModifiedBy',
          'lastModifiedAt', 'kotTimestamps']));
    });

    test('toMap carries every Hive field', () {
      final keys = fullOrder().toMap().keys.toSet();
      for (final name in hiveFieldNames(orderSource)) {
        expect(keys, contains(name), reason: '@HiveField $name not exported');
      }
    });

    test('fromMap reads every Hive field back, through a backup file', () {
      final original = fullOrder();
      final restored = OrderModel.fromMap(throughFile(original.toMap()));
      expect(canon(restored.toMap()), canon(original.toMap()));
    });

    test('the five fields come back with their types', () {
      final r = OrderModel.fromMap(throughFile(fullOrder().toMap()));
      expect(r.billNumber, 41);
      expect(r.sessionId, 'sess-2026-11-12');
      expect(r.lastModifiedBy, 'Ravi');
      expect(r.lastModifiedAt, DateTime(2026, 11, 12, 12, 45, 10));
      expect(r.kotTimestamps, isA<Map<int, DateTime>>());
      expect(r.kotTimestamps, {
        7: DateTime(2026, 11, 12, 12, 30, 5),
        9: DateTime(2026, 11, 12, 12, 50, 1),
      });
    });

    test('kotTimestamps is written as JSON with string keys', () {
      final m = fullOrder().toMap();
      expect(() => jsonEncode(m['kotTimestamps']), returnsNormally);
      expect(m['kotTimestamps'], {
        '7': '2026-11-12T12:30:05.000',
        '9': '2026-11-12T12:50:01.000',
      });
    });

    test('an older backup without the five keys restores them as null', () {
      final old = throughFile(fullOrder().toMap())
        ..remove('billNumber')
        ..remove('sessionId')
        ..remove('lastModifiedBy')
        ..remove('lastModifiedAt')
        ..remove('kotTimestamps');
      final r = OrderModel.fromMap(old);
      expect(r.billNumber, isNull);
      expect(r.sessionId, isNull);
      expect(r.lastModifiedBy, isNull);
      expect(r.lastModifiedAt, isNull);
      expect(r.kotTimestamps, isNull);
      expect(r.items, hasLength(2), reason: 'the rest is unchanged');
      expect(r.totalPaid, 100);
    });

    test('unreadable values are dropped, never refusing the order', () {
      final m = throughFile(fullOrder().toMap())
        ..['lastModifiedAt'] = 'not a time'
        ..['kotTimestamps'] = {'7': 'garbage', '9': '2026-11-12T12:50:01.000'}
        ..['billNumber'] = '41';
      final r = OrderModel.fromMap(m);
      expect(r.lastModifiedAt, isNull);
      expect(r.kotTimestamps, {9: DateTime(2026, 11, 12, 12, 50, 1)});
      expect(r.billNumber, 41);
    });

    test('an order with the five fields unset round-trips as unset', () {
      final o = fullOrder().copyWith();
      final bare = OrderModel(
        id: o.id, customerName: o.customerName,
        customerNumber: o.customerNumber, customerEmail: o.customerEmail,
        items: o.items, status: o.status, timeStamp: o.timeStamp,
        orderType: o.orderType, totalPrice: o.totalPrice,
        kotNumbers: o.kotNumbers, itemCountAtLastKot: o.itemCountAtLastKot,
        kotBoundaries: o.kotBoundaries,
      );
      final r = OrderModel.fromMap(throughFile(bare.toMap()));
      expect(r.billNumber, isNull);
      expect(r.kotTimestamps, isNull);
      expect(r.lastModifiedAt, isNull);
    });
  });

  // ==========================================================================
  group('SaleModel payment legs (BKP-1)', () {
    const splitJson =
        '[{"method":"cash","amount":300.0},{"method":"upi","amount":200.0}]';

    SaleModel fullSale({String? legs = splitJson}) => SaleModel(
          saleId: 's1',
          customerId: 'c1',
          totalItems: 3,
          subtotal: 476.19,
          discountAmount: 5,
          taxAmount: 23.81,
          totalAmount: 500,
          paymentType: 'split',
          date: '2026-11-12T10:00:00.000',
          createdAt: '2026-11-12T10:00:00.000',
          updatedAt: '2026-11-12T10:05:00.000',
          isReturn: true,
          originalSaleId: 's0',
          totalTaxableAmount: 476.19,
          totalGstAmount: 23.81,
          totalCgstAmount: 11.9,
          totalSgstAmount: 11.91,
          grandTotal: 500,
          paymentListJson: legs,
          changeReturn: 0.5,
          totalPaid: 500.5,
          isSplitPayment: true,
          paidAmount: 500,
          dueAmount: 0,
          status: 'paid',
          discountType: 'flat',
          discountValue: 5,
          discountReason: 'regular',
          loyaltyPointsUsed: 20,
          roundOff: 0.01,
          isTaxInclusive: true,
          lineDiscountTotal: 2,
          exchangeGroupId: 'ex-1',
          shiftId: 'shift-1',
          returnReason: 'damaged',
          returnNote: 'box torn',
          invoiceNumber: 'INV-00042',
          taxEnabled: true,
          storeGstNumber: '29ABCDE1234F1Z5',
        );

    test('toMap carries every Hive field', () {
      final names = hiveFieldNames(saleSource);
      expect(names, hasLength(39));
      final keys = fullSale().toMap().keys.toSet();
      for (final name in names) {
        expect(keys, contains(name), reason: '@HiveField $name not exported');
      }
    });

    test('fromMap reads every Hive field back, through a backup file', () {
      final original = fullSale();
      final restored = SaleModel.fromMap(throughFile(original.toMap()));
      expect(canon(restored.toMap()), canon(original.toMap()));
    });

    test('a split sale keeps its exact legs', () {
      final r = SaleModel.fromMap(throughFile(fullSale().toMap()));
      expect(r.paymentListJson, splitJson);
      expect(r.paymentList, [
        {'method': 'cash', 'amount': 300.0},
        {'method': 'upi', 'amount': 200.0},
      ]);
    });

    test('a sale stored without legs (single payment) stays without them', () {
      final r = SaleModel.fromMap(throughFile(fullSale(legs: null).toMap()));
      expect(r.paymentListJson, isNull, reason: 'nothing invented');
      expect(r.paymentList, [
        {'method': 'split', 'amount': 500.0},
      ], reason: 'the same single-leg fallback as before the backup');
    });

    test('an OLD backup with only "paymentList" restores the real legs', () {
      final old = throughFile(fullSale().toMap())..remove('paymentListJson');
      expect(old['paymentList'], hasLength(2));
      final r = SaleModel.fromMap(old);
      expect(r.paymentListJson, splitJson);
      expect(r.paymentList.map((l) => l['method']), ['cash', 'upi']);
    });

    test('an old backup of a three-way split restores all three legs', () {
      const three = '[{"method":"cash","amount":100.0},'
          '{"method":"card","amount":150.0},{"method":"upi","amount":250.0}]';
      final old = throughFile(fullSale(legs: three).toMap())
        ..remove('paymentListJson');
      expect(SaleModel.fromMap(old).paymentListJson, three);
    });

    test('a new backup still has "paymentList" for readers that use it', () {
      final m = throughFile(fullSale().toMap());
      expect(m['paymentList'], [
        {'method': 'cash', 'amount': 300.0},
        {'method': 'upi', 'amount': 200.0},
      ]);
      // A reader from before BKP-1 takes `paymentListJson` as-is: it now
      // gets the real legs instead of nothing.
      expect(m['paymentListJson'], splitJson);
    });

    test('an unreadable old "paymentList" restores as no legs, not a throw',
        () {
      for (final bad in <Object?>['cash', <Object?>[], ['x'], 7, null]) {
        final old = throughFile(fullSale().toMap())
          ..remove('paymentListJson')
          ..['paymentList'] = bad;
        expect(SaleModel.fromMap(old).paymentListJson, isNull,
            reason: 'paymentList = $bad');
      }
    });
  });
}
