// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_supplier_claim_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantSupplierClaimItemModelAdapter
    extends TypeAdapter<RestaurantSupplierClaimItemModel> {
  @override
  final int typeId = 146;

  @override
  RestaurantSupplierClaimItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestaurantSupplierClaimItemModel(
      claimItemId: fields[0] as String,
      claimId: fields[1] as String,
      grnItemId: fields[2] as String,
      itemId: fields[3] as String,
      itemName: fields[4] as String?,
      claimedQty: fields[5] as double,
      costPrice: fields[6] as double?,
      totalAmount: fields[7] as double?,
      remarks: fields[8] as String?,
      createdAt: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RestaurantSupplierClaimItemModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.claimItemId)
      ..writeByte(1)
      ..write(obj.claimId)
      ..writeByte(2)
      ..write(obj.grnItemId)
      ..writeByte(3)
      ..write(obj.itemId)
      ..writeByte(4)
      ..write(obj.itemName)
      ..writeByte(5)
      ..write(obj.claimedQty)
      ..writeByte(6)
      ..write(obj.costPrice)
      ..writeByte(7)
      ..write(obj.totalAmount)
      ..writeByte(8)
      ..write(obj.remarks)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantSupplierClaimItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
