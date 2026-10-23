/// The one rule for when a KOT's food counts as consumed: it can no longer
/// be cancelled, and a void must not put its ingredients back on the shelf.
///
/// KOT statuses written by the app: Processing → Cooking → Ready → Served
/// (activeorder.dart, kds_handler.dart); 'Completed' is order-level, used as
/// the fallback when a KOT has no status of its own. Ready food is made, so
/// it is consumed; Processing and Cooking are still cancellable/restorable.
/// 'cooked' is never written but the Takeaway screen always treated it as
/// consumed, so it stays.
class KotStatusRule {
  static const Set<String> _consumed = {'ready', 'served', 'completed', 'cooked'};

  static bool isConsumed(String? status) =>
      status != null && _consumed.contains(status.toLowerCase());
}
