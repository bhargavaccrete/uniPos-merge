// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eodmodel_317.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EndOfDayReportAdapter extends TypeAdapter<EndOfDayReport> {
  @override
  final int typeId = 117;

  @override
  EndOfDayReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EndOfDayReport(
      date: fields[0] as DateTime,
      openingBalance: fields[1] as double,
      orderSummaries: (fields[2] as List).cast<OrderTypeSummary>(),
      totalDiscount: fields[3] as double,
      totalTax: fields[4] as double,
      categorySales: (fields[5] as List).cast<CategorySales>(),
      paymentSummaries: (fields[6] as List).cast<PaymentSummary>(),
      cashReconciliation: fields[7] as CashReconciliation,
      totalSales: fields[8] as double,
      closingBalance: fields[9] as double,
      taxSummaries: (fields[10] as List).cast<TaxSummary>(),
      totalOrderCount: fields[11] as int,
      totalRefunds: fields[12] as double,
      reportId: fields[13] as String,
      totalExpenses: fields[14] as double,
      cashExpenses: fields[15] as double,
      mode: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EndOfDayReport obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.openingBalance)
      ..writeByte(2)
      ..write(obj.orderSummaries)
      ..writeByte(3)
      ..write(obj.totalDiscount)
      ..writeByte(4)
      ..write(obj.totalTax)
      ..writeByte(5)
      ..write(obj.categorySales)
      ..writeByte(6)
      ..write(obj.paymentSummaries)
      ..writeByte(7)
      ..write(obj.cashReconciliation)
      ..writeByte(8)
      ..write(obj.totalSales)
      ..writeByte(9)
      ..write(obj.closingBalance)
      ..writeByte(10)
      ..write(obj.taxSummaries)
      ..writeByte(11)
      ..write(obj.totalOrderCount)
      ..writeByte(12)
      ..write(obj.totalRefunds)
      ..writeByte(13)
      ..write(obj.reportId)
      ..writeByte(14)
      ..write(obj.totalExpenses)
      ..writeByte(15)
      ..write(obj.cashExpenses)
      ..writeByte(16)
      ..write(obj.mode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EndOfDayReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderTypeSummaryAdapter extends TypeAdapter<OrderTypeSummary> {
  @override
  final int typeId = 18;

  @override
  OrderTypeSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderTypeSummary(
      orderType: fields[0] as String,
      orderCount: fields[1] as int,
      totalAmount: fields[2] as double,
      averageOrderValue: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, OrderTypeSummary obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.orderType)
      ..writeByte(1)
      ..write(obj.orderCount)
      ..writeByte(2)
      ..write(obj.totalAmount)
      ..writeByte(3)
      ..write(obj.averageOrderValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderTypeSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategorySalesAdapter extends TypeAdapter<CategorySales> {
  @override
  final int typeId = 19;

  @override
  CategorySales read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategorySales(
      categoryName: fields[0] as String,
      totalAmount: fields[1] as double,
      itemsSold: fields[2] as int,
      percentage: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CategorySales obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.categoryName)
      ..writeByte(1)
      ..write(obj.totalAmount)
      ..writeByte(2)
      ..write(obj.itemsSold)
      ..writeByte(3)
      ..write(obj.percentage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategorySalesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaymentSummaryAdapter extends TypeAdapter<PaymentSummary> {
  @override
  final int typeId = 20;

  @override
  PaymentSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentSummary(
      paymentType: fields[0] as String,
      totalAmount: fields[1] as double,
      transactionCount: fields[2] as int,
      percentage: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentSummary obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.paymentType)
      ..writeByte(1)
      ..write(obj.totalAmount)
      ..writeByte(2)
      ..write(obj.transactionCount)
      ..writeByte(3)
      ..write(obj.percentage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CashReconciliationAdapter extends TypeAdapter<CashReconciliation> {
  @override
  final int typeId = 22;

  @override
  CashReconciliation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CashReconciliation(
      systemExpectedCash: fields[0] as double,
      actualCash: fields[1] as double,
      difference: fields[2] as double,
      reconciliationStatus: fields[3] as String,
      remarks: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CashReconciliation obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.systemExpectedCash)
      ..writeByte(1)
      ..write(obj.actualCash)
      ..writeByte(2)
      ..write(obj.difference)
      ..writeByte(3)
      ..write(obj.reconciliationStatus)
      ..writeByte(4)
      ..write(obj.remarks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashReconciliationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaxSummaryAdapter extends TypeAdapter<TaxSummary> {
  @override
  final int typeId = 21;

  @override
  TaxSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxSummary(
      taxName: fields[0] as String,
      taxRate: fields[1] as double,
      taxAmount: fields[2] as double,
      taxableAmount: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, TaxSummary obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.taxName)
      ..writeByte(1)
      ..write(obj.taxRate)
      ..writeByte(2)
      ..write(obj.taxAmount)
      ..writeByte(3)
      ..write(obj.taxableAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
