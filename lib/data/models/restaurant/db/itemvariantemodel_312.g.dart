// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'itemvariantemodel_312.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemVarianteAdapter extends TypeAdapter<ItemVariante> {
  @override
  final int typeId = 312;

  @override
  ItemVariante read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemVariante(
      variantId: fields[0] as String,
      price: fields[1] as double,
      trackInventory: fields[2] as bool?,
      stockQuantity: fields[3] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemVariante obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.variantId)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.trackInventory)
      ..writeByte(3)
      ..write(obj.stockQuantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemVarianteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
