// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_grn_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantGRNItemModelAdapter
    extends TypeAdapter<RestaurantGRNItemModel> {
  @override
  final int typeId = 142;

  @override
  RestaurantGRNItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestaurantGRNItemModel(
      grnItemId: fields[0] as String,
      grnId: fields[1] as String,
      poItemId: fields[2] as String,
      itemId: fields[3] as String,
      itemName: fields[4] as String?,
      orderedQty: fields[5] as double,
      receivedQty: fields[6] as double,
      acceptedQty: fields[7] as double,
      damagedQty: fields[8] as double?,
      costPrice: fields[9] as double?,
      totalAmount: fields[10] as double?,
      remarks: fields[11] as String?,
      createdAt: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RestaurantGRNItemModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.grnItemId)
      ..writeByte(1)
      ..write(obj.grnId)
      ..writeByte(2)
      ..write(obj.poItemId)
      ..writeByte(3)
      ..write(obj.itemId)
      ..writeByte(4)
      ..write(obj.itemName)
      ..writeByte(5)
      ..write(obj.orderedQty)
      ..writeByte(6)
      ..write(obj.receivedQty)
      ..writeByte(7)
      ..write(obj.acceptedQty)
      ..writeByte(8)
      ..write(obj.damagedQty)
      ..writeByte(9)
      ..write(obj.costPrice)
      ..writeByte(10)
      ..write(obj.totalAmount)
      ..writeByte(11)
      ..write(obj.remarks)
      ..writeByte(12)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantGRNItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
