/// Canonical item units — the single source of truth shared by the Add Item
/// sheet, the Edit Item screen, and the bulk-import template. Keeping one list
/// guarantees any unit that can be picked can also be edited (a value not in a
/// DropdownButton's items crashes it).
const List<String> kItemUnits = ['kg', 'gm', 'liter', 'ml', 'piece'];

/// The units "By Weight" offers — measured quantities only. Counting in
/// pieces is "By Unit", never By Weight.
const List<String> kWeightUnits = ['kg', 'gm', 'liter', 'ml'];

/// True for a pound spelling. [normalizeItemUnit] maps these to 'kg' only so a
/// legacy item's LABEL keeps working — it converts no quantity. Imports must
/// refuse them instead, or 10 lb of stock would be booked as 10 kg (≈2.2×).
bool isPoundUnit(String? raw) {
  final u = (raw ?? '').toLowerCase().trim();
  return u == 'lb' || u == 'lbs' || u == 'pound' || u == 'pounds';
}

/// Map any legacy / alias / mis-cased unit string to a canonical [kItemUnits]
/// value, or null when blank/unrecognized. This keeps items saved with older
/// spellings ('litre', 'pcs', 'lbs', 'gram', …) working in the dropdowns.
String? normalizeItemUnit(String? raw) {
  final u = (raw ?? '').toLowerCase().trim();
  if (u.isEmpty) return null;
  switch (u) {
    case 'kg':
    case 'kgs':
    case 'kilogram':
    case 'kilo':
    case 'lbs': // no pounds in the app — closest supported
    case 'lb':
    case 'pound':
      return 'kg';
    case 'gm':
    case 'g':
    case 'gram':
    case 'grams':
    case 'gms':
      return 'gm';
    case 'liter':
    case 'litre':
    case 'l':
    case 'ltr':
      return 'liter';
    case 'ml':
    case 'milliliter':
    case 'millilitre':
      return 'ml';
    case 'piece':
    case 'pcs':
    case 'pc':
    case 'pec':
    case 'pieces':
      return 'piece';
    default:
      return null;
  }
}
