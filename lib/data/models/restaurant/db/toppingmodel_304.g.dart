// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toppingmodel_304.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ToppingAdapter extends TypeAdapter<Topping> {
  @override
  final int typeId = 104;

  @override
  Topping read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Topping(
      name: fields[0] as String,
      isveg: fields[1] as bool,
      price: fields[2] as double,
      isContainSize: fields[3] as bool?,
      variantion: (fields[4] as List?)?.cast<VariantModel>(),
      variantPrices: (fields[5] as Map?)?.cast<String, double>(),
      createdTime: fields[6] as DateTime?,
      lastEditedTime: fields[7] as DateTime?,
      editedBy: fields[8] as String?,
      editCount: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Topping obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isveg)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.isContainSize)
      ..writeByte(4)
      ..write(obj.variantion)
      ..writeByte(5)
      ..write(obj.variantPrices)
      ..writeByte(6)
      ..write(obj.createdTime)
      ..writeByte(7)
      ..write(obj.lastEditedTime)
      ..writeByte(8)
      ..write(obj.editedBy)
      ..writeByte(9)
      ..write(obj.editCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToppingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
