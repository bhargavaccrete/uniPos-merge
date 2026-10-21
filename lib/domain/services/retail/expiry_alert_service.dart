import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/expiry_status.dart';

/// One variant considered for an expiry alert, with the naming already
/// resolved. Lets the alert maths be exercised without booting Hive/GetIt.
typedef ExpiryCandidate = ({
  String productId,
  String productName,
  String variantLabel,
  VarianteModel variant,
});

/// Expiry alerts for retail, **derived on every read**.
///
/// Nothing is persisted. The alert list is recomputed from live variant data
/// each time it is asked for, which is what makes the notification rules hold
/// without any bookkeeping:
///
///  * **No duplicates** — there is no stored alert to duplicate, so opening the
///    app ten times produces the same list ten times.
///  * **Edited expiry** — the next read is simply correct; there is no stale
///    record to retire.
///  * **Cleared expiry** — the variant stops matching and drops out.
///
/// Mirrors [StockAlertService]'s shape (query + summary, `Map<String,dynamic>`
/// rows) so the Expiry Alerts screen is built the same way the Stock Alerts
/// screen is. Quantities are read as `num` — decimal variants are the point.
///
/// Split deliberately: [buildAlerts] is pure and holds the rules; the
/// store-reading wrappers below just supply candidates.
///
/// Not batch tracking: one expiry per variant, no lots, no FEFO.
class ExpiryAlertService {
  ExpiryAlertService._();

  /// THE alert rule, pure. Keeps only candidates whose status is alerting and
  /// sorts them most-urgent first (expired items sort to the top because their
  /// `daysUntil` is negative).
  static List<Map<String, dynamic>> buildAlerts(
    List<ExpiryCandidate> candidates, {
    DateTime? asOf,
    int warningDays = kExpiryWarningDays,
  }) {
    final rows = <Map<String, dynamic>>[];

    for (final c in candidates) {
      final status = expiryStatusFor(
        c.variant.expiryDateTime,
        asOf: asOf,
        warningDays: warningDays,
      );
      if (!status.isAlerting) continue;

      rows.add({
        'productId': c.productId,
        'productName': c.productName,
        'variantId': c.variant.varianteId,
        'variantLabel': c.variantLabel,
        'expiryDate': c.variant.expiryDate,
        'status': status,
        'daysUntil':
            daysUntilExpiry(c.variant.expiryDateTime, asOf: asOf) ?? 0,
        // `num`, never `int` — a loose-goods variant holds fractional stock.
        'currentStock': c.variant.stockQty,
        'unit': c.variant.isDecimalQuantity ? c.variant.effectiveUnit : null,
        'barcode': c.variant.barcode,
      });
    }

    rows.sort(
        (a, b) => (a['daysUntil'] as num).compareTo(b['daysUntil'] as num));
    return rows;
  }

  /// Headline counts, pure counterpart of [getExpirySummary].
  static Map<String, dynamic> summarise(List<Map<String, dynamic>> items) {
    final expired =
        items.where((i) => i['status'] == RetailExpiryStatus.expired).length;
    return {
      'totalAlerts': items.length,
      'expiredCount': expired,
      // Everything alerting that has not actually gone off yet — i.e.
      // expiringToday plus expiringSoon.
      'expiringSoonCount': items.length - expired,
      'items': items,
    };
  }

  /// Every variant in the catalogue currently in an alerting expiry state.
  static List<Map<String, dynamic>> getExpiryAlerts({
    DateTime? asOf,
    int warningDays = kExpiryWarningDays,
  }) =>
      buildAlerts(_candidates(), asOf: asOf, warningDays: warningDays);

  /// Counts for the dashboard card and the screen's summary band.
  static Map<String, dynamic> getExpirySummary({
    DateTime? asOf,
    int warningDays = kExpiryWarningDays,
  }) =>
      summarise(getExpiryAlerts(asOf: asOf, warningDays: warningDays));

  /// Badge count for the dashboard. Cheap enough to call inside an `Observer`.
  static int alertCount({DateTime? asOf}) => getExpiryAlerts(asOf: asOf).length;

  /// Reads the catalogue and resolves each variant's display naming.
  static List<ExpiryCandidate> _candidates() {
    final out = <ExpiryCandidate>[];
    for (final product in productStore.products) {
      for (final variant in productStore.variantsFor(product.productId)) {
        // Skip early: most variants never expire, and resolving a label is
        // the expensive part.
        if (!variant.hasExpiry) continue;
        out.add((
          productId: product.productId,
          productName: product.productName,
          variantLabel: attributeStore
              .describeAttributes(attributeStore.attributesOf(variant)),
          variant: variant,
        ));
      }
    }
    return out;
  }
}
