import 'package:hive/hive.dart';

import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';

/// BLK-09 fixture: the OrderModel adapter exactly as it was BEFORE
/// `loyaltyPointsUsed`, `discountAppliedBy` and `shiftId` (HiveFields 37–39)
/// existed — its `write` is copied verbatim from the generated adapter at that
/// point (37 fields). Used to write genuinely old-format active orders and
/// prove the current adapter still reads them. Reading delegates to the
/// current adapter.
class PrePaidOrderFieldsOrderAdapter extends TypeAdapter<OrderModel> {
  @override
  final int typeId = 109;

  @override
  OrderModel read(BinaryReader reader) => OrderModelAdapter().read(reader);

  @override
  void write(BinaryWriter writer, OrderModel obj) {
    writer
      ..writeByte(37)
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
      ..write(obj.billNumber)
      ..writeByte(33)
      ..write(obj.sessionId)
      ..writeByte(34)
      ..write(obj.lastModifiedBy)
      ..writeByte(35)
      ..write(obj.lastModifiedAt)
      ..writeByte(36)
      ..write(obj.kotTimestamps);
  }
}
