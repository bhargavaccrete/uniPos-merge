// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantSessionModelAdapter
    extends TypeAdapter<RestaurantSessionModel> {
  @override
  final int typeId = 131;

  @override
  RestaurantSessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestaurantSessionModel(
      sessionId: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      openingCash: fields[3] as double,
      closingCash: fields[4] as double?,
      isClosed: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RestaurantSessionModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.openingCash)
      ..writeByte(4)
      ..write(obj.closingCash)
      ..writeByte(5)
      ..write(obj.isClosed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantSessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
