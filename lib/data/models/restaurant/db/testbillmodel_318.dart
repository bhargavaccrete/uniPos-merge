import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'testbillmodel_318.g.dart';

@HiveType(typeId: HiveTypeIds.TestBill)
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

  /// Convert TestBillModel to Map for backup
  Map<String, dynamic> toMap() {
    return {
      'billNo': billNo,
      'dateTime': dateTime.toIso8601String(),
      'tableNo': tableNo,
      'totalAmount': totalAmount,
      'itemList': itemList.map((e) => e.toMap()).toList(),
      'paymentType': paymentType,
      'customerName': customerName,
    };
  }

  /// Create TestBillModel from Map for restore
  factory TestBillModel.fromMap(Map<String, dynamic> map) {
    return TestBillModel(
      billNo: map['billNo'] as String? ?? '',
      dateTime: DateTime.tryParse(map['dateTime'] ?? '') ?? DateTime.now(),
      tableNo: map['tableNo'] as int? ?? 0,
      totalAmount: (map['totalAmount'] as num? ?? 0).toDouble(),
      itemList: (map['itemList'] as List<dynamic>?)
              ?.map((e) => TestBillItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      paymentType: map['paymentType'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'TestBillModel(billNo: $billNo, dateTime: $dateTime, tableNo: $tableNo, '
        'totalAmount: ₹$totalAmount, items: ${itemList.length}, payment: $paymentType, '
        'customer: $customerName)';
  }
}

@HiveType(typeId: HiveTypeIds.TestBillItem)
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

  /// Convert TestBillItem to Map for backup
  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'quantity': quantity,
      'price': price,
      'totalPrice': totalPrice,
    };
  }

  /// Create TestBillItem from Map for restore
  factory TestBillItem.fromMap(Map<String, dynamic> map) {
    return TestBillItem(
      itemName: map['itemName'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      price: (map['price'] as num? ?? 0).toDouble(),
      totalPrice: (map['totalPrice'] as num? ?? 0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'TestBillItem(name: $itemName, qty: $quantity, price: ₹$price, total: ₹$totalPrice)';
  }
}
