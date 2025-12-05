// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_attribute_model_221.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductAttributeModelAdapter extends TypeAdapter<ProductAttributeModel> {
  @override
  final int typeId = 221;

  @override
  ProductAttributeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductAttributeModel(
      id: fields[0] as String,
      productId: fields[1] as String,
      attributeId: fields[2] as String,
      selectedValueIds: (fields[3] as List).cast<String>(),
      usedForVariants: fields[4] as bool,
      isVisible: fields[5] as bool,
      position: fields[6] as int,
      createdAt: fields[7] as String,
      updatedAt: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductAttributeModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.attributeId)
      ..writeByte(3)
      ..write(obj.selectedValueIds)
      ..writeByte(4)
      ..write(obj.usedForVariants)
      ..writeByte(5)
      ..write(obj.isVisible)
      ..writeByte(6)
      ..write(obj.position)
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
      other is ProductAttributeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
