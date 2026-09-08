import 'package:hive/hive.dart';
import '../../../core/config/fiscal_year_rule.dart';
import '../../../core/constants/hive_box_names.dart';

/// Generates document numbers — `INV-00001`, `PO-00001`, `GRN-00001`.
///
/// Backed by a monotonic counter in the shared `appCounters` box, the same
/// mechanism as `SkuGeneratorService` and `CustomerIdGeneratorService`.
/// Mode-agnostic — both retail and restaurant documents (PO, GRN, purchase
/// return, supplier claim, inventory loss, stock take) share this one counter
/// box, so numbers never collide across modes.
///
/// **The sequence restarts at 1 each FINANCIAL year**, per [FiscalYearRule]
/// (1 April in India). It used to restart every DAY, embedding the date as
/// `PO-20260813-001`. That is wrong for a tax invoice: CGST Rule 46(b) wants
/// "a consecutive serial number... unique for a financial year", and a number
/// restarting each morning is ~300 series a year rather than one.
///
/// **Why not count existing records.** The previous `todayRecords.length + 1`
/// was only safe because nothing could delete a PO. Delete today's `PO-003` and
/// the next PO reuses `003` — two different orders sharing a number. A stored
/// counter never goes backwards within its year.
///
/// The trade-off is gaps: opening a create form consumes a number, so
/// abandoning it leaves a hole in the sequence. Gaps in an internal PO number
/// are harmless; duplicates are not.
///
/// The counter lives in `appCounters`, which backup/restore round-trips whole
/// (every key, not a fixed list), so restoring a backup doesn't rewind the
/// sequence and new keys here need no backup changes.
class DocumentNumberService {
  Box get _counters => Hive.box(HiveBoxNames.appCounters);

  /// Width of the zero-padded sequence. Five digits covers 99,999 documents in
  /// a year and still leaves room: with the longest allowed prefix the number
  /// stays inside Rule 46(b)'s sixteen-character limit. Past 99,999 it simply
  /// grows a digit rather than wrapping.
  static const int sequenceWidth = 5;

  /// Longest prefix a shop may configure, so `PREFIX-123456` cannot exceed the
  /// sixteen characters Rule 46(b) allows.
  static const int maxPrefixLength = 6;

  /// Document codes. These key the counters, so they are fixed even when a shop
  /// renames the prefix it prints — see [displayPrefix].
  static const String invoice = 'INV';
  static const String creditNote = 'CRN';

  String _fyKey(String prefix) => '${prefix}_lastFy';
  String _seqKey(String prefix) => '${prefix}_lastSeq';

  /// Key holding a shop's own prefix override, set from Invoice Numbering.
  static String prefixKey(String prefix) => '${prefix}_prefix';

  /// The prefix actually printed for [prefix]. Counter keys stay under the
  /// ORIGINAL prefix, so renaming `INV` to `BILL` re-labels the series without
  /// restarting it.
  String displayPrefix(String prefix) {
    final override = (_counters.get(prefixKey(prefix)) as String?)?.trim();
    return (override == null || override.isEmpty) ? prefix : override;
  }

  /// [prefix] is the document code — `'INV'`, `'PO'`, `'GRN'`.
  ///
  /// [isTaken] lets the caller reject a number already present in its own box.
  /// Only meaningful where the number is also the record's key; a number used
  /// purely for display cannot overwrite anything and needs no guard.
  Future<String> next(
    String prefix, {
    bool Function(String number)? isTaken,
  }) async {
    final seq = await _reserve(prefix, isTaken: isTaken);
    return _format(displayPrefix(prefix), seq);
  }

  /// The sequence this document type will use next, without consuming it —
  /// for the settings screen's preview.
  int peekNext(String prefix) {
    final fy = FiscalYearRule.currentKey;
    if ((_counters.get(_fyKey(prefix)) as String?) != fy) return 1;
    return (_counters.get(_seqKey(prefix), defaultValue: 0) as int) + 1;
  }

  /// Force the next sequence, so a shop migrating mid-year can continue the
  /// series it already issues. Stamps the current financial year too, or the
  /// very next mint would treat the year as new and reset the value away.
  Future<void> setNext(String prefix, int value) async {
    final seq = value < 1 ? 0 : value - 1;
    await _counters.put(_fyKey(prefix), FiscalYearRule.currentKey);
    await _counters.put(_seqKey(prefix), seq);
  }

  /// Store a shop's own prefix. An empty value clears the override.
  Future<void> setPrefix(String prefix, String value) async {
    final clean = value.trim().toUpperCase();
    await _counters.put(prefixKey(prefix), clean);
  }

  Future<int> _reserve(
    String prefix, {
    bool Function(String number)? isTaken,
  }) async {
    final fy = FiscalYearRule.currentKey;
    final label = displayPrefix(prefix);

    // A stored year that isn't this one means the year turned over — start
    // again at 1. Comparing the stored token rather than recomputing a date
    // keeps the reset correct across a restore, where the counter comes back
    // with the year it was saved under.
    final storedFy = _counters.get(_fyKey(prefix)) as String?;
    var seq = storedFy == fy
        ? (_counters.get(_seqKey(prefix), defaultValue: 0) as int)
        : 0;

    seq++;
    while (isTaken != null && isTaken(_format(label, seq))) {
      seq++;
    }

    await _counters.put(_fyKey(prefix), fy);
    await _counters.put(_seqKey(prefix), seq);
    return seq;
  }

  String _format(String prefix, int seq) =>
      '$prefix-${seq.toString().padLeft(sequenceWidth, '0')}';
}
