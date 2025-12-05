// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_details.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaxDetailsAdapter extends TypeAdapter<TaxDetails> {
  @override
  final int typeId = 2;

  @override
  TaxDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxDetails(
      isEnabled: fields[0] as bool,
      isInclusive: fields[1] as bool,
      defaultRate: fields[2] as double,
      taxName: fields[3] as String,
      placeOfSupply: fields[4] as String?,
      applyOnDelivery: fields[5] as bool,
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TaxDetails obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.isEnabled)
      ..writeByte(1)
      ..write(obj.isInclusive)
      ..writeByte(2)
      ..write(obj.defaultRate)
      ..writeByte(3)
      ..write(obj.taxName)
      ..writeByte(4)
      ..write(obj.placeOfSupply)
      ..writeByte(5)
      ..write(obj.applyOnDelivery)
      ..writeByte(6)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxDetailsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
