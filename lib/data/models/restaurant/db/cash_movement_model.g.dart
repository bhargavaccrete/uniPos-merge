// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_movement_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CashMovementModelAdapter extends TypeAdapter<CashMovementModel> {
  @override
  final int typeId = 128;

  @override
  CashMovementModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CashMovementModel(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      type: fields[2] as String,
      amount: fields[3] as double,
      reason: fields[4] as String,
      note: fields[5] as String?,
      staffName: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CashMovementModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.reason)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.staffName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashMovementModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
