import 'package:hive/hive.dart';

import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';

/// SB-2b fixture: the PastOrderModel adapter exactly as it was BEFORE
/// `refundEventsJson` (HiveField 40) existed — its `write` is copied verbatim
/// from the generated adapter at that commit (40 fields, no field 40). Used
/// to write genuinely old-format records and prove the current adapter still
/// reads them. Reading delegates to the current adapter.
class PreRefundEventsPastOrderAdapter extends TypeAdapter<PastOrderModel> {
  @override
  final int typeId = 113;

  @override
  PastOrderModel read(BinaryReader reader) => PastOrderModelAdapter().read(reader);

  @override
  void write(BinaryWriter writer, PastOrderModel obj) {
    writer
      ..writeByte(40)
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
      ..write(obj.isTaxInclusive)
      ..writeByte(26)
      ..write(obj.tableNo)
      ..writeByte(27)
      ..write(obj.loyaltyPointsUsed)
      ..writeByte(28)
      ..write(obj.shiftId)
      ..writeByte(29)
      ..write(obj.sessionId)
      ..writeByte(30)
      ..write(obj.discountAppliedBy)
      ..writeByte(31)
      ..write(obj.voidedBy)
      ..writeByte(35)
      ..write(obj.voidReason)
      ..writeByte(32)
      ..write(obj.refundedBy)
      ..writeByte(33)
      ..write(obj.customerId)
      ..writeByte(34)
      ..write(obj.serviceCharge)
      ..writeByte(36)
      ..write(obj.taxEnabled)
      ..writeByte(37)
      ..write(obj.storeGstNumber)
      ..writeByte(38)
      ..write(obj.roundOffStep)
      ..writeByte(39)
      ..write(obj.discountOnItems);
  }
}
