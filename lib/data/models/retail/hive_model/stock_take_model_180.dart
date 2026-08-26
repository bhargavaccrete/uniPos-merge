import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';

part 'stock_take_model_180.g.dart';

const _uuid = Uuid();

/// Stock take lifecycle.
/// - draft: being counted; nothing has touched stock yet
/// - completed: variances committed as stock adjustments, terminal
/// - cancelled: abandoned without committing, terminal
enum StockTakeStatus {
  draft,
  completed,
  cancelled,
}

/// Stock Take — a physical count session.
///
/// **A draft moves nothing.** Counting is data entry; stock only changes when
/// the take is committed, and even then not by this model. Commit walks the
/// lines and calls `StockAdjustmentService.adjust` for each variance, so a
/// counted correction produces exactly the same audit row and loss treatment as
/// a single-variant adjustment. These boxes hold paperwork, never stock.
///
/// **Committing is terminal and one-way.** There is no re-open: the adjustments
/// it produced are already facts in the movement log, so re-committing would
/// double-apply them. A wrong count is fixed by a new take, the same way a
/// wrong adjustment is fixed by another adjustment.
///
/// Header/lines are split across two boxes, matching the PO/GRN and
/// return/claim pairs — a take can hold hundreds of lines and the list screen
/// only needs the header.
@HiveType(typeId: HiveTypeIds.retailStockTake)
class StockTakeModel extends HiveObject {
  @HiveField(0)
  final String takeId;

  /// `ST-20260820-001`, from DocumentNumberService.
  @HiveField(1)
  final String takeNumber;

  @HiveField(2)
  final String status; // StockTakeStatus as string

  /// Optional label so a shop can say what was counted ("Aisle 3", "Shirts").
  @HiveField(3)
  final String? scopeNote;

  /// Reason applied to every variance line at commit.
  ///
  /// One reason for the whole take rather than per line: a shopkeeper counting
  /// a shelf knows why the shelf is off, not why each SKU is. Stored so the
  /// completed record explains itself without re-deriving from the movements.
  ///
  /// Null while draft. See `StockAdjustmentReason`.
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

  /// Set when the take reached [StockTakeStatus.completed].
  @HiveField(9)
  final String? completedAt;

  /// Lines that actually moved stock at commit. Stored rather than recounted
  /// because later movements change what the lines would look like today.
  @HiveField(10)
  final int? committedLineCount;

  /// Net units applied at commit — negative when the count found less than the
  /// system claimed, which is the usual direction.
  @HiveField(11)
  final double? committedNetQty;

  StockTakeModel({
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

  factory StockTakeModel.create({
    required String takeNumber,
    required String countedBy,
    String? scopeNote,
  }) {
    final now = DateTime.now().toIso8601String();
    return StockTakeModel(
      takeId: _uuid.v4(),
      takeNumber: takeNumber,
      status: StockTakeStatus.draft.name,
      scopeNote: scopeNote,
      countedBy: countedBy,
      createdAt: now,
      updatedAt: now,
    );
  }

  StockTakeStatus get statusEnum => StockTakeStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => StockTakeStatus.draft,
      );

  bool get isDraft => statusEnum == StockTakeStatus.draft;
  bool get isCompleted => statusEnum == StockTakeStatus.completed;
  bool get isCancelled => statusEnum == StockTakeStatus.cancelled;

  /// Only a draft can still be counted or committed.
  bool get isEditable => isDraft;

  String get statusDisplay {
    switch (statusEnum) {
      case StockTakeStatus.draft:
        return 'Draft';
      case StockTakeStatus.completed:
        return 'Completed';
      case StockTakeStatus.cancelled:
        return 'Cancelled';
    }
  }

  StockTakeModel copyWith({
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
    return StockTakeModel(
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

  factory StockTakeModel.fromMap(Map<String, dynamic> map) => StockTakeModel(
        takeId: map['takeId'] as String,
        takeNumber: map['takeNumber'] as String? ?? '',
        status: map['status'] as String? ?? StockTakeStatus.draft.name,
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
