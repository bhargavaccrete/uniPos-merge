import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../../../../data/models/restaurant/db/toppingmodel_304.dart';
import '../../../../../../data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';

class TestDataGenerator {
  static final Random _random = Random();

  /// Generate test categories
  static final List<String> _categoryNames = [
    'Appetizers',
    'Main Course',
    'Desserts',
    'Beverages',
    'Salads',
    'Soups',
    'Sides',
    'Breakfast',
    'Lunch Specials',
    'Dinner Specials',
  ];

  /// Generate test item names
  static final List<String> _itemPrefixes = [
    'Delicious', 'Special', 'Chef\'s', 'Premium', 'Classic',
    'Spicy', 'Grilled', 'Fried', 'Baked', 'Fresh',
    'Homemade', 'Signature', 'Golden', 'Crispy', 'Tender'
  ];

  static final List<String> _itemTypes = [
    'Chicken', 'Beef', 'Fish', 'Pasta', 'Rice',
    'Burger', 'Pizza', 'Sandwich', 'Wrap', 'Curry',
    'Steak', 'Shrimp', 'Salad', 'Soup', 'Noodles'
  ];

  /// Generate random price
  static double _randomPrice() {
    return double.parse((50 + _random.nextDouble() * 450).toStringAsFixed(2));
  }

  /// Generate random item name
  static String _randomItemName() {
    final prefix = _itemPrefixes[_random.nextInt(_itemPrefixes.length)];
    final type = _itemTypes[_random.nextInt(_itemTypes.length)];
    final number = _random.nextInt(100);
    return '$prefix $type #$number';
  }

  /// Generate random ID
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
           _random.nextInt(999999).toString();
  }

  /// Size variant names
  static final List<String> _sizeNames = ['Small', 'Medium', 'Large', 'Extra Large'];

  /// Topping names
  static final List<String> _toppingNames = [
    'Extra Cheese', 'Bacon', 'Mushrooms', 'Onions', 'Tomatoes',
    'Peppers', 'Olives', 'Jalapeños', 'Pineapple', 'Chicken',
    'Beef', 'Sausage', 'Ham', 'Spinach', 'Garlic'
  ];

  /// Generate a placeholder image for items with more variety
  static Future<String> _generatePlaceholderImage(String itemName, int index) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final productDir = Directory('${appDir.path}/product_images');
      if (!productDir.existsSync()) {
        productDir.createSync(recursive: true);
      }

      // Create a simple colored placeholder image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = const Size(400, 400);

      // More variety in background colors
      final colors = [
        Colors.red.shade400,
        Colors.blue.shade400,
        Colors.green.shade400,
        Colors.orange.shade400,
        Colors.purple.shade400,
        Colors.teal.shade400,
        Colors.pink.shade400,
        Colors.indigo.shade400,
        Colors.amber.shade400,
        Colors.cyan.shade400,
        Colors.lime.shade400,
        Colors.deepOrange.shade400,
        Colors.lightBlue.shade400,
        Colors.lightGreen.shade400,
        Colors.deepPurple.shade400,
      ];

      // Use random color instead of sequential
      final bgColor = colors[_random.nextInt(colors.length)];

      // Draw background with gradient
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(size.width, size.height),
          [bgColor, bgColor.withOpacity(0.7)],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Draw decorative shapes for variety
      final shapePaint = Paint()..color = Colors.white.withOpacity(0.2);
      canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 60, shapePaint);
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), 80, shapePaint);

      // Draw text with shadow
      final textPainter = TextPainter(
        text: TextSpan(
          text: itemName.length > 20 ? '${itemName.substring(0, 17)}...' : itemName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black45,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: size.width - 40);
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );

      // Add item number at bottom
      final numberPainter = TextPainter(
        text: TextSpan(
          text: '#${index + 1}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      numberPainter.layout();
      numberPainter.paint(
        canvas,
        Offset((size.width - numberPainter.width) / 2, size.height - 40),
      );

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // Save to file
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final filePath = p.join(productDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      debugPrint('⚠️ Failed to generate image: $e');
      return '';
    }
  }

  /// Generate test variants (sizes)
  static Future<void> generateTestVariants() async {
    final variantBox = Hive.box<VariantModel>('variante');

    debugPrint('📦 Generating size variants...');

    for (final sizeName in _sizeNames) {
      final variant = VariantModel(
        id: _generateId(),
        name: sizeName,
        createdTime: DateTime.now(),
        editCount: 0,
      );
      await variantBox.add(variant);
    }

    debugPrint('✅ Generated ${_sizeNames.length} size variants!');
  }

  /// Generate test extras with toppings
  static Future<void> generateTestExtras() async {
    final extraBox = Hive.box<Extramodel>('extra');

    debugPrint('📦 Generating extras with toppings...');

    // Generate 3-5 extra groups
    final extraGroups = [
      'Cheese Options',
      'Meat Toppings',
      'Vegetable Toppings',
      'Premium Toppings',
      'Special Add-ons'
    ];

    for (int i = 0; i < 3; i++) {
      final groupName = extraGroups[i];
      final toppings = <Topping>[];

      // Generate 3-5 toppings per group
      final toppingCount = 3 + _random.nextInt(3);
      for (int j = 0; j < toppingCount; j++) {
        final toppingName = _toppingNames[_random.nextInt(_toppingNames.length)];
        final topping = Topping(
          name: '$toppingName ${j + 1}',
          isveg: _random.nextBool(),
          price: double.parse((10 + _random.nextDouble() * 40).toStringAsFixed(2)),
          isContainSize: false,
          createdTime: DateTime.now(),
          editCount: 0,
        );
        toppings.add(topping);
      }

      final extra = Extramodel(
        Id: _generateId(),
        Ename: groupName,
        isEnabled: true,
        topping: toppings,
        createdTime: DateTime.now(),
        editCount: 0,
      );

      await extraBox.add(extra);
    }

    debugPrint('✅ Generated ${extraGroups.take(3).length} extra groups with toppings!');
  }

  /// Generate test categories
  static Future<void> generateTestCategories(int count) async {
    final categoryBox = Hive.box<Category>('categories');

    debugPrint('📦 Generating $count test categories...');

    for (int i = 0; i < count; i++) {
      final categoryName = i < _categoryNames.length
          ? _categoryNames[i]
          : '${_categoryNames[_random.nextInt(_categoryNames.length)]} ${i + 1}';

      final category = Category(
        id: _generateId(),
        name: categoryName,
        imagePath: null,
        createdTime: DateTime.now(),
        editCount: 0,
      );

      await categoryBox.add(category);

      if ((i + 1) % 10 == 0) {
        debugPrint('✅ Generated ${i + 1}/$count categories');
      }
    }

    debugPrint('✅ All $count categories generated!');
  }

  /// Generate test items with variants, extras, and images
  static Future<void> generateTestItems(int count, {bool withImages = false}) async {
    final itemBox = Hive.box<Items>('itemBoxs');
    final categoryBox = Hive.box<Category>('categories');
    final variantBox = Hive.box<VariantModel>('variante');
    final extraBox = Hive.box<Extramodel>('extra');

    if (categoryBox.isEmpty) {
      debugPrint('⚠️ No categories found. Generating 10 categories first...');
      await generateTestCategories(10);
    }

    debugPrint('📦 Generating $count test items${withImages ? ' with images' : ''}...');

    final categories = categoryBox.values.toList();
    final variants = variantBox.values.toList();
    final extras = extraBox.values.toList();
    final items = <Items>[];
    int imageCount = 0;

    for (int i = 0; i < count; i++) {
      final randomCategory = categories[_random.nextInt(categories.length)];
      final basePrice = _randomPrice();
      final itemName = _randomItemName();

      // 30% chance to have size variants
      List<ItemVariante>? itemVariants;
      if (_random.nextDouble() < 0.3 && variants.isNotEmpty) {
        itemVariants = [];
        for (int j = 0; j < variants.length; j++) {
          final variant = variants[j];
          // Price increases by 20-30% for each larger size
          final priceMultiplier = 1.0 + (j * 0.25);
          itemVariants.add(ItemVariante(
            variantId: variant.id,
            price: double.parse((basePrice * priceMultiplier).toStringAsFixed(2)),
            trackInventory: false,
            stockQuantity: 100,
          ));
        }
      }

      // 40% chance to have extras
      List<String>? extraIds;
      if (_random.nextDouble() < 0.4 && extras.isNotEmpty) {
        extraIds = [];
        // Add 1-2 random extra groups
        final extraCount = 1 + _random.nextInt(2);
        for (int j = 0; j < extraCount && j < extras.length; j++) {
          extraIds.add(extras[j].Id);
        }
      }

      // Generate image for ALL items if withImages is true (100% coverage for better testing)
      String? imagePath;
      if (withImages) {
        imagePath = await _generatePlaceholderImage(itemName, i);
        if (imagePath.isNotEmpty) {
          imageCount++;
        }
      }

      final item = Items(
        id: _generateId(),
        name: itemName,
        price: itemVariants != null ? null : basePrice, // null if has variants
        categoryOfItem: randomCategory.id,
        description: 'Test item #${i + 1} - This is a delicious dish made with the finest ingredients.',
        imagePath: imagePath,
        isVeg: _random.nextBool() ? 'veg' : 'non-veg',
        unit: 'plate',
        variant: itemVariants,
        choiceIds: [],
        extraId: extraIds,
        taxRate: 0.0,
        isEnabled: true,
        trackInventory: false,
        stockQuantity: 100,
        allowOrderWhenOutOfStock: true,
        isSoldByWeight: false,
        createdTime: DateTime.now(),
        editCount: 0,
      );

      items.add(item);

      // Add in batches of 50
      if (items.length >= 50) {
        await itemBox.addAll(items);
        items.clear();
        debugPrint('✅ Generated ${i + 1}/$count items${withImages ? " ($imageCount with images)" : ""}');
      }
    }

    // Add remaining items
    if (items.isNotEmpty) {
      await itemBox.addAll(items);
    }

    debugPrint('✅ All $count items generated!${withImages ? " ($imageCount items have images)" : ""}');
  }

  /// Generate complete test dataset with variants, extras, and optional images
  static Future<void> generateCompleteTestData({
    int categories = 10,
    int items = 150,
    bool withImages = false,
  }) async {
    debugPrint('🚀 Starting test data generation...');
    debugPrint('Categories: $categories');
    debugPrint('Items: $items');
    debugPrint('Include images: $withImages');

    // Generate categories first
    await generateTestCategories(categories);

    // Generate variants (sizes)
    await generateTestVariants();

    // Generate extras with toppings
    await generateTestExtras();

    // Generate items with variants, extras, and optionally images
    await generateTestItems(items, withImages: withImages);

    debugPrint('✅ Test data generation complete!');
    debugPrint('📊 Total: $categories categories, ${_sizeNames.length} variants, 3 extra groups, $items items${withImages ? " (with images)" : ""}');
  }

  /// Clear all test data and images
  static Future<void> clearAllData() async {
    debugPrint('🗑️ Clearing all data...');

    final itemBox = Hive.box<Items>('itemBoxs');
    final categoryBox = Hive.box<Category>('categories');
    final variantBox = Hive.box<VariantModel>('variante');
    final extraBox = Hive.box<Extramodel>('extra');

    // Clear images directory
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final productDir = Directory('${appDir.path}/product_images');
      if (productDir.existsSync()) {
        await productDir.delete(recursive: true);
        debugPrint('🗑️ Deleted product images directory');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to delete images: $e');
    }

    await itemBox.clear();
    await categoryBox.clear();
    await variantBox.clear();
    await extraBox.clear();

    debugPrint('✅ All data cleared!');
  }

  /// Get current data statistics
  static void printDataStats() {
    final itemBox = Hive.box<Items>('itemBoxs');
    final categoryBox = Hive.box<Category>('categories');
    final variantBox = Hive.box<VariantModel>('variante');
    final extraBox = Hive.box<Extramodel>('extra');

    debugPrint('📊 Current Data Statistics:');
    debugPrint('Categories: ${categoryBox.length}');
    debugPrint('Items: ${itemBox.length}');
    debugPrint('Variants: ${variantBox.length}');
    debugPrint('Extras: ${extraBox.length}');

    // Count items with variants and extras
    int itemsWithVariants = 0;
    int itemsWithExtras = 0;
    for (final item in itemBox.values) {
      if (item.variant != null && item.variant!.isNotEmpty) itemsWithVariants++;
      if (item.extraId != null && item.extraId!.isNotEmpty) itemsWithExtras++;
    }
    debugPrint('Items with variants: $itemsWithVariants');
    debugPrint('Items with extras: $itemsWithExtras');
  }
}