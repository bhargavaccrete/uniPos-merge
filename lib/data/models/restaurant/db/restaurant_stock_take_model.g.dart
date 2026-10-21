// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_stock_take_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantStockTakeModelAdapter
    extends TypeAdapter<RestaurantStockTakeModel> {
  @override
  final int typeId = 148;

  @override
  RestaurantStockTakeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestaurantStockTakeModel(
      takeId: fields[0] as String,
      takeNumber: fields[1] as String,
      status: fields[2] as String,
      scopeNote: fields[3] as String?,
      varianceReason: fields[4] as String?,
      note: fields[5] as String?,
      countedBy: fields[6] as String,
      createdAt: fields[7] as String,
      updatedAt: fields[8] as String,
      completedAt: fields[9] as String?,
      committedLineCount: fields[10] as int?,
      committedNetQty: fields[11] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, RestaurantStockTakeModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.takeId)
      ..writeByte(1)
      ..write(obj.takeNumber)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.scopeNote)
      ..writeByte(4)
      ..write(obj.varianceReason)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.countedBy)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.completedAt)
      ..writeByte(10)
      ..write(obj.committedLineCount)
      ..writeByte(11)
      ..write(obj.committedNetQty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantStockTakeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
