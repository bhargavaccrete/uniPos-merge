// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attribute_model_219.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttributeModelAdapter extends TypeAdapter<AttributeModel> {
  @override
  final int typeId = 219;

  @override
  AttributeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttributeModel(
      attributeId: fields[0] as String,
      name: fields[1] as String,
      slug: fields[2] as String,
      sortOrder: fields[3] as int,
      isActive: fields[4] as bool,
      createdAt: fields[5] as String,
      updatedAt: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AttributeModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.attributeId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.slug)
      ..writeByte(3)
      ..write(obj.sortOrder)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttributeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
