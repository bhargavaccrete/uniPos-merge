import 'package:hive/hive.dart';

part 'payment_entry_model_216.g.dart';

/// Payment method types
enum PaymentMethod {
  cash,
  card,
  upi,
  wallet,
  credit,
  other,
}

/// Extension to convert PaymentMethod to display string
extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.wallet:
        return 'Wallet';
      case PaymentMethod.credit:
        return 'Credit';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  String get value {
    return name;
  }

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PaymentMethod.other,
    );
  }
}

@HiveType(typeId: 216)
class PaymentEntryModel extends HiveObject {
  @HiveField(0)
  final String paymentEntryId;

  @HiveField(1)
  final String saleId;

  @HiveField(2)
  final String paymentMethod; // cash, card, upi, wallet, credit, other

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final String? referenceId; // For UPI/Card transaction reference

  @HiveField(5)
  final String timestamp;

  @HiveField(6)
  final String? note;

  PaymentEntryModel({
    required this.paymentEntryId,
    required this.saleId,
    required this.paymentMethod,
    required this.amount,
    this.referenceId,
    required this.timestamp,
    this.note,
  });

  factory PaymentEntryModel.create({
    required String paymentEntryId,
    required String saleId,
    required String paymentMethod,
    required double amount,
    String? referenceId,
    String? note,
  }) {
    return PaymentEntryModel(
      paymentEntryId: paymentEntryId,
      saleId: saleId,
      paymentMethod: paymentMethod.toLowerCase(),
      amount: amount,
      referenceId: referenceId,
      timestamp: DateTime.now().toIso8601String(),
      note: note,
    );
  }

  /// Copy with method for updates
  PaymentEntryModel copyWith({
    String? paymentEntryId,
    String? saleId,
    String? paymentMethod,
    double? amount,
    String? referenceId,
    String? timestamp,
    String? note,
  }) {
    return PaymentEntryModel(
      paymentEntryId: paymentEntryId ?? this.paymentEntryId,
      saleId: saleId ?? this.saleId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      referenceId: referenceId ?? this.referenceId,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentEntryId': paymentEntryId,
      'saleId': saleId,
      'method': paymentMethod,
      'amount': amount,
      'referenceId': referenceId,
      'timestamp': timestamp,
      'note': note,
    };
  }

  /// Short map for receipt display
  Map<String, dynamic> toShortMap() {
    return {
      'method': paymentMethod,
      'amount': amount,
      if (referenceId != null) 'ref': referenceId,
    };
  }

  @override
  String toString() {
    return 'PaymentEntryModel(method: $paymentMethod, amount: $amount, ref: $referenceId)';
  }
}