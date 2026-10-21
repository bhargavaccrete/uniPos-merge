// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_claim_item_model_177.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SupplierClaimItemModelAdapter
    extends TypeAdapter<SupplierClaimItemModel> {
  @override
  final int typeId = 177;

  @override
  SupplierClaimItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierClaimItemModel(
      claimItemId: fields[0] as String,
      claimId: fields[1] as String,
      grnItemId: fields[2] as String,
      variantId: fields[3] as String,
      productId: fields[4] as String,
      productName: fields[5] as String?,
      variantInfo: fields[6] as String?,
      claimedQty: fields[7] as double,
      costPrice: fields[8] as double?,
      totalAmount: fields[9] as double?,
      remarks: fields[10] as String?,
      createdAt: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierClaimItemModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.claimItemId)
      ..writeByte(1)
      ..write(obj.claimId)
      ..writeByte(2)
      ..write(obj.grnItemId)
      ..writeByte(3)
      ..write(obj.variantId)
      ..writeByte(4)
      ..write(obj.productId)
      ..writeByte(5)
      ..write(obj.productName)
      ..writeByte(6)
      ..write(obj.variantInfo)
      ..writeByte(7)
      ..write(obj.claimedQty)
      ..writeByte(8)
      ..write(obj.costPrice)
      ..writeByte(9)
      ..write(obj.totalAmount)
      ..writeByte(10)
      ..write(obj.remarks)
      ..writeByte(11)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierClaimItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
