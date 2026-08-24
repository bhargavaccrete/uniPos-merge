import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'restaurant_stock_take_model.g.dart';

const _uuid = Uuid();

/// Stock take lifecycle. Mirrors retail's `StockTakeStatus`.
/// - draft: being counted; nothing has touched stock yet
/// - completed: variances committed as stock adjustments, terminal
/// - cancelled: abandoned without committing, terminal
enum RestaurantStockTakeStatus {
  draft,
  completed,
  cancelled,
}

/// Stock Take — a physical count session for raw materials / semi-finished
/// items. Mirrors retail's `StockTakeModel`.
///
/// **A draft moves nothing.** Stock only changes when the take is committed,
/// via `RestaurantStockAdjustmentService.adjust` per line — same audit trail
/// and loss treatment as a single-item adjustment.
///
/// **Committing is terminal and one-way.** A wrong count is fixed by a new
/// take, not by reopening this one.
@HiveType(typeId: HiveTypeIds.restaurantStockTake)
class RestaurantStockTakeModel extends HiveObject {
  @HiveField(0)
  final String takeId;

  /// `ST-20260820-001`, from the shared `DocumentNumberService`.
  @HiveField(1)
  final String takeNumber;

  @HiveField(2)
  final String status; // RestaurantStockTakeStatus as string

  /// Optional label so staff can say what was counted ("Walk-in fridge").
  @HiveField(3)
  final String? scopeNote;

  /// Reason applied to every variance line at commit.
  @HiveField(4)
  final String? varianceReason;

  @HiveField(5)
  final String? note;

  /// Who ran the count — denormalised so history survives a staff rename.
  @HiveField(6)
  final String countedBy;

  @HiveField(7)
  final String createdAt;

  @HiveField(8)
  final String updatedAt;

  @HiveField(9)
  final String? completedAt;

  @HiveField(10)
  final int? committedLineCount;

  /// Net units applied at commit — negative when the count found less than
  /// the system claimed, which is the usual direction.
  @HiveField(11)
  final double? committedNetQty;

  RestaurantStockTakeModel({
    required this.takeId,
    required this.takeNumber,
    required this.status,
    this.scopeNote,
    this.varianceReason,
    this.note,
    required this.countedBy,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.committedLineCount,
    this.committedNetQty,
  });

  factory RestaurantStockTakeModel.create({
    required String takeNumber,
    required String countedBy,
    String? scopeNote,
  }) {
    final now = DateTime.now().toIso8601String();
    return RestaurantStockTakeModel(
      takeId: _uuid.v4(),
      takeNumber: takeNumber,
      status: RestaurantStockTakeStatus.draft.name,
      scopeNote: scopeNote,
      countedBy: countedBy,
      createdAt: now,
      updatedAt: now,
    );
  }

  RestaurantStockTakeStatus get statusEnum =>
      RestaurantStockTakeStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => RestaurantStockTakeStatus.draft,
      );

  bool get isDraft => statusEnum == RestaurantStockTakeStatus.draft;
  bool get isCompleted => statusEnum == RestaurantStockTakeStatus.completed;
  bool get isCancelled => statusEnum == RestaurantStockTakeStatus.cancelled;

  bool get isEditable => isDraft;

  String get statusDisplay {
    switch (statusEnum) {
      case RestaurantStockTakeStatus.draft:
        return 'Draft';
      case RestaurantStockTakeStatus.completed:
        return 'Completed';
      case RestaurantStockTakeStatus.cancelled:
        return 'Cancelled';
    }
  }

  RestaurantStockTakeModel copyWith({
    String? status,
    String? scopeNote,
    String? varianceReason,
    String? note,
    String? completedAt,
    int? committedLineCount,
    double? committedNetQty,
    bool clearScopeNote = false,
    bool clearNote = false,
  }) {
    return RestaurantStockTakeModel(
      takeId: takeId,
      takeNumber: takeNumber,
      status: status ?? this.status,
      scopeNote: clearScopeNote ? null : (scopeNote ?? this.scopeNote),
      varianceReason: varianceReason ?? this.varianceReason,
      note: clearNote ? null : (note ?? this.note),
      countedBy: countedBy,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
      completedAt: completedAt ?? this.completedAt,
      committedLineCount: committedLineCount ?? this.committedLineCount,
      committedNetQty: committedNetQty ?? this.committedNetQty,
    );
  }

  Map<String, dynamic> toMap() => {
        'takeId': takeId,
        'takeNumber': takeNumber,
        'status': status,
        'scopeNote': scopeNote,
        'varianceReason': varianceReason,
        'note': note,
        'countedBy': countedBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'completedAt': completedAt,
        'committedLineCount': committedLineCount,
        'committedNetQty': committedNetQty,
      };

  factory RestaurantStockTakeModel.fromMap(Map<String, dynamic> map) =>
      RestaurantStockTakeModel(
        takeId: map['takeId'] as String,
        takeNumber: map['takeNumber'] as String? ?? '',
        status: map['status'] as String? ?? RestaurantStockTakeStatus.draft.name,
        scopeNote: map['scopeNote'] as String?,
        varianceReason: map['varianceReason'] as String?,
        note: map['note'] as String?,
        countedBy: map['countedBy'] as String? ?? 'Admin',
        createdAt:
            map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        updatedAt:
            map['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
        completedAt: map['completedAt'] as String?,
        committedLineCount: (map['committedLineCount'] as num?)?.toInt(),
        committedNetQty: (map['committedNetQty'] as num?)?.toDouble(),
      );
}
