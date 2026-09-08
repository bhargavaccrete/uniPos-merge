import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';

/// Deleting a category re-parents its products to `''` instead of deleting
/// them. That makes "no category" a NORMAL state, and every screen that shows a
/// product has to render it as a real label — the raw fallback printed a blank
/// chip, so the product looked like it had lost its category entirely.
void main() {
  late Directory tempDir;
  late CategoryStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('category_display_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(HiveTypeIds.category)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailProduct)) {
      Hive.registerAdapter(ProductModelAdapter());
    }
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    store = CategoryStore(CategoryRepository());
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedCategory(String id, String name) async {
    await Hive.box<Category>(HiveBoxNames.category).put(
      id,
      Category(id: id, name: name, createdTime: DateTime(2026, 1, 1)),
    );
    await store.loadCategories();
  }

  test('a live category resolves to its own name', () async {
    await seedCategory('c1', 'Beverages');
    expect(store.displayNameFor('c1'), 'Beverages');
  });

  test('an empty id — what a deleted category leaves behind — is named',
      () async {
    await store.loadCategories();
    expect(store.displayNameFor(''), 'Uncategorized');
  });

  test('null is named too', () async {
    await store.loadCategories();
    expect(store.displayNameFor(null), 'Uncategorized');
  });

  test('an id whose category is gone never shows a bare UUID', () async {
    await seedCategory('c1', 'Beverages');
    // `category` always holds an ID, never a name, so echoing it back tells the
    // shopkeeper nothing.
    expect(store.displayNameFor('9f1c-dead-beef'), 'Uncategorized');
  });

  test('deleting a category leaves its products named, not blank', () async {
    await seedCategory('c1', 'Beverages');
    final products = Hive.box<ProductModel>(HiveBoxNames.products);
    await products.put(
      'p1',
      ProductModel(
        productId: 'p1',
        productName: 'Cola',
        category: 'c1',
        hasVariants: false,
        createdAt: '2026-01-01T00:00:00.000',
        updateAt: '2026-01-01T00:00:00.000',
      ),
    );

    expect(store.displayNameFor(products.get('p1')!.category), 'Beverages');

    await CategoryRepository().deleteCategory('c1');
    await store.loadCategories();

    final reparented = products.get('p1')!;
    expect(reparented.category, '', reason: 'the product survives the delete');
    expect(store.displayNameFor(reparented.category), 'Uncategorized');
  });
}
