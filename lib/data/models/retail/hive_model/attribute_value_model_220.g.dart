// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attribute_value_model_220.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttributeValueModelAdapter extends TypeAdapter<AttributeValueModel> {
  @override
  final int typeId = 220;

  @override
  AttributeValueModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttributeValueModel(
      valueId: fields[0] as String,
      attributeId: fields[1] as String,
      value: fields[2] as String,
      slug: fields[3] as String,
      colorCode: fields[4] as String?,
      sortOrder: fields[5] as int,
      isActive: fields[6] as bool,
      createdAt: fields[7] as String,
      updatedAt: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AttributeValueModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.valueId)
      ..writeByte(1)
      ..write(obj.attributeId)
      ..writeByte(2)
      ..write(obj.value)
      ..writeByte(3)
      ..write(obj.slug)
      ..writeByte(4)
      ..write(obj.colorCode)
      ..writeByte(5)
      ..write(obj.sortOrder)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttributeValueModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
