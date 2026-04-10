// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceModelAdapter extends TypeAdapter<AttendanceModel> {
  @override
  final int typeId = 132;

  @override
  AttendanceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceModel(
      id: fields[0] as String,
      staffName: fields[1] as String,
      staffRole: fields[2] as String,
      clockIn: fields[3] as DateTime,
      clockOut: fields[4] as DateTime?,
      totalMinutes: fields[5] as int?,
      date: fields[6] as String,
      sessionId: fields[7] as String?,
      breakStartTime: fields[8] as DateTime?,
      breakTotalMinutes: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.staffName)
      ..writeByte(2)
      ..write(obj.staffRole)
      ..writeByte(3)
      ..write(obj.clockIn)
      ..writeByte(4)
      ..write(obj.clockOut)
      ..writeByte(5)
      ..write(obj.totalMinutes)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.sessionId)
      ..writeByte(8)
      ..write(obj.breakStartTime)
      ..writeByte(9)
      ..write(obj.breakTotalMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
