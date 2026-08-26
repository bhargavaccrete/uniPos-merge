// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_take_item_model_181.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StockTakeItemModelAdapter extends TypeAdapter<StockTakeItemModel> {
  @override
  final int typeId = 181;

  @override
  StockTakeItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockTakeItemModel(
      takeItemId: fields[0] as String,
      takeId: fields[1] as String,
      variantId: fields[2] as String,
      productId: fields[3] as String,
      productName: fields[4] as String?,
      variantInfo: fields[5] as String?,
      systemQty: fields[6] as double,
      countedQty: fields[7] as double,
      costPrice: fields[8] as double?,
      countedAt: fields[9] as String,
      appliedQty: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, StockTakeItemModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.takeItemId)
      ..writeByte(1)
      ..write(obj.takeId)
      ..writeByte(2)
      ..write(obj.variantId)
      ..writeByte(3)
      ..write(obj.productId)
      ..writeByte(4)
      ..write(obj.productName)
      ..writeByte(5)
      ..write(obj.variantInfo)
      ..writeByte(6)
      ..write(obj.systemQty)
      ..writeByte(7)
      ..write(obj.countedQty)
      ..writeByte(8)
      ..write(obj.costPrice)
      ..writeByte(9)
      ..write(obj.countedAt)
      ..writeByte(10)
      ..write(obj.appliedQty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockTakeItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
