// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_order_model_211.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PurchaseOrderModelAdapter extends TypeAdapter<PurchaseOrderModel> {
  @override
  final int typeId = 161;

  @override
  PurchaseOrderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseOrderModel(
      poId: fields[0] as String,
      poNumber: fields[1] as String,
      supplierId: fields[2] as String,
      supplierName: fields[3] as String?,
      expectedDeliveryDate: fields[4] as String,
      totalItems: fields[5] as int,
      estimatedTotal: fields[6] as double,
      status: fields[7] as String,
      notes: fields[8] as String?,
      createdAt: fields[9] as String,
      updatedAt: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseOrderModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.poId)
      ..writeByte(1)
      ..write(obj.poNumber)
      ..writeByte(2)
      ..write(obj.supplierId)
      ..writeByte(3)
      ..write(obj.supplierName)
      ..writeByte(4)
      ..write(obj.expectedDeliveryDate)
      ..writeByte(5)
      ..write(obj.totalItems)
      ..writeByte(6)
      ..write(obj.estimatedTotal)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseOrderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
