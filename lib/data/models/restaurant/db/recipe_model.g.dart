// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeModelAdapter extends TypeAdapter<RecipeModel> {
  @override
  final int typeId = 135;

  @override
  RecipeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeModel(
      id: fields[0] as String,
      itemId: fields[1] as String,
      yieldQty: fields[2] as double,
      yieldUnit: fields[3] as String?,
      ingredients: (fields[4] as List).cast<RecipeIngredientModel>(),
      prepInstructions: fields[5] as String?,
      createdTime: fields[6] as DateTime?,
      lastEditedTime: fields[7] as DateTime?,
      editedBy: fields[8] as String?,
      editCount: fields[9] == null ? 0 : fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.yieldQty)
      ..writeByte(3)
      ..write(obj.yieldUnit)
      ..writeByte(4)
      ..write(obj.ingredients)
      ..writeByte(5)
      ..write(obj.prepInstructions)
      ..writeByte(6)
      ..write(obj.createdTime)
      ..writeByte(7)
      ..write(obj.lastEditedTime)
      ..writeByte(8)
      ..write(obj.editedBy)
      ..writeByte(9)
      ..write(obj.editCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
