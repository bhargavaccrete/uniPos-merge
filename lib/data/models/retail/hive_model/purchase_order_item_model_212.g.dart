// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_order_item_model_212.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PurchaseOrderItemModelAdapter
    extends TypeAdapter<PurchaseOrderItemModel> {
  @override
  final int typeId = 212;

  @override
  PurchaseOrderItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseOrderItemModel(
      poItemId: fields[0] as String,
      poId: fields[1] as String,
      variantId: fields[2] as String,
      productId: fields[3] as String,
      productName: fields[4] as String?,
      variantInfo: fields[5] as String?,
      orderedQty: fields[6] as int,
      estimatedPrice: fields[7] as double?,
      estimatedTotal: fields[8] as double?,
      createdAt: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseOrderItemModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.poItemId)
      ..writeByte(1)
      ..write(obj.poId)
      ..writeByte(2)
      ..write(obj.variantId)
      ..writeByte(3)
      ..write(obj.productId)
      ..writeByte(4)
      ..write(obj.productName)
      ..writeByte(5)
      ..write(obj.variantInfo)
      ..writeByte(6)
      ..write(obj.orderedQty)
      ..writeByte(7)
      ..write(obj.estimatedPrice)
      ..writeByte(8)
      ..write(obj.estimatedTotal)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseOrderItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
