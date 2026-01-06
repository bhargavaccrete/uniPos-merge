import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

part 'credit_payment_model_218.g.dart';

/// Credit Payment Model
/// Tracks individual payments made against credit sales
/// This is separate from PaymentEntryModel which tracks split payments during checkout
@HiveType(typeId: HiveTypeIds.retailCreditPayment)
class CreditPaymentModel extends HiveObject {
  @HiveField(0)
  final String paymentId;

  @HiveField(1)
  final String customerId;

  @HiveField(2)
  final String saleId; // The sale this payment is for

  @HiveField(3)
  final double amount; // Amount paid

  @HiveField(4)
  final String paymentMode; // cash / card / upi

  @HiveField(5)
  final String date; // Payment date

  @HiveField(6)
  final String? referenceId; // For UPI/Card transaction reference

  @HiveField(7)
  final String? note; // Optional note

  @HiveField(8)
  final String createdAt;

  @HiveField(9)
  final double balanceBefore; // Customer credit balance before this payment

  @HiveField(10)
  final double balanceAfter; // Customer credit balance after this payment

  @HiveField(11)
  final bool? isWriteOff; // True if this is a debt write-off

  CreditPaymentModel({
    required this.paymentId,
    required this.customerId,
    required this.saleId,
    required this.amount,
    required this.paymentMode,
    required this.date,
    this.referenceId,
    this.note,
    required this.createdAt,
    required this.balanceBefore,
    required this.balanceAfter,
    this.isWriteOff,
  });

  factory CreditPaymentModel.create({
    required String paymentId,
    required String customerId,
    required String saleId,
    required double amount,
    required String paymentMode,
    String? referenceId,
    String? note,
    required double balanceBefore,
    required double balanceAfter,
    bool isWriteOff = false,
  }) {
    final now = DateTime.now().toIso8601String();
    return CreditPaymentModel(
      paymentId: paymentId,
      customerId: customerId,
      saleId: saleId,
      amount: amount,
      paymentMode: paymentMode.toLowerCase(),
      date: now,
      referenceId: referenceId,
      note: note,
      createdAt: now,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      isWriteOff: isWriteOff,
    );
  }

  /// Check if payment is a write-off
  bool get isDebtWriteOff => isWriteOff ?? false;

  /// Get payment mode display text
  String get paymentModeDisplayText {
    switch (paymentMode.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'upi':
        return 'UPI';
      default:
        return paymentMode.toUpperCase();
    }
  }

  /// Copy with updated fields
  CreditPaymentModel copyWith({
    String? paymentId,
    String? customerId,
    String? saleId,
    double? amount,
    String? paymentMode,
    String? date,
    String? referenceId,
    String? note,
    String? createdAt,
    double? balanceBefore,
    double? balanceAfter,
    bool? isWriteOff,
  }) {
    return CreditPaymentModel(
      paymentId: paymentId ?? this.paymentId,
      customerId: customerId ?? this.customerId,
      saleId: saleId ?? this.saleId,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      date: date ?? this.date,
      referenceId: referenceId ?? this.referenceId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      isWriteOff: isWriteOff ?? this.isWriteOff,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'customerId': customerId,
      'saleId': saleId,
      'amount': amount,
      'paymentMode': paymentMode,
      'date': date,
      'referenceId': referenceId,
      'note': note,
      'createdAt': createdAt,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'isWriteOff': isWriteOff ?? false,
    };
  }

  factory CreditPaymentModel.fromMap(Map<String, dynamic> map) {
    return CreditPaymentModel(
      paymentId: map['paymentId'] as String,
      customerId: map['customerId'] as String,
      saleId: map['saleId'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMode: map['paymentMode'] as String,
      date: map['date'] as String,
      referenceId: map['referenceId'] as String?,
      note: map['note'] as String?,
      createdAt: map['createdAt'] as String,
      balanceBefore: (map['balanceBefore'] as num).toDouble(),
      balanceAfter: (map['balanceAfter'] as num).toDouble(),
      isWriteOff: map['isWriteOff'] as bool?,
    );
  }
}