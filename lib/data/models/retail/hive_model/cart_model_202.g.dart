// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_model_202.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CartItemModelAdapter extends TypeAdapter<CartItemModel> {
  @override
  final int typeId = 152;

  @override
  CartItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CartItemModel(
      cartItemId: fields[0] as String,
      variantId: fields[1] as String,
      productId: fields[2] as String,
      productName: fields[3] as String,
      attributes: (fields[21] as Map?)?.cast<String, String>(),
      price: fields[7] as double,
      qty: fields[8] as double,
      total: fields[9] as double,
      barcode: fields[10] as String?,
      addedAt: fields[11] as String,
      gstRate: fields[12] as double?,
      taxableAmount: fields[13] as double?,
      gstAmount: fields[14] as double?,
      cgstAmount: fields[15] as double?,
      sgstAmount: fields[16] as double?,
      hsnCode: fields[17] as String?,
      discountAmount: fields[18] as double?,
      categoryName: fields[19] as String?,
      tabIndex: fields[20] as int?,
      originalPrice: fields[22] as double?,
      overrideReason: fields[23] as String?,
      overrideNote: fields[24] as String?,
      lineDiscountType: fields[25] as String?,
      lineDiscountValue: fields[26] as double?,
      lineDiscountAmount: fields[27] as double?,
      lineDiscountReason: fields[28] as String?,
      lineDiscountNote: fields[29] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CartItemModel obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.cartItemId)
      ..writeByte(1)
      ..write(obj.variantId)
      ..writeByte(2)
      ..write(obj.productId)
      ..writeByte(3)
      ..write(obj.productName)
      ..writeByte(7)
      ..write(obj.price)
      ..writeByte(8)
      ..write(obj.qty)
      ..writeByte(9)
      ..write(obj.total)
      ..writeByte(10)
      ..write(obj.barcode)
      ..writeByte(11)
      ..write(obj.addedAt)
      ..writeByte(12)
      ..write(obj.gstRate)
      ..writeByte(13)
      ..write(obj.taxableAmount)
      ..writeByte(14)
      ..write(obj.gstAmount)
      ..writeByte(15)
      ..write(obj.cgstAmount)
      ..writeByte(16)
      ..write(obj.sgstAmount)
      ..writeByte(17)
      ..write(obj.hsnCode)
      ..writeByte(18)
      ..write(obj.discountAmount)
      ..writeByte(19)
      ..write(obj.categoryName)
      ..writeByte(20)
      ..write(obj.tabIndex)
      ..writeByte(21)
      ..write(obj.attributes)
      ..writeByte(22)
      ..write(obj.originalPrice)
      ..writeByte(23)
      ..write(obj.overrideReason)
      ..writeByte(24)
      ..write(obj.overrideNote)
      ..writeByte(25)
      ..write(obj.lineDiscountType)
      ..writeByte(26)
      ..write(obj.lineDiscountValue)
      ..writeByte(27)
      ..write(obj.lineDiscountAmount)
      ..writeByte(28)
      ..write(obj.lineDiscountReason)
      ..writeByte(29)
      ..write(obj.lineDiscountNote);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
