// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_loss_model_178.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryLossModelAdapter extends TypeAdapter<InventoryLossModel> {
  @override
  final int typeId = 178;

  @override
  InventoryLossModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryLossModel(
      lossId: fields[0] as String,
      lossNumber: fields[1] as String,
      source: fields[2] as String,
      grnId: fields[3] as String?,
      grnNumber: fields[4] as String?,
      grnItemId: fields[5] as String?,
      poId: fields[6] as String?,
      supplierId: fields[7] as String?,
      supplierName: fields[8] as String?,
      variantId: fields[9] as String,
      productId: fields[10] as String,
      productName: fields[11] as String?,
      variantInfo: fields[12] as String?,
      quantity: fields[13] as double,
      costPrice: fields[14] as double?,
      lossValue: fields[15] as double,
      reason: fields[16] as String,
      note: fields[17] as String?,
      recordedAt: fields[18] as String,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryLossModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.lossId)
      ..writeByte(1)
      ..write(obj.lossNumber)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.grnId)
      ..writeByte(4)
      ..write(obj.grnNumber)
      ..writeByte(5)
      ..write(obj.grnItemId)
      ..writeByte(6)
      ..write(obj.poId)
      ..writeByte(7)
      ..write(obj.supplierId)
      ..writeByte(8)
      ..write(obj.supplierName)
      ..writeByte(9)
      ..write(obj.variantId)
      ..writeByte(10)
      ..write(obj.productId)
      ..writeByte(11)
      ..write(obj.productName)
      ..writeByte(12)
      ..write(obj.variantInfo)
      ..writeByte(13)
      ..write(obj.quantity)
      ..writeByte(14)
      ..write(obj.costPrice)
      ..writeByte(15)
      ..write(obj.lossValue)
      ..writeByte(16)
      ..write(obj.reason)
      ..writeByte(17)
      ..write(obj.note)
      ..writeByte(18)
      ..write(obj.recordedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryLossModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
