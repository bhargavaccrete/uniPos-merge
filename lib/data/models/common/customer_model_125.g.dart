// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_model_125.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 125;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      customerId: fields[0] as String,
      name: fields[1] as String?,
      phone: fields[2] as String?,
      email: fields[12] as String?,
      address: fields[13] as String?,
      gstNumber: fields[14] as String?,
      totalVisites: fields[3] as int,
      lastVisitAt: fields[4] as String?,
      lastorderType: fields[5] as String?,
      totalPurchaseAmount: fields[15] == null ? 0.0 : fields[15] as double,
      favoriteItems: fields[6] as String?,
      foodPrefrence: fields[7] as String?,
      notes: fields[8] as String?,
      loyaltyPoints: fields[9] as int,
      totalPointEarned: fields[16] == null ? 0 : fields[16] as int,
      totalPointRedeemed: fields[17] == null ? 0 : fields[17] as int,
      creditBalance: fields[18] == null ? 0.0 : fields[18] as double,
      creditLimit: fields[19] == null ? 0.0 : fields[19] as double,
      createdAt: fields[10] as String,
      updatedAt: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.customerId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(12)
      ..write(obj.email)
      ..writeByte(13)
      ..write(obj.address)
      ..writeByte(14)
      ..write(obj.gstNumber)
      ..writeByte(3)
      ..write(obj.totalVisites)
      ..writeByte(4)
      ..write(obj.lastVisitAt)
      ..writeByte(5)
      ..write(obj.lastorderType)
      ..writeByte(15)
      ..write(obj.totalPurchaseAmount)
      ..writeByte(6)
      ..write(obj.favoriteItems)
      ..writeByte(7)
      ..write(obj.foodPrefrence)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.loyaltyPoints)
      ..writeByte(16)
      ..write(obj.totalPointEarned)
      ..writeByte(17)
      ..write(obj.totalPointRedeemed)
      ..writeByte(18)
      ..write(obj.creditBalance)
      ..writeByte(19)
      ..write(obj.creditLimit)
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
      other is CustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
