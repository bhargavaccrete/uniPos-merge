


import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'expensel_316.g.dart';

@HiveType(typeId: HiveTypeIds.restaurantExpense1)
class Expense extends HiveObject{
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime dateandTime;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String? categoryOfExpense;

  @HiveField(4)
  final String? reason;

  @HiveField(5)
  final String? paymentType;



  Expense({
    required this.id,
    required this.dateandTime,
    required this.amount,
    this.categoryOfExpense,
    this.reason,
    this.paymentType
  });


  Expense copyWith({
    String? id,
    DateTime ? dateandTime,
    double ? amount,
    String? categoryOfExpense,
    String ? reason,
    String ? paymentType
  }){
    return Expense(
        id: id ?? this.id,
        dateandTime: dateandTime  ?? this.dateandTime,
        amount: amount ?? this.amount,
        categoryOfExpense: categoryOfExpense ?? this.categoryOfExpense,
        paymentType: paymentType ?? this.paymentType,
        reason: reason ?? this.reason
    );
  }

  Map<String, dynamic> toMap(){
    return {
      'id':id,
      'dateandTime':dateandTime.toIso8601String(),
      'amount':amount,
      'categoryOfExpense':categoryOfExpense,
      'reason':reason,
      'paymentType':paymentType
    };
  }

  factory Expense.fromMap(Map<String,dynamic>map){
    return Expense(
        id: map['id'] ?? '',
        dateandTime: map['dateandTime'] is String
            ? DateTime.parse(map['dateandTime'])
            : map['dateandTime'],
        amount: (map['amount'] ?? 0).toDouble(),
        categoryOfExpense: map['categoryOfExpense'],
        reason: map['reason'],
        paymentType: map['paymentType']
    );
  }


}