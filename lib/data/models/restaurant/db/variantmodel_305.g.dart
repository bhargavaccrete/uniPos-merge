// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variantmodel_305.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VariantModelAdapter extends TypeAdapter<VariantModel> {
  @override
  final int typeId = 305;

  @override
  VariantModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VariantModel(
      id: fields[0] as String,
      name: fields[1] as String,
      createdTime: fields[2] as DateTime?,
      lastEditedTime: fields[3] as DateTime?,
      editedBy: fields[4] as String?,
      editCount: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, VariantModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdTime)
      ..writeByte(3)
      ..write(obj.lastEditedTime)
      ..writeByte(4)
      ..write(obj.editedBy)
      ..writeByte(5)
      ..write(obj.editCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariantModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
