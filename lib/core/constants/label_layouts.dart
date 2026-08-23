/// Geometry of the one A4 sticker sheet retail label printing supports.
///
/// **V1 deliberately supports exactly ONE layout.** A wrong pitch wastes a whole
/// sheet of stickers, so one reliable, tested geometry beats several
/// approximate ones. Multiple layouts and custom sizing are V2 — when they
/// arrive, this file grows a list and the geometry below becomes its first
/// entry; nothing else needs to move.
///
/// Matches **Avery L7651** and the common Indian 65-up equivalent, so a shop can
/// buy sheets that line up without measuring anything.
///
/// Pure Dart (no Flutter/pdf import) so it can be unit-tested and read from
/// anywhere, matching the other files in this folder.
class LabelLayout {
  /// Shown to the user, and printed on nothing.
  final String name;

  /// Reference product code, so matching stationery is easy to source.
  final String reference;

  final int columns;
  final int rows;

  /// One label, in millimetres.
  final double labelWidthMm;
  final double labelHeightMm;

  /// Distance from the sheet edge to the first label, in millimetres.
  final double marginLeftMm;
  final double marginTopMm;

  /// Gap BETWEEN adjacent labels, in millimetres. Zero is normal vertically on
  /// die-cut sheets.
  final double columnGapMm;
  final double rowGapMm;

  const LabelLayout({
    required this.name,
    required this.reference,
    required this.columns,
    required this.rows,
    required this.labelWidthMm,
    required this.labelHeightMm,
    required this.marginLeftMm,
    required this.marginTopMm,
    required this.columnGapMm,
    required this.rowGapMm,
  });

  /// Labels on one sheet.
  int get perPage => columns * rows;

  /// Centre-to-centre spacing, i.e. label size plus gap.
  double get columnPitchMm => labelWidthMm + columnGapMm;
  double get rowPitchMm => labelHeightMm + rowGapMm;

  /// Width/height the grid occupies, excluding the leading margin.
  double get gridWidthMm => columns * labelWidthMm + (columns - 1) * columnGapMm;
  double get gridHeightMm => rows * labelHeightMm + (rows - 1) * rowGapMm;

  /// Sheets needed for [labelCount] labels. Zero labels means zero sheets, so a
  /// caller can render "0 pages" rather than an empty sheet.
  int pagesFor(int labelCount) {
    if (labelCount <= 0) return 0;
    return (labelCount + perPage - 1) ~/ perPage;
  }

  /// Does the grid fit the page it is meant for? Guards a future edit that
  /// changes one number and silently pushes the last column off the paper.
  bool fitsWithin({required double pageWidthMm, required double pageHeightMm}) =>
      marginLeftMm + gridWidthMm <= pageWidthMm &&
      marginTopMm + gridHeightMm <= pageHeightMm;
}

/// A4 in millimetres, for [LabelLayout.fitsWithin].
const double kA4WidthMm = 210.0;
const double kA4HeightMm = 297.0;

/// The single supported V1 layout: 65 labels per A4 sheet.
///
/// 5 x 13 of 38.1 x 21.2 mm. Horizontal gap 2.5 mm, no vertical gap; margins
/// work out symmetric (left 4.7 / right 4.8, top and bottom 10.7).
const LabelLayout kLabelLayout65Up = LabelLayout(
  name: '65 labels per A4 sheet',
  reference: 'Avery L7651 (38.1 x 21.2 mm)',
  columns: 5,
  rows: 13,
  labelWidthMm: 38.1,
  labelHeightMm: 21.2,
  marginLeftMm: 4.7,
  marginTopMm: 10.7,
  columnGapMm: 2.5,
  rowGapMm: 0,
);
