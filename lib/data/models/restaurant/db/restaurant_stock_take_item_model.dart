import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_stock_take_item_model.g.dart';

const _uuid = Uuid();

/// One counted item inside a restaurant stock take. Mirrors retail's
/// `StockTakeItemModel`, quantities kept as `double` to support restaurant's
/// weight-based raw materials.
///
/// [systemQty] is a snapshot taken when the line was counted, not a live
/// reading — commit applies [variance] as a *delta* so a sale/production run
/// landing between count and commit isn't erased. See
/// `RestaurantStockTakeStore.commit`.
@HiveType(typeId: HiveTypeIds.restaurantStockTakeItem)
class RestaurantStockTakeItemModel extends HiveObject {
  @HiveField(0)
  final String takeItemId;

  @HiveField(1)
  final String takeId;

  @HiveField(2)
  final String itemId;

  /// Denormalised for display, so the line survives an item rename/delete.
  @HiveField(3)
  final String? itemName;

  /// What the system claimed when this line was counted.
  @HiveField(4)
  final double systemQty;

  /// What the shop physically counted.
  @HiveField(5)
  final double countedQty;

  /// Cost at count time, for valuing the variance.
  @HiveField(6)
  final double? costPrice;

  @HiveField(7)
  final String countedAt;

  /// Units actually applied at commit. Null while draft, or when the line
  /// had no variance and was skipped.
  @HiveField(8)
  final double? appliedQty;

  RestaurantStockTakeItemModel({
    required this.takeItemId,
    required this.takeId,
    required this.itemId,
    this.itemName,
    required this.systemQty,
    required this.countedQty,
    this.costPrice,
    required this.countedAt,
    this.appliedQty,
  });

  factory RestaurantStockTakeItemModel.create({
    required String takeId,
    required String itemId,
    String? itemName,
    required double systemQty,
    required double countedQty,
    double? costPrice,
  }) {
    return RestaurantStockTakeItemModel(
      takeItemId: _uuid.v4(),
      takeId: takeId,
      itemId: itemId,
      itemName: itemName,
      systemQty: systemQty,
      countedQty: countedQty,
      costPrice: costPrice,
      countedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Counted minus system. Negative means stock is missing.
  double get variance => countedQty - systemQty;

  bool get hasVariance => variance != 0;

  bool get isShortage => variance < 0;

  /// Value of the variance at count-time cost. Negative for a shortage.
  double get varianceValue => costPrice == null ? 0 : variance * costPrice!;

  RestaurantStockTakeItemModel copyWith({
    double? systemQty,
    double? countedQty,
    double? costPrice,
    double? appliedQty,
  }) {
    return RestaurantStockTakeItemModel(
      takeItemId: takeItemId,
      takeId: takeId,
      itemId: itemId,
      itemName: itemName,
      systemQty: systemQty ?? this.systemQty,
      countedQty: countedQty ?? this.countedQty,
      costPrice: costPrice ?? this.costPrice,
      // Re-stamped on a recount (a new count) — NOT on marking a line
      // applied, which misdated the count and reordered the lines.
      countedAt: (systemQty != null || countedQty != null)
          ? DateTime.now().toIso8601String()
          : countedAt,
      appliedQty: appliedQty ?? this.appliedQty,
    );
  }

  Map<String, dynamic> toMap() => {
        'takeItemId': takeItemId,
        'takeId': takeId,
        'itemId': itemId,
        'itemName': itemName,
        'systemQty': systemQty,
        'countedQty': countedQty,
        'costPrice': costPrice,
        'countedAt': countedAt,
        'appliedQty': appliedQty,
      };

  factory RestaurantStockTakeItemModel.fromMap(Map<String, dynamic> map) =>
      RestaurantStockTakeItemModel(
        takeItemId: map['takeItemId'] as String,
        takeId: map['takeId'] as String? ?? '',
        itemId: map['itemId'] as String? ?? '',
        itemName: map['itemName'] as String?,
        systemQty: (map['systemQty'] as num?)?.toDouble() ?? 0,
        countedQty: (map['countedQty'] as num?)?.toDouble() ?? 0,
        costPrice: (map['costPrice'] as num?)?.toDouble(),
        countedAt:
            map['countedAt'] as String? ?? DateTime.now().toIso8601String(),
        appliedQty: (map['appliedQty'] as num?)?.toDouble(),
      );
}
