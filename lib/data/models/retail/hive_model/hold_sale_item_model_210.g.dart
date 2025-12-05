// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hold_sale_item_model_210.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HoldSaleItemModelAdapter extends TypeAdapter<HoldSaleItemModel> {
  @override
  final int typeId = 210;

  @override
  HoldSaleItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HoldSaleItemModel(
      holdSaleItemId: fields[0] as String,
      holdSaleId: fields[1] as String,
      variantId: fields[2] as String,
      productId: fields[3] as String,
      productName: fields[4] as String,
      size: fields[5] as String?,
      color: fields[6] as String?,
      weight: fields[7] as String?,
      price: fields[8] as double,
      qty: fields[9] as int,
      total: fields[10] as double,
      barcode: fields[11] as String?,
      createdAt: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HoldSaleItemModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.holdSaleItemId)
      ..writeByte(1)
      ..write(obj.holdSaleId)
      ..writeByte(2)
      ..write(obj.variantId)
      ..writeByte(3)
      ..write(obj.productId)
      ..writeByte(4)
      ..write(obj.productName)
      ..writeByte(5)
      ..write(obj.size)
      ..writeByte(6)
      ..write(obj.color)
      ..writeByte(7)
      ..write(obj.weight)
      ..writeByte(8)
      ..write(obj.price)
      ..writeByte(9)
      ..write(obj.qty)
      ..writeByte(10)
      ..write(obj.total)
      ..writeByte(11)
      ..write(obj.barcode)
      ..writeByte(12)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoldSaleItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
