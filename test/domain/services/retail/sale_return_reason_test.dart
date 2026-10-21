import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/inventory_loss_model_178.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';

import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/services/retail/sale_return_reason.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// Why a refund happened — the field `ReturnService` accepted for three
/// releases and never wrote.
///
/// The contract these pin:
///   * a reason passed to either entry point reaches the stored return document;
///   * it survives `copyWith`, which is how `ExchangeService._stamp` rewrites a
///     freshly written return's payment legs — the one path that would silently
///     drop it while plain refunds stayed correct;
///   * it survives the backup round-trip;
///   * a code retired in a later release still renders as itself.
void main() {
  group('SaleReturnReason vocabulary', () {
    test('every code resolves to its label', () {
      expect(SaleReturnReason.labelFor('damaged'), 'Damaged');
      expect(SaleReturnReason.labelFor('wrong_item'), 'Wrong Item Given');
      expect(SaleReturnReason.byCode('changed_mind'),
          same(SaleReturnReason.changedMind));
      expect(SaleReturnReason.byCode(null), isNull);
    });

    // A vocabulary can shrink between releases; old rows must still read.
    test('an unknown code falls back to its raw value', () {
      expect(SaleReturnReason.labelFor('retired_code'), 'retired_code');
    });

    test('only `other` demands a note', () {
      expect(SaleReturnReason.other.requiresNote, isTrue);
      final rest =
          SaleReturnReason.all.where((r) => r.code != 'other');
      expect(rest.every((r) => !r.requiresNote), isTrue);
    });
  });

  group('SaleModel carries the reason', () {
    SaleModel returnDoc({String? reason = 'damaged', String? note}) {
      final now = DateTime.now().toIso8601String();
      return SaleModel(
        saleId: 'RTN_1',
        totalItems: 1,
        subtotal: -100,
        discountAmount: 0,
        taxAmount: -18,
        totalAmount: -118,
        paymentType: 'cash',
        date: now,
        createdAt: now,
        updatedAt: now,
        isReturn: true,
        originalSaleId: 'S1',
        returnReason: reason,
        returnNote: note,
      );
    }

    // THE regression guard. `ExchangeService._stamp` copyWith's the return
    // document to rewrite paymentType / paymentListJson; if returnReason is
    // missing from copyWith it is wiped on every exchange leg and nowhere else,
    // which is exactly how discountType and roundOff were lost once before.
    test('copyWith preserves the reason when payment fields are rewritten', () {
      final original = returnDoc(reason: 'defective', note: 'motor dead');

      final stamped = original.copyWith(
        paymentType: 'upi',
        paymentListJson: '[{"method":"upi","amount":-118}]',
        isSplitPayment: false,
        exchangeGroupId: 'EXC-20260903-001',
      );

      expect(stamped.returnReason, 'defective');
      expect(stamped.returnNote, 'motor dead');
      expect(stamped.paymentType, 'upi');
      expect(stamped.exchangeGroupId, 'EXC-20260903-001');
    });

    test('toMap/fromMap round-trips both fields', () {
      final restored = SaleModel.fromMap(
        returnDoc(reason: 'other', note: 'customer complaint').toMap(),
      );
      expect(restored.returnReason, 'other');
      expect(restored.returnNote, 'customer complaint');
    });

    test('a forward sale reads back null', () {
      final now = DateTime.now().toIso8601String();
      final sale = SaleModel(
        saleId: 'S1',
        totalItems: 1,
        subtotal: 100,
        discountAmount: 0,
        taxAmount: 18,
        totalAmount: 118,
        paymentType: 'cash',
        date: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(sale.returnReason, isNull);
      expect(sale.returnNote, isNull);
    });
  });

  group('ReturnService writes the reason', () {
    late Directory tempDir;
    late ReturnService service;

    setUp(() async {
      await locator.reset();

      tempDir = await Directory.systemTemp.createTemp('return_reason_');
      Hive.init(tempDir.path);
      await HiveInit.registerRetailAdapters();

      await AppConfig.init();
      await AppConfig.box.put('businessMode', 'retail');

      await Hive.openBox<SaleModel>(HiveBoxNames.sales);
      await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
      await Hive.openBox<ProductModel>(HiveBoxNames.products);
      await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
      await Hive.openBox<Customer>(HiveBoxNames.customer);
      await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
      await Hive.openBox<CashMovementModel>(
          HiveBoxNames.restaurantCashMovements);
      await Hive.openBox(HiveBoxNames.dayManagementBox);
      await Hive.openBox(HiveBoxNames.appCounters);

      locator.registerLazySingleton<SaleStore>(() => SaleStore());
      locator.registerLazySingleton<SaleItemRepository>(
          () => SaleItemRepository());
      locator
          .registerLazySingleton<VariantRepository>(() => VariantRepository());
      locator.registerLazySingleton<ProductStore>(() => ProductStore());
      locator.registerLazySingleton<CustomerStore>(
          () => CustomerStore(CustomerRepository()));
      locator.registerLazySingleton<CreditPaymentRepository>(
          () => CreditPaymentRepository());
      locator.registerLazySingleton<CashMovementRepository>(
          () => CashMovementRepository());
      locator.registerLazySingleton<CashMovementStore>(
          () => CashMovementStore(locator<CashMovementRepository>()));
      // Damaged / expired returns are written off (R-44) through this store.
      await Hive.openBox<PurchaseReturnModel>(HiveBoxNames.purchaseReturns);
      await Hive.openBox<SupplierClaimModel>(HiveBoxNames.supplierClaims);
      await Hive.openBox<InventoryLossModel>(HiveBoxNames.inventoryLosses);
      locator.registerLazySingleton<DamagedGoodsStore>(() => DamagedGoodsStore());

      service = ReturnService();
    });

    tearDown(() async {
      await locator.reset();
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<void> seed({String saleId = 'S1', double qty = 2}) async {
      final now = DateTime.now().toIso8601String();
      final total = 118.0 * qty;

      await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
        'v1',
        VarianteModel(
          varianteId: 'v1',
          productId: 'p1',
          stockQty: 10,
          costPrice: 60,
          sellingPrice: 100,
          createdAt: now,
        ),
      );
      await Hive.box<SaleModel>(HiveBoxNames.sales).put(
        saleId,
        SaleModel(
          saleId: saleId,
          totalItems: qty,
          subtotal: 100.0 * qty,
          discountAmount: 0,
          taxAmount: 18.0 * qty,
          totalAmount: total,
          paymentType: 'cash',
          date: now,
          createdAt: now,
          updatedAt: now,
          totalTaxableAmount: 100.0 * qty,
          totalGstAmount: 18.0 * qty,
          grandTotal: total,
          paidAmount: total,
        ),
      );
      await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
        '$saleId-L1',
        SaleItemModel.fromCalculated(
          saleId: saleId,
          varianteId: 'v1',
          productId: 'p1',
          productName: 'Test Item',
          price: 100,
          qty: qty,
          discountAmount: 0,
          gstRate: 18,
          taxableAmount: 100.0 * qty,
          gstAmount: 18.0 * qty,
          total: total,
          costPrice: 60,
        ),
      );
    }

    test('a full return stores the reason and note', () async {
      await seed();

      final returnId = await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
        returnReason: SaleReturnReason.damaged.code,
        returnNote: 'box crushed in transit',
      );

      final doc = Hive.box<SaleModel>(HiveBoxNames.sales).get(returnId);
      expect(doc, isNotNull);
      expect(doc!.isReturn, isTrue);
      expect(doc.returnReason, 'damaged');
      expect(doc.returnNote, 'box crushed in transit');
      // The header is still negated — the reason rides along, it does not
      // disturb the sign convention.
      expect(doc.totalAmount, lessThan(0));
    });

    test('a partial return stores the reason', () async {
      await seed(qty: 3);

      final returnId = await service.processPartialReturn(
        originalSaleId: 'S1',
        itemsToReturn: {'v1': 1},
        refundMethod: 'upi',
        returnReason: SaleReturnReason.sizeOrFit.code,
      );

      final doc = Hive.box<SaleModel>(HiveBoxNames.sales).get(returnId);
      expect(doc!.returnReason, 'size_or_fit');
      expect(doc.returnNote, isNull);
      // The refund method still lands on paymentType — the report reads it there.
      expect(doc.paymentType, 'upi');
    });

    test('the original sale is never stamped with a return reason', () async {
      await seed();

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
        returnReason: SaleReturnReason.expired.code,
      );

      final original = Hive.box<SaleModel>(HiveBoxNames.sales).get('S1');
      expect(original!.returnReason, isNull);
    });
  });
}
