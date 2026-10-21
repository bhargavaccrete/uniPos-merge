// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_ledger_entry_model_179.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SupplierLedgerEntryModelAdapter
    extends TypeAdapter<SupplierLedgerEntryModel> {
  @override
  final int typeId = 179;

  @override
  SupplierLedgerEntryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierLedgerEntryModel(
      entryId: fields[0] as String,
      supplierId: fields[1] as String,
      date: fields[2] as String,
      type: fields[3] as String,
      amount: fields[4] as double,
      balanceAfter: fields[5] as double,
      description: fields[6] as String,
      docNumber: fields[7] as String?,
      docId: fields[8] as String?,
      paymentMode: fields[9] as String?,
      referenceNo: fields[10] as String?,
      note: fields[11] as String?,
      createdAt: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierLedgerEntryModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.entryId)
      ..writeByte(1)
      ..write(obj.supplierId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.balanceAfter)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.docNumber)
      ..writeByte(8)
      ..write(obj.docId)
      ..writeByte(9)
      ..write(obj.paymentMode)
      ..writeByte(10)
      ..write(obj.referenceNo)
      ..writeByte(11)
      ..write(obj.note)
      ..writeByte(12)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierLedgerEntryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
