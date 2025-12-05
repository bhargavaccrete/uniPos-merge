// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_model_207.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PurchaseModelAdapter extends TypeAdapter<PurchaseModel> {
  @override
  final int typeId = 207;

  @override
  PurchaseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseModel(
      purchaseId: fields[0] as String,
      supplierId: fields[1] as String,
      invoiceNumber: fields[2] as String?,
      totalItems: fields[3] as int,
      totalAmount: fields[4] as double,
      purchaseDate: fields[5] as String,
      createdAt: fields[6] as String,
      updatedAt: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.purchaseId)
      ..writeByte(1)
      ..write(obj.supplierId)
      ..writeByte(2)
      ..write(obj.invoiceNumber)
      ..writeByte(3)
      ..write(obj.totalItems)
      ..writeByte(4)
      ..write(obj.totalAmount)
      ..writeByte(5)
      ..write(obj.purchaseDate)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
