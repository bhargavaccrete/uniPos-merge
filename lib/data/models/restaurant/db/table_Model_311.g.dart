// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_Model_311.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TableModelAdapter extends TypeAdapter<TableModel> {
  @override
  final int typeId = 311;

  @override
  TableModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TableModel(
      id: fields[0] as String,
      status: fields[1] as String,
      currentOrderTotal: fields[2] as double?,
      currentOrderId: fields[3] as String?,
      timeStamp: fields[4] as String?,
      tableCapacity: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TableModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.currentOrderTotal)
      ..writeByte(3)
      ..write(obj.currentOrderId)
      ..writeByte(4)
      ..write(obj.timeStamp)
      ..writeByte(5)
      ..write(obj.tableCapacity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
