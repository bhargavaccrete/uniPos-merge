// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hold_sale_model_209.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HoldSaleModelAdapter extends TypeAdapter<HoldSaleModel> {
  @override
  final int typeId = 159;

  @override
  HoldSaleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HoldSaleModel(
      holdSaleId: fields[0] as String,
      customerId: fields[1] as String?,
      customerName: fields[2] as String?,
      note: fields[3] as String?,
      totalItems: fields[4] as int,
      subtotal: fields[5] as double,
      createdAt: fields[6] as String,
      updatedAt: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HoldSaleModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.holdSaleId)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.customerName)
      ..writeByte(3)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.totalItems)
      ..writeByte(5)
      ..write(obj.subtotal)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoldSaleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
