import 'order_status.dart';

class KdsOrderDto {
  final String orderId;
  final int? orderNumber; // Daily order number (starts from 1, resets daily)
  final String tableNo;
  final String orderType;
  final OrderStatus status;
  final DateTime createdAt;
  final List<KdsItemDto> items;
  final int kotNumber; // KOT number for THIS specific KOT card
  final List<int>? allKotNumbers; // All KOT numbers for the parent order
  final bool isPartialOrder; // True if this order has multiple KOTs

  KdsOrderDto({
    required this.orderId,
    this.orderNumber,
    required this.tableNo,
    required this.orderType,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.kotNumber,
    this.allKotNumbers,
    this.isPartialOrder = false,
  });

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    if (orderNumber != null) 'orderNumber': orderNumber,
    'tableNo': tableNo,
    'orderType': orderType,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'kotNumber': kotNumber,
    if (allKotNumbers != null) 'allKotNumbers': allKotNumbers,
    'isPartialOrder': isPartialOrder,
  };
}

class KdsItemDto {
  final String name;
  final int qty;
  final String? note;
  final String? variant; // Variant name (e.g., "Large", "Medium")
  final List<String>? choices; // Choice selections (e.g., ["Extra Cheese", "No Onions"])
  final List<Map<String, dynamic>>? extras; // Additional items/toppings
  final String? category; // Category name for kitchen organization
  final String? weightDisplay; // For weighted items

  KdsItemDto({
    required this.name,
    required this.qty,
    this.note,
    this.variant,
    this.choices,
    this.extras,
    this.category,
    this.weightDisplay,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    if (note != null) 'note': note,
    if (variant != null) 'variant': variant,
    if (choices != null && choices!.isNotEmpty) 'choices': choices,
    if (extras != null && extras!.isNotEmpty) 'extras': extras,
    if (category != null) 'category': category,
    if (weightDisplay != null) 'weightDisplay': weightDisplay,
  };
}
