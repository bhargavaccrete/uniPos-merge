// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_handover_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CashHandoverModelAdapter extends TypeAdapter<CashHandoverModel> {
  @override
  final int typeId = 129;

  @override
  CashHandoverModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CashHandoverModel(
      id: fields[0] as String,
      closedBy: fields[1] as String,
      closedAt: fields[2] as DateTime,
      closedAmount: fields[3] as double,
      closedNote: fields[4] as String?,
      receivedBy: fields[5] as String?,
      receivedAt: fields[6] as DateTime?,
      receivedAmount: fields[7] as double?,
      receivedNote: fields[8] as String?,
      status: fields[9] as String,
      variance: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, CashHandoverModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.closedBy)
      ..writeByte(2)
      ..write(obj.closedAt)
      ..writeByte(3)
      ..write(obj.closedAmount)
      ..writeByte(4)
      ..write(obj.closedNote)
      ..writeByte(5)
      ..write(obj.receivedBy)
      ..writeByte(6)
      ..write(obj.receivedAt)
      ..writeByte(7)
      ..write(obj.receivedAmount)
      ..writeByte(8)
      ..write(obj.receivedNote)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.variance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashHandoverModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
