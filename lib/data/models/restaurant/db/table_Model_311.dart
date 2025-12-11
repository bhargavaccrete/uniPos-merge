

import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
part 'table_Model_311.g.dart';

@HiveType(typeId:HiveTypeIds.restaurantTable)
class TableModel extends HiveObject{

  @HiveField(0)
  final String id;

  @HiveField(1)
  String status;

  @HiveField(2)
  double? currentOrderTotal;

  @HiveField(3)
  String? currentOrderId;

  @HiveField(4)
  String? timeStamp;

  @HiveField(5)
  int? tableCapacity;


  TableModel({
    required this.id,
    this.status = 'Available',
    this.currentOrderTotal,
    this.currentOrderId,
    this.timeStamp,
    this.tableCapacity

  });

  // Convert to Map for export
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status,
      'currentOrderTotal': currentOrderTotal,
      'currentOrderId': currentOrderId,
      'timeStamp': timeStamp,
      'tableCapacity':tableCapacity
    };
  }

  // Create from Map for import
  factory TableModel.fromMap(Map<String, dynamic> map) {
    return TableModel(
      id: map['id'] ?? '',
      status: map['status'] ?? 'Available',
      currentOrderTotal: map['currentOrderTotal']?.toDouble(),
      currentOrderId: map['currentOrderId'],
      timeStamp: map['timeStamp'],
      tableCapacity: map['tableCapacity'],
    );
  }

}
