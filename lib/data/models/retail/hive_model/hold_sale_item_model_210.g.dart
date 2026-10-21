// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hold_sale_item_model_210.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HoldSaleItemModelAdapter extends TypeAdapter<HoldSaleItemModel> {
  @override
  final int typeId = 160;

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
      attributes: (fields[17] as Map?)?.cast<String, String>(),
      price: fields[8] as double,
      qty: fields[9] as double,
      total: fields[10] as double,
      barcode: fields[11] as String?,
      createdAt: fields[12] as String,
      gstRate: fields[13] as double?,
      taxableAmount: fields[14] as double?,
      gstAmount: fields[15] as double?,
      discountAmount: fields[16] as double?,
      originalPrice: fields[18] as double?,
      overrideReason: fields[19] as String?,
      overrideNote: fields[20] as String?,
      lineDiscountType: fields[21] as String?,
      lineDiscountValue: fields[22] as double?,
      lineDiscountAmount: fields[23] as double?,
      lineDiscountReason: fields[24] as String?,
      lineDiscountNote: fields[25] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HoldSaleItemModel obj) {
    writer
      ..writeByte(23)
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
      ..writeByte(17)
      ..write(obj.attributes)
      ..writeByte(8)
      ..write(obj.price)
      ..writeByte(9)
      ..write(obj.qty)
      ..writeByte(10)
      ..write(obj.total)
      ..writeByte(11)
      ..write(obj.barcode)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.gstRate)
      ..writeByte(14)
      ..write(obj.taxableAmount)
      ..writeByte(15)
      ..write(obj.gstAmount)
      ..writeByte(16)
      ..write(obj.discountAmount)
      ..writeByte(18)
      ..write(obj.originalPrice)
      ..writeByte(19)
      ..write(obj.overrideReason)
      ..writeByte(20)
      ..write(obj.overrideNote)
      ..writeByte(21)
      ..write(obj.lineDiscountType)
      ..writeByte(22)
      ..write(obj.lineDiscountValue)
      ..writeByte(23)
      ..write(obj.lineDiscountAmount)
      ..writeByte(24)
      ..write(obj.lineDiscountReason)
      ..writeByte(25)
      ..write(obj.lineDiscountNote);
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
