import 'package:hive/hive.dart';
import '../../../core/constants/hive_box_names.dart';

/// Generates dated document numbers — `PO-20260813-001`, `GRN-20260813-001`.
///
/// Backed by a monotonic per-day counter in the shared `appCounters` box, the
/// same mechanism as `SkuGeneratorService` and `CustomerIdGeneratorService`.
///
/// **Why not count existing records.** The previous
/// `todayRecords.length + 1` was only safe because nothing could delete a PO.
/// Delete today's `PO-…-003` and the next PO reuses `003` — two different
/// orders sharing a number. A stored counter never goes backwards, so numbers
/// stay unique even after a delete.
///
/// The trade-off is gaps: opening a create form consumes a number, so
/// abandoning it leaves a hole in the sequence. Gaps in an internal PO number
/// are harmless; duplicates are not.
///
/// The counter lives in `appCounters`, which backup/restore round-trips, so
/// restoring a backup doesn't rewind the sequence.
class DocumentNumberService {
  Box get _counters => Hive.box(HiveBoxNames.appCounters);

  /// [prefix] is the document code — `'PO'`, `'GRN'`.
  ///
  /// [isTaken] lets the caller reject a number already present in its own box.
  /// It's a self-heal for the one case the counter can't cover: `appCounters`
  /// wiped or restored while the document box wasn't.
  Future<String> next(
    String prefix, {
    bool Function(String number)? isTaken,
  }) async {
    final now = DateTime.now();
    final datePart = '${now.year}${_two(now.month)}${_two(now.day)}';

    final dateKey = '${prefix}_lastDate';
    final seqKey = '${prefix}_lastSeq';

    // The sequence restarts each day so the date inside the number stays
    // meaningful — PO-20260813-001 is the first PO of the 13th, not the 1st
    // PO ever.
    final storedDate = _counters.get(dateKey) as String?;
    var seq = storedDate == datePart
        ? (_counters.get(seqKey, defaultValue: 0) as int)
        : 0;

    seq++;
    var number = _format(prefix, datePart, seq);
    while (isTaken != null && isTaken(number)) {
      seq++;
      number = _format(prefix, datePart, seq);
    }

    await _counters.put(dateKey, datePart);
    await _counters.put(seqKey, seq);
    return number;
  }

  String _format(String prefix, String datePart, int seq) =>
      '$prefix-$datePart-${seq.toString().padLeft(3, '0')}';

  String _two(int value) => value.toString().padLeft(2, '0');
}
