import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

/// Read-only stand-in for the retired `TaxRateItem` (typeId 5).
///
/// `TaxDetails` used to carry `@HiveField(7) List<TaxRateItem>? taxRates`.
/// The field and its adapter were removed when named tax rates moved to the
/// shared Tax entity (typeId 114), but boxes written before that still hold
/// those bytes — and the generated `TaxDetails.read()` resolves EVERY field on
/// disk before discarding the ones it no longer wants. Without an adapter for
/// typeId 5 the whole taxBox fails to open.
///
/// This adapter exists only so those frames can be parsed and thrown away.
/// Nothing constructs or writes it; the record is rewritten without field 7
/// the next time TaxDetails is saved.
class LegacyTaxRateItem {
  const LegacyTaxRateItem();
}

class LegacyTaxRateItemAdapter extends TypeAdapter<LegacyTaxRateItem> {
  @override
  final int typeId = HiveTypeIds.legacyTaxRateItem;

  @override
  LegacyTaxRateItem read(BinaryReader reader) {
    // Consume the original layout (3 fields: name, rate, isDefault) so the
    // reader lands on the correct byte, then discard the values.
    final numOfFields = reader.readByte();
    for (var i = 0; i < numOfFields; i++) {
      reader.readByte();
      reader.read();
    }
    return const LegacyTaxRateItem();
  }

  @override
  void write(BinaryWriter writer, LegacyTaxRateItem obj) {
    throw UnsupportedError('LegacyTaxRateItem is read-only legacy data.');
  }
}
