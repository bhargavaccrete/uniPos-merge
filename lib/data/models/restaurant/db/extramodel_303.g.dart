// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extramodel_303.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExtramodelAdapter extends TypeAdapter<Extramodel> {
  @override
  final int typeId = 303;

  @override
  Extramodel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Extramodel(
      Id: fields[0] as String,
      Ename: fields[1] as String,
      isEnabled: fields[2] as bool?,
      topping: (fields[3] as List?)?.cast<Topping>(),
      createdTime: fields[4] as DateTime?,
      lastEditedTime: fields[5] as DateTime?,
      editedBy: fields[6] as String?,
      editCount: fields[7] as int,
      minimum: fields[8] as int?,
      maximum: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Extramodel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.Id)
      ..writeByte(1)
      ..write(obj.Ename)
      ..writeByte(2)
      ..write(obj.isEnabled)
      ..writeByte(3)
      ..write(obj.topping)
      ..writeByte(4)
      ..write(obj.createdTime)
      ..writeByte(5)
      ..write(obj.lastEditedTime)
      ..writeByte(6)
      ..write(obj.editedBy)
      ..writeByte(7)
      ..write(obj.editCount)
      ..writeByte(8)
      ..write(obj.minimum)
      ..writeByte(9)
      ..write(obj.maximum);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtramodelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
