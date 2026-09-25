import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which browsable list a sort preference belongs to.
///
/// Each list keeps its own choice, so Manage Menu's Items can be Newest-first
/// while the POS menu stays A–Z. The enum's `name` is the persistence key
/// suffix, so renaming a value silently resets that list to the default.
///
/// The first six are Manage Menu's tabs; the rest name a screen. Serving both
/// verticals is why this lives in `services/common/` rather than under
/// `restaurant/`.
enum SortableList {
  // Manage Menu tabs (restaurant)
  all,
  items,
  categories,
  variants,
  choices,
  extras,

  // Restaurant POS menu — one choice covering its sections and their items.
  posMenu,

  // Retail catalog hub tabs
  retailProducts,
  retailCategories,
}

/// The sort orders offered on every sortable list.
///
/// Every entity involved (Items, Category, Variant, Choice, Extra,
/// ProductModel) carries a name and a nullable created timestamp, so one set
/// of options covers them all without per-entity special cases.
enum ListSortOption { nameAsc, nameDesc, newest, oldest }

/// Remembers the per-list sort choice across restarts.
///
/// A [ChangeNotifier] rather than a MobX store: this is view preference, not
/// domain data. Listening also solves the load race — prefs arrive
/// asynchronously, so the first frame renders the default and the
/// notification re-sorts once the real value is known. Because the default
/// *is* the most common choice (A–Z), that settling frame is invisible in the
/// usual case.
class ListSortService extends ChangeNotifier {
  ListSortService._internal() {
    _load();
  }

  static final ListSortService instance = ListSortService._internal();

  static const String _keyPrefix = 'list_sort_';

  /// Alphabetical, as the product default. Hive hands lists back in ascending
  /// *key* (UUID) order, which reads as random — see `applySort`.
  static const ListSortOption defaultOption = ListSortOption.nameAsc;

  final Map<SortableList, ListSortOption> _options = {};

  bool _loaded = false;

  /// Whether the stored preferences have arrived yet.
  bool get isLoaded => _loaded;

  /// The active sort for [list], falling back to [defaultOption].
  ListSortOption optionFor(SortableList list) =>
      _options[list] ?? defaultOption;

  /// Records [option] for [list] and persists it. Notifies listeners first so
  /// the list reorders immediately rather than waiting on the disk write.
  Future<void> setOption(SortableList list, ListSortOption option) async {
    if (_options[list] == option) return;
    _options[list] = option;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${list.name}', option.name);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final list in SortableList.values) {
        final stored = _parse(prefs.getString('$_keyPrefix${list.name}'));
        if (stored != null) _options[list] = stored;
      }
    } catch (_) {
      // A prefs failure just means everyone keeps the default order.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Tolerates a value written by an older build whose enum has since changed.
  static ListSortOption? _parse(String? raw) {
    if (raw == null) return null;
    for (final option in ListSortOption.values) {
      if (option.name == raw) return option;
    }
    return null;
  }
}

/// Returns a new list ordered by [option].
///
/// Generic over the row type because the sortable entities share no base
/// class — the caller supplies the two accessors instead ([nameOf] and
/// [createdAtOf]), which is what lets Extra's oddly-named `Ename` and retail's
/// `ProductModel.name` participate without any model change.
///
/// The input is never sorted in place: these lists come straight off MobX
/// `ObservableList`s, and sorting one would mutate store state from a build.
List<T> applySort<T>(
  List<T> rows,
  ListSortOption option, {
  required String Function(T) nameOf,
  required DateTime? Function(T) createdAtOf,
}) {
  final sorted = List<T>.of(rows);
  switch (option) {
    case ListSortOption.nameAsc:
      sorted.sort((a, b) => _compareNames(nameOf(a), nameOf(b)));
      break;
    case ListSortOption.nameDesc:
      sorted.sort((a, b) => _compareNames(nameOf(b), nameOf(a)));
      break;
    case ListSortOption.newest:
      sorted.sort((a, b) => _compareByDate(a, b, nameOf, createdAtOf, true));
      break;
    case ListSortOption.oldest:
      sorted.sort((a, b) => _compareByDate(a, b, nameOf, createdAtOf, false));
      break;
  }
  return sorted;
}

/// Case-insensitive, so 'apple' doesn't land after 'Zebra' — a raw
/// `compareTo` orders by code unit, putting every capital before every
/// lowercase letter.
int _compareNames(String a, String b) =>
    a.trim().toLowerCase().compareTo(b.trim().toLowerCase());

/// Date order with a name tiebreak, so rows sharing a timestamp (a bulk
/// import writes many in the same millisecond) still land in a stable,
/// readable order instead of shuffling between rebuilds.
int _compareByDate<T>(
  T a,
  T b,
  String Function(T) nameOf,
  DateTime? Function(T) createdAtOf,
  bool newestFirst,
) {
  final result = _compareDates(createdAtOf(a), createdAtOf(b), newestFirst);
  return result != 0 ? result : _compareNames(nameOf(a), nameOf(b));
}

/// `createdTime` is nullable on every one of these models, and legacy or
/// imported rows really do carry null. Undated rows sink to the bottom in
/// BOTH directions — treating null as epoch-zero would park them at the top
/// of "Oldest", which reads as a bug.
int _compareDates(DateTime? a, DateTime? b, bool newestFirst) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return newestFirst ? b.compareTo(a) : a.compareTo(b);
}
