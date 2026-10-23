// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_production_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeProductionModelAdapter extends TypeAdapter<RecipeProductionModel> {
  @override
  final int typeId = 137;

  @override
  RecipeProductionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeProductionModel(
      id: fields[0] as String,
      recipeId: fields[1] as String,
      itemId: fields[2] as String,
      itemName: fields[3] as String,
      batchQty: fields[4] as double,
      producedTime: fields[5] as DateTime,
      producedBy: fields[6] as String?,
      movementIds: (fields[7] as List).cast<String>(),
      actualQty: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeProductionModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.recipeId)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.itemName)
      ..writeByte(4)
      ..write(obj.batchQty)
      ..writeByte(5)
      ..write(obj.producedTime)
      ..writeByte(6)
      ..write(obj.producedBy)
      ..writeByte(7)
      ..write(obj.movementIds)
      ..writeByte(8)
      ..write(obj.actualQty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeProductionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
