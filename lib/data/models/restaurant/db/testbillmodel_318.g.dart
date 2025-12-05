// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'testbillmodel_318.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TestBillModelAdapter extends TypeAdapter<TestBillModel> {
  @override
  final int typeId = 118;

  @override
  TestBillModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestBillModel(
      billNo: fields[0] as String,
      dateTime: fields[1] as DateTime,
      tableNo: fields[2] as int,
      totalAmount: fields[3] as double,
      itemList: (fields[4] as List).cast<TestBillItem>(),
      paymentType: fields[5] as String,
      customerName: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TestBillModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.billNo)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.tableNo)
      ..writeByte(3)
      ..write(obj.totalAmount)
      ..writeByte(4)
      ..write(obj.itemList)
      ..writeByte(5)
      ..write(obj.paymentType)
      ..writeByte(6)
      ..write(obj.customerName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestBillModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TestBillItemAdapter extends TypeAdapter<TestBillItem> {
  @override
  final int typeId = 24;

  @override
  TestBillItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestBillItem(
      itemName: fields[0] as String,
      quantity: fields[1] as int,
      price: fields[2] as double,
      totalPrice: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, TestBillItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.itemName)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.totalPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestBillItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
