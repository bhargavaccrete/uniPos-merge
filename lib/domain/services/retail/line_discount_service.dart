import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../restaurant/cart_calculation_service.dart' show DiscountType;
import 'line_discount_reason.dart';

/// Outcome of validating a typed line discount.
///
/// Three states rather than a bool, because "below cost" is neither valid nor
/// invalid — it is allowed, but only after the cashier is told what it means.
enum LineDiscountVerdict {
  /// Safe to apply without further prompting.
  ok,

  /// Allowed, but the line sells below cost — caller MUST confirm explicitly.
  belowCost,

  /// Refused. [LineDiscountValidation.message] says why.
  blocked,
}

class LineDiscountValidation {
  final LineDiscountVerdict verdict;

  /// Why it was blocked, or what the warning is. Null when [verdict] is ok.
  final String? message;

  /// The discount in currency for the whole line, once resolved from the entered
  /// type and value. Zero when the input was invalid.
  final double amount;

  /// Effective charged price per unit after the discount. This is the figure the
  /// below-cost check uses and the dialog previews.
  final double effectiveUnitPrice;

  const LineDiscountValidation._(
    this.verdict,
    this.amount,
    this.effectiveUnitPrice, [
    this.message,
  ]);

  bool get isBlocked => verdict == LineDiscountVerdict.blocked;
  bool get needsConfirmation => verdict == LineDiscountVerdict.belowCost;
  bool get isAllowed => !isBlocked;
}

/// Rules and permission for discounting a single cart line.
///
/// **Order of operations** (approved): catalogue price → price override → LINE
/// discount → order-level discount on the remainder → tax. So this service always
/// reasons about `CartItemModel.price`, which already carries any override, and
/// never about the variant's catalogue price.
///
/// **The master price is never touched.** A line discount lives only on the cart
/// line and, once billed, on the sale line.
///
/// Both a price override and a line discount may apply to the same line; the
/// below-cost check is made on the price AFTER both.
class LineDiscountService {
  LineDiscountService._();

  /// Only the admin identity may discount a line. It moves money off a settled
  /// sale, so it gets the same narrow gate as `PriceOverrideService.canOverride`
  /// and `StockAdjustmentService.canAdjust` — see `AuthService.login`, which names
  /// the admin session 'Admin'.
  ///
  /// Callers must HIDE the action when this is false rather than showing it and
  /// refusing.
  static bool get canDiscount => authService.currentUsername == 'Admin';

  /// Resolve an entered discount to a currency amount for the whole line.
  ///
  /// [gross] is `chargedUnitPrice * qty`. A percentage is taken off the gross, so
  /// re-resolving after a quantity change keeps the percentage intact — which is
  /// exactly why the type and raw value are persisted rather than only the amount.
  ///
  /// Never returns a negative, and never more than [gross].
  static double resolveAmount({
    required DiscountType type,
    required double value,
    required double gross,
  }) {
    if (value <= 0 || gross <= 0) return 0;
    final raw = type == DiscountType.percentage ? gross * (value / 100) : value;
    if (raw <= 0) return 0;
    return raw > gross ? gross : raw;
  }

  /// Validate an entered line discount against the line and the variant's cost.
  ///
  /// Order matters: hard blocks are checked before the soft warning, so an
  /// impossible discount is refused outright rather than surfacing as a
  /// "below cost — are you sure?" the cashier can click through.
  static LineDiscountValidation validate({
    required VarianteModel variant,
    required DiscountType type,
    required double value,
    required double chargedUnitPrice,
    required double qty,
  }) {
    final gross = chargedUnitPrice * qty;

    // 1. Hard block: nothing to discount.
    if (gross <= 0) {
      return const LineDiscountValidation._(
        LineDiscountVerdict.blocked,
        0,
        0,
        'This line has no value to discount.',
      );
    }

    // 2. Hard block: a negative discount is a price increase by the back door.
    if (value < 0) {
      return const LineDiscountValidation._(
        LineDiscountVerdict.blocked,
        0,
        0,
        'Discount cannot be negative.',
      );
    }

    // 3. Hard block: a percentage over 100 is not a discount.
    if (type == DiscountType.percentage && value > 100) {
      return const LineDiscountValidation._(
        LineDiscountVerdict.blocked,
        0,
        0,
        'Percentage cannot exceed 100%.',
      );
    }

    // 4. Nothing entered — treated as "clear the discount", not an error.
    if (value == 0) {
      return LineDiscountValidation._(
        LineDiscountVerdict.ok,
        0,
        chargedUnitPrice,
      );
    }

    final raw = type == DiscountType.percentage ? gross * (value / 100) : value;

    // 5. Hard block: a free line. Refused rather than clamped, so "discount 100%"
    //    and "discount more than the line" are both a deliberate no rather than a
    //    silent zero the cashier does not notice.
    if (raw >= gross) {
      return LineDiscountValidation._(
        LineDiscountVerdict.blocked,
        0,
        0,
        'Discount cannot equal or exceed the line total '
            '(${_money(gross)}). The final price must be above zero.',
      );
    }

    final amount = raw;
    final effectiveUnit = (gross - amount) / qty;

    // 6. Soft warning: selling under cost is a real decision (clearance, damaged
    //    stock) so it is allowed — but never silently. Measured on the price after
    //    BOTH the override and this discount.
    final cost = variant.costPrice;
    if (cost != null && cost > 0 && effectiveUnit < cost) {
      return LineDiscountValidation._(
        LineDiscountVerdict.belowCost,
        amount,
        effectiveUnit,
        'This brings the unit price to ${_money(effectiveUnit)}, below the '
            '${_money(cost)} cost. The line will sell at a loss.',
      );
    }

    return LineDiscountValidation._(
      LineDiscountVerdict.ok,
      amount,
      effectiveUnit,
    );
  }

  /// Is this reason + note combination complete?
  static bool isReasonComplete(LineDiscountReason? reason, String? note) {
    if (reason == null) return false;
    if (!reason.requiresNote) return true;
    return (note ?? '').trim().isNotEmpty;
  }

  /// Plain number for a message. Deliberately not `formatMoney` — that needs a
  /// MoneyScope from the widget tree and this class is UI-free.
  static String _money(double v) => v.toStringAsFixed(2);
}
