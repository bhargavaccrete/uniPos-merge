// import 'package:BillBerry/model/db/cartmodel_308.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:hive/hive.dart';

part 'pastordermodel_313.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantPastOrder)

class pastOrderModel extends HiveObject{


  @HiveField(0)
  final String id;

  @HiveField(1)
  final String customerName;

  @HiveField(2)
  final double totalPrice;

  @HiveField(3)
  final List<CartItem>items;

  @HiveField(4)
  final DateTime? orderAt;

  @HiveField(5)
  final int? kotNumber; // Deprecated - no longer used (kept for Hive schema compatibility)

  @HiveField(6)
  final String? orderType;

  @HiveField(7)
  final String? paymentmode;


  @HiveField(8)
  final String? remark;

  @HiveField(9)
  final  double? subTotal;

  @HiveField(10)
  final  double? Discount;

  @HiveField(11)
  final double? gstRate;

  @HiveField(12)
  final double? gstAmount;

  @HiveField(13)
  final bool? isRefunded;

  @HiveField(14)
  final String? refundReason;

  @HiveField(15)
  final double? refundAmount;

  @HiveField(16)
  final DateTime? refundedAt;

  @HiveField(17) // You can reuse the index from the deleted field
  String? orderStatus;

  // --- MULTIPLE KOT SUPPORT ---
  @HiveField(18)
  final List<int> kotNumbers; // List of all KOT numbers - REQUIRED [1, 2, 3...]

  @HiveField(19)
  final List<int> kotBoundaries; // Item count at each KOT [3, 5, 6]

  // --- DAILY BILL NUMBER ---
  @HiveField(20)
  final int? billNumber; // Daily bill number (resets every day) - e.g., 1, 2, 3...

  pastOrderModel({
    required this.id,
    required this.customerName,
    required this.totalPrice,
    required this.items,
    required this.orderAt,
    this.kotNumber, // Deprecated - kept for Hive schema
    required this.orderType,
    required this.paymentmode,
    this.remark,
    this.subTotal,
    this.Discount,
    this.gstRate,
    this.gstAmount,
    this.isRefunded,
    this.refundReason,
    this.refundAmount,
    this.refundedAt,
    this.orderStatus = 'COMPLETED',
    required this.kotNumbers, // REQUIRED
    required this.kotBoundaries, // REQUIRED
    this.billNumber, // Optional - Daily bill number
  }) : assert(kotNumbers.isNotEmpty, 'Order must have at least one KOT number'),
        assert(kotBoundaries.isNotEmpty, 'Order must have at least one KOT boundary'),
        assert(kotNumbers.length == kotBoundaries.length, 'KOT numbers and boundaries must match');


  pastOrderModel copyWith({
    String? id,
    String? customername,
    double? totalPrice,
    List<CartItem>? items,
    DateTime? orderAt,
    int? kotNumber,
    String? orderType,
    String? paymentMode,
    String? remark,
    double? subTotal,
    double? Discount,
    double? gstRate,
    double? gstAmount,
    bool? isRefunded,
    String? refundReason,
    double? refundAmount,
    DateTime? refundedAt,
    String? orderStatus,
    List<int>? kotNumbers,
    List<int>? kotBoundaries,
    int? billNumber,
  }) {
    return pastOrderModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      totalPrice: totalPrice ?? this.totalPrice,
      items: items ?? this.items,
      orderAt: orderAt ?? this.orderAt,
      kotNumber: kotNumber ?? this.kotNumber,
      orderType: orderType ?? this.orderType,
      paymentmode: paymentMode ?? this.paymentmode,
      remark:  remark ?? this.remark,
      subTotal: subTotal ?? this.subTotal,
      Discount:  Discount ?? this.Discount,
      gstRate: gstRate ?? this.gstRate,
      gstAmount: gstAmount ?? this.gstAmount,
      isRefunded: isRefunded ?? this.isRefunded,
      refundReason: refundReason ?? this.refundReason,
      refundAmount: refundAmount ?? this.refundAmount,
      refundedAt: refundedAt ?? this.refundedAt,
      orderStatus: orderStatus ?? this.orderStatus,
      kotNumbers: kotNumbers ?? this.kotNumbers,
      kotBoundaries: kotBoundaries ?? this.kotBoundaries,
      billNumber: billNumber ?? this.billNumber,
    );
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

  // Convert to Map for export
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'totalPrice': totalPrice,
      'items': items.map((e) => e.toMap()).toList(),
      'orderAt': orderAt?.toIso8601String(),
      'kotNumber': kotNumber,
      'orderType': orderType,
      'paymentmode': paymentmode,
      'remark': remark,
      'subTotal': subTotal,
      'Discount': Discount,
      'gstRate': gstRate,
      'gstAmount': gstAmount,
      'isRefunded': isRefunded,
      'refundReason': refundReason,
      'refundAmount': refundAmount,
      'refundedAt': refundedAt?.toIso8601String(),
      'orderStatus': orderStatus,
      'kotNumbers': kotNumbers,
      'kotBoundaries': kotBoundaries,
      'billNumber': billNumber,
    };
  }

  // Create from Map for import
  factory pastOrderModel.fromMap(Map<String, dynamic> map) {
    return pastOrderModel(
      id: map['id'] ?? '',
      customerName: map['customerName'] ?? '',
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      items: (map['items'] as List?)?.map((e) => CartItem.fromMap(e)).toList() ?? [],
      orderAt: map['orderAt'] != null ? DateTime.parse(map['orderAt']) : null,
      kotNumber: map['kotNumber'],
      orderType: map['orderType'],
      paymentmode: map['paymentmode'],
      remark: map['remark'],
      subTotal: map['subTotal']?.toDouble(),
      Discount: map['Discount']?.toDouble(),
      gstRate: map['gstRate']?.toDouble(),
      gstAmount: map['gstAmount']?.toDouble(),
      isRefunded: map['isRefunded'],
      refundReason: map['refundReason'],
      refundAmount: map['refundAmount']?.toDouble(),
      refundedAt: map['refundedAt'] != null ? DateTime.parse(map['refundedAt']) : null,
      orderStatus: map['orderStatus'] ?? 'COMPLETED',
      kotNumbers: (map['kotNumbers'] as List?)?.map((e) => e as int).toList() ?? [1],
      kotBoundaries: (map['kotBoundaries'] as List?)?.map((e) => e as int).toList() ?? [0],
      billNumber: map['billNumber'],
    );
  }
}