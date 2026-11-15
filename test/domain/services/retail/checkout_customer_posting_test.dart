import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/domain/services/retail/checkout_customer_posting.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';

/// A customer store whose purchase update fails the first time, the way a
/// storage error mid-checkout would.
class _FailsOnceStore extends CustomerStore {
  _FailsOnceStore(super.repository);
  bool failed = false;

  @override
  Future<void> updateAfterPurchase(
      String customerId, double amount, int points) async {
    if (!failed) {
      failed = true;
      throw Exception('disk full');
    }
    return super.updateAfterPurchase(customerId, amount, points);
  }
}

/// BLK-13: checkout applies the customer-account updates AFTER the sale is
/// saved, through [CheckoutCustomerPosting], and each update exactly once — a
/// retry after a failure finishes only what is left, never charging credit or
/// points twice.
void main() {
  late Directory tempDir;

  Future<void> setUpStores({bool failsOnce = false}) async {
    tempDir = await Directory.systemTemp.createTemp('checkout_posting_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    locator.registerLazySingleton<CustomerStore>(() => failsOnce
        ? _FailsOnceStore(CustomerRepository())
        : CustomerStore(CustomerRepository()));
    await Hive.box<Customer>(HiveBoxNames.customer).put(
      'C1',
      Customer(
        customerId: 'C1',
        name: 'Asha',
        phone: '9999999999',
        loyaltyPoints: 50,
        createdAt: DateTime(2026, 10, 1).toIso8601String(),
      ),
    );
  }

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Customer asha() => Hive.box<Customer>(HiveBoxNames.customer).get('C1')!;

  group('a paid sale', () {
    setUp(() => setUpStores());

    CheckoutCustomerPosting paid({int redeemed = 20, double due = 0}) =>
        CheckoutCustomerPosting.paidSale(
          customerId: 'C1',
          pointsRedeemed: redeemed,
          dueAmount: due,
          grandTotal: 500,
          pointsEarned: 5,
        );

    test('points spent, purchase, points earned and a visit, once', () async {
      final p = paid();
      await p.apply();

      expect(p.isComplete, isTrue);
      expect(asha().loyaltyPoints, 50 - 20 + 5);
      expect(asha().totalPointRedeemed, 20);
      expect(asha().totalPurchaseAmount, 500);
      expect(asha().totalVisites, 1);
      expect(asha().creditBalance, 0);
    });

    test('applying again changes nothing', () async {
      final p = paid();
      await p.apply();
      final once = asha().toMap().toString();

      await p.apply();
      expect(asha().toMap().toString(), once);
    });

    test('part paid (₹500 bill, ₹300 paid): credit ₹200, purchase ₹500 '
        'and one visit — counted once', () async {
      await paid(due: 200).apply();
      expect(asha().creditBalance, 200,
          reason: 'only the unpaid balance goes on credit');
      expect(asha().totalPurchaseAmount, 500,
          reason: 'not 700 — the balance is not a second purchase');
      expect(asha().totalVisites, 1, reason: 'not 2 — one sale, one visit');
      expect(asha().loyaltyPoints, 50 - 20 + 5, reason: 'points once');
    });

    test('no points spent: nothing redeemed', () async {
      await paid(redeemed: 0).apply();
      expect(asha().totalPointRedeemed, 0);
      expect(asha().loyaltyPoints, 50 + 5);
    });
  });

  group('a Pay Later sale', () {
    setUp(() => setUpStores());

    test('the bill on credit, purchase, a visit and points spent, once',
        () async {
      final p = CheckoutCustomerPosting.creditSale(
          customerId: 'C1', grandTotal: 500, pointsRedeemed: 20);
      await p.apply();
      await p.apply();

      expect(asha().creditBalance, 500, reason: 'not 1000');
      expect(asha().totalPurchaseAmount, 500);
      expect(asha().totalVisites, 1);
      expect(asha().loyaltyPoints, 30);
    });
  });

  group('a failure part-way', () {
    setUp(() => setUpStores(failsOnce: true));

    test('the retry finishes the rest without repeating what was done',
        () async {
      final p = CheckoutCustomerPosting.paidSale(
        customerId: 'C1',
        pointsRedeemed: 20,
        dueAmount: 0,
        grandTotal: 500,
        pointsEarned: 5,
      );

      await expectLater(p.apply(), throwsA(isA<Exception>()));
      expect(p.isComplete, isFalse);
      expect(asha().loyaltyPoints, 30, reason: 'points spent before the error');
      expect(asha().totalPurchaseAmount, 0);

      await p.apply(); // the "tap again to finish" retry
      expect(p.isComplete, isTrue);
      expect(asha().loyaltyPoints, 35,
          reason: '30 + 5 earned — the 20 is not spent a second time');
      expect(asha().totalPointRedeemed, 20);
      expect(asha().totalPurchaseAmount, 500);
      expect(asha().totalVisites, 1);
    });
  });
}
