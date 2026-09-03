import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/hive_box_names.dart';
import '../../../core/di/service_locator.dart';

/// Mints internal retail barcodes: `BB` + 10 zero-padded digits, e.g.
/// `BB0000000042`.
///
/// **Code 128** is the target symbology — alphanumeric, variable length, no
/// check digit, and no GS1 prefix to buy. A `BB` code therefore cannot collide
/// with a manufacturer's EAN by construction. The fixed 12-character length
/// makes a mis-scan obvious at a glance.
///
/// **The one rule that matters: a barcode is stable once assigned.** Callers
/// must only invoke [next] for a variant whose barcode is null/empty. Nothing in
/// the print path may call this — printing a label is read-only with respect to
/// the barcode, or reprinting a sheet would mint a new value and orphan every
/// label already stuck to the stock.
///
/// There is deliberately no "regenerate": the only route to a new value is for
/// an admin to clear the old one explicitly, having been warned that previously
/// printed labels stop identifying the variant.
class BarcodeGeneratorService {
  /// Human-visible marker that this code was issued by the app rather than a
  /// manufacturer. Stable — changing it would strand every printed label.
  static const String prefix = 'BB';

  /// Digits after [prefix]. Ten leaves room for ~10 billion variants and keeps
  /// every code the same width.
  static const int digits = 10;

  static const String _sequenceKey = 'lastBarcodeSequence';

  Box get _counters => Hive.box(HiveBoxNames.appCounters);

  /// Next unused barcode.
  ///
  /// [isTaken] MUST be supplied and MUST consult the persisted variants box, not
  /// an in-memory cache. It is not belt-and-braces: `appCounters` does not
  /// round-trip in a retail backup, so after a restore the stored sequence can
  /// be behind reality. The loop below is what makes the generator correct
  /// anyway — the same self-heal `DocumentNumberService.next` uses.
  ///
  /// [maxAttempts] bounds the walk so a pathological catalogue cannot hang the
  /// UI; exceeding it throws rather than returning a duplicate.
  Future<String> next({
    required bool Function(String barcode) isTaken,
    int maxAttempts = 100000,
  }) async {
    var seq = _counters.get(_sequenceKey, defaultValue: 0) as int;

    String candidate;
    var attempts = 0;
    do {
      seq++;
      attempts++;
      if (attempts > maxAttempts) {
        throw StateError(
          'Could not find a free barcode after $maxAttempts attempts. '
          'The barcode sequence may be corrupt.',
        );
      }
      candidate = format(seq);
    } while (isTaken(candidate));

    await _counters.put(_sequenceKey, seq);
    return candidate;
  }

  /// `BB` + zero-padded [sequence]. Exposed for tests and for rendering a
  /// preview without consuming a number.
  static String format(int sequence) =>
      '$prefix${sequence.toString().padLeft(digits, '0')}';

  /// True when [barcode] looks like one this service issued.
  ///
  /// Used to tell an internal code from a manufacturer's, e.g. to decide whether
  /// offering to change it is safe. Deliberately strict: prefix, exact length,
  /// and digits only after the prefix.
  static bool isGenerated(String? barcode) {
    final code = barcode?.trim() ?? '';
    if (code.length != prefix.length + digits) return false;
    if (!code.startsWith(prefix)) return false;
    return RegExp('^[0-9]{$digits}\$').hasMatch(code.substring(prefix.length));
  }

  /// The sequence embedded in a generated code, or null when [barcode] is not
  /// one of ours.
  static int? sequenceOf(String? barcode) {
    if (!isGenerated(barcode)) return null;
    return int.tryParse(barcode!.trim().substring(prefix.length));
  }
}

/// Who may create barcodes and print labels.
///
/// A label is a physical artifact that goes onto stock, and generating a barcode
/// WRITES to the catalogue — so it rides `catalogEdit`, the same key that gates
/// every other catalogue modification. Admin and Manager pass; a Cashier does
/// not.
///
/// Callers must HIDE the action when this is false rather than showing it and
/// refusing.
class BarcodeLabelPermission {
  BarcodeLabelPermission._();

  static bool get canPrint => RestaurantSession.canAccess('catalogEdit');
}
