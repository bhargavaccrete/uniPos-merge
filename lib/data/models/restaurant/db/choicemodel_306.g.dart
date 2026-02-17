// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'choicemodel_306.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChoicesModelAdapter extends TypeAdapter<ChoicesModel> {
  @override
  final int typeId = 106;

  @override
  ChoicesModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChoicesModel(
      id: fields[0] as String,
      name: fields[1] as String,
      choiceOption: (fields[2] as List).cast<ChoiceOption>(),
      createdTime: fields[3] as DateTime?,
      lastEditedTime: fields[4] as DateTime?,
      editedBy: fields[5] as String?,
      editCount: fields[6] as int,
      allowMultipleSelection: fields[7] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, ChoicesModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.choiceOption)
      ..writeByte(3)
      ..write(obj.createdTime)
      ..writeByte(4)
      ..write(obj.lastEditedTime)
      ..writeByte(5)
      ..write(obj.editedBy)
      ..writeByte(6)
      ..write(obj.editCount)
      ..writeByte(7)
      ..write(obj.allowMultipleSelection);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChoicesModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
