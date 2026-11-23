import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/mode_keys.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/restaurant/db/choicemodel_306.dart';
import 'package:billberrylite/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:billberrylite/data/models/restaurant/db/extramodel_303.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/domain/services/restaurant/stock_adjust_service.dart';
import 'package:billberrylite/util/common/staff_roles.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';

/// Per-entity outcome of a generation run.
class GenCount {
  int added = 0;
  int reused = 0;
  int skipped = 0;
  String? reason;

  void skip(String? why, [int n = 1]) {
    skipped += n;
    reason ??= why;
  }
}

class SetupDataResult {
  final Map<String, GenCount> counts = {};

  /// "Name · Role · PIN 200001" for every staff member created.
  final List<String> staffLogins = [];

  GenCount of(String key) => counts.putIfAbsent(key, GenCount.new);
}

enum _Kind { madeToOrder, halfFull, sized, inAdvance, bottled }

class _Dish {
  final String name;
  final bool veg;
  final double price;
  final _Kind? kind;
  const _Dish(this.name, this.veg, this.price, [this.kind]);
}

class _Menu {
  final String category;
  final _Kind kind;
  final double taxPct;
  final bool spice;
  final bool addOns;
  final bool pizza;
  final List<_Dish> dishes;
  const _Menu(
    this.category,
    this.kind,
    this.taxPct,
    this.dishes, {
    this.spice = false,
    this.addOns = false,
    this.pizza = false,
  });
}

/// Restaurant setup data (taxes, variants, choices, extras, categories, items,
/// tables, staff, customers) written through the same stores the screens use,
/// so plan limits, duplicate guards and opening-stock movements all apply.
class SetupDataGenerator {
  SetupDataGenerator._();

  static final Random _random = Random();
  static const _uuid = Uuid();
  static const String generatedBy = 'TestData';

  static const _menus = <_Menu>[
    _Menu('Starters', _Kind.madeToOrder, 5, spice: true, [
      _Dish('Paneer Tikka', true, 260),
      _Dish('Chicken Tikka', false, 320),
      _Dish('Veg Spring Roll', true, 180),
      _Dish('Chicken 65', false, 290),
      _Dish('Hara Bhara Kabab', true, 210),
      _Dish('Fish Fingers', false, 340),
    ]),
    _Menu('Main Course', _Kind.madeToOrder, 5, spice: true, addOns: true, [
      _Dish('Butter Chicken', false, 380),
      _Dish('Paneer Butter Masala', true, 320),
      _Dish('Dal Makhani', true, 260),
      _Dish('Kadai Chicken', false, 360),
      _Dish('Palak Paneer', true, 300),
      _Dish('Mutton Rogan Josh', false, 450),
      _Dish('Mix Veg', true, 240),
    ]),
    _Menu('Biryani & Rice', _Kind.halfFull, 5, spice: true, addOns: true, [
      _Dish('Chicken Biryani', false, 320),
      _Dish('Veg Biryani', true, 260),
      _Dish('Mutton Biryani', false, 420),
      _Dish('Jeera Rice', true, 180),
      _Dish('Veg Pulao', true, 200),
    ]),
    _Menu('Breads', _Kind.madeToOrder, 5, [
      _Dish('Tandoori Roti', true, 30),
      _Dish('Butter Naan', true, 60),
      _Dish('Garlic Naan', true, 80),
      _Dish('Laccha Paratha', true, 70),
      _Dish('Aloo Paratha', true, 90),
    ]),
    _Menu('South Indian', _Kind.madeToOrder, 5, [
      _Dish('Masala Dosa', true, 140),
      _Dish('Idli Sambhar', true, 90),
      _Dish('Medu Vada', true, 100),
      _Dish('Onion Uttapam', true, 150),
    ]),
    _Menu('Chinese', _Kind.madeToOrder, 5, spice: true, [
      _Dish('Veg Hakka Noodles', true, 200),
      _Dish('Chicken Fried Rice', false, 240),
      _Dish('Veg Manchurian', true, 210),
      _Dish('Chilli Paneer', true, 250),
    ]),
    _Menu('Pizza', _Kind.sized, 5, pizza: true, [
      _Dish('Margherita Pizza', true, 280),
      _Dish('Farmhouse Pizza', true, 340),
      _Dish('Chicken Tikka Pizza', false, 380),
      _Dish('Paneer Pizza', true, 350),
    ]),
    _Menu('Soups', _Kind.madeToOrder, 5, [
      _Dish('Tomato Soup', true, 140),
      _Dish('Sweet Corn Soup', true, 150),
      _Dish('Chicken Manchow Soup', false, 180),
    ]),
    _Menu('Desserts', _Kind.inAdvance, 12, [
      _Dish('Gulab Jamun', true, 90),
      _Dish('Rasmalai', true, 120),
      _Dish('Chocolate Brownie', true, 150),
      _Dish('Kulfi', true, 100),
    ]),
    _Menu('Beverages', _Kind.madeToOrder, 5, [
      _Dish('Mineral Water', true, 30, _Kind.bottled),
      _Dish('Coca Cola', true, 60, _Kind.bottled),
      _Dish('Sprite', true, 60, _Kind.bottled),
      _Dish('Fresh Lime Soda', true, 90),
      _Dish('Masala Chai', true, 40),
      _Dish('Cold Coffee', true, 140),
    ]),
  ];

  static const _firstNames = [
    'Rahul', 'Priya', 'Amit', 'Sneha', 'Vikram', 'Anjali', 'Arjun', 'Pooja',
    'Rajesh', 'Kavita', 'Suresh', 'Deepa', 'Karthik', 'Meera', 'Anil', 'Divya',
    'Manoj', 'Shalini', 'Nitin', 'Rekha', 'Sachin', 'Preeti', 'Ravi', 'Nisha',
    'Ajay', 'Swati', 'Varun', 'Shreya', 'Ashok', 'Rani', 'Rohan', 'Karishma',
  ];

  static const _lastNames = [
    'Kumar', 'Sharma', 'Singh', 'Verma', 'Patel', 'Reddy', 'Gupta', 'Agarwal',
    'Jain', 'Malhotra', 'Chopra', 'Desai', 'Iyer', 'Nair', 'Menon', 'Rao',
  ];

  static const _taxSlabs = [5.0, 12.0, 18.0];

  static Future<SetupDataResult> generate({
    required int categories,
    required int items,
    required int tables,
    required int staff,
    required int customers,
    Future<Uint8List?> Function(String name, int index)? imageFor,
  }) async {
    final r = SetupDataResult();
    await reloadStores();

    final taxIds = await _taxes(r);
    final variantIds = await _variants(r);
    final choiceIds = await _choices(r);
    final extraIds = await _extras(r);
    final cats = await _categories(categories, r);
    await _items(items, cats, taxIds, variantIds, choiceIds, extraIds, r,
        imageFor);
    await _tables(tables, r);
    await _staff(staff, r);
    await _customers(customers, r);
    return r;
  }

  /// Re-reads every setup store from Hive so duplicate checks and screens see
  /// the current boxes (also after Clear All Data).
  static Future<void> reloadStores() async {
    await Future.wait([
      taxStore.loadTaxes(),
      variantStore.loadVariants(),
      choiceStore.loadChoices(),
      extraStore.loadExtras(),
      categoryStore.loadCategories(),
      itemStore.loadItems(),
      tableStore.loadTables(),
      staffStore.loadStaff(),
      customerStore.loadCustomers(),
    ]);
  }

  // ── Taxes ────────────────────────────────────────────────────────────────

  static Future<Map<double, String>> _taxes(SetupDataResult r) async {
    final c = r.of('taxes');
    final out = <double, String>{};
    if (!TaxFeature.enabled) {
      c.skip('Tax is turned off for this business — items get no tax',
          _taxSlabs.length);
      return out;
    }
    for (final pct in _taxSlabs) {
      final existing = taxStore.taxes
          .where((t) =>
              t.taxperecentage != null && (t.taxperecentage! - pct).abs() < 1e-9)
          .firstOrNull;
      if (existing != null) {
        out[pct] = existing.id;
        c.reused++;
        continue;
      }
      final tax = Tax(
        id: _uuid.v4(),
        taxname: '${TaxLabelRule.name} ${pct.toStringAsFixed(0)}%',
        taxperecentage: pct,
      );
      if (await taxStore.addTax(tax)) {
        out[pct] = tax.id;
        c.added++;
      } else {
        c.skip(taxStore.errorMessage);
      }
    }
    return out;
  }

  // ── Variants / choices / extras ──────────────────────────────────────────

  static Future<Map<String, String>> _variants(SetupDataResult r) async {
    final c = r.of('variants');
    final out = <String, String>{};
    for (final name in const ['Half', 'Full', 'Small', 'Medium', 'Large']) {
      final existing = variantStore.variants
          .where((v) => v.name.trim().toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        out[name] = existing.id;
        c.reused++;
        continue;
      }
      final v = VariantModel(
          id: _uuid.v4(), name: name, createdTime: DateTime.now());
      if (await variantStore.addVariant(v)) {
        out[name] = v.id;
        c.added++;
      } else {
        c.skip(variantStore.errorMessage);
      }
    }
    return out;
  }

  static Future<Map<String, String>> _choices(SetupDataResult r) async {
    final c = r.of('choices');
    final out = <String, String>{};
    const groups = {
      'Spice Level': ['Mild', 'Medium', 'Spicy'],
      'Pizza Crust': ['Thin Crust', 'Pan', 'Cheese Burst'],
    };
    for (final g in groups.entries) {
      final existing = choiceStore.choices
          .where((x) => x.name.trim().toLowerCase() == g.key.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        out[g.key] = existing.id;
        c.reused++;
        continue;
      }
      final choice = ChoicesModel(
        id: _uuid.v4(),
        name: g.key,
        choiceOption: [
          for (final o in g.value) ChoiceOption(id: _uuid.v4(), name: o),
        ],
        allowMultipleSelection: false,
        createdTime: DateTime.now(),
      );
      if (await choiceStore.addChoice(choice)) {
        out[g.key] = choice.id;
        c.added++;
      } else {
        c.skip(choiceStore.errorMessage);
      }
    }
    return out;
  }

  static Future<Map<String, String>> _extras(SetupDataResult r) async {
    final c = r.of('extras');
    final out = <String, String>{};
    final groups = {
      'Pizza Toppings': const [
        ('Extra Cheese', true, 40.0),
        ('Olives', true, 30.0),
        ('Jalapeno', true, 30.0),
        ('Chicken Sausage', false, 60.0),
      ],
      'Add-ons': const [
        ('Extra Butter', true, 20.0),
        ('Extra Gravy', true, 40.0),
        ('Raita', true, 50.0),
        ('Boiled Egg', false, 25.0),
      ],
    };
    for (final g in groups.entries) {
      final existing = extraStore.extras
          .where((x) => x.Ename.trim().toLowerCase() == g.key.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        out[g.key] = existing.Id;
        c.reused++;
        continue;
      }
      final extra = Extramodel(
        Id: _uuid.v4(),
        Ename: g.key,
        isEnabled: true,
        topping: [
          for (final t in g.value)
            Topping(
              name: t.$1,
              isveg: t.$2,
              price: t.$3,
              isContainSize: false,
              createdTime: DateTime.now(),
            ),
        ],
        createdTime: DateTime.now(),
      );
      if (await extraStore.addExtra(extra)) {
        out[g.key] = extra.Id;
        c.added++;
      } else {
        c.skip(extraStore.errorMessage);
      }
    }
    return out;
  }

  // ── Categories ───────────────────────────────────────────────────────────

  static Future<List<Category>> _categories(
      int count, SetupDataResult r) async {
    final c = r.of('categories');
    if (count <= 0) return categoryStore.categories.toList();

    final taken =
        categoryStore.categories.map((x) => x.name.trim().toLowerCase()).toSet();
    final out = <Category>[];
    for (var i = 0; i < count; i++) {
      final base = _menus[i % _menus.length].category;
      final round = i ~/ _menus.length;
      final wanted = round == 0 ? base : '$base ${round + 1}';
      var name = wanted;
      for (var k = 2; taken.contains(name.toLowerCase()); k++) {
        name = '$wanted ($k)';
      }
      final cat = Category(
        id: _uuid.v4(),
        name: name,
        createdTime: DateTime.now(),
        editedBy: generatedBy,
      );
      if (await categoryStore.addCategory(cat)) {
        taken.add(name.toLowerCase());
        out.add(cat);
        c.added++;
      } else {
        c.skip(categoryStore.errorMessage, count - i);
        break;
      }
    }
    return out;
  }

  static _Menu _menuFor(Category cat) {
    final n = cat.name.toLowerCase();
    return _menus.firstWhere(
      (m) => n.startsWith(m.category.toLowerCase()),
      orElse: () => _menus[1],
    );
  }

  // ── Items ────────────────────────────────────────────────────────────────

  static Future<void> _items(
    int count,
    List<Category> cats,
    Map<double, String> taxIds,
    Map<String, String> variantIds,
    Map<String, String> choiceIds,
    Map<String, String> extraIds,
    SetupDataResult r,
    Future<Uint8List?> Function(String name, int index)? imageFor,
  ) async {
    final c = r.of('items');
    if (count <= 0) return;
    if (cats.isEmpty) {
      c.skip('No categories to put items in', count);
      return;
    }
    if (!PlanEnforce.allows(EntKeys.manageMenuItemsAdd)) {
      c.skip('Adding items isn’t available on the current plan', count);
      return;
    }

    final takenNames =
        itemStore.items.map((i) => i.name.trim().toLowerCase()).toSet();
    final cursor = <String, int>{};

    for (var i = 0; i < count; i++) {
      if (!PlanEnforce.withinLimit(
          EntKeys.manageMenuItemsMax, itemStore.items.length)) {
        c.skip(
          'Plan item limit reached (max ${PlanEnforce.limit(EntKeys.manageMenuItemsMax)})',
          count - i,
        );
        break;
      }

      final cat = cats[i % cats.length];
      final menu = _menuFor(cat);
      final n = cursor.update(cat.id, (v) => v + 1, ifAbsent: () => 0);
      final dish = menu.dishes[n % menu.dishes.length];
      final round = n ~/ menu.dishes.length;
      var name = round == 0 ? dish.name : '${dish.name} ${round + 1}';
      if (takenNames.contains(name.toLowerCase())) name = '$name #${i + 1}';
      takenNames.add(name.toLowerCase());

      final item = _buildItem(
        name: name,
        dish: dish,
        menu: menu,
        categoryId: cat.id,
        taxIds: taxIds,
        variantIds: variantIds,
        choiceIds: choiceIds,
        extraIds: extraIds,
        imageBytes: imageFor == null ? null : await imageFor(name, i),
      );

      if (await itemStore.addItem(item)) {
        await StockAdjustService.recordOpeningStock(item);
        c.added++;
      } else {
        c.skip(itemStore.errorMessage);
      }
    }
  }

  static Items _buildItem({
    required String name,
    required _Dish dish,
    required _Menu menu,
    required String categoryId,
    required Map<double, String> taxIds,
    required Map<String, String> variantIds,
    required Map<String, String> choiceIds,
    required Map<String, String> extraIds,
    Uint8List? imageBytes,
  }) {
    final kind = dish.kind ?? menu.kind;
    final base = _jitter(dish.price);

    final type =
        kind == _Kind.bottled ? ProductType.tradeItem : ProductType.finishedGood;
    final prep = kind == _Kind.inAdvance
        ? ProductType.madeInAdvance
        : ProductType.madeToOrder;
    final stored =
        ProductType.storedFields(type: type, prepMode: prep, makeFresh: false);

    final wantsStock = kind == _Kind.bottled || kind == _Kind.inAdvance;
    final belowThreshold = _random.nextInt(10) == 0;
    final qty = !wantsStock
        ? 0.0
        : (belowThreshold ? _random.nextInt(8) : 20 + _random.nextInt(181))
            .toDouble();
    final physical = ProductType.resolvePhysicalStock(
      stored.productType,
      prepMode: stored.prepMode,
      requestedTrackInventory: wantsStock,
      requestedStockQuantity: qty,
    );

    final variants = <ItemVariante>[];
    void addVariant(String vName, double factor) {
      final id = variantIds[vName];
      if (id != null) {
        variants.add(ItemVariante(
          variantId: id,
          price: _round5(base * factor),
          trackInventory: false,
          stockQuantity: 0,
        ));
      }
    }

    if (kind == _Kind.halfFull) {
      addVariant('Half', 0.6);
      addVariant('Full', 1.0);
    } else if (kind == _Kind.sized) {
      addVariant('Small', 0.7);
      addVariant('Medium', 1.0);
      addVariant('Large', 1.35);
    }
    final price = variants.isEmpty
        ? base
        : variants.map((v) => v.price).reduce(min);

    final taxPct = kind == _Kind.bottled ? 18.0 : menu.taxPct;
    final taxId = taxIds[taxPct];

    final choices = <String>[
      if (menu.pizza && choiceIds['Pizza Crust'] != null)
        choiceIds['Pizza Crust']!,
      if (menu.spice &&
          choiceIds['Spice Level'] != null &&
          _random.nextDouble() < 0.6)
        choiceIds['Spice Level']!,
    ];
    final extras = <String>[
      if (menu.pizza && extraIds['Pizza Toppings'] != null)
        extraIds['Pizza Toppings']!,
      if (menu.addOns && extraIds['Add-ons'] != null && _random.nextBool())
        extraIds['Add-ons']!,
    ];

    return Items(
      id: _uuid.v4(),
      name: name,
      price: price,
      description: 'Freshly prepared ${dish.name.toLowerCase()}',
      categoryOfItem: categoryId,
      imageBytes: imageBytes,
      isVeg: dish.veg ? 'Veg' : 'Non-Veg',
      unit: 'piece',
      isSoldByWeight: false,
      variant: variants,
      choiceIds: choices,
      extraId: extras,
      taxRate: taxId != null ? taxPct / 100 : 0.0,
      taxIds: taxId != null ? [taxId] : null,
      isEnabled: true,
      trackInventory: physical.trackInventory,
      stockQuantity: physical.stockQuantity,
      allowOrderWhenOutOfStock: kind != _Kind.bottled,
      lowStockThreshold: physical.trackInventory ? 10 : null,
      lowStockAlertEnabled: physical.trackInventory,
      isFavorite: _random.nextInt(15) == 0,
      productType: stored.productType,
      prepMode: stored.prepMode,
      makeFreshWhenOut: stored.makeFreshWhenOut,
      createdTime: DateTime.now(),
      editedBy: generatedBy,
    );
  }

  // ── Tables ───────────────────────────────────────────────────────────────

  static Future<void> _tables(int count, SetupDataResult r) async {
    final c = r.of('tables');
    const capacities = [2, 2, 4, 4, 4, 6, 8];
    var n = 1;
    for (var i = 0; i < count; i++) {
      if (!PlanEnforce.withinLimit(
          EntKeys.billingTablesMax, tableStore.tables.length)) {
        c.skip(
          'Plan table limit reached (max ${PlanEnforce.limit(EntKeys.billingTablesMax)})',
          count - i,
        );
        break;
      }
      while (tableStore.nameTaken('T$n')) {
        n++;
      }
      final table = TableModel(
        id: 'T$n',
        tableCapacity: capacities[_random.nextInt(capacities.length)],
      );
      n++;
      if (await tableStore.addTable(table)) {
        c.added++;
      } else {
        c.skip(tableStore.errorMessage, count - i);
        break;
      }
    }
  }

  // ── Staff ────────────────────────────────────────────────────────────────

  static Future<void> _staff(int count, SetupDataResult r) async {
    final c = r.of('staff');
    if (count <= 0) return;
    if (!PlanEnforce.allows(ModeKeys.users)) {
      c.skip('The current plan doesn’t include staff management', count);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final adminPin = prefs.getString(RestaurantAuthHelper.adminPinKey) ??
        RestaurantAuthHelper.hashPassword(RestaurantAuthHelper.defaultAdminPin);
    bool pinTaken(String pin) =>
        RestaurantAuthHelper.verifyPassword(pin, adminPin) ||
        staffStore.staff
            .any((s) => RestaurantAuthHelper.verifyPassword(pin, s.pinNo));

    final userNames =
        staffStore.staff.map((s) => s.userName.toLowerCase()).toSet();
    final mobiles = staffStore.staff.map((s) => s.mobileNo).toSet();
    var pin = 200001;

    for (var i = 0; i < count; i++) {
      if (!PlanEnforce.withinLimit(ModeKeys.usersMax, staffStore.staff.length)) {
        c.skip(
          'Plan staff limit reached (max ${PlanEnforce.limit(ModeKeys.usersMax)})',
          count - i,
        );
        break;
      }
      final role = switch (i % 6) {
        0 => StaffRoles.restaurant[0],
        1 || 2 => StaffRoles.restaurant[1],
        _ => StaffRoles.restaurant[2],
      };
      final first = _pick(_firstNames);
      final last = _pick(_lastNames);
      var userName = first.toLowerCase();
      for (var k = 1; userNames.contains(userName); k++) {
        userName = '${first.toLowerCase()}$k';
      }
      while (pinTaken('$pin')) {
        pin++;
      }

      final staff = StaffModel(
        id: _uuid.v4(),
        userName: userName,
        firstName: first,
        lastName: last,
        isCashier: role,
        mobileNo: _uniquePhone(mobiles),
        emailId: '$userName@example.com',
        pinNo: RestaurantAuthHelper.hashPassword('$pin'),
        createdAt: DateTime.now(),
      );
      if (await staffStore.addStaff(staff)) {
        userNames.add(userName);
        r.staffLogins.add('$first $last · $role · PIN $pin');
        c.added++;
      } else {
        c.skip(staffStore.errorMessage, count - i);
        break;
      }
      pin++;
    }
  }

  // ── Customers ────────────────────────────────────────────────────────────

  static Future<void> _customers(int count, SetupDataResult r) async {
    final c = r.of('customers');
    if (count <= 0) return;
    if (!PlanEnforce.allows(ModeKeys.customers)) {
      c.skip('The current plan doesn’t include saved customers', count);
      return;
    }
    final phones = customerStore.customers
        .map((x) => x.phone)
        .whereType<String>()
        .toSet();

    for (var i = 0; i < count; i++) {
      if (!PlanEnforce.withinLimit(
          ModeKeys.customersMax, customerStore.customers.length)) {
        c.skip(
          'Plan customer limit reached (max ${PlanEnforce.limit(ModeKeys.customersMax)})',
          count - i,
        );
        break;
      }
      final first = _pick(_firstNames);
      final last = _pick(_lastNames);
      final customer = Customer.create(
        customerId: _uuid.v4(),
        name: '$first $last',
        phone: _uniquePhone(phones),
        email: _random.nextDouble() < 0.3
            ? '${first.toLowerCase()}.${last.toLowerCase()}${i + 1}@example.com'
            : null,
        notes: generatedBy,
      );
      if (await customerStore.addCustomer(customer)) {
        c.added++;
      } else {
        c.skip(customerStore.errorMessage, count - i);
        break;
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static T _pick<T>(List<T> list) => list[_random.nextInt(list.length)];

  /// 10-digit mobile starting 6–9, not already in [taken]; adds it to [taken].
  static String _uniquePhone(Set<String> taken) {
    String phone;
    do {
      phone = '${6 + _random.nextInt(4)}'
          '${_random.nextInt(1000000000).toString().padLeft(9, '0')}';
    } while (taken.contains(phone));
    taken.add(phone);
    return phone;
  }

  static double _round5(double v) => (v / 5).round() * 5.0;

  /// ±15% around [price], rounded to 5.
  static double _jitter(double price) =>
      _round5(price * (0.85 + _random.nextDouble() * 0.3));
}
