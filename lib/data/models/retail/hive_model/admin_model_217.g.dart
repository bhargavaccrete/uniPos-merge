// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_model_217.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdminModelAdapter extends TypeAdapter<AdminModel> {
  @override
  final int typeId = 217;

  @override
  AdminModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdminModel(
      adminId: fields[0] as String,
      username: fields[1] as String,
      passwordHash: fields[2] as String,
      createdAt: fields[3] as String,
      updatedAt: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AdminModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.adminId)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.passwordHash)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
