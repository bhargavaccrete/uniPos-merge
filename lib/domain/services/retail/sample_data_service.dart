import 'package:uuid/uuid.dart';
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../core/di/service_locator.dart';

/// Service for providing sample data for different business types
/// Helps users get started quickly with pre-populated products
class SampleDataService {
  final _uuid = const Uuid();

  /// Get sample products and variants based on business type
  Future<Map<String, dynamic>> getSampleDataForBusinessType(String businessTypeId) async {
    switch (businessTypeId) {
      case 'retail':
        return _getRetailSampleData();
      case 'grocery':
        return _getGrocerySampleData();
      case 'clothing':
        return _getClothingSampleData();
      case 'electronics':
        return _getElectronicsSampleData();
      case 'pharmacy':
        return _getPharmacySampleData();
      default:
        return _getGeneralSampleData();
    }
  }

  /// Import sample data into the system
  Future<Map<String, dynamic>> importSampleData(String businessTypeId) async {
    try {
      final sampleData = await getSampleDataForBusinessType(businessTypeId);
      final products = sampleData['products'] as List<ProductModel>;
      final variants = sampleData['variants'] as List<VarianteModel>;
      final categories = sampleData['categories'] as List<String>;

      int importedCount = 0;

      // Add categories first
      for (var category in categories) {
        if (!productStore.categories.contains(category)) {
          await productStore.addCategory(category);
        }
      }

      // Add products and their variants
      for (var product in products) {
        await productStore.addProduct(product);
        importedCount++;

        // Add variants for this product
        final productVariants = variants.where((v) => v.productId == product.productId).toList();
        for (var variant in productVariants) {
          await productStore.addVariant(variant);
          importedCount++;
        }
      }

      return {
        'success': true,
        'imported': importedCount,
        'message': 'Successfully imported $importedCount items',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to import sample data: $e',
      };
    }
  }

  Map<String, dynamic> _getRetailSampleData() {
    final products = <ProductModel>[];
    final variants = <VarianteModel>[];
    final categories = ['Electronics', 'Home & Kitchen', 'Books', 'Stationery', 'Toys'];

    // Product 1: Wireless Mouse
    final mouseId = _uuid.v4();
    products.add(ProductModel(
      productId: mouseId,
      productName: 'Wireless Mouse',
      brandName: 'TechPro',
      category: 'Electronics',
      description: 'Ergonomic wireless mouse with 2.4GHz connectivity',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: mouseId,
      color: 'Black',
      sku: 'MOUSE-BLK-001',
      barcode: '1234567890001',
      mrp: 599.00,
      costPrice: 350.00,
      stockQty: 50,
      minStock: 10,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: mouseId,
      color: 'White',
      sku: 'MOUSE-WHT-001',
      barcode: '1234567890002',
      mrp: 599.00,
      costPrice: 350.00,
      stockQty: 30,
      minStock: 10,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 2: Coffee Maker
    final coffeeMakerId = _uuid.v4();
    products.add(ProductModel(
      productId: coffeeMakerId,
      productName: 'Coffee Maker',
      brandName: 'HomeEssentials',
      category: 'Home & Kitchen',
      description: '12-cup programmable coffee maker with auto-shutoff',
      hasVariants: false,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: coffeeMakerId,
      sku: 'COFFEE-001',
      barcode: '1234567890003',
      mrp: 2499.00,
      costPrice: 1800.00,
      stockQty: 25,
      minStock: 5,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 3: Notebook Set
    final notebookId = _uuid.v4();
    products.add(ProductModel(
      productId: notebookId,
      productName: 'Premium Notebook Set',
      brandName: 'WriteWell',
      category: 'Stationery',
      description: 'Set of 3 ruled notebooks with hardcover',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: notebookId,
      size: 'A4',
      color: 'Blue',
      sku: 'NOTE-A4-BLU',
      barcode: '1234567890004',
      mrp: 299.00,
      costPrice: 180.00,
      stockQty: 100,
      minStock: 20,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: notebookId,
      size: 'A5',
      color: 'Red',
      sku: 'NOTE-A5-RED',
      barcode: '1234567890005',
      mrp: 199.00,
      costPrice: 120.00,
      stockQty: 80,
      minStock: 20,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 4: LED Desk Lamp
    final lampId = _uuid.v4();
    products.add(ProductModel(
      productId: lampId,
      productName: 'LED Desk Lamp',
      brandName: 'BrightLight',
      category: 'Electronics',
      description: 'Adjustable LED desk lamp with USB charging port',
      hasVariants: false,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: lampId,
      sku: 'LAMP-LED-001',
      barcode: '1234567890006',
      mrp: 1299.00,
      costPrice: 850.00,
      stockQty: 40,
      minStock: 8,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 5: Building Blocks Set
    final blocksId = _uuid.v4();
    products.add(ProductModel(
      productId: blocksId,
      productName: 'Building Blocks Set',
      brandName: 'KidPlay',
      category: 'Toys',
      description: '500-piece colorful building blocks for kids',
      hasVariants: false,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: blocksId,
      sku: 'TOY-BLOCKS-500',
      barcode: '1234567890007',
      mrp: 899.00,
      costPrice: 550.00,
      stockQty: 35,
      minStock: 10,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    return {
      'products': products,
      'variants': variants,
      'categories': categories,
    };
  }

  Map<String, dynamic> _getGrocerySampleData() {
    final products = <ProductModel>[];
    final variants = <VarianteModel>[];
    final categories = ['Dairy', 'Beverages', 'Snacks', 'Cereals', 'Personal Care'];

    // Product 1: Fresh Milk
    final milkId = _uuid.v4();
    products.add(ProductModel(
      productId: milkId,
      productName: 'Fresh Milk',
      brandName: 'DairyFresh',
      category: 'Dairy',
      description: 'Full cream fresh milk',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: milkId,
      size: '500ml',
      sku: 'MILK-500ML',
      barcode: '2234567890001',
      mrp: 30.00,
      costPrice: 22.00,
      stockQty: 200,
      minStock: 50,
      taxRate: 0.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: milkId,
      size: '1L',
      sku: 'MILK-1L',
      barcode: '2234567890002',
      mrp: 58.00,
      costPrice: 42.00,
      stockQty: 150,
      minStock: 40,
      taxRate: 0.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 2: Orange Juice
    final juiceId = _uuid.v4();
    products.add(ProductModel(
      productId: juiceId,
      productName: 'Orange Juice',
      brandName: 'FreshFruit',
      category: 'Beverages',
      description: '100% pure orange juice',
      hasVariants: false,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: juiceId,
      size: '1L',
      sku: 'JUICE-ORA-1L',
      barcode: '2234567890003',
      mrp: 120.00,
      costPrice: 85.00,
      stockQty: 80,
      minStock: 20,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 3: Potato Chips
    final chipsId = _uuid.v4();
    products.add(ProductModel(
      productId: chipsId,
      productName: 'Potato Chips',
      brandName: 'CrunchyBites',
      category: 'Snacks',
      description: 'Classic salted potato chips',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: chipsId,
      size: '50g',
      sku: 'CHIPS-50G',
      barcode: '2234567890004',
      mrp: 20.00,
      costPrice: 14.00,
      stockQty: 300,
      minStock: 50,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: chipsId,
      size: '100g',
      sku: 'CHIPS-100G',
      barcode: '2234567890005',
      mrp: 35.00,
      costPrice: 25.00,
      stockQty: 200,
      minStock: 40,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 4: Corn Flakes
    final cerealId = _uuid.v4();
    products.add(ProductModel(
      productId: cerealId,
      productName: 'Corn Flakes',
      brandName: 'MorningCrunch',
      category: 'Cereals',
      description: 'Crispy corn flakes breakfast cereal',
      hasVariants: false,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: cerealId,
      size: '500g',
      sku: 'CEREAL-CORN-500G',
      barcode: '2234567890006',
      mrp: 180.00,
      costPrice: 130.00,
      stockQty: 60,
      minStock: 15,
      taxRate: 5.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 5: Hand Wash
    final handwashId = _uuid.v4();
    products.add(ProductModel(
      productId: handwashId,
      productName: 'Liquid Hand Wash',
      brandName: 'CleanHands',
      category: 'Personal Care',
      description: 'Antibacterial liquid hand wash',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: handwashId,
      size: '200ml',
      sku: 'WASH-200ML',
      barcode: '2234567890007',
      mrp: 85.00,
      costPrice: 60.00,
      stockQty: 100,
      minStock: 20,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: handwashId,
      size: '500ml',
      sku: 'WASH-500ML',
      barcode: '2234567890008',
      mrp: 175.00,
      costPrice: 125.00,
      stockQty: 75,
      minStock: 15,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    return {
      'products': products,
      'variants': variants,
      'categories': categories,
    };
  }

  Map<String, dynamic> _getClothingSampleData() {
    final products = <ProductModel>[];
    final variants = <VarianteModel>[];
    final categories = ['Men\'s Wear', 'Women\'s Wear', 'Kids Wear', 'Accessories'];

    // Product 1: Men's T-Shirt
    final tshirtId = _uuid.v4();
    products.add(ProductModel(
      productId: tshirtId,
      productName: 'Cotton T-Shirt',
      brandName: 'FashionHub',
      category: 'Men\'s Wear',
      description: 'Premium cotton round neck t-shirt',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    final sizes = ['S', 'M', 'L', 'XL'];
    final colors = ['Black', 'White', 'Blue', 'Red'];
    int barcodeCounter = 1;
    for (var size in sizes) {
      for (var color in colors) {
        variants.add(VarianteModel(
          varianteId: _uuid.v4(),
          productId: tshirtId,
          size: size,
          color: color,
          sku: 'TSHIRT-$size-${color.substring(0, 3).toUpperCase()}',
          barcode: '334456789000${barcodeCounter++}',
          mrp: 499.00,
          costPrice: 280.00,
          stockQty: 15,
          minStock: 3,
          taxRate: 5.0,
          createdAt: DateTime.now().toIso8601String(),
        ));
      }
    }

    // Product 2: Women's Kurta
    final kurtaId = _uuid.v4();
    products.add(ProductModel(
      productId: kurtaId,
      productName: 'Designer Kurta',
      brandName: 'EthnicStyle',
      category: 'Women\'s Wear',
      description: 'Elegant printed cotton kurta',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    final kurtaSizes = ['S', 'M', 'L', 'XL'];
    final kurtaColors = ['Pink', 'Green', 'Yellow'];
    for (var size in kurtaSizes) {
      for (var color in kurtaColors) {
        variants.add(VarianteModel(
          varianteId: _uuid.v4(),
          productId: kurtaId,
          size: size,
          color: color,
          sku: 'KURTA-$size-${color.substring(0, 3).toUpperCase()}',
          barcode: '334456789000${barcodeCounter++}',
          mrp: 899.00,
          costPrice: 550.00,
          stockQty: 10,
          minStock: 2,
          taxRate: 5.0,
          createdAt: DateTime.now().toIso8601String(),
        ));
      }
    }

    // Product 3: Kids Jeans
    final jeansId = _uuid.v4();
    products.add(ProductModel(
      productId: jeansId,
      productName: 'Kids Denim Jeans',
      brandName: 'JuniorStyle',
      category: 'Kids Wear',
      description: 'Comfortable stretch denim jeans for kids',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    final kidsSizes = ['2-3Y', '4-5Y', '6-7Y', '8-9Y'];
    final jeansColors = ['Blue', 'Black'];
    for (var size in kidsSizes) {
      for (var color in jeansColors) {
        variants.add(VarianteModel(
          varianteId: _uuid.v4(),
          productId: jeansId,
          size: size,
          color: color,
          sku: 'JEANS-$size-${color.substring(0, 3).toUpperCase()}',
          barcode: '334456789000${barcodeCounter++}',
          mrp: 699.00,
          costPrice: 420.00,
          stockQty: 12,
          minStock: 3,
          taxRate: 5.0,
          createdAt: DateTime.now().toIso8601String(),
        ));
      }
    }

    // Product 4: Leather Belt
    final beltId = _uuid.v4();
    products.add(ProductModel(
      productId: beltId,
      productName: 'Genuine Leather Belt',
      brandName: 'ClassicAccessories',
      category: 'Accessories',
      description: 'Premium genuine leather belt',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    final beltSizes = ['32', '34', '36', '38', '40'];
    final beltColors = ['Brown', 'Black'];
    for (var size in beltSizes) {
      for (var color in beltColors) {
        variants.add(VarianteModel(
          varianteId: _uuid.v4(),
          productId: beltId,
          size: size,
          color: color,
          sku: 'BELT-$size-${color.substring(0, 3).toUpperCase()}',
          barcode: '334456789000${barcodeCounter++}',
          mrp: 799.00,
          costPrice: 480.00,
          stockQty: 20,
          minStock: 5,
          taxRate: 18.0,
          createdAt: DateTime.now().toIso8601String(),
        ));
      }
    }

    return {
      'products': products,
      'variants': variants,
      'categories': categories,
    };
  }

  Map<String, dynamic> _getElectronicsSampleData() {
    final products = <ProductModel>[];
    final variants = <VarianteModel>[];
    final categories = ['Mobile Accessories', 'Audio', 'Computing', 'Smart Devices'];

    // Product 1: Phone Case
    final caseId = _uuid.v4();
    products.add(ProductModel(
      productId: caseId,
      productName: 'Silicone Phone Case',
      brandName: 'TechGuard',
      category: 'Mobile Accessories',
      description: 'Slim silicone protective case',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    final phoneModels = ['iPhone 14', 'iPhone 15', 'Samsung S23', 'OnePlus 11'];
    final caseColors = ['Black', 'Blue', 'Pink'];
    int electronicsBarcode = 1;
    for (var model in phoneModels) {
      for (var color in caseColors) {
        variants.add(VarianteModel(
          varianteId: _uuid.v4(),
          productId: caseId,
          size: model,
          color: color,
          sku: 'CASE-${model.replaceAll(' ', '')}-${color.substring(0, 3).toUpperCase()}',
          barcode: '434567890000${electronicsBarcode++}',
          mrp: 299.00,
          costPrice: 150.00,
          stockQty: 25,
          minStock: 5,
          taxRate: 18.0,
          createdAt: DateTime.now().toIso8601String(),
        ));
      }
    }

    // Product 2: Bluetooth Earphones
    final earphoneId = _uuid.v4();
    products.add(ProductModel(
      productId: earphoneId,
      productName: 'TWS Earbuds',
      brandName: 'SoundPro',
      category: 'Audio',
      description: 'True wireless stereo earbuds with charging case',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: earphoneId,
      color: 'Black',
      sku: 'TWS-BLK-001',
      barcode: '434567890100',
      mrp: 1999.00,
      costPrice: 1200.00,
      stockQty: 40,
      minStock: 10,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: earphoneId,
      color: 'White',
      sku: 'TWS-WHT-001',
      barcode: '434567890101',
      mrp: 1999.00,
      costPrice: 1200.00,
      stockQty: 35,
      minStock: 10,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 3: USB Flash Drive
    final usbId = _uuid.v4();
    products.add(ProductModel(
      productId: usbId,
      productName: 'USB Flash Drive',
      brandName: 'DataStore',
      category: 'Computing',
      description: 'High-speed USB 3.0 flash drive',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    final capacities = ['32GB', '64GB', '128GB'];
    for (var capacity in capacities) {
      final price = capacity == '32GB' ? 399.0 : (capacity == '64GB' ? 699.0 : 1199.0);
      final cost = capacity == '32GB' ? 250.0 : (capacity == '64GB' ? 450.0 : 750.0);
      variants.add(VarianteModel(
        varianteId: _uuid.v4(),
        productId: usbId,
        size: capacity,
        sku: 'USB-$capacity',
        barcode: '434567890${capacities.indexOf(capacity) + 200}',
        mrp: price,
        costPrice: cost,
        stockQty: 50,
        minStock: 10,
        taxRate: 18.0,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }

    // Product 4: Smart Watch
    final watchId = _uuid.v4();
    products.add(ProductModel(
      productId: watchId,
      productName: 'Fitness Smart Watch',
      brandName: 'FitTrack',
      category: 'Smart Devices',
      description: 'Fitness tracker with heart rate monitor',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    final watchColors = ['Black', 'Blue', 'Pink'];
    for (var color in watchColors) {
      variants.add(VarianteModel(
        varianteId: _uuid.v4(),
        productId: watchId,
        color: color,
        sku: 'WATCH-${color.substring(0, 3).toUpperCase()}',
        barcode: '434567890${300 + watchColors.indexOf(color)}',
        mrp: 2999.00,
        costPrice: 1800.00,
        stockQty: 30,
        minStock: 8,
        taxRate: 18.0,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }

    return {
      'products': products,
      'variants': variants,
      'categories': categories,
    };
  }

  Map<String, dynamic> _getPharmacySampleData() {
    final products = <ProductModel>[];
    final variants = <VarianteModel>[];
    final categories = ['Medicines', 'Vitamins', 'First Aid', 'Personal Care', 'Baby Care'];

    // Product 1: Paracetamol
    final paracetamolId = _uuid.v4();
    products.add(ProductModel(
      productId: paracetamolId,
      productName: 'Paracetamol 500mg',
      brandName: 'HealthCare',
      category: 'Medicines',
      description: 'Pain relief and fever reducer',
      hasVariants: false,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: paracetamolId,
      sku: 'MED-PARA-500',
      barcode: '534567890001',
      mrp: 15.00,
      costPrice: 10.00,
      stockQty: 500,
      minStock: 100,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 2: Vitamin C
    final vitCId = _uuid.v4();
    products.add(ProductModel(
      productId: vitCId,
      productName: 'Vitamin C Tablets',
      brandName: 'VitaBoost',
      category: 'Vitamins',
      description: '1000mg vitamin C supplement',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: vitCId,
      size: '30 tablets',
      sku: 'VIT-C-30',
      barcode: '534567890002',
      mrp: 180.00,
      costPrice: 120.00,
      stockQty: 100,
      minStock: 20,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: vitCId,
      size: '60 tablets',
      sku: 'VIT-C-60',
      barcode: '534567890003',
      mrp: 320.00,
      costPrice: 220.00,
      stockQty: 80,
      minStock: 15,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 3: Bandages
    final bandageId = _uuid.v4();
    products.add(ProductModel(
      productId: bandageId,
      productName: 'Adhesive Bandages',
      brandName: 'FirstAid Plus',
      category: 'First Aid',
      description: 'Sterile adhesive bandages pack',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: bandageId,
      size: '10 pieces',
      sku: 'BAND-10',
      barcode: '534567890004',
      mrp: 45.00,
      costPrice: 30.00,
      stockQty: 150,
      minStock: 30,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: bandageId,
      size: '25 pieces',
      sku: 'BAND-25',
      barcode: '534567890005',
      mrp: 95.00,
      costPrice: 65.00,
      stockQty: 100,
      minStock: 20,
      taxRate: 12.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 4: Sanitizer
    final sanitizerId = _uuid.v4();
    products.add(ProductModel(
      productId: sanitizerId,
      productName: 'Hand Sanitizer',
      brandName: 'SafeHands',
      category: 'Personal Care',
      description: '70% alcohol-based hand sanitizer',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: sanitizerId,
      size: '50ml',
      sku: 'SAN-50ML',
      barcode: '534567890006',
      mrp: 40.00,
      costPrice: 28.00,
      stockQty: 200,
      minStock: 40,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    variants.add(VarianteModel(
      varianteId: _uuid.v4(),
      productId: sanitizerId,
      size: '200ml',
      sku: 'SAN-200ML',
      barcode: '534567890007',
      mrp: 120.00,
      costPrice: 85.00,
      stockQty: 120,
      minStock: 25,
      taxRate: 18.0,
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Product 5: Baby Diapers
    final diaperId = _uuid.v4();
    products.add(ProductModel(
      productId: diaperId,
      productName: 'Baby Diapers',
      brandName: 'BabyCare',
      category: 'Baby Care',
      description: 'Soft and absorbent baby diapers',
      hasVariants: true,
      createdAt: DateTime.now().toIso8601String(),
      updateAt: DateTime.now().toIso8601String(),
    ));
    final sizes = ['S', 'M', 'L', 'XL'];
    for (var size in sizes) {
      final price = size == 'S' ? 299.0 : (size == 'M' ? 349.0 : (size == 'L' ? 399.0 : 449.0));
      final cost = size == 'S' ? 220.0 : (size == 'M' ? 260.0 : (size == 'L' ? 300.0 : 340.0));
      variants.add(VarianteModel(
        varianteId: _uuid.v4(),
        productId: diaperId,
        size: '$size (20 pcs)',
        sku: 'DIAPER-$size-20',
        barcode: '53456789001${sizes.indexOf(size)}',
        mrp: price,
        costPrice: cost,
        stockQty: 60,
        minStock: 15,
        taxRate: 12.0,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }

    return {
      'products': products,
      'variants': variants,
      'categories': categories,
    };
  }

  Map<String, dynamic> _getGeneralSampleData() {
    // Fallback to retail sample data
    return _getRetailSampleData();
  }
}