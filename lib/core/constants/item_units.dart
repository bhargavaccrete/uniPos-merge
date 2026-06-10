/// Canonical item units — the single source of truth shared by the Add Item
/// sheet, the Edit Item screen, and the bulk-import template. Keeping one list
/// guarantees any unit that can be picked can also be edited (a value not in a
/// DropdownButton's items crashes it).
const List<String> kItemUnits = ['kg', 'gm', 'liter', 'ml', 'piece'];

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
