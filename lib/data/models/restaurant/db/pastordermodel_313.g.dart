// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pastordermodel_313.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PastOrderModelAdapter extends TypeAdapter<PastOrderModel> {
  @override
  final int typeId = 113;

  @override
  PastOrderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PastOrderModel(
      id: fields[0] as String,
      customerName: fields[1] as String,
      totalPrice: fields[2] as double,
      items: (fields[3] as List).cast<CartItem>(),
      orderAt: fields[4] as DateTime?,
      kotNumber: fields[5] as int?,
      orderType: fields[6] as String?,
      paymentmode: fields[7] as String?,
      remark: fields[8] as String?,
      subTotal: fields[9] as double?,
      Discount: fields[10] as double?,
      gstRate: fields[11] as double?,
      gstAmount: fields[12] as double?,
      isRefunded: fields[13] as bool?,
      refundReason: fields[14] as String?,
      refundAmount: fields[15] as double?,
      refundedAt: fields[16] as DateTime?,
      orderStatus: fields[17] as String?,
      kotNumbers: (fields[18] as List).cast<int>(),
      kotBoundaries: (fields[19] as List).cast<int>(),
      billNumber: fields[20] as int?,
      paymentListJson: fields[21] as String?,
      isSplitPayment: fields[22] as bool?,
      totalPaid: fields[23] as double?,
      changeReturn: fields[24] as double?,
      isTaxInclusive: fields[25] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, PastOrderModel obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerName)
      ..writeByte(2)
      ..write(obj.totalPrice)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.orderAt)
      ..writeByte(5)
      ..write(obj.kotNumber)
      ..writeByte(6)
      ..write(obj.orderType)
      ..writeByte(7)
      ..write(obj.paymentmode)
      ..writeByte(8)
      ..write(obj.remark)
      ..writeByte(9)
      ..write(obj.subTotal)
      ..writeByte(10)
      ..write(obj.Discount)
      ..writeByte(11)
      ..write(obj.gstRate)
      ..writeByte(12)
      ..write(obj.gstAmount)
      ..writeByte(13)
      ..write(obj.isRefunded)
      ..writeByte(14)
      ..write(obj.refundReason)
      ..writeByte(15)
      ..write(obj.refundAmount)
      ..writeByte(16)
      ..write(obj.refundedAt)
      ..writeByte(17)
      ..write(obj.orderStatus)
      ..writeByte(18)
      ..write(obj.kotNumbers)
      ..writeByte(19)
      ..write(obj.kotBoundaries)
      ..writeByte(20)
      ..write(obj.billNumber)
      ..writeByte(21)
      ..write(obj.paymentListJson)
      ..writeByte(22)
      ..write(obj.isSplitPayment)
      ..writeByte(23)
      ..write(obj.totalPaid)
      ..writeByte(24)
      ..write(obj.changeReturn)
      ..writeByte(25)
      ..write(obj.isTaxInclusive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PastOrderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
