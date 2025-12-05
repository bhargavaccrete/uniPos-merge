
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
part 'ordermodel_309.g.dart';

@HiveType(typeId: 309)
class OrderModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String customerName;

  @HiveField(2)
  final String customerNumber;

  @HiveField(3)
  final String customerEmail;

  @HiveField(4)
  final List<CartItem> items;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final DateTime timeStamp;

  @HiveField(7)
  final String orderType;

  @HiveField(8)
  final String? tableNo;

  @HiveField(9)
  final double totalPrice;

  @HiveField(10)
  final int? kotNumber; // Deprecated - no longer used (kept for Hive schema compatibility)

  // --- NEW FIELDS TO STORE FINAL TRANSACTION DETAILS ---
  @HiveField(11)
  final double? discount;

  @HiveField(12)
  final double? serviceCharge;

  @HiveField(13)
  final String? paymentMethod;

  @HiveField(14)
  final DateTime? completedAt;

  @HiveField(15)
  final String? paymentStatus;

  @HiveField(16)
  final double? subTotal;

  @HiveField(17)
  final bool? isPaid;

  @HiveField(18)
  final double? gstRate;

  @HiveField(19)
  final double? gstAmount;

  @HiveField(20)
  final String? remark;

  // --- MULTIPLE KOT SUPPORT ---
  @HiveField(21)
  final List<int> kotNumbers; // List of all KOT numbers - REQUIRED [1, 2, 3...]

  @HiveField(22)
  final int itemCountAtLastKot; // Number of items when last KOT was generated - REQUIRED

  @HiveField(23)
  final List<int> kotBoundaries; // Item count at each KOT [3, 5, 6] means items 0-2 in KOT1, 3-4 in KOT2, 5-5 in KOT3

  OrderModel( {
    required this.id,
    required this.customerName,
    required this.customerNumber,
    required this.customerEmail,
    required this.items,
    required this.status,
    required this.timeStamp,
    required this.orderType,
    this.tableNo,
    required this.totalPrice,
    this.kotNumber, // Deprecated - kept for Hive schema
    // Add new fields to constructor (as optional)
    this.discount,
    this.serviceCharge,
    this.paymentMethod,
    this.completedAt,
    this.paymentStatus,
    this.subTotal,
    this.isPaid,
    this.gstRate,
    this.gstAmount,
    this.remark,
    // KOT tracking - REQUIRED for all orders
    required this.kotNumbers,
    required this.itemCountAtLastKot,
    required this.kotBoundaries,
  }) : assert(kotNumbers.isNotEmpty, 'Order must have at least one KOT number'),
       assert(kotBoundaries.isNotEmpty, 'Order must have at least one KOT boundary'),
       assert(kotNumbers.length == kotBoundaries.length, 'KOT numbers and boundaries must match');

  // --- A COMPLETE AND MORE FLEXIBLE copyWith METHOD ---
  OrderModel copyWith({
    String? id,
    String? customerName,
    String? customerNumber,
    String? customerEmail,
    List<CartItem>? items,
    String? status,
    DateTime? timeStamp,
    String? orderType,
    String? tableNo,
    double? totalPrice,
    int? kotNumber,
    double? discount,
    double? serviceCharge,
    String? paymentMethod,
    DateTime? completedAt,
    String ? paymentStatus,
    double? subTotal,
    bool? isPaid,
    double? gstRate,
    double? gstAmount,
    String? remark,
    List<int>? kotNumbers,
    int? itemCountAtLastKot,
    List<int>? kotBoundaries,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerNumber: customerNumber ?? this.customerNumber,
      customerEmail: customerEmail ?? this.customerEmail,
      items: items ?? this.items,
      status: status ?? this.status,
      timeStamp: timeStamp ?? this.timeStamp,
      orderType: orderType ?? this.orderType,
      tableNo: tableNo ?? this.tableNo,
      totalPrice: totalPrice ?? this.totalPrice,
      kotNumber: kotNumber ?? this.kotNumber,
      discount: discount ?? this.discount,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      completedAt: completedAt ?? this.completedAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subTotal: subTotal ?? this.subTotal,
      isPaid: isPaid?? this.isPaid,
      gstAmount: gstAmount ?? this.gstAmount,
      gstRate:  gstRate ?? this.gstRate,
      remark: remark ?? this.remark,
      kotNumbers: kotNumbers ?? this.kotNumbers,
      itemCountAtLastKot: itemCountAtLastKot ?? this.itemCountAtLastKot,
      kotBoundaries: kotBoundaries ?? this.kotBoundaries,
    );
  }

  // Helper method to get newly added items since last KOT
  List<CartItem> getNewlyAddedItems() {
    if (itemCountAtLastKot >= items.length) {
      return [];
    }
    return items.sublist(itemCountAtLastKot);
  }

  // Helper method to get KOT numbers
  List<int> getKotNumbers() {
    return kotNumbers; // Always present, no fallback needed
  }

  // Helper method to get items grouped by KOT number
  Map<int, List<CartItem>> getItemsByKot() {
    Map<int, List<CartItem>> itemsByKot = {};

    int startIndex = 0;
    for (int i = 0; i < kotNumbers.length; i++) {
      int endIndex = kotBoundaries[i];
      int kotNum = kotNumbers[i];

      // Get items for this KOT
      List<CartItem> kotItems = items.sublist(startIndex, endIndex);
      itemsByKot[kotNum] = kotItems;

      startIndex = endIndex;
    }

    return itemsByKot;
  }
}