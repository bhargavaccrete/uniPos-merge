import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'supplier_ledger_entry_model_179.g.dart';

const _uuid = Uuid();

/// What moved a supplier's balance.
///
/// - opening: the balance the supplier was created with
/// - purchase: a confirmed GRN, billed at the full received value
/// - returnCredit: a supplier credit note against a purchase return
/// - claimCredit: a supplier claim reaching `settled`
/// - payment: money actually paid to the supplier
/// - adjustment: a manual correction that is not a payment
enum SupplierLedgerType {
  opening,
  purchase,
  returnCredit,
  claimCredit,
  payment,
  adjustment,
}

/// One movement of a supplier's balance.
///
/// **Why this table exists.** `SupplierModel.currentBalance` is a running total
/// with no journal behind it — it can say what is owed but never why. Four of
/// the five things that moved it left a document (GRN, return, claim, opening
/// balance); the fifth, the old "Update Balance" dialog, left nothing at all.
/// Since every payment went through that dialog, payments were invisible and no
/// ledger rebuilt from documents could ever reconcile.
///
/// Every balance movement now writes one row here, from the single choke point
/// `SupplierStore.recordBalanceMovement`. Nothing else may touch the balance.
///
/// [balanceAfter] is STORED rather than recomputed on read, mirroring
/// `CreditPaymentModel.balanceBefore/balanceAfter` on the customer side: a row
/// stays true about the moment it was written even if entries are ever
/// back-dated or filtered.
@HiveType(typeId: HiveTypeIds.retailSupplierLedgerEntry)
class SupplierLedgerEntryModel extends HiveObject {
  @HiveField(0)
  final String entryId;

  @HiveField(1)
  final String supplierId;

  /// When the movement happened — not necessarily when it was recorded. A
  /// back-dated payment sorts by this; [createdAt] keeps the entry time.
  @HiveField(2)
  final String date;

  /// [SupplierLedgerType] as a string.
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

  /// cash / upi / bank / cheque — payments only.
  @HiveField(9)
  final String? paymentMode;

  /// Cheque number, UTR, transaction id.
  @HiveField(10)
  final String? referenceNo;

  @HiveField(11)
  final String? note;

  @HiveField(12)
  final String createdAt;

  SupplierLedgerEntryModel({
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
  });

  factory SupplierLedgerEntryModel.create({
    required String supplierId,
    required SupplierLedgerType type,
    required double amount,
    required double balanceAfter,
    required String description,
    String? date,
    String? docNumber,
    String? docId,
    String? paymentMode,
    String? referenceNo,
    String? note,
  }) {
    final now = DateTime.now().toIso8601String();
    return SupplierLedgerEntryModel(
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

  SupplierLedgerType get typeEnum => SupplierLedgerType.values.firstWhere(
    (e) => e.name == type,
    orElse: () => SupplierLedgerType.adjustment,
  );

  /// True when this movement increased what is owed.
  bool get isDebit => amount > 0;

  String get typeDisplay {
    switch (typeEnum) {
      case SupplierLedgerType.opening:
        return 'Opening';
      case SupplierLedgerType.purchase:
        return 'Purchase';
      case SupplierLedgerType.returnCredit:
        return 'Return Credit';
      case SupplierLedgerType.claimCredit:
        return 'Claim Credit';
      case SupplierLedgerType.payment:
        return 'Payment';
      case SupplierLedgerType.adjustment:
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
  };

  factory SupplierLedgerEntryModel.fromMap(Map<String, dynamic> map) {
    return SupplierLedgerEntryModel(
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
    );
  }
}

/// The reconciliation shown on a supplier's Overview tab.
///
/// The buckets are not decoration — they must satisfy
/// `opening + purchases + returnCredits + claimCredits + payments + adjustments
/// == closing`, which is what makes the Outstanding figure above them
/// trustworthy. [summariseLedger] is the only thing that builds one.
class SupplierAccountSummary {
  final double opening;
  final double purchases;

  /// Negative — credits reduce what is owed.
  final double returnCredits;
  final double claimCredits;
  final double payments;
  final double adjustments;

  /// Balance after the last movement.
  final double closing;

  const SupplierAccountSummary({
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
/// testable without Hive or the service locator, the same way the GRN credit
/// decisions are.
///
/// [entries] may be in any order — buckets are order-independent — but
/// [SupplierAccountSummary.closing] is taken from the chronologically last
/// entry's stored `balanceAfter` rather than by summing, so it reports what the
/// balance actually was rather than what the buckets imply. When the two
/// disagree there is a bug, and the Overview tab should show it.
SupplierAccountSummary summariseLedger(List<SupplierLedgerEntryModel> entries) {
  if (entries.isEmpty) return const SupplierAccountSummary();

  var opening = 0.0;
  var purchases = 0.0;
  var returnCredits = 0.0;
  var claimCredits = 0.0;
  var payments = 0.0;
  var adjustments = 0.0;

  for (final e in entries) {
    switch (e.typeEnum) {
      case SupplierLedgerType.opening:
        opening += e.amount;
      case SupplierLedgerType.purchase:
        purchases += e.amount;
      case SupplierLedgerType.returnCredit:
        returnCredits += e.amount;
      case SupplierLedgerType.claimCredit:
        claimCredits += e.amount;
      case SupplierLedgerType.payment:
        payments += e.amount;
      case SupplierLedgerType.adjustment:
        adjustments += e.amount;
    }
  }

  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));

  return SupplierAccountSummary(
    opening: opening,
    purchases: purchases,
    returnCredits: returnCredits,
    claimCredits: claimCredits,
    payments: payments,
    adjustments: adjustments,
    closing: sorted.last.balanceAfter,
  );
}
