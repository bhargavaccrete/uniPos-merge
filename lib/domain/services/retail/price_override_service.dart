import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import 'price_override_reason.dart';

/// Outcome of validating a typed override price.
///
/// Three states rather than a bool, because "below cost" is neither valid nor
/// invalid — it is allowed, but only after the cashier is told what it means.
enum PriceOverrideVerdict {
  /// Safe to apply without further prompting.
  ok,

  /// Allowed, but sells at a loss — caller MUST confirm explicitly first.
  belowCost,

  /// Refused. [PriceOverrideValidation.message] says why.
  blocked,
}

class PriceOverrideValidation {
  final PriceOverrideVerdict verdict;

  /// Why it was blocked, or what the warning is. Null when [verdict] is ok.
  final String? message;

  const PriceOverrideValidation._(this.verdict, [this.message]);

  const PriceOverrideValidation.ok() : this._(PriceOverrideVerdict.ok);

  const PriceOverrideValidation.belowCost(String message)
      : this._(PriceOverrideVerdict.belowCost, message);

  const PriceOverrideValidation.blocked(String message)
      : this._(PriceOverrideVerdict.blocked, message);

  bool get isBlocked => verdict == PriceOverrideVerdict.blocked;
  bool get needsConfirmation => verdict == PriceOverrideVerdict.belowCost;
  bool get isAllowed => !isBlocked;
}

/// Rules and permission for overriding a line's selling price at the till.
///
/// **The master price is never touched.** An override lives only on the cart
/// line and, once billed, on the sale line — `VarianteModel.sellingPrice` is
/// read to seed the line and is never written back. A ₹900 product sold once at
/// ₹850 is still a ₹900 product tomorrow.
///
/// The whole feature is deliberately a thin layer: the overridden figure is
/// written to `CartItemModel.price`, which is already the sole per-line money
/// input to `RetailBillingService`. Nothing downstream — tax, discount share,
/// grand total, receipt, reports, returns — needed changing.
class PriceOverrideService {
  PriceOverrideService._();

  /// Admin and Manager may override a price; a Cashier may not. An override
  /// moves money off the books, so it gets the same manager-level gate as
  /// `StockAdjustmentService.canAdjust`.
  ///
  /// Resolved from the signed-in staff member's ROLE, not their display name.
  ///
  /// Callers must HIDE the action when this is false rather than showing it and
  /// refusing (see the retail stock-adjustment precedent).
  static bool get canOverride => RestaurantSession.canAccess('billingOverride');

  /// Validate [newPrice] against the variant's own MRP and cost.
  ///
  /// Order matters: hard blocks are checked before the soft warning, so a
  /// zero-or-negative price is refused outright rather than surfacing as a
  /// "below cost — are you sure?" the cashier can click through.
  static PriceOverrideValidation validate({
    required VarianteModel variant,
    required double newPrice,
    required double currentPrice,
  }) {
    // 1. Hard block: a free or negative line is never a price.
    if (newPrice <= 0) {
      return const PriceOverrideValidation.blocked(
        'Price must be greater than zero.',
      );
    }

    // 2. Hard block: above MRP. MRP is the printed maximum and charging over it
    //    is a legal problem, not a business judgement — so no confirm path.
    final mrp = variant.mrp;
    if (mrp != null && mrp > 0 && newPrice > mrp) {
      return PriceOverrideValidation.blocked(
        'Cannot exceed MRP (${_money(mrp)}).',
      );
    }

    // 3. No-op: nothing to record, and storing an "override" equal to the
    //    catalogue price would put an unexplained reason on a normal line.
    if (newPrice == currentPrice) {
      return const PriceOverrideValidation.blocked(
        'Same as the current price.',
      );
    }

    // 4. Soft warning: selling under cost is a real decision (clearance,
    //    damaged stock) so it is allowed — but never silently.
    final cost = variant.costPrice;
    if (cost != null && cost > 0 && newPrice < cost) {
      return PriceOverrideValidation.belowCost(
        'This is below cost (${_money(cost)}). The line will sell at a loss.',
      );
    }

    return const PriceOverrideValidation.ok();
  }

  /// Is this reason + note combination complete?
  static bool isReasonComplete(PriceOverrideReason? reason, String? note) {
    if (reason == null) return false;
    if (!reason.requiresNote) return true;
    return (note ?? '').trim().isNotEmpty;
  }

  /// Plain number for a message. Deliberately not `formatMoney` — that needs a
  /// MoneyScope from the widget tree and this class is UI-free.
  static String _money(double v) => v.toStringAsFixed(2);
}
