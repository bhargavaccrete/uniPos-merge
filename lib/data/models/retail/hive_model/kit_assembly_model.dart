import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'kit_assembly_model.g.dart';

/// Append-only record of one "assembled a batch" run for a repack/kit
/// variant — e.g. "assembled 10 units of '12-Pack' from bulk stock". Mirrors
/// restaurant's `RecipeProductionModel`. Never edited or deleted. See
/// docs/retail_inventory_system_plan.md §3.2.
@HiveType(typeId: HiveTypeIds.retailKitAssembly)
class RetailKitAssemblyModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bundleId;

  /// The repack/kit variant this assembly run replenished.
  @HiveField(2)
  final String variantId;

  /// Product name captured at save time (survives rename/delete).
  @HiveField(3)
  final String productName;

  @HiveField(4)
  final int batchQty;

  @HiveField(5)
  final DateTime assembledTime;

  @HiveField(6)
  final String? assembledBy;

  /// IDs of the StockMovementModel rows this run created — for a forward
  /// assembly, one 'out' per component consumed and one 'in' for the
  /// assembled variant; for a reversal ([isReversal]), the opposite.
  @HiveField(7)
  final List<String> movementIds;

  /// True when this row is a disassembly (kit broken back down into
  /// components) rather than a forward assembly — e.g. a customer return of
  /// an already-assembled kit. [batchQty] stays positive either way; this
  /// flag is what the history screen uses to show direction. Nullable so
  /// every assembly recorded before this field existed deserializes as a
  /// forward assembly (`false`), matching its historical meaning.
  @HiveField(8, defaultValue: false)
  final bool isReversal;

  RetailKitAssemblyModel({
    required this.id,
    required this.bundleId,
    required this.variantId,
    required this.productName,
    required this.batchQty,
    required this.assembledTime,
    this.assembledBy,
    this.movementIds = const [],
    this.isReversal = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'bundleId': bundleId,
        'variantId': variantId,
        'productName': productName,
        'batchQty': batchQty,
        'assembledTime': assembledTime.toIso8601String(),
        'assembledBy': assembledBy,
        'movementIds': movementIds,
        'isReversal': isReversal,
      };

  factory RetailKitAssemblyModel.fromMap(Map<String, dynamic> map) =>
      RetailKitAssemblyModel(
        id: map['id'] as String,
        bundleId: map['bundleId'] as String,
        variantId: map['variantId'] as String,
        productName: map['productName'] as String,
        batchQty: (map['batchQty'] as num).toInt(),
        assembledTime: DateTime.parse(map['assembledTime'] as String),
        assembledBy: map['assembledBy'] as String?,
        movementIds: (map['movementIds'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        isReversal: map['isReversal'] as bool? ?? false,
      );
}
