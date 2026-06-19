// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_cancellation_model_134.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemCancellationModelAdapter extends TypeAdapter<ItemCancellationModel> {
  @override
  final int typeId = 134;

  @override
  ItemCancellationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemCancellationModel(
      id: fields[0] as String,
      itemName: fields[1] as String,
      variantName: fields[2] as String?,
      quantity: fields[3] as int,
      amount: fields[4] as double,
      reason: fields[5] as String,
      orderId: fields[6] as String,
      billNumber: fields[7] as int?,
      kotNumber: fields[8] as int?,
      staffName: fields[9] as String?,
      timestamp: fields[10] as DateTime,
      sessionId: fields[11] as String?,
      orderType: fields[12] as String?,
      tableNo: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemCancellationModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemName)
      ..writeByte(2)
      ..write(obj.variantName)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.reason)
      ..writeByte(6)
      ..write(obj.orderId)
      ..writeByte(7)
      ..write(obj.billNumber)
      ..writeByte(8)
      ..write(obj.kotNumber)
      ..writeByte(9)
      ..write(obj.staffName)
      ..writeByte(10)
      ..write(obj.timestamp)
      ..writeByte(11)
      ..write(obj.sessionId)
      ..writeByte(12)
      ..write(obj.orderType)
      ..writeByte(13)
      ..write(obj.tableNo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemCancellationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
