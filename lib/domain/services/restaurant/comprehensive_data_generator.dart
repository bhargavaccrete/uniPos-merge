import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../data/models/restaurant/db/eodmodel_317.dart';
import '../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../data/models/restaurant/db/staffModel_310.dart';
import '../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../data/models/restaurant/db/toppingmodel_304.dart';
import '../../../data/models/restaurant/db/variantmodel_305.dart';


class ComprehensiveDataGenerator {
  static final Random _random = Random();

  // Indian names
  static final List<String> _firstNames = [
    'Rahul', 'Priya', 'Amit', 'Sneha', 'Vikram', 'Anjali', 'Arjun', 'Pooja',
    'Rajesh', 'Kavita', 'Suresh', 'Deepa', 'Karthik', 'Meera', 'Anil', 'Divya',
    'Manoj', 'Shalini', 'Nitin', 'Rekha', 'Sachin', 'Preeti', 'Ravi', 'Nisha',
    'Ajay', 'Swati', 'Varun', 'Shreya', 'Ashok', 'Rani', 'Rohan', 'Karishma',
  ];

  static final List<String> _lastNames = [
    'Kumar', 'Sharma', 'Singh', 'Verma', 'Patel', 'Reddy', 'Gupta', 'Agarwal',
    'Jain', 'Malhotra', 'Chopra', 'Desai', 'Iyer', 'Nair', 'Menon', 'Rao',
  ];

  // Menu items
  static final List<String> _menuItems = [
    'Butter Chicken', 'Paneer Tikka', 'Biryani', 'Dal Makhani', 'Masala Dosa',
    'Tandoori Roti', 'Naan', 'Garlic Naan', 'Palak Paneer', 'Chicken Tikka',
    'Fish Curry', 'Veg Pulao', 'Chole Bhature', 'Samosa', 'Idli Sambhar',
    'Vada Pav', 'Pav Bhaji', 'Raita', 'Gulab Jamun', 'Rasmalai', 'Chai',
    'Coffee', 'Lassi', 'Fresh Lime Soda', 'Mango Juice', 'Chicken Curry',
    'Mutton Rogan Josh', 'Aloo Paratha', 'Paneer Butter Masala', 'Mixed Veg',
  ];

  static final List<String> _paymentTypes = ['Cash', 'Card', 'UPI'];
  static final List<String> _orderTypes = ['Dine-in', 'Takeaway', 'Delivery'];
  static final List<String> _orderStatuses = ['Processing', 'Cooking', 'Ready', 'Served'];

  // Helper methods
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        _random.nextInt(999999).toString();
  }

  static double _randomPrice({double min = 50, double max = 500}) {
    return double.parse((min + _random.nextDouble() * (max - min)).toStringAsFixed(2));
  }

  static DateTime _randomDateTime({int daysBack = 30}) {
    final now = DateTime.now();
    final randomDays = _random.nextInt(daysBack);
    final randomHours = _random.nextInt(12) + 8;
    final randomMinutes = _random.nextInt(60);
    return DateTime(
      now.year,
      now.month,
      now.day - randomDays,
      randomHours,
      randomMinutes,
    );
  }

  // 1. Generate Tables
  static Future<int> generateTables(int count) async {
    final box = Hive.box<TableModel>('tablesBox');
    print('📦 Generating $count tables...');

    final startTime = DateTime.now();

    int generated = 0;

    for (int i = 1; i <= count; i++) {
      final table = TableModel(
        id: 'T$i',




        status: _random.nextBool() ? 'Available' : 'Occupied',
        tableCapacity: 2 + _random.nextInt(6),
      );
      await box.add(table);
      generated++;

      if (generated % 100 == 0) {
        print('✅ Generated $generated/$count tables');
      }
    }

    final duration = DateTime.now().difference(startTime);
    print('✅ Generated $generated tables in ${duration.inMilliseconds}ms');
    return generated;
  }

  // 2. Generate Staff
  static Future<int> generateStaff(int count) async {
    final box = Hive.box<StaffModel>('staffBox');
    print('📦 Generating $count staff members...');

    final startTime = DateTime.now();
    int generated = 0;

    for (int i = 0; i < count; i++) {
      final first = _firstNames[_random.nextInt(_firstNames.length)];
      final last = _lastNames[_random.nextInt(_lastNames.length)];
      final userName = '${first.toLowerCase()}${_random.nextInt(100)}';

      final staff = StaffModel(
        id: _generateId(),
        userName: userName,
        firstName: first,
        lastName: last,
        isCashier: _random.nextBool() ? 'Yes' : 'No',
        mobileNo: '9${_random.nextInt(900000000) + 100000000}',
        emailId: '${userName}@restaurant.com',
        pinNo: '${1000 + _random.nextInt(9000)}',
        createdAt: _randomDateTime(daysBack: 365),
        isActive: true,
      );
      await box.add(staff);
      generated++;

      if (generated % 50 == 0) {
        print('✅ Generated $generated/$count staff');
      }
    }

    final duration = DateTime.now().difference(startTime);
    print('✅ Generated $generated staff in ${duration.inMilliseconds}ms');
    return generated;
  }

  // 3. Generate Tax Rates
  static Future<int> generateTaxRates(int count) async {
    final box = Hive.box<Tax>('restaurant_taxes');
    print('📦 Generating $count tax rates...');

    final startTime = DateTime.now();
    int generated = 0;

    final taxNames = ['GST 5%', 'GST 12%', 'GST 18%', 'GST 28%', 'Service Charge', 'VAT'];
    final taxRates = [5.0, 12.0, 18.0, 28.0, 10.0, 15.0];

    for (int i = 0; i < count && i < taxNames.length; i++) {
      final tax = Tax(
        id: _generateId(),
        taxname: taxNames[i],
        taxperecentage: taxRates[i],
      );
      await box.add(tax);
      generated++;
    }

    final duration = DateTime.now().difference(startTime);
    print('✅ Generated $generated tax rates in ${duration.inMilliseconds}ms');
    return generated;
  }

  // 4. Generate Past Orders (Completed Orders)
  static Future<int> generatePastOrders(int count, {int batchSize = 100}) async {
    final box = Hive.box<PastOrderModel>('pastorderBox');
    final itemBox = Hive.box<Items>('itemBoxs');

    print('📦 Generating $count past orders...');

    if (itemBox.isEmpty) {
      print('⚠️ No items found. Generate items first!');
      return 0;
    }

    final items = itemBox.values.toList();
    final startTime = DateTime.now();
    int generated = 0;
    List<PastOrderModel> batch = [];

    for (int i = 0; i < count; i++) {
      final cartItemCount = 2 + _random.nextInt(7);
      List<CartItem> cartItems = [];
      double totalPrice = 0;

      for (int j = 0; j < cartItemCount; j++) {
        final item = items[_random.nextInt(items.length)];
        final qty = 1 + _random.nextInt(3);
        final price = item.price ?? _randomPrice();
        final itemTotal = price * qty;
        totalPrice += itemTotal;

        cartItems.add(CartItem(
          id: _generateId(),
          title: item.name,
          imagePath: '', // Items now use imageBytes instead of imagePath
          price: price,
          quantity: qty,
          categoryName: 'Food',
          productId: item.id,
          isStockManaged: false,
        ));
      }

      final gstRate = [5.0, 12.0, 18.0][_random.nextInt(3)];
      final subTotal = totalPrice;
      final gstAmount = (subTotal * gstRate) / 100;
      totalPrice = subTotal + gstAmount;

      final first = _firstNames[_random.nextInt(_firstNames.length)];
      final last = _lastNames[_random.nextInt(_lastNames.length)];

      final order = PastOrderModel(
        id: 'ORD${(i + 1).toString().padLeft(6, '0')}',
        customerName: '$first $last',
        orderType: _orderTypes[_random.nextInt(_orderTypes.length)],
        orderStatus: 'COMPLETED',
        orderAt: _randomDateTime(daysBack: 90),
        items: cartItems,
        totalPrice: double.parse(totalPrice.toStringAsFixed(2)),
        subTotal: double.parse(subTotal.toStringAsFixed(2)),
        Discount: 0,
        gstRate: gstRate,
        gstAmount: double.parse(gstAmount.toStringAsFixed(2)),
        paymentmode: _paymentTypes[_random.nextInt(_paymentTypes.length)],
        isRefunded: false,
        kotNumbers: [1],
        kotBoundaries: [cartItems.length],
      );

      batch.add(order);

      if (batch.length >= batchSize) {
        await box.addAll(batch);
        generated += batch.length;
        batch.clear();
        print('✅ Generated $generated/$count past orders');
      }
    }

    if (batch.isNotEmpty) {
      await box.addAll(batch);
      generated += batch.length;
    }

    final duration = DateTime.now().difference(startTime);
    print('✅ Generated $generated past orders in ${duration.inSeconds}s');
    return generated;
  }

  // 5. Generate Active Orders
  static Future<int> generateActiveOrders(int count) async {
    final box = Hive.box<OrderModel>('orderBox');
    final itemBox = Hive.box<Items>('itemBoxs');
    final tableBox = Hive.box<TableModel>('tablesBox');

    print('📦 Generating $count active orders...');

    if (itemBox.isEmpty) {
      print('⚠️ No items found. Generate items first!');
      return 0;
    }

    final items = itemBox.values.toList();
    final tables = tableBox.values.toList();
    final startTime = DateTime.now();
    int generated = 0;

    for (int i = 0; i < count; i++) {
      final cartItemCount = 2 + _random.nextInt(7);
      List<CartItem> cartItems = [];
      double totalPrice = 0;

      for (int j = 0; j < cartItemCount; j++) {
        final item = items[_random.nextInt(items.length)];
        final qty = 1 + _random.nextInt(3);
        final price = item.price ?? _randomPrice();
        final itemTotal = price * qty;
        totalPrice += itemTotal;

        cartItems.add(CartItem(
          id: _generateId(),
          title: item.name,
          imagePath: '', // Items now use imageBytes instead of imagePath
          price: price,
          quantity: qty,
          categoryName: 'Food',
          productId: item.id,
          isStockManaged: false,
        ));
      }

      final gstRate = [5.0, 12.0, 18.0][_random.nextInt(3)];
      final subTotal = totalPrice;
      final gstAmount = (subTotal * gstRate) / 100;
      totalPrice = subTotal + gstAmount;

      final first = _firstNames[_random.nextInt(_firstNames.length)];
      final last = _lastNames[_random.nextInt(_lastNames.length)];

      final order = OrderModel(
        id: _generateId(),
        customerName: '$first $last',
        customerNumber: '9${_random.nextInt(900000000) + 100000000}',
        customerEmail: '',
        status: _orderStatuses[_random.nextInt(_orderStatuses.length)],
        orderType: _orderTypes[_random.nextInt(_orderTypes.length)],
        tableNo: tables.isNotEmpty ? tables[_random.nextInt(tables.length)].id : null,
        items: cartItems,
        totalPrice: double.parse(totalPrice.toStringAsFixed(2)),
        subTotal: double.parse(subTotal.toStringAsFixed(2)),
        discount: 0,
        gstRate: gstRate,
        gstAmount: double.parse(gstAmount.toStringAsFixed(2)),
        paymentMethod: _paymentTypes[_random.nextInt(_paymentTypes.length)],
        paymentStatus: 'Pending',
        isPaid: false,
        timeStamp: DateTime.now(),
        kotNumbers: [1],
        itemCountAtLastKot: cartItems.length,
        kotBoundaries: [cartItems.length],
      );

      await box.add(order);
      generated++;

      if (generated % 100 == 0) {
        print('✅ Generated $generated/$count active orders');
      }
    }

    final duration = DateTime.now().difference(startTime);
    print('✅ Generated $generated active orders in ${duration.inMilliseconds}ms');
    return generated;
  }

  // 6. Generate EOD Reports
  static Future<int> generateEODReports(int count) async {
    final box = Hive.box<EndOfDayReport>('restaurant_eodBox');
    print('📦 Generating $count EOD reports...');

    final startTime = DateTime.now();
    int generated = 0;

    for (int i = 0; i < count; i++) {
      final date = _randomDateTime(daysBack: count);
      final totalSales = _randomPrice(min: 10000, max: 50000);
      final totalExpenses = _randomPrice(min: 1000, max: 5000);

      final totalOrders1 = _random.nextInt(50) + 20;
      final amount1 = totalSales * 0.6;
      final totalOrders2 = _random.nextInt(30) + 10;
      final amount2 = totalSales * 0.3;
      final totalOrders3 = _random.nextInt(20) + 5;
      final amount3 = totalSales * 0.1;

      final totalOrders4 = _random.nextInt(40) + 20;
      final amount4 = totalSales * 0.4;
      final totalOrders5 = _random.nextInt(30) + 10;
      final amount5 = totalSales * 0.3;
      final totalOrders6 = _random.nextInt(30) + 15;
      final amount6 = totalSales * 0.3;

      final report = EndOfDayReport(
        reportId: _generateId(),
        date: date,
        openingBalance: _randomPrice(min: 5000, max: 10000),
        closingBalance: totalSales - totalExpenses,
        totalSales: totalSales,
        totalRefunds: _randomPrice(min: 0, max: 500),
        totalDiscount: _randomPrice(min: 0, max: 1000),
        totalTax: totalSales * 0.18,
        totalExpenses: totalExpenses,
        cashExpenses: totalExpenses * 0.6,
        orderSummaries: [
          OrderTypeSummary(
            orderType: 'Dine-in',
            orderCount: totalOrders1,
            totalAmount: amount1,
            averageOrderValue: amount1 / totalOrders1,
          ),
          OrderTypeSummary(
            orderType: 'Takeaway',
            orderCount: totalOrders2,
            totalAmount: amount2,
            averageOrderValue: amount2 / totalOrders2,
          ),
          OrderTypeSummary(
            orderType: 'Delivery',
            orderCount: totalOrders3,
            totalAmount: amount3,
            averageOrderValue: amount3 / totalOrders3,
          ),
        ],
        categorySales: [],
        paymentSummaries: [
          PaymentSummary(
            paymentType: 'Cash',
            totalAmount: amount4,
            transactionCount: totalOrders4,
            percentage: 40.0,
          ),
          PaymentSummary(
            paymentType: 'Card',
            totalAmount: amount5,
            transactionCount: totalOrders5,
            percentage: 30.0,
          ),
          PaymentSummary(
            paymentType: 'UPI',
            totalAmount: amount6,
            transactionCount: totalOrders6,
            percentage: 30.0,
          ),
        ],
        taxSummaries: [],
        cashReconciliation: CashReconciliation(
          systemExpectedCash: amount4,
          actualCash: amount4,
          difference: 0,
          reconciliationStatus: 'Balanced',
        ),
        totalOrderCount: totalOrders1 + totalOrders2 + totalOrders3,
      );

      await box.add(report);
      generated++;

      if (generated % 10 == 0) {
        print('✅ Generated $generated/$count EOD reports');
      }
    }

    final duration = DateTime.now().difference(startTime);
    print('✅ Generated $generated EOD reports in ${duration.inMilliseconds}ms');
    return generated;
  }

  // Master method to generate all data
  static Future<Map<String, dynamic>> generateAllData({
    int categories = 20,
    int items = 500,
    int tables = 50,
    int staff = 20,
    int taxRates = 6,
    int activeOrders = 100,
    int pastOrders = 5000,
    int eodReports = 30,
    bool withImages = false,
  }) async {
    print('🚀 Starting comprehensive data generation...');
    print('═' * 60);

    final overallStart = DateTime.now();
    Map<String, dynamic> results = {};

    try {
      print('\n1️⃣ Generating Categories...');
      await _generateCategories(categories);
      results['categories'] = categories;

      print('\n2️⃣ Generating Variants...');
      await _generateVariants();
      results['variants'] = 4;

      print('\n3️⃣ Generating Extras...');
      await _generateExtras();
      results['extras'] = 3;

      print('\n4️⃣ Generating Items${withImages ? " with images" : ""}...');
      await _generateItems(items, withImages: withImages);
      results['items'] = items;

      print('\n5️⃣ Generating Tables...');
      results['tables'] = await generateTables(tables);

      print('\n6️⃣ Generating Staff...');
      results['staff'] = await generateStaff(staff);

      print('\n7️⃣ Generating Tax Rates...');
      results['taxRates'] = await generateTaxRates(taxRates);

      print('\n8️⃣ Generating Active Orders...');
      results['activeOrders'] = await generateActiveOrders(activeOrders);

      print('\n9️⃣ Generating Past Orders (this may take a while)...');
      results['pastOrders'] = await generatePastOrders(pastOrders);

      print('\n🔟 Generating EOD Reports...');
      results['eodReports'] = await generateEODReports(eodReports);

      final overallDuration = DateTime.now().difference(overallStart);

      print('\n');
      print('═' * 60);
      print('✅ COMPLETE! All data generated successfully');
      print('═' * 60);
      print('📊 Summary:');
      print('   Categories: ${results['categories']}');
      print('   Variants: ${results['variants']}');
      print('   Extras: ${results['extras']}');
      print('   Items: ${results['items']}');
      print('   Tables: ${results['tables']}');
      print('   Staff: ${results['staff']}');
      print('   Tax Rates: ${results['taxRates']}');
      print('   Active Orders: ${results['activeOrders']}');
      print('   Past Orders: ${results['pastOrders']}');
      print('   EOD Reports: ${results['eodReports']}');
      print('');
      print('⏱️  Total Time: ${overallDuration.inSeconds}s (${overallDuration.inMilliseconds}ms)');
      print('═' * 60);

      results['totalTime'] = overallDuration.inMilliseconds;
      results['success'] = true;

    } catch (e) {
      print('❌ Error during generation: $e');
      results['error'] = e.toString();
      results['success'] = false;
    }

    return results;
  }

  // Helper methods
  static Future<void> _generateCategories(int count) async {
    final box = Hive.box<Category>('categories');
    final categoryNames = [
      'Appetizers', 'Main Course', 'Desserts', 'Beverages', 'Salads',
      'Soups', 'Sides', 'Breakfast', 'Lunch Specials', 'Dinner Specials',
    ];

    for (int i = 0; i < count; i++) {
      final name = i < categoryNames.length
          ? categoryNames[i]
          : '${categoryNames[_random.nextInt(categoryNames.length)]} ${i + 1}';

      await box.add(Category(
        id: _generateId(),
        name: name,
        imagePath: null,
        createdTime: DateTime.now(),
        editCount: 0,
      ));

      if ((i + 1) % 10 == 0) {
        print('✅ Generated ${i + 1}/$count categories');
      }
    }
  }

  static Future<void> _generateVariants() async {
    final box = Hive.box<VariantModel>('variante');
    final sizes = ['Small', 'Medium', 'Large', 'Extra Large'];

    for (final size in sizes) {
      await box.add(VariantModel(
        id: _generateId(),
        name: size,
        createdTime: DateTime.now(),
        editCount: 0,
      ));
    }
  }

  static Future<void> _generateExtras() async {
    final box = Hive.box<Extramodel>('extra');
    final groups = ['Cheese Options', 'Meat Toppings', 'Vegetable Toppings'];

    for (final group in groups) {
      final toppings = <Topping>[];
      for (int i = 0; i < 4; i++) {
        toppings.add(Topping(
          name: '$group Item ${i + 1}',
          isveg: _random.nextBool(),
          price: _randomPrice(min: 10, max: 50),
          isContainSize: false,
          createdTime: DateTime.now(),
          editCount: 0,
        ));
      }

      await box.add(Extramodel(
        Id: _generateId(),
        Ename: group,
        isEnabled: true,
        topping: toppings,
        createdTime: DateTime.now(),
        editCount: 0,
      ));
    }
  }

  static Future<void> _generateItems(int count, {bool withImages = false}) async {
    final itemBox = Hive.box<Items>('itemBoxs');
    final categoryBox = Hive.box<Category>('categories');
    final categories = categoryBox.values.toList();

    List<Items> batch = [];
    int imageCount = 0;

    for (int i = 0; i < count; i++) {
      final category = categories[_random.nextInt(categories.length)];
      final menuItem = _menuItems[_random.nextInt(_menuItems.length)];
      final itemName = '$menuItem #${i + 1}';

      // Generate image if requested and convert to bytes
      Uint8List? imageBytes;
      if (withImages) {
        final imagePath = await _generatePlaceholderImage(itemName, i);
        if (imagePath != null && imagePath.isNotEmpty) {
          try {
            final file = File(imagePath);
            if (file.existsSync()) {
              imageBytes = await file.readAsBytes();
              imageCount++;
            }
          } catch (e) {
            print('⚠️ Failed to read image for item #${i + 1}: $e');
          }
        }
      }

      final item = Items(
        id: _generateId(),
        name: itemName,
        price: _randomPrice(),
        categoryOfItem: category.id,
        description: 'Delicious $menuItem made with finest ingredients',
        imageBytes: imageBytes,
        isVeg: _random.nextBool() ? 'veg' : 'non-veg',
        unit: 'plate',
        variant: null,
        choiceIds: [],
        extraId: null,
        taxRate: 0.0,
        isEnabled: true,
        trackInventory: false,
        stockQuantity: 100,
        allowOrderWhenOutOfStock: true,
        isSoldByWeight: false,
        createdTime: DateTime.now(),
        editCount: 0,
      );

      batch.add(item);

      if (batch.length >= 100) {
        await itemBox.addAll(batch);
        batch.clear();
        print('✅ Generated ${i + 1}/$count items${withImages ? " ($imageCount with images)" : ""}');
      }
    }

    if (batch.isNotEmpty) {
      await itemBox.addAll(batch);
    }

    if (withImages) {
      print('📸 Generated $imageCount images for $count items');
    }
  }

  /// Generate a placeholder image for items with more variety
  static Future<String?> _generatePlaceholderImage(String itemName, int index) async {
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
      print('⚠️ Failed to generate image for item #${index + 1}: $e');
      return null;
    }
  }

  // Clear all data from all boxes
  static Future<void> clearAllData() async {
    print('🗑️ Clearing all data from all boxes...');

    final boxes = [
      'categories',
      'itemBoxs',
      'variante',
      'extra',
      'orderBox',
      'pastorderBox',
      'tablesBox',
      'staffBox',
      'restaurant_taxes',
      'restaurant_eodBox',
      'cart_box',
    ];

    for (final boxName in boxes) {
      try {
        final box = Hive.box(boxName);
        final count = box.length;
        await box.clear();
        print('✅ Cleared $boxName (had $count items)');
      } catch (e) {
        print('⚠️ Error clearing $boxName: $e');
      }
    }

    print('✅ All data cleared!');
  }

  // Get statistics for all boxes
  static Map<String, int> getAllStats() {
    return {
      'categories': Hive.box<Category>('categories').length,
      'items': Hive.box<Items>('itemBoxs').length,
      'variants': Hive.box<VariantModel>('variante').length,
      'extras': Hive.box<Extramodel>('extra').length,
      'activeOrders': Hive.box<OrderModel>('orderBox').length,
      'pastOrders': Hive.box<PastOrderModel>('pastorderBox').length,
      'tables': Hive.box<TableModel>('tablesBox').length,
      'staff': Hive.box<StaffModel>('staffBox').length,
      'taxRates': Hive.box<Tax>('restaurant_taxes').length,
      'eodReports': Hive.box<EndOfDayReport>('restaurant_eodBox').length,
      'cart': Hive.box<CartItem>('cart_box').length,
    };
  }

  // Get file sizes for all boxes
  static Future<Map<String, String>> getBoxFileSizes() async {
    final Map<String, String> sizes = {};

    final boxes = [
      'categories', 'itemBoxs', 'variante', 'extra', 'orderBox',
      'pastorderBox', 'tablesBox', 'staffBox', 'restaurant_taxes', 'restaurant_eodBox', 'cart_box',
    ];

    for (final boxName in boxes) {
      try {
        final box = Hive.box(boxName);

        // Try to get file size using Hive's internal methods
        if (box.isOpen) {
          // Hive stores data, calculate approximate size based on entries
          final itemCount = box.length;
          if (itemCount == 0) {
            sizes[boxName] = '0 B';
          } else {
            // Get the actual file path
            final path = box.path;
            if (path != null && path.isNotEmpty) {
              try {
                final file = File(path);
                if (await file.exists()) {
                  final bytes = await file.length();
                  sizes[boxName] = _formatBytes(bytes);
                } else {
                  // File doesn't exist yet, estimate size
                  sizes[boxName] = 'Empty';
                }
              } catch (fileError) {
                // If file read fails, show count instead
                sizes[boxName] = '$itemCount items';
              }
            } else {
              // No path available, show item count
              sizes[boxName] = '$itemCount items';
            }
          }
        } else {
          sizes[boxName] = 'Closed';
        }
      } catch (e) {
        // Fallback: try to show the error or item count
        try {
          final box = Hive.box(boxName);
          sizes[boxName] = '${box.length} items';
        } catch (_) {
          sizes[boxName] = 'N/A';
        }
      }
    }

    return sizes;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}