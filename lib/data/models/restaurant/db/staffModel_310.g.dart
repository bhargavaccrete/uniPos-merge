// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staffModel_310.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StaffModelAdapter extends TypeAdapter<StaffModel> {
  @override
  final int typeId = 310;

  @override
  StaffModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StaffModel(
      id: fields[0] as String,
      userName: fields[1] as String,
      firstName: fields[2] as String,
      lastName: fields[3] as String,
      isCashier: fields[4] as String,
      mobileNo: fields[5] as String,
      emailId: fields[6] as String,
      pinNo: fields[7] as String,
      createdAt: fields[8] as DateTime,
      isActive: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, StaffModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userName)
      ..writeByte(2)
      ..write(obj.firstName)
      ..writeByte(3)
      ..write(obj.lastName)
      ..writeByte(4)
      ..write(obj.isCashier)
      ..writeByte(5)
      ..write(obj.mobileNo)
      ..writeByte(6)
      ..write(obj.emailId)
      ..writeByte(7)
      ..write(obj.pinNo)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
