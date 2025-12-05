// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credit_payment_model_218.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CreditPaymentModelAdapter extends TypeAdapter<CreditPaymentModel> {
  @override
  final int typeId = 168;

  @override
  CreditPaymentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CreditPaymentModel(
      paymentId: fields[0] as String,
      customerId: fields[1] as String,
      saleId: fields[2] as String,
      amount: fields[3] as double,
      paymentMode: fields[4] as String,
      date: fields[5] as String,
      referenceId: fields[6] as String?,
      note: fields[7] as String?,
      createdAt: fields[8] as String,
      balanceBefore: fields[9] as double,
      balanceAfter: fields[10] as double,
      isWriteOff: fields[11] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, CreditPaymentModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.paymentId)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.saleId)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.paymentMode)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.referenceId)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.balanceBefore)
      ..writeByte(10)
      ..write(obj.balanceAfter)
      ..writeByte(11)
      ..write(obj.isWriteOff);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreditPaymentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
