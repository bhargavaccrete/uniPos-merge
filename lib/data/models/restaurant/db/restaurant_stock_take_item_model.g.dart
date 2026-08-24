// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_stock_take_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantStockTakeItemModelAdapter
    extends TypeAdapter<RestaurantStockTakeItemModel> {
  @override
  final int typeId = 149;

  @override
  RestaurantStockTakeItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestaurantStockTakeItemModel(
      takeItemId: fields[0] as String,
      takeId: fields[1] as String,
      itemId: fields[2] as String,
      itemName: fields[3] as String?,
      systemQty: fields[4] as double,
      countedQty: fields[5] as double,
      costPrice: fields[6] as double?,
      countedAt: fields[7] as String,
      appliedQty: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, RestaurantStockTakeItemModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.takeItemId)
      ..writeByte(1)
      ..write(obj.takeId)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.itemName)
      ..writeByte(4)
      ..write(obj.systemQty)
      ..writeByte(5)
      ..write(obj.countedQty)
      ..writeByte(6)
      ..write(obj.costPrice)
      ..writeByte(7)
      ..write(obj.countedAt)
      ..writeByte(8)
      ..write(obj.appliedQty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantStockTakeItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
