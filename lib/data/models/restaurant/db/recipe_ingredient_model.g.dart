// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_ingredient_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeIngredientModelAdapter extends TypeAdapter<RecipeIngredientModel> {
  @override
  final int typeId = 136;

  @override
  RecipeIngredientModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeIngredientModel(
      ingredientItemId: fields[0] as String,
      quantity: fields[1] as double,
      unit: fields[2] as String?,
      wastagePercent: fields[3] == null ? 0.0 : fields[3] as double,
      note: fields[4] as String?,
      conversionFactor: fields[5] == null ? 1.0 : fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeIngredientModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.ingredientItemId)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.wastagePercent)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.conversionFactor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredientModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
