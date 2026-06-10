// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_movement_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StockMovementModelAdapter extends TypeAdapter<StockMovementModel> {
  @override
  final int typeId = 126;

  @override
  StockMovementModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockMovementModel(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      itemId: fields[2] as String,
      variantId: fields[3] as String?,
      itemName: fields[4] as String,
      type: fields[5] as String,
      quantity: fields[6] as double,
      balanceAfter: fields[7] as double,
      reason: fields[8] as String,
      note: fields[9] as String?,
      unit: fields[10] as String,
      staffName: fields[11] as String,
      sessionId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StockMovementModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.variantId)
      ..writeByte(4)
      ..write(obj.itemName)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.quantity)
      ..writeByte(7)
      ..write(obj.balanceAfter)
      ..writeByte(8)
      ..write(obj.reason)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.unit)
      ..writeByte(11)
      ..write(obj.staffName)
      ..writeByte(12)
      ..write(obj.sessionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
