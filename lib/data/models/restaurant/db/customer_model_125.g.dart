// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_model_125.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantCustomerAdapter extends TypeAdapter<RestaurantCustomer> {
  @override
  final int typeId = 125;

  @override
  RestaurantCustomer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestaurantCustomer(
      customerId: fields[0] as String,
      name: fields[1] as String?,
      phone: fields[2] as String?,
      totalVisites: fields[3] as int,
      lastVisitAt: fields[4] as String?,
      lastorderType: fields[5] as String?,
      favoriteItems: fields[6] as String?,
      foodPrefrence: fields[7] as String?,
      notes: fields[8] as String?,
      loyaltyPoints: fields[9] as int,
      createdAt: fields[10] as String,
      updatedAt: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RestaurantCustomer obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.customerId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.totalVisites)
      ..writeByte(4)
      ..write(obj.lastVisitAt)
      ..writeByte(5)
      ..write(obj.lastorderType)
      ..writeByte(6)
      ..write(obj.favoriteItems)
      ..writeByte(7)
      ..write(obj.foodPrefrence)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.loyaltyPoints)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantCustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
