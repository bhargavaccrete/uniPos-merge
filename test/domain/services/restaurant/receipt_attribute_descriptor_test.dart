import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/store/retail/attribute_store.dart'
    show describeAttributeMap;

/// REGRESSION — RESTAURANT BILL PRINTING MUST NOT NEED `AttributeStore`
///
/// Printing a restaurant bill threw:
///
///   Bad state: GetIt: Object/factory with type AttributeStore is not
///   registered inside GetIt.
///
/// Restaurant's bill/KOT print reuses retail's `ReceiptPdfService`,
/// `PrintService` and `EscPosReceiptBuilder`. Those built each line's variant
/// descriptor through `attributeStore.describeAttributes(...)` — but
/// `AttributeStore` is registered only by `_registerRetailDependencies()`, so
/// in restaurant mode the GetIt lookup blew up mid-PDF.
///
/// The logic never read anything off the store; it only used its arguments. It
/// is now the top-level [describeAttributeMap], which cannot fail on
/// registration. **These tests deliberately never touch GetIt** — the fact that
/// they run at all with no locator set up is the regression check.
void main() {
  group('describeAttributeMap works with no service locator at all', () {
    test('a restaurant line (no attribute map) falls back to the size column', () {
      // How restaurant items reach the receipt: `size` carries the variant
      // name, and there is no generic attribute map.
      expect(
        describeAttributeMap(null, size: 'Large', labelled: false),
        'Large',
      );
    });

    test('an empty attribute map also falls back to the legacy columns', () {
      expect(
        describeAttributeMap(const {}, size: 'Regular', labelled: false),
        'Regular',
      );
    });

    test('a plain restaurant item with nothing to show returns empty', () {
      // Callers use "" to decide not to render the line at all.
      expect(describeAttributeMap(null), '');
      expect(describeAttributeMap(const {}), '');
    });

    test('retail attributes render labelled, as on a retail bill', () {
      expect(
        describeAttributeMap(const {'Storage': '1tb'}),
        'Storage: 1tb',
      );
    });

    test('multiple attributes join with the default separator', () {
      expect(
        describeAttributeMap(const {'Size': 'L', 'Color': 'Red'}),
        'Size: L · Color: Red',
      );
    });

    test('a custom separator is honoured (the PDF item block uses " | ")', () {
      expect(
        describeAttributeMap(const {'Size': 'L', 'Color': 'Red'},
            separator: ' | '),
        'Size: L | Color: Red',
      );
    });

    test('labelled:false drops the names — the thermal receipt style', () {
      expect(
        describeAttributeMap(const {'Size': 'L', 'Color': 'Red'},
            labelled: false),
        'L · Red',
      );
    });

    test('a real attribute map wins over the legacy columns', () {
      expect(
        describeAttributeMap(const {'Storage': '1tb'},
            size: 'Large', color: 'Red'),
        'Storage: 1tb',
      );
    });

    test('blank keys and values are skipped, not rendered as empty pairs', () {
      expect(
        describeAttributeMap(const {'Size': 'L', '': 'x', 'Color': '  '}),
        'Size: L',
      );
    });

    test('values are trimmed', () {
      expect(describeAttributeMap(const {'Size': '  L  '}), 'Size: L');
      expect(
        describeAttributeMap(null, size: '  Large  ', labelled: false),
        'Large',
      );
    });

    test('all three legacy columns render in Size / Color / Weight order', () {
      expect(
        describeAttributeMap(null, size: 'L', color: 'Red', weight: '1kg'),
        'Size: L · Color: Red · Weight: 1kg',
      );
    });

    test('weight is omitted when the caller does not pass it', () {
      // The PDF item block deliberately excludes weight — restaurant reuses
      // that column for the extras blob, rendered separately.
      expect(
        describeAttributeMap(null, size: 'L', color: 'Red'),
        'Size: L · Color: Red',
      );
    });
  });
}
