import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/util/common/tax_split.dart';

/// The rule every cgst/sgst writer routes through: the two components MUST add
/// back to the tax the customer was charged. Rounding each half independently
/// broke that on ~50% of bills.
void main() {
  double r2(double v) => double.parse(v.toStringAsFixed(2));

  group('TaxSplit.halves', () {
    test('an even split is exact', () {
      final h = TaxSplit.halves(9.00);
      expect(h.cgst, 4.50);
      expect(h.sgst, 4.50);
    });

    test('an odd paisa goes to CGST and SGST takes the remainder', () {
      // The regression: 1.81 used to print as 0.91 + 0.91 = 1.82.
      final h = TaxSplit.halves(1.81);
      expect(h.cgst, 0.91);
      expect(h.sgst, 0.90);
      expect(r2(h.cgst + h.sgst), 1.81);
    });

    test('zero splits into zeroes', () {
      final h = TaxSplit.halves(0);
      expect(h.cgst, 0);
      expect(h.sgst, 0);
    });

    test('sign is preserved, so a credit note still reconciles', () {
      final h = TaxSplit.halves(-1.81);
      expect(h.cgst, lessThan(0));
      expect(h.sgst, lessThan(0));
      expect(r2(h.cgst + h.sgst), -1.81);
    });

    test('the halves reconcile for every taxable base at every common slab',
        () {
      final failures = <String>[];
      for (final rate in [5, 12, 18, 28]) {
        // ₹0.01 to ₹2,000 in paise steps — the realistic range for a line.
        for (int paise = 1; paise <= 200000; paise++) {
          final gst = r2(paise / 100.0 * rate / 100.0);
          final h = TaxSplit.halves(gst);
          if (r2(h.cgst + h.sgst) != gst) {
            failures.add('₹${(paise / 100).toStringAsFixed(2)} @ $rate% '
                '→ GST $gst but ${h.cgst}+${h.sgst}');
            if (failures.length > 3) break;
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });
}
