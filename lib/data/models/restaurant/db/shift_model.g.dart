// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShiftModelAdapter extends TypeAdapter<ShiftModel> {
  @override
  final int typeId = 127;

  @override
  ShiftModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShiftModel(
      id: fields[0] as String,
      staffId: fields[1] as String,
      staffName: fields[2] as String,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime?,
      status: fields[5] as String,
      orderCount: fields[6] as int,
      totalSales: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ShiftModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.staffId)
      ..writeByte(2)
      ..write(obj.staffName)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.orderCount)
      ..writeByte(7)
      ..write(obj.totalSales);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
