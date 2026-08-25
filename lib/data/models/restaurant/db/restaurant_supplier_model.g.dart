// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_supplier_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantSupplierModelAdapter
    extends TypeAdapter<RestaurantSupplierModel> {
  @override
  final int typeId = 138;

  @override
  RestaurantSupplierModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestaurantSupplierModel(
      supplierId: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String?,
      address: fields[3] as String?,
      gstNumber: fields[4] as String?,
      currentBalance: fields[5] as double,
      createdAt: fields[6] as String,
      updatedAt: fields[7] as String,
      openingBalance: fields[8] == null ? 0.0 : fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RestaurantSupplierModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.supplierId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.gstNumber)
      ..writeByte(5)
      ..write(obj.currentBalance)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.openingBalance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantSupplierModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
