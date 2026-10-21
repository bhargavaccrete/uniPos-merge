import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'saved_printer_model.g.dart';

@HiveType(typeId: HiveTypeIds.savedPrinter)
class SavedPrinterModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  // 'bluetooth' | 'wifi' | 'usb' | 'windows' | 'windows_pdf'
  // 'windows'     → RAW ESC/POS through the Windows spooler (thermal printers)
  // 'windows_pdf' → rendered receipt PDF through the Windows printing API
  //                 (doPDF, Microsoft Print to PDF, document printers)
  final String type;

  @HiveField(3)
  // MAC for BT, "IP:port" for WiFi, "vendorId:productId" for USB, and the
  // Windows spooler queue name for 'windows'. The queue name may itself
  // contain a colon ("Printer on SERVER:2") — never split it.
  final String address;

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

  /// RAW ESC/POS through the Windows print spooler — a real thermal printer.
  bool get isWindows => type == 'windows';

  /// A Windows PDF/document printer. Receives a RENDERED receipt PDF, never
  /// ESC/POS: control codes are meaningless to a PDF writer, which discards
  /// them while every layer still reports success.
  bool get isWindowsPdf => type == 'windows_pdf';

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
