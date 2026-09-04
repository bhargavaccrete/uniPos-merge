import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';

import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';

import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/quick_item_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// Quick ("open") items — lines typed at the POS for something the catalogue
/// does not carry.
///
/// The contract these pin:
///   * `QuickItemService` mints a UNIQUE productId and variantId per line, so
///     every GROUPED report must fold them onto one bucket or a name sold N
///     times becomes N single-sale rows — which is what let ad-hoc lines crowd
///     real products out of Top Selling;
///   * the folded lines are collapsed, never dropped, so revenue still
///     reconciles;
///   * the Quick Items report is the one place the per-name breakdown lives,
///     and it groups on the typed name rather than an id.
void main() {
  late Directory tempDir;
  late ReportService service;

  final day = DateTime(2026, 7, 14, 10);
  final windowStart = DateTime(2026, 7, 1);
  final windowEnd = DateTime(2026, 8, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('quick_items_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator
        .registerLazySingleton<SaleItemRepository>(() => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<CategoryStore>(
        () => CategoryStore(CategoryRepository()));
    locator.registerLazySingleton<AttributeStore>(() => AttributeStore());
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));

    service = ReportService();
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Seeding ───────────────────────────────────────────────────────────────

  Future<void> seedSale(
    String saleId, {
    DateTime? at,
    bool isReturn = false,
    double total = 100,
  }) async {
    final iso = (at ?? day).toIso8601String();
    final sign = isReturn ? -1 : 1;
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      saleId,
      SaleModel(
        saleId: saleId,
        totalItems: 1,
        subtotal: total * sign,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: total * sign,
        paymentType: 'cash',
        date: iso,
        createdAt: iso,
        updatedAt: iso,
        isReturn: isReturn,
      ),
    );
  }

  /// A catalogue line.
  Future<void> seedLine(
    String lineId, {
    required String saleId,
    required String productId,
    String? variantId,
    String name = 'Denim Shirt',
    double qty = 1,
    double total = 100,
    double gstRate = 0,
  }) async {
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      lineId,
      SaleItemModel.fromCalculated(
        saleId: saleId,
        varianteId: variantId ?? '$productId-v',
        productId: productId,
        productName: name,
        price: total / qty,
        qty: qty,
        discountAmount: 0,
        gstRate: gstRate,
        taxableAmount: total,
        gstAmount: 0,
        total: total,
      ),
    );
  }

  /// An ad-hoc line, minted the way `CartStore.addQuickItem` mints one: a fresh
  /// prefixed id per line, so two lines of the same name never share an id.
  Future<void> seedQuickLine(
    String lineId, {
    required String saleId,
    String name = 'Gift Wrap',
    double qty = 1,
    double total = 100,
    double gstRate = 0,
    double discount = 0,
  }) async {
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      lineId,
      SaleItemModel.fromCalculated(
        saleId: saleId,
        varianteId: QuickItemService.newVariantId(),
        productId: QuickItemService.newProductId(),
        productName: name,
        price: total / qty,
        qty: qty,
        discountAmount: discount,
        gstRate: gstRate,
        taxableAmount: total,
        gstAmount: 0,
        total: total,
        // A quick item never has a cost price — this is why Profit reports it
        // as unknown rather than as 100% margin.
        costPrice: null,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> quick() =>
      service.getQuickItemsReport(startDate: windowStart, endDate: windowEnd);
  Future<List<Map<String, dynamic>>> productWise() => service
      .getProductWiseSalesReport(startDate: windowStart, endDate: windowEnd);
  Future<List<Map<String, dynamic>>> variantWise() => service
      .getVariantWiseSalesReport(startDate: windowStart, endDate: windowEnd);
  Future<List<Map<String, dynamic>>> categoryWise() => service
      .getCategoryWiseSalesReport(startDate: windowStart, endDate: windowEnd);

  // ── The fold, on every grouped report ─────────────────────────────────────

  group('grouped reports fold ad-hoc lines onto one bucket', () {
    // THE regression this whole change exists for.
    test('50 sales of one typed name are ONE product-wise row, not 50',
        () async {
      for (var i = 1; i <= 50; i++) {
        await seedSale('S-$i');
        await seedQuickLine('L-$i', saleId: 'S-$i', total: 100);
      }

      final rows = await productWise();
      expect(rows, hasLength(1));
      expect(rows.single['productId'], ReportService.quickItemGroupId);
      expect(rows.single['productName'], ReportService.quickItemGroupName);
      expect(rows.single['totalQuantity'], closeTo(50, 0.005));
      expect(rows.single['totalRevenue'], closeTo(5000, 0.005));
    });

    // Collapsed, never dropped — otherwise product-wise stops reconciling with
    // net revenue on Daily/Monthly.
    test('the folded revenue is preserved, not discarded', () async {
      await seedSale('S1');
      await seedLine('L1', saleId: 'S1', productId: 'P1', total: 300);
      await seedQuickLine('L2', saleId: 'S1', total: 200);

      final rows = await productWise();
      final total = rows.fold<double>(
        0,
        (s, r) => s + (r['totalRevenue'] as double),
      );
      expect(total, closeTo(500, 0.005));
      expect(rows, hasLength(2));
    });

    test('different typed names still share the one product-wise bucket',
        () async {
      await seedSale('S1');
      await seedQuickLine('L1', saleId: 'S1', name: 'Gift Wrap', total: 100);
      await seedQuickLine('L2', saleId: 'S1', name: 'Delivery', total: 150);

      final rows = await productWise();
      expect(rows, hasLength(1));
      expect(rows.single['totalRevenue'], closeTo(250, 0.005));
      expect(rows.single['isQuickItem'], isTrue);
    });

    // Variant ids are minted per line too, so it had the identical defect.
    test('variant-wise folds them the same way', () async {
      await seedSale('S1');
      await seedQuickLine('L1', saleId: 'S1', total: 100);
      await seedQuickLine('L2', saleId: 'S1', total: 100);
      await seedLine('L3', saleId: 'S1', productId: 'P1', total: 100);

      final rows = await variantWise();
      expect(rows, hasLength(2));
      final quickRow = rows.firstWhere((r) => r['isQuickItem'] as bool);
      expect(quickRow['variantId'], ReportService.quickItemGroupId);
      expect(quickRow['totalRevenue'], closeTo(200, 0.005));
      // No catalogue attributes to describe.
      expect(quickRow['variantLabel'], '');
    });

    test('a real product is untouched by the fold', () async {
      await seedSale('S1');
      await seedLine('L1', saleId: 'S1', productId: 'P1', total: 100);

      final rows = await productWise();
      expect(rows.single['productId'], 'P1');
      expect(rows.single['isQuickItem'], isFalse);
    });

    // Top Selling is defined as "filter, order and limit over Product-wise" and
    // is pinned that way, so it inherits the fold rather than carrying its own
    // rule. The effect is the right way round: ad-hoc trade now ranks at its
    // true combined size instead of being split into small rows that each look
    // negligible.
    test('Top Selling inherits the fold rather than one row per ad-hoc line',
        () async {
      await seedSale('S1');
      await seedLine('L1', saleId: 'S1', productId: 'P1', total: 250);
      for (var i = 1; i <= 3; i++) {
        await seedQuickLine('Q-$i', saleId: 'S1', total: 100);
      }

      final rows = await service.getTopSellingProductsReport(
          startDate: windowStart, endDate: windowEnd);

      // Two rows, not four.
      expect(rows, hasLength(2));
      // Unfolded these were 3 rows of 100 each, all ranking BELOW P1's 250 and
      // hiding that ad-hoc lines were the larger share.
      expect(rows.first['productId'], ReportService.quickItemGroupId);
      expect(rows.first['totalRevenue'], closeTo(300, 0.005));
      expect(rows.last['productId'], 'P1');
    });
  });

  group('category-wise', () {
    test('ad-hoc lines get their own bucket, not Uncategorized', () async {
      await seedSale('S1');
      // A real product with no category at all.
      await Hive.box<ProductModel>(HiveBoxNames.products).put(
        'P1',
        ProductModel(
          productId: 'P1',
          productName: 'Loose Item',
          category: '',
          hasVariants: false,
          createdAt: day.toIso8601String(),
          updateAt: day.toIso8601String(),
        ),
      );
      await productStore.loadProducts();
      await seedLine('L1', saleId: 'S1', productId: 'P1', total: 100);
      await seedQuickLine('L2', saleId: 'S1', total: 100);

      final rows = await categoryWise();
      final labels = rows.map((r) => r['category']).toList();
      expect(labels, contains('Uncategorized'));
      expect(labels, contains(ReportService.quickItemGroupName));
    });

    // Each quick line has a unique productId, so counting those raw made 3
    // ad-hoc sales read as 3 distinct products.
    test('the product count is not inflated by ad-hoc lines', () async {
      await seedSale('S1');
      for (var i = 1; i <= 3; i++) {
        await seedQuickLine('L-$i', saleId: 'S1', total: 100);
      }

      final row = (await categoryWise())
          .firstWhere((r) => r['category'] == ReportService.quickItemGroupName);
      expect(row['productCount'], 1);
    });
  });

  // ── The report itself ─────────────────────────────────────────────────────

  group('getQuickItemsReport', () {
    test('a period with no ad-hoc lines returns nothing', () async {
      await seedSale('S1');
      await seedLine('L1', saleId: 'S1', productId: 'P1');
      expect(await quick(), isEmpty);
    });

    test('catalogue lines never appear', () async {
      await seedSale('S1');
      await seedLine('L1', saleId: 'S1', productId: 'P1', total: 500);
      await seedQuickLine('L2', saleId: 'S1', name: 'Gift Wrap', total: 100);

      final rows = await quick();
      expect(rows, hasLength(1));
      expect(rows.single['itemName'], 'Gift Wrap');
    });

    // The whole point of grouping on the name rather than an id.
    test('the same name across many sales is ONE row', () async {
      for (var i = 1; i <= 5; i++) {
        await seedSale('S-$i');
        await seedQuickLine('L-$i', saleId: 'S-$i', name: 'Gift Wrap', total: 40);
      }

      final row = (await quick()).single;
      expect(row['itemName'], 'Gift Wrap');
      expect(row['lineCount'], 5);
      expect(row['totalQuantity'], closeTo(5, 0.005));
      expect(row['totalRevenue'], closeTo(200, 0.005));
      expect(row['avgPrice'], closeTo(40, 0.005));
    });

    test('names fold case-insensitively, keeping the first spelling', () async {
      await seedSale('S1');
      await seedQuickLine('L1', saleId: 'S1', name: 'Gift Wrap', total: 100);
      await seedSale('S2');
      await seedQuickLine('L2', saleId: 'S2', name: 'gift wrap ', total: 100);

      final row = (await quick()).single;
      expect(row['itemName'], 'Gift Wrap');
      expect(row['lineCount'], 2);
    });

    test('different names stay separate and sort by revenue', () async {
      await seedSale('S1');
      await seedQuickLine('L1', saleId: 'S1', name: 'Gift Wrap', total: 50);
      await seedQuickLine('L2', saleId: 'S1', name: 'Delivery', total: 300);

      final rows = await quick();
      expect(rows.map((r) => r['itemName']), ['Delivery', 'Gift Wrap']);
    });

    test('a refund nets the name down and is not a second sale', () async {
      await seedSale('S1');
      await seedQuickLine('L1', saleId: 'S1', name: 'Gift Wrap', total: 100);
      await seedSale('R1', isReturn: true, at: day.add(const Duration(days: 1)));
      await seedQuickLine('RL1', saleId: 'R1', name: 'Gift Wrap', total: 100);

      final row = (await quick()).single;
      expect(row['totalRevenue'], closeTo(0, 0.005));
      expect(row['totalQuantity'], closeTo(0, 0.005));
      // The refund is not another time it was sold.
      expect(row['lineCount'], 1);
      // Fully returned: no meaningful average, and never a division by zero.
      expect(row['avgPrice'], closeTo(0, 0.005));
    });

    test('share of sales is measured against all revenue in the window',
        () async {
      await seedSale('S1');
      await seedLine('L1', saleId: 'S1', productId: 'P1', total: 750);
      await seedQuickLine('L2', saleId: 'S1', name: 'Delivery', total: 250);

      expect((await quick()).single['shareOfRevenuePct'], closeTo(25, 0.05));
    });

    test('the tax rates a name was sold at are collected', () async {
      await seedSale('S1');
      await seedQuickLine('L1',
          saleId: 'S1', name: 'Repair', total: 100, gstRate: 18);
      await seedSale('S2');
      await seedQuickLine('L2',
          saleId: 'S2', name: 'Repair', total: 100, gstRate: 5);

      final rates = ((await quick()).single['gstRates'] as List).cast<double>();
      expect(rates, [5, 18]);
    });

    test('first and last sold span the name, not one line', () async {
      await seedSale('S1', at: DateTime(2026, 7, 3));
      await seedQuickLine('L1', saleId: 'S1', name: 'Gift Wrap');
      await seedSale('S2', at: DateTime(2026, 7, 25));
      await seedQuickLine('L2', saleId: 'S2', name: 'Gift Wrap');

      final row = (await quick()).single;
      expect(DateTime.parse(row['firstSold'] as String).day, 3);
      expect(DateTime.parse(row['lastSold'] as String).day, 25);
    });

    test('discount on an ad-hoc line is carried', () async {
      await seedSale('S1');
      await seedQuickLine('L1',
          saleId: 'S1', name: 'Gift Wrap', total: 80, discount: 20);

      expect((await quick()).single['totalDiscount'], closeTo(20, 0.005));
    });

    test('the window start is inclusive and the end exclusive', () async {
      await seedSale('S_early', at: DateTime(2026, 6, 30, 23));
      await seedQuickLine('L1', saleId: 'S_early', name: 'Early');
      await seedSale('S_start', at: windowStart);
      await seedQuickLine('L2', saleId: 'S_start', name: 'Start');
      await seedSale('S_end', at: windowEnd);
      await seedQuickLine('L3', saleId: 'S_end', name: 'End');

      final names = (await quick()).map((r) => r['itemName']).toList();
      expect(names, ['Start']);
    });
  });
}
