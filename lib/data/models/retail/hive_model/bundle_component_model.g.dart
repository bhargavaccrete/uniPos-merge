// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bundle_component_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BundleComponentModelAdapter extends TypeAdapter<BundleComponentModel> {
  @override
  final int typeId = 183;

  @override
  BundleComponentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BundleComponentModel(
      componentVariantId: fields[0] as String,
      quantity: fields[1] as int,
      note: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BundleComponentModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.componentVariantId)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BundleComponentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
