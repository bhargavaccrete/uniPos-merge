import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/domain/services/restaurant/order_line_cancel.dart';
import 'package:billberrylite/domain/services/restaurant/void_order_commit.dart';

import '../../../helpers/test_helpers.dart';

class _TaxOn extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// M5: a tax-inclusive order stores its pre-tax base once, not with GST
/// taken off a second time. SALE-6: a part-paid order is a paid void.
void main() {
  setUp(() {
    if (!GetIt.I.isRegistered<BusinessDetailsRepository>()) {
      locator.registerSingleton<BusinessDetailsRepository>(_TaxOn());
    }
  });
  tearDown(() => locator.reset());

  OrderModel order({
    required bool inclusive,
    double? totalPaid,
    bool? isPaid,
    String? paymentStatus,
  }) =>
      OrderModel(
        id: 'o1',
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: [
          makeCartItem(id: 'a', price: 105, quantity: 1, taxRate: 0.05),
          makeCartItem(id: 'b', price: 210, quantity: 1, taxRate: 0.05),
        ],
        status: 'Processing',
        timeStamp: DateTime(2026, 11, 8),
        orderType: 'Dine In',
        totalPrice: 315,
        kotNumbers: [1],
        itemCountAtLastKot: 2,
        kotBoundaries: [2],
        isTaxInclusive: inclusive,
        totalPaid: totalPaid,
        isPaid: isPaid,
        paymentStatus: paymentStatus,
      );

  group('M5: stored pre-tax amount after an item cancel', () {
    test('tax-inclusive: ₹210 incl. 5% left → pre-tax 200, GST 10', () {
      final r = OrderLineCancel.forActiveOrders(order(inclusive: true),
          itemIndexInOrder: 0)!;
      expect(r.order.subTotal, closeTo(200, 1e-9), reason: 'not 190');
      expect(r.order.gstAmount, closeTo(10, 1e-9));
      expect(r.order.totalPrice, closeTo(210, 1e-9));
    });

    test('tax-exclusive is unchanged: ₹210 + 5%', () {
      final r = OrderLineCancel.forActiveOrders(order(inclusive: false),
          itemIndexInOrder: 0)!;
      expect(r.order.subTotal, closeTo(210, 1e-9));
      expect(r.order.gstAmount, closeTo(10.5, 1e-9));
    });
  });

  group('SALE-6: what counts as a paid void', () {
    test('part paid (₹200 of ₹315) is paid', () {
      expect(VoidOrderCommit.wasPaid(order(inclusive: false, totalPaid: 200)), isTrue);
    });
    test('fully paid is paid', () {
      expect(VoidOrderCommit.wasPaid(order(inclusive: false, isPaid: true, totalPaid: 315)),
          isTrue);
    });
    test('nothing paid is not', () {
      expect(VoidOrderCommit.wasPaid(order(inclusive: false)), isFalse);
      expect(VoidOrderCommit.wasPaid(order(inclusive: false, totalPaid: 0)), isFalse);
    });
  });
}
