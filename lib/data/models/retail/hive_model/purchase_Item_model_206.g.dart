// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_Item_model_206.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PurchaseItemModelAdapter extends TypeAdapter<PurchaseItemModel> {
  @override
  final int typeId = 156;

  @override
  PurchaseItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseItemModel(
      purchaseItemId: fields[0] as String,
      purchaseId: fields[1] as String,
      variantId: fields[2] as String,
      productId: fields[3] as String,
      quantity: fields[4] as int,
      costPrice: fields[5] as double,
      mrp: fields[6] as double,
      total: fields[7] as double,
      createdAt: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseItemModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.purchaseItemId)
      ..writeByte(1)
      ..write(obj.purchaseId)
      ..writeByte(2)
      ..write(obj.variantId)
      ..writeByte(3)
      ..write(obj.productId)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.costPrice)
      ..writeByte(6)
      ..write(obj.mrp)
      ..writeByte(7)
      ..write(obj.total)
      ..writeByte(8)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
