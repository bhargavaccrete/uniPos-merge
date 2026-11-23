import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/extramodel_303.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:billberrylite/server/captain_line_pricing.dart';

/// AND-04/05: Captain's send-order lines are priced from the POS menu —
/// never Captain's price, tax rate or discount — and quantities are checked.
void main() {
  final paneer = Items(
    id: 'paneer',
    name: 'Paneer Tikka',
    price: 300,
    taxRate: 0.05,
    trackInventory: true,
    variant: [ItemVariante(variantId: 'vL', price: 400)],
    extraId: ['g1'],
  );
  final chicken = Items(
    id: 'chicken',
    name: 'Chicken',
    price: 400, // per kg
    unit: 'kg',
    isSoldByWeight: true,
    extraId: ['g1'],
  );
  final toppings = Extramodel(Id: 'g1', Ename: 'Add-ons', topping: [
    Topping(
        name: 'Cheese',
        isveg: true,
        price: 30,
        isContainSize: true,
        variantPrices: {'vL': 50}),
  ]);
  final otherGroup = Extramodel(Id: 'g2', Ename: 'Other', topping: [
    Topping(name: 'Sauce', isveg: true, price: 10),
  ]);

  List<CartItem> price(List<CartItem> lines) => CaptainLinePricing.reprice(
        lines,
        itemsById: {'paneer': paneer, 'chicken': chicken},
        variantNames: {'vL': 'Large'},
        extrasById: {'g1': toppings, 'g2': otherGroup},
      );

  CartItem line({
    String productId = 'paneer',
    double clientPrice = 1,
    int quantity = 1,
    String? variantName,
    List<Map<String, dynamic>>? extras,
    String? weightDisplay,
    double? discount,
    double? taxRate,
    String title = 'Anything',
  }) =>
      CartItem(
        id: 'l1',
        productId: productId,
        title: title,
        price: clientPrice,
        quantity: quantity,
        variantName: variantName,
        extras: extras,
        weightDisplay: weightDisplay,
        discount: discount,
        taxRate: taxRate,
      );

  Map<String, dynamic> extra(String name,
          {String categoryId = 'g1', int quantity = 1, double price = 0}) =>
      {
        'name': name,
        'displayName': 'Add-ons - $name',
        'price': price,
        'categoryName': 'Add-ons',
        'categoryId': categoryId,
        'quantity': quantity,
      };

  Matcher rejected() => throwsA(isA<CaptainLineRejected>());

  group('price comes from the POS menu', () {
    test('a ₹1 client price becomes the menu price', () {
      final l = price([line(clientPrice: 1, quantity: 2)]).single;
      expect(l.price, 300);
      expect(l.totalPrice, 600);
    });

    test('tax rate is the item\'s, discount is dropped, title is the menu name',
        () {
      final l = price([line(taxRate: 0, discount: 299)]).single;
      expect(l.taxRate, 0.05);
      expect(l.discount, isNull);
      expect(l.title, 'Paneer Tikka');
    });

    test('a product not on the menu is rejected', () {
      expect(() => price([line(productId: 'ghost')]), rejected());
    });

    test('one bad line rejects the whole request', () {
      expect(() => price([line(), line(productId: 'ghost')]), rejected());
    });
  });

  group('quantity', () {
    for (final q in [0, -2, 1000]) {
      test('$q is rejected', () {
        expect(() => price([line(quantity: q)]), rejected());
      });
    }

    test('1 and ${CaptainLinePricing.maxQuantity} are accepted', () {
      expect(price([line(quantity: 1)]).single.quantity, 1);
      expect(price([line(quantity: CaptainLinePricing.maxQuantity)]).single.quantity,
          CaptainLinePricing.maxQuantity);
    });
  });

  group('variants and extras', () {
    test('a variant is priced at the variant price', () {
      final l = price([line(variantName: 'Large')]).single;
      expect(l.price, 400);
      expect(l.variantPrice, 400);
      expect(l.variantName, 'Large');
    });

    test('an unknown variant is rejected', () {
      expect(() => price([line(variantName: 'XL')]), rejected());
    });

    test('extras use the POS price × their quantity', () {
      final l = price([
        line(extras: [extra('Cheese', quantity: 2, price: 0)])
      ]).single;
      expect(l.price, 300 + 30 * 2);
      expect(l.extras!.single['price'], 30);
      expect(l.extras!.single['quantity'], 2);
    });

    test('a size-bound extra uses the variant\'s price', () {
      final l = price([
        line(variantName: 'Large', extras: [extra('Cheese', quantity: 2)])
      ]).single;
      expect(l.price, 400 + 50 * 2);
    });

    test('an unknown extra is rejected', () {
      expect(() => price([line(extras: [extra('Gold leaf')])]), rejected());
    });

    test('an extra from a group the item does not have is rejected', () {
      expect(() => price([line(extras: [extra('Sauce', categoryId: 'g2')])]),
          rejected());
    });

    for (final q in [0, -1]) {
      test('an extra quantity of $q is rejected', () {
        expect(() => price([line(extras: [extra('Cheese', quantity: q)])]),
            rejected());
      });
    }
  });

  group('weighed items: price and stock read the same weight', () {
    test('750GM at ₹400/kg is ₹300, whatever Captain priced it', () {
      final l = price([
        line(productId: 'chicken', clientPrice: 1, weightDisplay: '750GM')
      ]).single;
      expect(l.price, closeTo(300, 1e-9));
      expect(l.quantity, 1);
      expect(l.weightDisplay, '750GM');
    });

    test('1.5KG plus an extra', () {
      final l = price([
        line(productId: 'chicken', weightDisplay: '1.5KG',
            extras: [extra('Cheese')])
      ]).single;
      expect(l.price, closeTo(600 + 30, 1e-9));
    });

    test('a weighed line with quantity other than 1 is rejected', () {
      expect(
          () => price([
                line(productId: 'chicken', quantity: 2, weightDisplay: '1KG')
              ]),
          rejected());
    });

    for (final display in [null, '', '0KG', 'abc']) {
      test('weight "$display" is rejected', () {
        expect(
            () => price([line(productId: 'chicken', weightDisplay: display)]),
            rejected());
      });
    }
  });
}
