// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bundle_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RetailBundleModelAdapter extends TypeAdapter<RetailBundleModel> {
  @override
  final int typeId = 182;

  @override
  RetailBundleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RetailBundleModel(
      id: fields[0] as String,
      productId: fields[1] as String,
      variantId: fields[2] as String,
      components: (fields[3] as List).cast<BundleComponentModel>(),
      createdAt: fields[4] as String,
      updatedAt: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RetailBundleModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.variantId)
      ..writeByte(3)
      ..write(obj.components)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetailBundleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
