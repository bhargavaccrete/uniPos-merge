// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_details.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BusinessDetailsAdapter extends TypeAdapter<BusinessDetails> {
  @override
  final int typeId = 102;

  @override
  BusinessDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessDetails(
      businessTypeId: fields[0] as String?,
      businessTypeName: fields[1] as String?,
      storeName: fields[2] as String?,
      ownerName: fields[3] as String?,
      phone: fields[4] as String?,
      email: fields[5] as String?,
      address: fields[6] as String?,
      gstin: fields[7] as String?,
      pan: fields[8] as String?,
      city: fields[9] as String?,
      state: fields[10] as String?,
      country: fields[11] as String?,
      pincode: fields[12] as String?,
      logo: fields[13] as String?,
      isSetupComplete: fields[14] as bool,
      createdAt: fields[15] as DateTime?,
      updatedAt: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessDetails obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.businessTypeId)
      ..writeByte(1)
      ..write(obj.businessTypeName)
      ..writeByte(2)
      ..write(obj.storeName)
      ..writeByte(3)
      ..write(obj.ownerName)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.address)
      ..writeByte(7)
      ..write(obj.gstin)
      ..writeByte(8)
      ..write(obj.pan)
      ..writeByte(9)
      ..write(obj.city)
      ..writeByte(10)
      ..write(obj.state)
      ..writeByte(11)
      ..write(obj.country)
      ..writeByte(12)
      ..write(obj.pincode)
      ..writeByte(13)
      ..write(obj.logo)
      ..writeByte(14)
      ..write(obj.isSetupComplete)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessDetailsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
