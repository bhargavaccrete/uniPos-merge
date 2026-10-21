/// A string-only pre-check that lets a date-window scan skip `DateTime.tryParse`
/// for a `SaleModel.createdAt` that is provably far outside the window.
///
/// Parsing a local timestamp costs a timezone lookup per sale, which dominates
/// every retail report over a large history. This never decides that a sale is
/// IN a window — it only proves "definitely outside", and everything it cannot
/// prove still goes through `tryParse` and the caller's own comparison, which
/// remain the only authority.
///
/// The proof holds only for the exact shape every writer produces,
/// `DateTime.now().toIso8601String()` on a local time:
/// `yyyy-MM-ddTHH:mm:ss.mmm` (23 chars) or `…mmmuuu` (26 chars), with every
/// field in range. Anything else — `Z`, offsets, date-only, a space or comma,
/// other precisions, overflowed fields that `tryParse` would normalise, or
/// garbage — is never pre-filtered.
///
/// Such a string is a local wall-clock time. A timezone transition can move its
/// instant, and a DateTime's local date relative to its instant, by at most a
/// day each (the largest real jumps skip one whole calendar day), so a sale
/// dated more than [marginDays] from a bound's local date cannot fall on the
/// wrong side of that bound. Only the calendar date is compared.
class SaleCreatedAtPrefilter {
  static const int marginDays = 3;

  /// Calendar dates (yyyymmdd) strictly below this are before the start.
  final int? _minDay;

  /// Calendar dates (yyyymmdd) strictly above this are at or after the end.
  final int? _maxDay;

  const SaleCreatedAtPrefilter._(this._minDay, this._maxDay);

  factory SaleCreatedAtPrefilter.forWindow(DateTime? start, DateTime? end) =>
      SaleCreatedAtPrefilter._(
        start == null ? null : _shiftedDay(start, -marginDays),
        end == null ? null : _shiftedDay(end, marginDays),
      );

  /// True only when [createdAt] is canonical, valid, and its date lies more
  /// than [marginDays] before the start or after the end.
  bool isDefinitelyOutside(String createdAt) {
    final minDay = _minDay;
    final maxDay = _maxDay;
    if (minDay == null && maxDay == null) return false;

    final day = _canonicalDay(createdAt);
    if (day == null) return false;
    return (minDay != null && day < minDay) || (maxDay != null && day > maxDay);
  }

  /// The bound's local calendar date moved by [days], as yyyymmdd. Calendar
  /// arithmetic on UTC fields, so no timezone rule is involved.
  static int _shiftedDay(DateTime bound, int days) {
    final local = bound.toLocal();
    final shifted = DateTime.utc(local.year, local.month, local.day + days);
    return shifted.year * 10000 + shifted.month * 100 + shifted.day;
  }

  /// yyyymmdd for a canonical, fully valid writer timestamp; null otherwise.
  static int? _canonicalDay(String s) {
    final length = s.length;
    if (length != 23 && length != 26) return null;
    if (s.codeUnitAt(4) != _dash ||
        s.codeUnitAt(7) != _dash ||
        s.codeUnitAt(10) != _upperT ||
        s.codeUnitAt(13) != _colon ||
        s.codeUnitAt(16) != _colon ||
        s.codeUnitAt(19) != _dot) {
      return null;
    }
    for (var i = 20; i < length; i++) {
      if (_digit(s, i) < 0) return null;
    }

    final year = _number(s, 0, 4);
    final month = _number(s, 5, 2);
    final day = _number(s, 8, 2);
    final hour = _number(s, 11, 2);
    final minute = _number(s, 14, 2);
    final second = _number(s, 17, 2);
    if (year < 0 || month < 1 || month > 12 || day < 1) return null;
    if (day > _daysInMonth(year, month)) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    if (second < 0 || second > 59) return null;
    return year * 10000 + month * 100 + day;
  }

  static int _digit(String s, int i) {
    final c = s.codeUnitAt(i) - _zero;
    return (c < 0 || c > 9) ? -1 : c;
  }

  /// The [count]-digit number at [from], or -1 if any character is not a digit.
  static int _number(String s, int from, int count) {
    var value = 0;
    for (var i = from; i < from + count; i++) {
      final d = _digit(s, i);
      if (d < 0) return -1;
      value = value * 10 + d;
    }
    return value;
  }

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      return leap ? 29 : 28;
    }
    return const [31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];
  }

  static const int _zero = 0x30;
  static const int _dash = 0x2D;
  static const int _colon = 0x3A;
  static const int _dot = 0x2E;
  static const int _upperT = 0x54;
}
