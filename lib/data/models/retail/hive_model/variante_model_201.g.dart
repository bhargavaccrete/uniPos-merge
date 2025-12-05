// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variante_model_201.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VarianteModelAdapter extends TypeAdapter<VarianteModel> {
  @override
  final int typeId = 151;

  @override
  VarianteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VarianteModel(
      varianteId: fields[0] as String,
      productId: fields[1] as String,
      size: fields[2] as String?,
      color: fields[3] as String?,
      weight: fields[4] as String?,
      sku: fields[5] as String?,
      barcode: fields[6] as String?,
      mrp: fields[7] as double?,
      costPrice: fields[8] as double?,
      stockQty: fields[9] as int,
      minStock: fields[10] as int?,
      taxRate: fields[11] as double?,
      createdAt: fields[12] as String,
      updateAt: fields[13] as String?,
      customAttributes: (fields[14] as Map?)?.cast<String, String>(),
      sellingPrice: fields[15] as double?,
      hsnCode: fields[16] as String?,
      attributeValueIds: (fields[17] as Map?)?.cast<String, String>(),
      imagePath: fields[18] as String?,
      isDefault: fields[19] as bool,
      status: fields[20] as String,
    );
  }

  @override
  void write(BinaryWriter writer, VarianteModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.varianteId)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.size)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.weight)
      ..writeByte(5)
      ..write(obj.sku)
      ..writeByte(6)
      ..write(obj.barcode)
      ..writeByte(7)
      ..write(obj.mrp)
      ..writeByte(8)
      ..write(obj.costPrice)
      ..writeByte(9)
      ..write(obj.stockQty)
      ..writeByte(10)
      ..write(obj.minStock)
      ..writeByte(11)
      ..write(obj.taxRate)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.sellingPrice)
      ..writeByte(16)
      ..write(obj.hsnCode)
      ..writeByte(13)
      ..write(obj.updateAt)
      ..writeByte(14)
      ..write(obj.customAttributes)
      ..writeByte(17)
      ..write(obj.attributeValueIds)
      ..writeByte(18)
      ..write(obj.imagePath)
      ..writeByte(19)
      ..write(obj.isDefault)
      ..writeByte(20)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VarianteModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
