import 'package:hive/hive.dart';

part 'payment_method.g.dart';

@HiveType(typeId: 6) // Unique type ID for PaymentMethod
class PaymentMethod extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String value; // Internal value like 'cash', 'card', 'upi'

  @HiveField(3)
  final String iconName; // Icon name as string

  @HiveField(4)
  final bool isEnabled;

  @HiveField(5)
  final int sortOrder; // For ordering payment methods

  PaymentMethod({
    required this.id,
    required this.name,
    required this.value,
    required this.iconName,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  PaymentMethod copyWith({
    String? id,
    String? name,
    String? value,
    String? iconName,
    bool? isEnabled,
    int? sortOrder,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      iconName: iconName ?? this.iconName,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'iconName': iconName,
      'isEnabled': isEnabled,
      'sortOrder': sortOrder,
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] as String,
      name: map['name'] as String,
      value: map['value'] as String,
      iconName: map['iconName'] as String,
      isEnabled: map['isEnabled'] as bool? ?? true,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}