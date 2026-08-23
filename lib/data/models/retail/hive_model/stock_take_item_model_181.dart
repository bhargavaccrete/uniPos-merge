import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'stock_take_item_model_181.g.dart';

const _uuid = Uuid();

/// One counted variant inside a stock take.
///
/// **[systemQty] is a snapshot, not a live reading.** It records what the system
/// believed at the moment this line was counted, which is what makes the
/// variance meaningful — the shop counted against that number, not against
/// whatever stock says at commit time.
///
/// That distinction is the whole reason commit applies [variance] as a *delta*
/// rather than writing [countedQty] absolutely. If a sale lands between the
/// count and the commit, writing the counted figure would erase it; applying
/// the variance keeps both facts. See `StockTakeStore.commit`.
///
/// [appliedQty] is filled in at commit with what was actually applied, so a
/// completed line can be audited even after later movements change the variant.
@HiveType(typeId: HiveTypeIds.retailStockTakeItem)
class StockTakeItemModel extends HiveObject {
  @HiveField(0)
  final String takeItemId;

  @HiveField(1)
  final String takeId;

  @HiveField(2)
  final String variantId;

  @HiveField(3)
  final String productId;

  /// Denormalised for display, so the line survives a product rename or delete.
  @HiveField(4)
  final String? productName;

  @HiveField(5)
  final String? variantInfo;

  /// What the system claimed when this line was counted.
  @HiveField(6)
  final int systemQty;

  /// What the shop physically counted.
  @HiveField(7)
  final int countedQty;

  /// Cost at count time, for valuing the variance.
  @HiveField(8)
  final double? costPrice;

  @HiveField(9)
  final String countedAt;

  /// Units actually applied at commit. Null while draft, or when the line had
  /// no variance and so was skipped.
  @HiveField(10)
  final int? appliedQty;

  StockTakeItemModel({
    required this.takeItemId,
    required this.takeId,
    required this.variantId,
    required this.productId,
    this.productName,
    this.variantInfo,
    required this.systemQty,
    required this.countedQty,
    this.costPrice,
    required this.countedAt,
    this.appliedQty,
  });

  factory StockTakeItemModel.create({
    required String takeId,
    required String variantId,
    required String productId,
    String? productName,
    String? variantInfo,
    required int systemQty,
    required int countedQty,
    double? costPrice,
  }) {
    return StockTakeItemModel(
      takeItemId: _uuid.v4(),
      takeId: takeId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      variantInfo: variantInfo,
      systemQty: systemQty,
      countedQty: countedQty,
      costPrice: costPrice,
      countedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Counted minus system. Negative means stock is missing, which is the usual
  /// direction; positive means more was found than the books expected.
  int get variance => countedQty - systemQty;

  bool get hasVariance => variance != 0;

  bool get isShortage => variance < 0;

  /// Value of the variance at count-time cost. Negative for a shortage, so it
  /// reads as a loss without the caller having to flip the sign.
  double get varianceValue => costPrice == null ? 0 : variance * costPrice!;

  StockTakeItemModel copyWith({
    int? systemQty,
    int? countedQty,
    double? costPrice,
    int? appliedQty,
  }) {
    return StockTakeItemModel(
      takeItemId: takeItemId,
      takeId: takeId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      variantInfo: variantInfo,
      systemQty: systemQty ?? this.systemQty,
      countedQty: countedQty ?? this.countedQty,
      costPrice: costPrice ?? this.costPrice,
      // Re-stamped on every edit: a recount is a new count, and the old
      // timestamp would misdate the snapshot that systemQty belongs to.
      countedAt: DateTime.now().toIso8601String(),
      appliedQty: appliedQty ?? this.appliedQty,
    );
  }

  Map<String, dynamic> toMap() => {
        'takeItemId': takeItemId,
        'takeId': takeId,
        'variantId': variantId,
        'productId': productId,
        'productName': productName,
        'variantInfo': variantInfo,
        'systemQty': systemQty,
        'countedQty': countedQty,
        'costPrice': costPrice,
        'countedAt': countedAt,
        'appliedQty': appliedQty,
      };

  factory StockTakeItemModel.fromMap(Map<String, dynamic> map) =>
      StockTakeItemModel(
        takeItemId: map['takeItemId'] as String,
        takeId: map['takeId'] as String? ?? '',
        variantId: map['variantId'] as String? ?? '',
        productId: map['productId'] as String? ?? '',
        productName: map['productName'] as String?,
        variantInfo: map['variantInfo'] as String?,
        systemQty: (map['systemQty'] as num?)?.toInt() ?? 0,
        countedQty: (map['countedQty'] as num?)?.toInt() ?? 0,
        costPrice: (map['costPrice'] as num?)?.toDouble(),
        countedAt:
            map['countedAt'] as String? ?? DateTime.now().toIso8601String(),
        appliedQty: (map['appliedQty'] as num?)?.toInt(),
      );
}
