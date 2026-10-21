import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'restaurant_supplier_ledger_entry_model.g.dart';

const _uuid = Uuid();

/// What moved a restaurant supplier's balance.
///
/// - opening: the balance the supplier was created with / brought forward
/// - purchase: a confirmed GRN, billed at the full received value
/// - returnCredit: a supplier credit note against a purchase return
/// - claimCredit: a supplier claim reaching `settled`
/// - payment: money actually paid to the supplier
/// - adjustment: a manual correction that is not a payment
enum RestaurantSupplierLedgerType {
  opening,
  purchase,
  returnCredit,
  claimCredit,
  payment,
  adjustment,
}

/// One movement of a restaurant supplier's balance.
///
/// **Why this table exists.** `RestaurantSupplierModel.currentBalance` was a
/// running total with no journal behind it — it could say what was owed but
/// never why. Two places moved it (GRN confirm, and return/claim credits) with
/// no record of either, and there was no way to record a payment at all.
///
/// Every balance movement now writes one row here, from the single choke point
/// `RestaurantSupplierStore.recordBalanceMovement`. Nothing else may touch the
/// balance.
///
/// Mirrors retail's `SupplierLedgerEntryModel` (typeId 179) field-for-field so
/// the two modes stay legible side by side; it is a separate model because the
/// two modes keep parallel data layers throughout (see CLAUDE.md, "Mode
/// duality") and restaurant suppliers live in their own box.
///
/// [balanceAfter] is STORED rather than recomputed on read: a row stays true
/// about the moment it was written even if entries are ever back-dated or
/// filtered.
@HiveType(typeId: HiveTypeIds.restaurantSupplierLedgerEntry)
class RestaurantSupplierLedgerEntryModel extends HiveObject {
  @HiveField(0)
  final String entryId;

  @HiveField(1)
  final String supplierId;

  /// When the movement happened — not necessarily when it was recorded. A
  /// back-dated payment sorts by this; [createdAt] keeps the entry time.
  @HiveField(2)
  final String date;

  /// [RestaurantSupplierLedgerType] as a string.
  @HiveField(3)
  final String type;

  /// **Signed.** Positive increases what is owed (a purchase), negative reduces
  /// it (a credit or a payment). Storing the sign rather than deriving it from
  /// [type] keeps the running total a plain fold.
  @HiveField(4)
  final double amount;

  /// Balance immediately after this movement.
  @HiveField(5)
  final double balanceAfter;

  @HiveField(6)
  final String description;

  /// Source document number — `GRN-…`, `PR-…`, `CLM-…`. Null for payments,
  /// adjustments and the opening balance.
  @HiveField(7)
  final String? docNumber;

  /// Source document id, for tapping through to it later.
  @HiveField(8)
  final String? docId;

  /// Cash / UPI / Bank / Cheque — payments only.
  @HiveField(9)
  final String? paymentMode;

  /// Cheque number, UTR, transaction id.
  @HiveField(10)
  final String? referenceNo;

  @HiveField(11)
  final String? note;

  @HiveField(12)
  final String createdAt;

  /// 1-based position of this movement within its supplier's ledger.
  ///
  /// [date] alone cannot order the journal: two movements recorded in the same
  /// millisecond produce identical strings, and the clock's resolution is
  /// platform-dependent. That matters because the closing balance is read from
  /// the chronologically last row's [balanceAfter] — a tie could report the
  /// wrong one. Sorting by `(date, seq)` gives a total order.
  ///
  /// Defaulted to 0 so rows written before this field existed stay valid; they
  /// simply fall back to date-only ordering, which is what they had anyway.
  @HiveField(13, defaultValue: 0)
  final int seq;

  RestaurantSupplierLedgerEntryModel({
    required this.entryId,
    required this.supplierId,
    required this.date,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.docNumber,
    this.docId,
    this.paymentMode,
    this.referenceNo,
    this.note,
    required this.createdAt,
    this.seq = 0,
  });

  factory RestaurantSupplierLedgerEntryModel.create({
    required String supplierId,
    required RestaurantSupplierLedgerType type,
    required double amount,
    required double balanceAfter,
    required String description,
    String? date,
    String? docNumber,
    String? docId,
    String? paymentMode,
    String? referenceNo,
    String? note,
    int seq = 0,
  }) {
    final now = DateTime.now().toIso8601String();
    return RestaurantSupplierLedgerEntryModel(
      seq: seq,
      entryId: _uuid.v4(),
      supplierId: supplierId,
      date: date ?? now,
      type: type.name,
      amount: amount,
      balanceAfter: balanceAfter,
      description: description,
      docNumber: docNumber,
      docId: docId,
      paymentMode: paymentMode,
      referenceNo: referenceNo,
      note: note,
      createdAt: now,
    );
  }

  RestaurantSupplierLedgerType get typeEnum =>
      RestaurantSupplierLedgerType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => RestaurantSupplierLedgerType.adjustment,
      );

  /// True when this movement increased what is owed.
  bool get isDebit => amount > 0;

  String get typeDisplay {
    switch (typeEnum) {
      case RestaurantSupplierLedgerType.opening:
        return 'Opening';
      case RestaurantSupplierLedgerType.purchase:
        return 'Purchase';
      case RestaurantSupplierLedgerType.returnCredit:
        return 'Return Credit';
      case RestaurantSupplierLedgerType.claimCredit:
        return 'Claim Credit';
      case RestaurantSupplierLedgerType.payment:
        return 'Payment';
      case RestaurantSupplierLedgerType.adjustment:
        return 'Adjustment';
    }
  }

  Map<String, dynamic> toMap() => {
        'entryId': entryId,
        'supplierId': supplierId,
        'date': date,
        'type': type,
        'amount': amount,
        'balanceAfter': balanceAfter,
        'description': description,
        'docNumber': docNumber,
        'docId': docId,
        'paymentMode': paymentMode,
        'referenceNo': referenceNo,
        'note': note,
        'createdAt': createdAt,
        'seq': seq,
      };

  factory RestaurantSupplierLedgerEntryModel.fromMap(Map<String, dynamic> map) {
    return RestaurantSupplierLedgerEntryModel(
      entryId: map['entryId'] as String,
      supplierId: map['supplierId'] as String,
      date: map['date'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      balanceAfter: (map['balanceAfter'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String? ?? '',
      docNumber: map['docNumber'] as String?,
      docId: map['docId'] as String?,
      paymentMode: map['paymentMode'] as String?,
      referenceNo: map['referenceNo'] as String?,
      note: map['note'] as String?,
      createdAt: map['createdAt'] as String,
      seq: (map['seq'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Total order for a supplier's journal: chronological, with [seq] breaking
/// same-timestamp ties. Every read path sorts through this so the repository,
/// the summary and the Ledger tab can never disagree about which movement was
/// last — and therefore about the closing balance.
int compareRestaurantLedgerEntries(
  RestaurantSupplierLedgerEntryModel a,
  RestaurantSupplierLedgerEntryModel b,
) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  return a.seq.compareTo(b.seq);
}

/// The reconciliation shown on a supplier's Overview tab.
///
/// The buckets are not decoration — they must satisfy
/// `opening + purchases + returnCredits + claimCredits + payments + adjustments
/// == closing`, which is what makes the Outstanding figure above them
/// trustworthy. [summariseRestaurantLedger] is the only thing that builds one.
class RestaurantSupplierAccountSummary {
  final double opening;
  final double purchases;

  /// Negative — credits reduce what is owed.
  final double returnCredits;
  final double claimCredits;
  final double payments;
  final double adjustments;

  /// Balance after the last movement.
  final double closing;

  const RestaurantSupplierAccountSummary({
    this.opening = 0,
    this.purchases = 0,
    this.returnCredits = 0,
    this.claimCredits = 0,
    this.payments = 0,
    this.adjustments = 0,
    this.closing = 0,
  });

  /// Everything the supplier has credited back.
  double get totalCredits => returnCredits + claimCredits;

  /// What the buckets imply the closing balance should be. When this and
  /// [closing] disagree, a movement bypassed the choke point.
  double get impliedClosing =>
      opening + purchases + returnCredits + claimCredits + payments + adjustments;

  /// True when the business has overpaid and the supplier owes it money.
  bool get isAdvance => closing < 0;

  bool get isEmpty =>
      opening == 0 &&
      purchases == 0 &&
      returnCredits == 0 &&
      claimCredits == 0 &&
      payments == 0 &&
      adjustments == 0;
}

/// Fold ledger entries into the Overview reconciliation.
///
/// Pure and top-level on purpose: the arithmetic that has to add up is then
/// testable without Hive or the service locator.
///
/// [entries] may be in any order — buckets are order-independent — but
/// [RestaurantSupplierAccountSummary.closing] is taken from the chronologically
/// last entry's stored `balanceAfter` rather than by summing, so it reports what
/// the balance actually was rather than what the buckets imply. When the two
/// disagree there is a bug, and the Overview tab surfaces it.
RestaurantSupplierAccountSummary summariseRestaurantLedger(
  List<RestaurantSupplierLedgerEntryModel> entries,
) {
  if (entries.isEmpty) return const RestaurantSupplierAccountSummary();

  var opening = 0.0;
  var purchases = 0.0;
  var returnCredits = 0.0;
  var claimCredits = 0.0;
  var payments = 0.0;
  var adjustments = 0.0;

  for (final e in entries) {
    switch (e.typeEnum) {
      case RestaurantSupplierLedgerType.opening:
        opening += e.amount;
      case RestaurantSupplierLedgerType.purchase:
        purchases += e.amount;
      case RestaurantSupplierLedgerType.returnCredit:
        returnCredits += e.amount;
      case RestaurantSupplierLedgerType.claimCredit:
        claimCredits += e.amount;
      case RestaurantSupplierLedgerType.payment:
        payments += e.amount;
      case RestaurantSupplierLedgerType.adjustment:
        adjustments += e.amount;
    }
  }

  final sorted = [...entries]..sort(compareRestaurantLedgerEntries);

  return RestaurantSupplierAccountSummary(
    opening: opening,
    purchases: purchases,
    returnCredits: returnCredits,
    claimCredits: claimCredits,
    payments: payments,
    adjustments: adjustments,
    closing: sorted.last.balanceAfter,
  );
}
