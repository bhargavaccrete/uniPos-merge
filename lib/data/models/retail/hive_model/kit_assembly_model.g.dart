// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kit_assembly_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RetailKitAssemblyModelAdapter
    extends TypeAdapter<RetailKitAssemblyModel> {
  @override
  final int typeId = 184;

  @override
  RetailKitAssemblyModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RetailKitAssemblyModel(
      id: fields[0] as String,
      bundleId: fields[1] as String,
      variantId: fields[2] as String,
      productName: fields[3] as String,
      batchQty: fields[4] as int,
      assembledTime: fields[5] as DateTime,
      assembledBy: fields[6] as String?,
      movementIds: (fields[7] as List).cast<String>(),
      isReversal: fields[8] == null ? false : fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RetailKitAssemblyModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bundleId)
      ..writeByte(2)
      ..write(obj.variantId)
      ..writeByte(3)
      ..write(obj.productName)
      ..writeByte(4)
      ..write(obj.batchQty)
      ..writeByte(5)
      ..write(obj.assembledTime)
      ..writeByte(6)
      ..write(obj.assembledBy)
      ..writeByte(7)
      ..write(obj.movementIds)
      ..writeByte(8)
      ..write(obj.isReversal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetailKitAssemblyModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
