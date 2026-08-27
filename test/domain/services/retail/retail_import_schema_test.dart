import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/core/constants/item_units.dart';
import 'package:billberrylite/domain/services/retail/retail_import_schema.dart';

/// PURE PARSER CONTRACT for the retail bulk-product import.
///
/// Everything here runs without Hive, GetIt or Flutter bindings — that is the
/// whole point of [RetailImportParser] being dependency-free. The write path
/// (barcode minting, rollback, product cap) is pinned separately in
/// `test/integration/retail_import_hive_test.dart`.
void main() {
  // ── Fixtures ───────────────────────────────────────────────────────────────

  /// A full-width row. Every field defaults to something valid so each test
  /// only states what it is actually exercising.
  List<dynamic> row({
    String handle = 'h1',
    String name = 'Product',
    String category = 'General',
    String description = '',
    String opt1Name = '',
    String opt1Value = '',
    String opt2Name = '',
    String opt2Value = '',
    String opt3Name = '',
    String opt3Value = '',
    String cost = '',
    String price = '10',
    String mrp = '',
    String stock = '',
    String barcode = '',
    String minStock = '',
    String tax = '',
    String hsn = '',
    String sku = '',
    String unit = '',
    String expiry = '',
  }) => [
    handle,
    name,
    category,
    description,
    opt1Name,
    opt1Value,
    opt2Name,
    opt2Value,
    opt3Name,
    opt3Value,
    cost,
    price,
    mrp,
    stock,
    barcode,
    minStock,
    tax,
    hsn,
    sku,
    unit,
    expiry,
  ];

  /// Header row + data rows, the shape `BulkImportStore.parsedRows` holds.
  List<List<dynamic>> sheet(List<List<dynamic>> dataRows) => [
    kRetailImportHeaderRow,
    ...dataRows,
  ];

  /// The yellow instruction row the downloaded template puts at row 2.
  List<dynamic> instructionRow() => [
    'Groups variants',
    'Product name',
    'Pick a category',
    'Optional',
    'e.g. Size',
    'e.g. Small',
    'e.g. Color',
    'e.g. Red',
    '',
    '',
    'Optional',
    'Required: number only',
    'Optional',
    'Optional, defaults to 0',
    'Optional, must be unique',
    'Optional, defaults to 5',
    'Pick a tax rate',
    'Optional',
    'Optional',
    'piece unless sold by weight',
    'YYYY-MM-DD',
  ];

  /// All error messages, for readable assertions.
  List<String> errorText(RetailImportParseResult r) =>
      r.errors.map((e) => e.toString()).toList();

  // ── A. Normal pcs product ─────────────────────────────────────────────────

  group('A — normal pcs product', () {
    test('a blank Unit reads as piece and is NOT a decimal product', () {
      final r = RetailImportParser.parse(
        sheet([
          row(
            handle: 'coke',
            name: 'Coca Cola 330ml',
            price: '25',
            stock: '100',
          ),
        ]),
      );

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups, hasLength(1));

      final g = r.groups.single;
      expect(g.unit, 'piece');
      expect(g.isDecimalQuantity, isFalse);
      expect(g.expiryDate, isNull);
      expect(g.hasVariants, isFalse);
      expect(g.variants.single.stockQty, 100);
      expect(g.variants.single.sellingPrice, 25);
    });

    test('optional blanks stay null — never 0.0, never an empty string', () {
      final r = RetailImportParser.parse(sheet([row()]));
      final v = r.groups.single.variants.single;

      expect(v.costPrice, isNull);
      expect(v.mrp, isNull);
      expect(v.barcode, isNull);
      expect(v.sku, isNull);
      expect(r.groups.single.hsnCode, isNull);
      expect(r.groups.single.description, isNull);
      // Documented defaults, not silent zeros.
      expect(v.stockQty, 0);
      expect(v.minStock, 5);
    });

    test('the template instruction row is skipped, not imported', () {
      final r = RetailImportParser.parse([
        kRetailImportHeaderRow,
        instructionRow(),
        row(handle: 'coke', name: 'Coke', price: '25'),
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups, hasLength(1));
      expect(r.dataRowCount, 1);
      expect(r.groups.single.name, 'Coke');
    });

    test('a single product with a MISTYPED price is reported, not mistaken '
        'for the instruction row', () {
      // Regression: deciding "instruction row" from a non-numeric Selling
      // Price alone made this row vanish silently.
      final r = RetailImportParser.parse([
        kRetailImportHeaderRow,
        row(handle: 'coke', name: 'Coke', price: 'twenty five'),
      ]);

      expect(r.dataRowCount, 1, reason: 'the row must not be swallowed');
      expect(r.errors.single.column, 'Selling Price');
      expect(r.errors.single.rowNumber, 2);
    });

    test('a hand-typed file with no instruction row keeps its first row', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'a', name: 'First', price: '5'),
          row(handle: 'b', name: 'Second', price: '6'),
        ]),
      );

      expect(r.groups.map((g) => g.name), ['First', 'Second']);
    });
  });

  // ── B. Decimal / weight product ───────────────────────────────────────────

  group('B — decimal (weight) product', () {
    test('Unit kg makes it decimal and accepts fractional stock', () {
      final r = RetailImportParser.parse(
        sheet([
          row(
            handle: 'potato',
            name: 'Potato',
            price: '30',
            stock: '10.5',
            minStock: '2.25',
            unit: 'kg',
          ),
        ]),
      );

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      final g = r.groups.single;
      expect(g.unit, 'kg');
      expect(g.isDecimalQuantity, isTrue);
      expect(g.variants.single.stockQty, 10.5);
      expect(g.variants.single.minStock, 2.25);
    });

    test('fractional stock on a pcs product is an ERROR, never rounded', () {
      final r = RetailImportParser.parse(
        sheet([row(handle: 'coke', name: 'Coke', price: '25', stock: '10.5')]),
      );

      expect(r.groups, isEmpty);
      expect(r.rejectedGroupCount, 1);
      expect(errorText(r).join(), contains('whole piece'));
      expect(errorText(r).join(), contains('Row 2'));
    });

    test('fractional Min Stock on a pcs product is an ERROR too', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'coke', name: 'Coke', price: '25', minStock: '1.5'),
        ]),
      );

      expect(r.errors.single.column, 'Min Stock');
    });

    test('a whole number on a decimal product is still fine', () {
      final r = RetailImportParser.parse(
        sheet([
          row(
            handle: 'rice',
            name: 'Rice',
            price: '60',
            stock: '50',
            unit: 'kg',
          ),
        ]),
      );

      expect(r.errors, isEmpty);
      expect(r.groups.single.variants.single.stockQty, 50);
    });

    test('decimal quantity is DERIVED from Unit — there is no way to say '
        '"decimal" and "piece" at once', () {
      // The enum has no decimal-quantity column at all; this pins that.
      expect(
        RetailImportColumn.values.map((c) => c.name),
        isNot(contains('isDecimalQuantity')),
      );
      final pcs = RetailImportParser.parse(
        sheet([row(unit: 'piece')]),
      ).groups.single;
      expect(pcs.isDecimalQuantity, isFalse);
    });
  });

  // ── C. Barcode ────────────────────────────────────────────────────────────

  group('C — barcode', () {
    test('a supplied barcode is carried through', () {
      final r = RetailImportParser.parse(
        sheet([row(barcode: '8901234567890')]),
      );
      expect(r.groups.single.variants.single.barcode, '8901234567890');
    });

    test('a blank barcode is null so the repository can mint one', () {
      final r = RetailImportParser.parse(sheet([row(barcode: '   ')]));
      expect(r.errors, isEmpty);
      expect(r.groups.single.variants.single.barcode, isNull);
    });

    // H — duplicate barcode rejection.
    test('a barcode duplicated within the file rejects the group and names '
        'the earlier row', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'a', name: 'A', barcode: 'DUP1'),
          row(handle: 'b', name: 'B', barcode: 'DUP1'),
        ]),
      );

      expect(r.groups.map((g) => g.name), [
        'A',
      ], reason: 'only the first survives');
      expect(r.rejectedGroupCount, 1);
      expect(errorText(r).join(), contains('already used on row 2'));
    });

    test('duplicate detection ignores case', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'a', name: 'A', barcode: 'abc1'),
          row(handle: 'b', name: 'B', barcode: 'ABC1'),
        ]),
      );
      expect(r.rejectedGroupCount, 1);
    });

    test('a barcode already in the catalogue is rejected', () {
      final r = RetailImportParser.parse(
        sheet([row(barcode: 'TAKEN')]),
        catalogue: RetailImportCatalogue(
          isBarcodeTaken: (b) => b == 'TAKEN',
          existingVariantKeys: (_) => null,
        ),
      );

      expect(r.groups, isEmpty);
      expect(
        errorText(r).join(),
        contains('already belongs to another product'),
      );
    });
  });

  // ── D. UOM ────────────────────────────────────────────────────────────────

  group('D — UOM', () {
    for (final unit in kItemUnits) {
      test('$unit is accepted and normalised', () {
        final r = RetailImportParser.parse(sheet([row(unit: unit)]));
        expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
        expect(r.groups.single.unit, unit);
      });
    }

    test('aliases resolve through normalizeItemUnit — no second unit list', () {
      const aliases = {
        'kgs': 'kg',
        'KG': 'kg',
        'Grams': 'gm',
        'Litre': 'liter',
        'ltr': 'liter',
        'MilliLitre': 'ml',
        'pcs': 'piece',
        ' Piece ': 'piece',
      };
      aliases.forEach((raw, expected) {
        final r = RetailImportParser.parse(sheet([row(unit: raw)]));
        expect(r.errors, isEmpty, reason: 'unit "$raw": ${errorText(r)}');
        expect(r.groups.single.unit, expected, reason: 'unit "$raw"');
      });
    });

    test('an unrecognised unit is an error that lists the valid ones', () {
      final r = RetailImportParser.parse(sheet([row(unit: 'dozen')]));

      expect(r.groups, isEmpty);
      final message = errorText(r).join();
      expect(message, contains('dozen'));
      for (final unit in kItemUnits) {
        expect(message, contains(unit));
      }
    });

    test('Unit is read from the parent row and applies to the whole group', () {
      final r = RetailImportParser.parse(
        sheet([
          row(
            handle: 't',
            name: 'Tea',
            opt1Name: 'Grade',
            opt1Value: 'A',
            unit: 'gm',
          ),
          row(handle: 't', name: 'Tea', opt1Name: 'Grade', opt1Value: 'B'),
        ]),
      );

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups.single.unit, 'gm');
      expect(r.groups.single.variants, hasLength(2));
    });

    test('a different Unit on a child row is ignored with a NOTICE, not an '
        'error', () {
      final r = RetailImportParser.parse(
        sheet([
          row(
            handle: 't',
            name: 'Tea',
            opt1Name: 'G',
            opt1Value: 'A',
            unit: 'kg',
          ),
          row(
            handle: 't',
            name: 'Tea',
            opt1Name: 'G',
            opt1Value: 'B',
            unit: 'gm',
          ),
        ]),
      );

      expect(r.errors, isEmpty);
      expect(r.groups.single.unit, 'kg');
      expect(r.notices.map((n) => n.toString()).join(), contains('Unit'));
      expect(r.notices.first.rowNumber, 3);
    });
  });

  // ── E. Expiry ─────────────────────────────────────────────────────────────

  group('E — expiry date', () {
    test('YYYY-MM-DD is normalised to local midnight', () {
      final r = RetailImportParser.parse(sheet([row(expiry: '2026-08-30')]));

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(
        DateTime.parse(r.groups.single.expiryDate!),
        DateTime(2026, 8, 30),
      );
    });

    test('a full ISO timestamp is flattened to the calendar day', () {
      final r = RetailImportParser.parse(
        sheet([row(expiry: '2026-08-30T17:45:12.000')]),
      );
      expect(
        DateTime.parse(r.groups.single.expiryDate!),
        DateTime(2026, 8, 30),
      );
    });

    test('blank means "never expires"', () {
      final r = RetailImportParser.parse(sheet([row(expiry: '')]));
      expect(r.groups.single.expiryDate, isNull);
    });

    test('an unreadable date is an error naming the row', () {
      final r = RetailImportParser.parse(sheet([row(expiry: 'next tuesday')]));

      expect(r.groups, isEmpty);
      expect(r.errors.single.column, 'Expiry Date');
      expect(r.errors.single.rowNumber, 2);
      expect(r.errors.single.message, contains('YYYY-MM-DD'));
    });

    test('an ambiguous DD/MM/YYYY form is rejected rather than guessed', () {
      final r = RetailImportParser.parse(sheet([row(expiry: '03/04/2026')]));
      expect(r.errors, hasLength(1));
    });

    test('parseImportDate strips the time component', () {
      expect(parseImportDate('2026-01-05T23:59:59'), DateTime(2026, 1, 5));
      expect(parseImportDate('  '), isNull);
      expect(parseImportDate('rubbish'), isNull);
    });
  });

  // ── F. Multiple variants ──────────────────────────────────────────────────

  group('F — a product with multiple variants', () {
    test('one Handle over four rows, two option dimensions', () {
      final r = RetailImportParser.parse(
        sheet([
          row(
            handle: 'ts',
            name: 'V-Neck',
            opt1Name: 'Size',
            opt1Value: 'S',
            opt2Name: 'Color',
            opt2Value: 'Red',
            price: '15',
            barcode: 'A',
          ),
          row(
            handle: 'ts',
            name: 'V-Neck',
            opt1Name: 'Size',
            opt1Value: 'S',
            opt2Name: 'Color',
            opt2Value: 'Blue',
            price: '15',
            barcode: 'B',
          ),
          row(
            handle: 'ts',
            name: 'V-Neck',
            opt1Name: 'Size',
            opt1Value: 'M',
            opt2Name: 'Color',
            opt2Value: 'Red',
            price: '15',
            barcode: 'C',
          ),
          row(
            handle: 'ts',
            name: 'V-Neck',
            opt1Name: 'Size',
            opt1Value: 'L',
            opt2Name: 'Color',
            opt2Value: 'Blue',
            price: '16',
            barcode: 'D',
          ),
        ]),
      );

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups, hasLength(1));

      final g = r.groups.single;
      expect(g.hasVariants, isTrue);
      expect(g.variants, hasLength(4));
      expect(g.variants.first.attributes, {'Size': 'S', 'Color': 'Red'});
      expect(g.variants.last.sellingPrice, 16);
      expect(r.variantCount, 4);
    });

    test('grouping is case-insensitive on the Handle', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'TS', name: 'Shirt', opt1Name: 'Size', opt1Value: 'S'),
          row(handle: 'ts', name: 'Shirt', opt1Name: 'Size', opt1Value: 'M'),
        ]),
      );

      expect(r.groups, hasLength(1));
      expect(r.groups.single.variants, hasLength(2));
    });

    test('the same attribute combination twice in one group is an error', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'ts', name: 'Shirt', opt1Name: 'Size', opt1Value: 'S'),
          row(handle: 'ts', name: 'Shirt', opt1Name: 'Size', opt1Value: 'S'),
        ]),
      );

      expect(r.groups, isEmpty);
      expect(errorText(r).join(), contains('already on row 2'));
    });

    test('attribute order does not change the combination identity', () {
      final r = RetailImportParser.parse(
        sheet([
          row(
            handle: 'ts',
            name: 'Shirt',
            opt1Name: 'Size',
            opt1Value: 'S',
            opt2Name: 'Color',
            opt2Value: 'Red',
          ),
          row(
            handle: 'ts',
            name: 'Shirt',
            opt1Name: 'Color',
            opt1Value: 'red',
            opt2Name: 'Size',
            opt2Value: 's',
          ),
        ]),
      );

      expect(
        r.groups,
        isEmpty,
        reason: 'same combination, different column order',
      );
    });

    test('two option-less rows under one Handle are an error, not a silent '
        'overwrite', () {
      final r = RetailImportParser.parse(
        sheet([row(handle: 'x', name: 'X'), row(handle: 'x', name: 'X')]),
      );

      expect(r.groups, isEmpty);
      expect(
        errorText(r).join(),
        contains('more than one row with no options'),
      );
    });

    test('an option name without its value is an error', () {
      final r = RetailImportParser.parse(
        sheet([row(opt1Name: 'Size', opt1Value: '')]),
      );
      expect(errorText(r).join(), contains('both a name and a value'));
    });

    test('attributeSignature is order- and case-independent', () {
      expect(
        attributeSignature({'Size': 'S', 'Color': 'Red'}),
        attributeSignature({'color': 'RED', 'size': 's'}),
      );
      expect(attributeSignature(null), '');
      expect(attributeSignature({}), '');
    });
  });

  // ── G-preview. Existing product + existing variant ────────────────────────

  group('G/H — against the existing catalogue', () {
    test('a variant that already exists is a NOTICE (it will be skipped), '
        'not an error', () {
      final r = RetailImportParser.parse(
        sheet([row(name: 'V-Neck', opt1Name: 'Size', opt1Value: 'M')]),
        catalogue: RetailImportCatalogue(
          isBarcodeTaken: (_) => false,
          existingVariantKeys: (name) => name == 'V-Neck'
              ? {
                  attributeSignature({'Size': 'M'}),
                }
              : null,
        ),
      );

      expect(r.errors, isEmpty);
      expect(r.groups, hasLength(1), reason: 'the group still imports');
      expect(r.notices.single.message, contains('will be skipped'));
    });

    test('a NEW variant on an existing product raises nothing at all', () {
      final r = RetailImportParser.parse(
        sheet([row(name: 'V-Neck', opt1Name: 'Size', opt1Value: 'XL')]),
        catalogue: RetailImportCatalogue(
          isBarcodeTaken: (_) => false,
          existingVariantKeys: (_) => {
            attributeSignature({'Size': 'M'}),
          },
        ),
      );

      expect(r.issues, isEmpty);
      expect(r.groups, hasLength(1));
    });
  });

  // ── I. Invalid rows ───────────────────────────────────────────────────────

  group('I — invalid rows carry their row number', () {
    test('a blank Handle is REPORTED, not silently dropped', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: '', name: 'Orphan'),
          row(handle: 'ok', name: 'Fine'),
        ]),
      );

      expect(r.groups.map((g) => g.name), ['Fine']);
      expect(r.errors.single.rowNumber, 2);
      expect(r.errors.single.message, contains('Handle is required'));
    });

    test('a blank Name rejects the group', () {
      final r = RetailImportParser.parse(sheet([row(name: '')]));

      expect(r.groups, isEmpty);
      expect(r.errors.single.column, 'Name');
    });

    test('a non-numeric price is an error, NOT a silent 0.0', () {
      final r = RetailImportParser.parse(sheet([row(price: 'abc')]));

      expect(r.groups, isEmpty);
      expect(r.errors.single.column, 'Selling Price');
      expect(r.errors.single.message, contains('abc'));
    });

    test('a missing required price is an error', () {
      final r = RetailImportParser.parse(sheet([row(price: '')]));
      expect(r.errors.single.message, contains('required'));
    });

    test('negative values are rejected on every numeric column', () {
      for (final probe in [
        ('Selling Price', row(price: '-1')),
        ('Cost Price', row(cost: '-1')),
        ('MRP', row(mrp: '-1')),
        ('Stock', row(stock: '-1')),
        ('Min Stock', row(minStock: '-1')),
      ]) {
        final r = RetailImportParser.parse(sheet([probe.$2]));
        expect(
          r.errors.any((e) => e.column == probe.$1),
          isTrue,
          reason: '${probe.$1} should reject a negative',
        );
        expect(r.errors.first.message, contains('cannot be negative'));
      }
    });

    test('a thousands separator is rejected rather than guessed', () {
      final r = RetailImportParser.parse(sheet([row(price: '1,200')]));
      expect(r.errors.single.message, contains('thousands separators'));
    });

    test('a currency symbol is tolerated', () {
      final r = RetailImportParser.parse(sheet([row(price: '₹ 1200')]));
      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups.single.variants.single.sellingPrice, 1200);
    });
  });

  // ── J. Mixed valid / invalid ──────────────────────────────────────────────

  group('J — mixed valid and invalid rows', () {
    test('valid groups import, invalid ones are rejected whole, and every '
        'error names its row', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'good1', name: 'Good One', price: '10'), // row 2
          row(handle: 'bad1', name: '', price: '10'), // row 3
          row(handle: 'good2', name: 'Good Two', price: '20'), // row 4
          row(handle: 'bad2', name: 'Bad Two', price: 'oops'), // row 5
          row(
            handle: 'good3',
            name: 'Good Three',
            price: '30',
            unit: 'kg',
            stock: '2.5',
          ), // row 6
        ]),
      );

      expect(r.groups.map((g) => g.name), [
        'Good One',
        'Good Two',
        'Good Three',
      ]);
      expect(r.rejectedGroupCount, 2);
      expect(r.errors.map((e) => e.rowNumber), [3, 5]);
      expect(r.dataRowCount, 5);
    });

    test('one bad row poisons only its own Handle, and takes its siblings '
        'with it', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'multi', name: 'Multi', opt1Name: 'S', opt1Value: 'A'),
          row(
            handle: 'multi',
            name: 'Multi',
            opt1Name: 'S',
            opt1Value: 'B',
            price: 'nope',
          ),
          row(handle: 'solo', name: 'Solo'),
        ]),
      );

      expect(r.groups.map((g) => g.name), ['Solo']);
      expect(r.rejectedGroupCount, 1);
    });

    test('issues come back sorted by row number', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'a', name: 'A', price: 'x'),
          row(handle: 'b', name: '', price: 'y'),
        ]),
      );

      final rowNumbers = r.issues.map((i) => i.rowNumber).toList();
      final sorted = [...rowNumbers]..sort();
      expect(rowNumbers, sorted);
    });

    test('completely empty rows are ignored without complaint', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'a', name: 'A'),
          List.filled(21, ''),
          row(handle: 'b', name: 'B'),
        ]),
      );

      expect(r.errors, isEmpty);
      expect(r.groups, hasLength(2));
      expect(r.dataRowCount, 2);
    });

    test('an empty sheet reports nothing to import', () {
      final r = RetailImportParser.parse([]);
      expect(r.hasAnythingToImport, isFalse);
      expect(r.issues, isEmpty);
    });
  });

  // ── K. Backward compatibility ─────────────────────────────────────────────

  group('K — files made before SKU/Unit/Expiry existed still import', () {
    /// The exact 18 headers the template wrote before this change.
    List<String> legacyHeaders() => const [
      'Handle*',
      'Name*',
      'Category*',
      'Description',
      'Option1 Name',
      'Option1 Value',
      'Option2 Name',
      'Option2 Value',
      'Option3 Name',
      'Option3 Value',
      'Cost Price',
      'Selling Price*',
      'MRP',
      'Stock',
      'Barcode',
      'Min Stock',
      'Tax Rate',
      'HSN Code',
    ];

    test('an 18-column legacy row parses with piece / no expiry / no SKU', () {
      final r = RetailImportParser.parse([
        legacyHeaders(),
        [
          'cotton_socks',
          'Cotton Socks',
          'Clothing',
          'Comfortable socks',
          'Size',
          'S',
          '',
          '',
          '',
          '',
          '2.00',
          '6.00',
          '7.00',
          '30',
          'SOCK-S',
          '5',
          '',
          '',
        ],
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      final g = r.groups.single;
      expect(g.name, 'Cotton Socks');
      expect(g.categoryName, 'Clothing');
      expect(g.unit, 'piece');
      expect(g.isDecimalQuantity, isFalse);
      expect(g.expiryDate, isNull);

      final v = g.variants.single;
      expect(v.sku, isNull, reason: 'SKU is no longer copied from the barcode');
      expect(v.barcode, 'SOCK-S');
      expect(v.costPrice, 2.0);
      expect(v.sellingPrice, 6.0);
      expect(v.mrp, 7.0);
      expect(v.stockQty, 30);
      expect(v.minStock, 5);
      expect(v.attributes, {'Size': 'S'});
    });

    test('a legacy multi-variant group still groups correctly', () {
      final r = RetailImportParser.parse([
        legacyHeaders(),
        [
          'ts',
          'Tee',
          'Clothing',
          '',
          'Size',
          'S',
          '',
          '',
          '',
          '',
          '5',
          '15',
          '18',
          '20',
          'TS-S',
          '5',
          '',
          '6109',
        ],
        [
          'ts',
          'Tee',
          'Clothing',
          '',
          'Size',
          'M',
          '',
          '',
          '',
          '',
          '5',
          '15',
          '18',
          '15',
          'TS-M',
          '5',
          '',
          '',
        ],
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups.single.variants, hasLength(2));
      expect(r.groups.single.hsnCode, '6109');
    });

    test('a row shorter than the header row does not crash', () {
      final r = RetailImportParser.parse([
        legacyHeaders(),
        ['h', 'Short Row', 'Cat', '', '', '', '', '', '', '', '', '9'],
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups.single.variants.single.sellingPrice, 9);
    });
  });

  // ── Header mapping ────────────────────────────────────────────────────────

  group('header mapping', () {
    test('columns are matched by NAME, so order does not matter', () {
      // Name and Selling Price swapped to the front.
      final r = RetailImportParser.parse([
        ['Selling Price*', 'Name*', 'Handle*', 'Unit'],
        ['42', 'Reordered', 'h1', 'kg'],
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups.single.name, 'Reordered');
      expect(r.groups.single.unit, 'kg');
      expect(r.groups.single.variants.single.sellingPrice, 42);
    });

    test('an unknown extra column is ignored', () {
      final r = RetailImportParser.parse([
        ['Handle*', 'Name*', 'Selling Price*', 'Supplier Notes'],
        ['h1', 'With Extra', '10', 'call before delivery'],
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups.single.name, 'With Extra');
    });

    test('friendly synonyms are accepted for hand-made files', () {
      final r = RetailImportParser.parse([
        ['Handle*', 'Product Name', 'Price', 'UOM', 'Expiry', 'Product Code'],
        ['h1', 'Synonyms', '12', 'kgs', '2027-01-01', 'SKU-9'],
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      final g = r.groups.single;
      expect(g.name, 'Synonyms');
      expect(g.unit, 'kg');
      expect(DateTime.parse(g.expiryDate!), DateTime(2027, 1, 1));
      expect(g.variants.single.sku, 'SKU-9');
      expect(g.variants.single.sellingPrice, 12);
    });

    test('header matching ignores case, spacing and the * marker', () {
      final r = RetailImportParser.parse([
        ['handle', '  NAME  ', 'selling price'],
        ['h1', 'Loose Headers', '7'],
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups.single.name, 'Loose Headers');
    });

    test('an unrecognisable header row falls back to template positions', () {
      // No recognisable header names at all — the old positional behaviour.
      final r = RetailImportParser.parse([
        List.filled(21, 'col'),
        [
          'h1',
          'Positional',
          'Cat',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '11',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'kg',
          '',
        ],
      ]);

      expect(r.errors, isEmpty, reason: errorText(r).join('\n'));
      expect(r.groups.single.name, 'Positional');
      expect(r.groups.single.unit, 'kg');
    });

    test('the header row and the enum stay the same length', () {
      expect(
        kRetailImportHeaderRow,
        hasLength(RetailImportColumn.values.length),
      );
      expect(kRetailImportHeaderRow, hasLength(21));
      // The first 18 must keep their historical positions.
      expect(kRetailImportHeaderRow.take(18).last, 'HSN Code');
      expect(kRetailImportHeaderRow[18], 'SKU');
      expect(kRetailImportHeaderRow[19], 'Unit');
      expect(kRetailImportHeaderRow[20], 'Expiry Date');
    });
  });

  // ── Product-level fields ──────────────────────────────────────────────────

  group('product-level fields come from the parent row', () {
    test('tax, HSN, category and description are read once per group', () {
      final r = RetailImportParser.parse(
        sheet([
          row(
            handle: 't',
            name: 'Tee',
            category: 'Clothing',
            description: 'Cotton',
            opt1Name: 'Size',
            opt1Value: 'S',
            tax: 'GST (5%)',
            hsn: '6109',
          ),
          row(handle: 't', name: 'Tee', opt1Name: 'Size', opt1Value: 'M'),
        ]),
      );

      final g = r.groups.single;
      expect(g.categoryName, 'Clothing');
      expect(g.description, 'Cotton');
      expect(g.taxLabel, 'GST (5%)');
      expect(g.hsnCode, '6109');
    });

    test('summary counts feed the preview dialog', () {
      final r = RetailImportParser.parse(
        sheet([
          row(handle: 'a', name: 'A', category: 'Food'),
          row(
            handle: 'b',
            name: 'B',
            category: 'Drink',
            opt1Name: 'S',
            opt1Value: 'x',
          ),
          row(handle: 'b', name: 'B', opt1Name: 'S', opt1Value: 'y'),
        ]),
      );

      expect(r.groups, hasLength(2));
      expect(r.variantCount, 3);
      expect(r.categoryNames, {'Food', 'Drink'});
      expect(r.hasAnythingToImport, isTrue);
    });
  });
}
