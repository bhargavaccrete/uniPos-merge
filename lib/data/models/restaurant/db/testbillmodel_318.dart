import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'testbillmodel_318.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantTestBill)
class TestBillModel extends HiveObject {
  @HiveField(0)
  String billNo;

  @HiveField(1)
  DateTime dateTime;

  @HiveField(2)
  int tableNo;

  @HiveField(3)
  double totalAmount;

  @HiveField(4)
  List<TestBillItem> itemList;

  @HiveField(5)
  String paymentType;

  @HiveField(6)
  String customerName;

  TestBillModel({
    required this.billNo,
    required this.dateTime,
    required this.tableNo,
    required this.totalAmount,
    required this.itemList,
    required this.paymentType,
    required this.customerName,
  });

  @override
  String toString() {
    return 'TestBillModel(billNo: $billNo, dateTime: $dateTime, tableNo: $tableNo, '
        'totalAmount: ₹$totalAmount, items: ${itemList.length}, payment: $paymentType, '
        'customer: $customerName)';
  }
}

@HiveType(typeId: 24)
class TestBillItem extends HiveObject {
  @HiveField(0)
  String itemName;

  @HiveField(1)
  int quantity;

  @HiveField(2)
  double price;

  @HiveField(3)
  double totalPrice;

  TestBillItem({
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.totalPrice,
  });

  @override
  String toString() {
    return 'TestBillItem(name: $itemName, qty: $quantity, price: ₹$price, total: ₹$totalPrice)';
  }
}