// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_printer_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedPrinterModelAdapter extends TypeAdapter<SavedPrinterModel> {
  @override
  final int typeId = 130;

  @override
  SavedPrinterModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedPrinterModel(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      address: fields[3] as String,
      paperSize: fields[4] as int,
      role: fields[5] as String,
      isDefault: fields[6] as bool,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedPrinterModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.paperSize)
      ..writeByte(5)
      ..write(obj.role)
      ..writeByte(6)
      ..write(obj.isDefault)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedPrinterModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
