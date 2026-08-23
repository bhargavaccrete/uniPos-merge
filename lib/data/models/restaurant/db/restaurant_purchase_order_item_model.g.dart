// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_purchase_order_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantPurchaseOrderItemModelAdapter
    extends TypeAdapter<RestaurantPurchaseOrderItemModel> {
  @override
  final int typeId = 140;

  @override
  RestaurantPurchaseOrderItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestaurantPurchaseOrderItemModel(
      poItemId: fields[0] as String,
      poId: fields[1] as String,
      itemId: fields[2] as String,
      itemName: fields[3] as String?,
      orderedQty: fields[4] as double,
      estimatedPrice: fields[5] as double?,
      estimatedTotal: fields[6] as double?,
      createdAt: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RestaurantPurchaseOrderItemModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.poItemId)
      ..writeByte(1)
      ..write(obj.poId)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.itemName)
      ..writeByte(4)
      ..write(obj.orderedQty)
      ..writeByte(5)
      ..write(obj.estimatedPrice)
      ..writeByte(6)
      ..write(obj.estimatedTotal)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantPurchaseOrderItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
