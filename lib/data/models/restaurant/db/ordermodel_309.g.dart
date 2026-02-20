// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ordermodel_309.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderModelAdapter extends TypeAdapter<OrderModel> {
  @override
  final int typeId = 109;

  @override
  OrderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderModel(
      id: fields[0] as String,
      customerName: fields[1] as String,
      customerNumber: fields[2] as String,
      customerEmail: fields[3] as String,
      items: (fields[4] as List).cast<CartItem>(),
      status: fields[5] as String,
      timeStamp: fields[6] as DateTime,
      orderType: fields[7] as String,
      tableNo: fields[8] as String?,
      totalPrice: fields[9] as double,
      kotNumber: fields[10] as int?,
      discount: fields[11] as double?,
      serviceCharge: fields[12] as double?,
      paymentMethod: fields[13] as String?,
      completedAt: fields[14] as DateTime?,
      paymentStatus: fields[15] as String?,
      subTotal: fields[16] as double?,
      isPaid: fields[17] as bool?,
      gstRate: fields[18] as double?,
      gstAmount: fields[19] as double?,
      remark: fields[20] as String?,
      kotNumbers: (fields[21] as List).cast<int>(),
      itemCountAtLastKot: fields[22] as int,
      kotBoundaries: (fields[23] as List).cast<int>(),
      kotStatuses: (fields[24] as Map?)?.cast<int, String>(),
      orderNumber: fields[25] as int?,
      customerId: fields[26] as String?,
      paymentListJson: fields[27] as String?,
      isSplitPayment: fields[28] as bool?,
      totalPaid: fields[29] as double?,
      changeReturn: fields[30] as double?,
      isTaxInclusive: fields[31] as bool?,
      billNumber: fields[32] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, OrderModel obj) {
    writer
      ..writeByte(33)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerName)
      ..writeByte(2)
      ..write(obj.customerNumber)
      ..writeByte(3)
      ..write(obj.customerEmail)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.timeStamp)
      ..writeByte(7)
      ..write(obj.orderType)
      ..writeByte(8)
      ..write(obj.tableNo)
      ..writeByte(9)
      ..write(obj.totalPrice)
      ..writeByte(10)
      ..write(obj.kotNumber)
      ..writeByte(11)
      ..write(obj.discount)
      ..writeByte(12)
      ..write(obj.serviceCharge)
      ..writeByte(13)
      ..write(obj.paymentMethod)
      ..writeByte(14)
      ..write(obj.completedAt)
      ..writeByte(15)
      ..write(obj.paymentStatus)
      ..writeByte(16)
      ..write(obj.subTotal)
      ..writeByte(17)
      ..write(obj.isPaid)
      ..writeByte(18)
      ..write(obj.gstRate)
      ..writeByte(19)
      ..write(obj.gstAmount)
      ..writeByte(20)
      ..write(obj.remark)
      ..writeByte(21)
      ..write(obj.kotNumbers)
      ..writeByte(22)
      ..write(obj.itemCountAtLastKot)
      ..writeByte(23)
      ..write(obj.kotBoundaries)
      ..writeByte(24)
      ..write(obj.kotStatuses)
      ..writeByte(25)
      ..write(obj.orderNumber)
      ..writeByte(26)
      ..write(obj.customerId)
      ..writeByte(27)
      ..write(obj.paymentListJson)
      ..writeByte(28)
      ..write(obj.isSplitPayment)
      ..writeByte(29)
      ..write(obj.totalPaid)
      ..writeByte(30)
      ..write(obj.changeReturn)
      ..writeByte(31)
      ..write(obj.isTaxInclusive)
      ..writeByte(32)
      ..write(obj.billNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
