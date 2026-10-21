// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppNotificationModelAdapter extends TypeAdapter<AppNotificationModel> {
  @override
  final int typeId = 133;

  @override
  AppNotificationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppNotificationModel(
      id: fields[0] as String,
      eventCode: fields[1] as String,
      subjectType: fields[2] as String?,
      subjectId: fields[3] as String?,
      data: fields[4] as String?,
      timestamp: fields[5] as DateTime,
      isRead: fields[6] as bool,
      isResolved: fields[7] as bool,
      source: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppNotificationModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.eventCode)
      ..writeByte(2)
      ..write(obj.subjectType)
      ..writeByte(3)
      ..write(obj.subjectId)
      ..writeByte(4)
      ..write(obj.data)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.isResolved)
      ..writeByte(8)
      ..write(obj.source);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotificationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
