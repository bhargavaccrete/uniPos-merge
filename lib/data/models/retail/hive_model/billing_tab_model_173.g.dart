// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_tab_model_173.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillingTabModelAdapter extends TypeAdapter<BillingTabModel> {
  @override
  final int typeId = 173;

  @override
  BillingTabModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillingTabModel(
      id: fields[0] as String,
      name: fields[1] as String,
      items: (fields[2] as List).cast<CartItemModel>(),
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      customerName: fields[5] as String?,
      customerPhone: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BillingTabModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.customerName)
      ..writeByte(6)
      ..write(obj.customerPhone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingTabModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
