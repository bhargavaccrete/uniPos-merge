// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expensemodel_315.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategory> {
  @override
  final int typeId = 315;

  @override
  ExpenseCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      isEnabled: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseCategory obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
