// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model_200.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 200;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      productId: fields[0] as String,
      productName: fields[1] as String,
      brandName: fields[2] as String?,
      category: fields[3] as String,
      subCategory: fields[4] as String?,
      imagePath: fields[5] as String?,
      description: fields[6] as String?,
      hasVariants: fields[7] as bool,
      createdAt: fields[8] as String,
      updateAt: fields[9] as String,
      gstRate: fields[10] as double?,
      hsnCode: fields[11] as String?,
      productType: fields[12] as String,
      defaultPrice: fields[13] as double?,
      defaultMrp: fields[14] as double?,
      defaultCostPrice: fields[15] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.brandName)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.subCategory)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.hasVariants)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updateAt)
      ..writeByte(10)
      ..write(obj.gstRate)
      ..writeByte(11)
      ..write(obj.hsnCode)
      ..writeByte(12)
      ..write(obj.productType)
      ..writeByte(13)
      ..write(obj.defaultPrice)
      ..writeByte(14)
      ..write(obj.defaultMrp)
      ..writeByte(15)
      ..write(obj.defaultCostPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
