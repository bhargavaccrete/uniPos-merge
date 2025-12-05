// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_item_model_204.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleItemModelAdapter extends TypeAdapter<SaleItemModel> {
  @override
  final int typeId = 154;

  @override
  SaleItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleItemModel(
      saleItemId: fields[0] as String,
      saleId: fields[1] as String,
      varianteId: fields[2] as String,
      productId: fields[3] as String,
      productName: fields[4] as String?,
      size: fields[5] as String?,
      color: fields[6] as String?,
      price: fields[7] as double,
      qty: fields[8] as int,
      total: fields[9] as double,
      discountAmount: fields[10] as double?,
      taxAmount: fields[11] as double?,
      barcode: fields[12] as String?,
      gstRate: fields[13] as double?,
      taxableAmount: fields[14] as double?,
      gstAmount: fields[15] as double?,
      hsnCode: fields[16] as String?,
      cgstAmount: fields[17] as double?,
      sgstAmount: fields[18] as double?,
      weight: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SaleItemModel obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.saleItemId)
      ..writeByte(1)
      ..write(obj.saleId)
      ..writeByte(2)
      ..write(obj.varianteId)
      ..writeByte(3)
      ..write(obj.productId)
      ..writeByte(4)
      ..write(obj.productName)
      ..writeByte(5)
      ..write(obj.size)
      ..writeByte(6)
      ..write(obj.color)
      ..writeByte(7)
      ..write(obj.price)
      ..writeByte(8)
      ..write(obj.qty)
      ..writeByte(9)
      ..write(obj.total)
      ..writeByte(10)
      ..write(obj.discountAmount)
      ..writeByte(11)
      ..write(obj.taxAmount)
      ..writeByte(12)
      ..write(obj.barcode)
      ..writeByte(13)
      ..write(obj.gstRate)
      ..writeByte(14)
      ..write(obj.taxableAmount)
      ..writeByte(15)
      ..write(obj.gstAmount)
      ..writeByte(16)
      ..write(obj.hsnCode)
      ..writeByte(17)
      ..write(obj.cgstAmount)
      ..writeByte(18)
      ..write(obj.sgstAmount)
      ..writeByte(19)
      ..write(obj.weight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
