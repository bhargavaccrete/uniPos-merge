import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'saved_printer_model.g.dart';

@HiveType(typeId: HiveTypeIds.savedPrinter)
class SavedPrinterModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String type; // 'bluetooth' | 'wifi'

  @HiveField(3)
  final String address; // MAC address for BT, "IP:port" for WiFi

  @HiveField(4)
  final int paperSize; // 58 or 80 (mm)

  @HiveField(5)
  final String role; // 'kot' | 'receipt' | 'both'

  @HiveField(6)
  final bool isDefault;

  @HiveField(7)
  final DateTime createdAt;

  SavedPrinterModel({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.paperSize = 80,
    this.role = 'both',
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isBluetooth => type == 'bluetooth';
  bool get isWifi => type == 'wifi';
  bool get isUsb => type == 'usb';
  bool get isKotPrinter => role == 'kot' || role == 'both';
  bool get isReceiptPrinter => role == 'receipt' || role == 'both';

  SavedPrinterModel copyWith({
    String? id,
    String? name,
    String? type,
    String? address,
    int? paperSize,
    String? role,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return SavedPrinterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      paperSize: paperSize ?? this.paperSize,
      role: role ?? this.role,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'address': address,
      'paperSize': paperSize,
      'role': role,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedPrinterModel.fromMap(Map<String, dynamic> map) {
    return SavedPrinterModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'bluetooth',
      address: map['address'] ?? '',
      paperSize: map['paperSize'] ?? 80,
      role: map['role'] ?? 'both',
      isDefault: map['isDefault'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
