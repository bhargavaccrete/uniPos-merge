// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_return_model_174.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PurchaseReturnModelAdapter extends TypeAdapter<PurchaseReturnModel> {
  @override
  final int typeId = 174;

  @override
  PurchaseReturnModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseReturnModel(
      returnId: fields[0] as String,
      returnNumber: fields[1] as String,
      grnId: fields[2] as String,
      grnNumber: fields[3] as String,
      poId: fields[4] as String,
      poNumber: fields[5] as String,
      supplierId: fields[6] as String,
      supplierName: fields[7] as String?,
      returnDate: fields[8] as String,
      totalQty: fields[9] as int,
      totalAmount: fields[10] as double,
      status: fields[11] as String,
      creditNoteNumber: fields[12] as String?,
      creditNoteDate: fields[13] as String?,
      creditNoteAmount: fields[14] as double?,
      notes: fields[15] as String?,
      createdAt: fields[16] as String,
      updatedAt: fields[17] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseReturnModel obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.returnId)
      ..writeByte(1)
      ..write(obj.returnNumber)
      ..writeByte(2)
      ..write(obj.grnId)
      ..writeByte(3)
      ..write(obj.grnNumber)
      ..writeByte(4)
      ..write(obj.poId)
      ..writeByte(5)
      ..write(obj.poNumber)
      ..writeByte(6)
      ..write(obj.supplierId)
      ..writeByte(7)
      ..write(obj.supplierName)
      ..writeByte(8)
      ..write(obj.returnDate)
      ..writeByte(9)
      ..write(obj.totalQty)
      ..writeByte(10)
      ..write(obj.totalAmount)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.creditNoteNumber)
      ..writeByte(13)
      ..write(obj.creditNoteDate)
      ..writeByte(14)
      ..write(obj.creditNoteAmount)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseReturnModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
