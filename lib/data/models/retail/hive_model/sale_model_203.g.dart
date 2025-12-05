// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_model_203.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleModelAdapter extends TypeAdapter<SaleModel> {
  @override
  final int typeId = 153;

  @override
  SaleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleModel(
      saleId: fields[0] as String,
      customerId: fields[1] as String?,
      totalItems: fields[2] as int,
      subtotal: fields[3] as double,
      discountAmount: fields[4] as double,
      taxAmount: fields[5] as double,
      totalAmount: fields[6] as double,
      paymentType: fields[7] as String,
      date: fields[8] as String,
      createdAt: fields[9] as String,
      updatedAt: fields[10] as String,
      isReturn: fields[11] == null ? false : fields[11] as bool?,
      originalSaleId: fields[12] as String?,
      totalTaxableAmount: fields[13] as double?,
      totalGstAmount: fields[14] as double?,
      totalCgstAmount: fields[15] as double?,
      totalSgstAmount: fields[16] as double?,
      grandTotal: fields[17] as double?,
      paymentListJson: fields[18] as String?,
      changeReturn: fields[19] as double?,
      totalPaid: fields[20] as double?,
      isSplitPayment: fields[21] as bool?,
      paidAmount: fields[22] == null ? 0.0 : fields[22] as double?,
      dueAmount: fields[23] == null ? 0.0 : fields[23] as double?,
      status: fields[24] == null ? 'paid' : fields[24] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SaleModel obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.saleId)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.totalItems)
      ..writeByte(3)
      ..write(obj.subtotal)
      ..writeByte(4)
      ..write(obj.discountAmount)
      ..writeByte(5)
      ..write(obj.taxAmount)
      ..writeByte(6)
      ..write(obj.totalAmount)
      ..writeByte(7)
      ..write(obj.paymentType)
      ..writeByte(8)
      ..write(obj.date)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.isReturn)
      ..writeByte(12)
      ..write(obj.originalSaleId)
      ..writeByte(13)
      ..write(obj.totalTaxableAmount)
      ..writeByte(14)
      ..write(obj.totalGstAmount)
      ..writeByte(15)
      ..write(obj.totalCgstAmount)
      ..writeByte(16)
      ..write(obj.totalSgstAmount)
      ..writeByte(17)
      ..write(obj.grandTotal)
      ..writeByte(18)
      ..write(obj.paymentListJson)
      ..writeByte(19)
      ..write(obj.changeReturn)
      ..writeByte(20)
      ..write(obj.totalPaid)
      ..writeByte(21)
      ..write(obj.isSplitPayment)
      ..writeByte(22)
      ..write(obj.paidAmount)
      ..writeByte(23)
      ..write(obj.dueAmount)
      ..writeByte(24)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
