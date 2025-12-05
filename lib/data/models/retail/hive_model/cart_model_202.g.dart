// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_model_202.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CartItemModelAdapter extends TypeAdapter<CartItemModel> {
  @override
  final int typeId = 202;

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
      size: fields[4] as String?,
      color: fields[5] as String?,
      weight: fields[6] as String?,
      price: fields[7] as double,
      qty: fields[8] as int,
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
    );
  }

  @override
  void write(BinaryWriter writer, CartItemModel obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.cartItemId)
      ..writeByte(1)
      ..write(obj.variantId)
      ..writeByte(2)
      ..write(obj.productId)
      ..writeByte(3)
      ..write(obj.productName)
      ..writeByte(4)
      ..write(obj.size)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.weight)
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
      ..write(obj.categoryName);
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
