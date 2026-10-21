// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_claim_model_176.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SupplierClaimModelAdapter extends TypeAdapter<SupplierClaimModel> {
  @override
  final int typeId = 176;

  @override
  SupplierClaimModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierClaimModel(
      claimId: fields[0] as String,
      claimNumber: fields[1] as String,
      grnId: fields[2] as String,
      grnNumber: fields[3] as String,
      poId: fields[4] as String,
      poNumber: fields[5] as String,
      supplierId: fields[6] as String,
      supplierName: fields[7] as String?,
      claimDate: fields[8] as String,
      totalQty: fields[9] as double,
      totalAmount: fields[10] as double,
      status: fields[11] as String,
      resolutionNote: fields[12] as String?,
      resolvedAt: fields[13] as String?,
      notes: fields[14] as String?,
      createdAt: fields[15] as String,
      updatedAt: fields[16] as String,
      creditApplied: fields[17] as bool?,
      lossRecorded: fields[18] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierClaimModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.claimId)
      ..writeByte(1)
      ..write(obj.claimNumber)
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
      ..write(obj.claimDate)
      ..writeByte(9)
      ..write(obj.totalQty)
      ..writeByte(10)
      ..write(obj.totalAmount)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.resolutionNote)
      ..writeByte(13)
      ..write(obj.resolvedAt)
      ..writeByte(14)
      ..write(obj.notes)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt)
      ..writeByte(17)
      ..write(obj.creditApplied)
      ..writeByte(18)
      ..write(obj.lossRecorded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierClaimModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
