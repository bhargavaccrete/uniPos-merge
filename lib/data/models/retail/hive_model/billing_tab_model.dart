import 'package:hive/hive.dart';
import 'cart_model_202.dart';

part 'billing_tab_model.g.dart';

@HiveType(typeId: 220)
class BillingTabModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<CartItemModel> items;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  String? customerName;

  @HiveField(6)
  String? customerPhone;

  BillingTabModel({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.customerPhone,
  });

  /// Get total items count in this tab
  int get totalItems {
    int total = 0;
    for (var item in items) {
      total += item.qty;
    }
    return total;
  }

  /// Get total price for this tab
  double get totalPrice {
    double total = 0.0;
    for (var item in items) {
      total += item.total;
    }
    return total;
  }

  /// Check if tab is empty
  bool get isEmpty => items.isEmpty;

  /// Get display name for tab
  String get displayName {
    if (customerName != null && customerName!.isNotEmpty) {
      return customerName!;
    }
    return name;
  }

  /// Create a copy with updated fields
  BillingTabModel copyWith({
    String? id,
    String? name,
    List<CartItemModel>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerPhone,
  }) {
    return BillingTabModel(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
}