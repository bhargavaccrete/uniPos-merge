/// Pure parsing + validation layer for the retail bulk-product import.
///
/// Deliberately depends on NOTHING but `item_units.dart` — no Hive, no GetIt,
/// no MobX, no Flutter. [BulkImportStore] owns every side effect; this file only
/// turns a raw sheet into validated value objects plus a list of issues. That
/// split is what makes the importer testable: the project has no mocking
/// framework, so anything touching a Box or the service locator could only be
/// exercised through a real Hive instance.
///
/// Catalogue-aware rules (is this barcode already in the DB? does a product of
/// this name already exist?) arrive as plain closures on
/// [RetailImportCatalogue], so tests supply a fake without any mocking package.
library;

import 'package:billberrylite/core/config/tariff_code_rule.dart';
import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/core/constants/item_units.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Columns
// ─────────────────────────────────────────────────────────────────────────────

/// Every column of the Products sheet, in template order.
///
/// Grouped by OWNERSHIP, which is the sheet's one real rule: identity, then the
/// product-level block that is read from the first row of each Handle only,
/// then the per-variant columns. Unit deliberately precedes Stock — it is what
/// decides whether a fractional Stock is legal, so a shop should meet it first.
///
/// This order is free to change: it is the *display* order only. What a file
/// without readable headers is measured against is [_legacyPositions], which is
/// frozen. Adding a column here therefore no longer has to mean appending it.
enum RetailImportColumn {
  handle,
  name,
  category,
  description,
  // ── Product-level: first row of each Handle only ──
  unit,
  taxRate,
  hsnCode,
  expiryDate,
  // ── Variant identity ──
  option1Name,
  option1Value,
  option2Name,
  option2Value,
  option3Name,
  option3Value,
  option4Name,
  option4Value,
  option5Name,
  option5Value,
  sku,
  barcode,
  // ── Variant numbers ──
  costPrice,
  sellingPrice,
  mrp,
  stock,
  minStock,
}

/// Where each column sat in the original 21-column template — FROZEN.
///
/// Used only as the fallback for a file whose header row cannot be read, which
/// in practice means a workbook downloaded or hand-made before the columns were
/// regrouped. Decoupling this from `RetailImportColumn.index` is what makes the
/// display order above safe to change.
///
/// Columns added after that layout (Option4/5) have no legacy position and map
/// to -1, which [_HeaderMap.cell] reads as "absent" rather than reaching into
/// whatever now occupies that index.
const Map<RetailImportColumn, int> _legacyPositions = {
  RetailImportColumn.handle: 0,
  RetailImportColumn.name: 1,
  RetailImportColumn.category: 2,
  RetailImportColumn.description: 3,
  RetailImportColumn.option1Name: 4,
  RetailImportColumn.option1Value: 5,
  RetailImportColumn.option2Name: 6,
  RetailImportColumn.option2Value: 7,
  RetailImportColumn.option3Name: 8,
  RetailImportColumn.option3Value: 9,
  RetailImportColumn.costPrice: 10,
  RetailImportColumn.sellingPrice: 11,
  RetailImportColumn.mrp: 12,
  RetailImportColumn.stock: 13,
  RetailImportColumn.barcode: 14,
  RetailImportColumn.minStock: 15,
  RetailImportColumn.taxRate: 16,
  RetailImportColumn.hsnCode: 17,
  RetailImportColumn.sku: 18,
  RetailImportColumn.unit: 19,
  RetailImportColumn.expiryDate: 20,
};

/// Header text written into row 1 of the Products sheet. `*` marks required.
///
/// Single source of truth — `RetailImportTemplateBuilder` writes these and the
/// parser reads them back, so the two can never drift apart.
const Map<RetailImportColumn, String> kRetailImportHeaders = {
  RetailImportColumn.handle: 'Handle*',
  RetailImportColumn.name: 'Name*',
  RetailImportColumn.category: 'Category*',
  RetailImportColumn.description: 'Description',
  RetailImportColumn.unit: 'Unit',
  RetailImportColumn.taxRate: 'Tax Rate',
  RetailImportColumn.hsnCode: 'HSN Code',
  RetailImportColumn.expiryDate: 'Expiry Date',
  RetailImportColumn.option1Name: 'Option1 Name',
  RetailImportColumn.option1Value: 'Option1 Value',
  RetailImportColumn.option2Name: 'Option2 Name',
  RetailImportColumn.option2Value: 'Option2 Value',
  RetailImportColumn.option3Name: 'Option3 Name',
  RetailImportColumn.option3Value: 'Option3 Value',
  RetailImportColumn.option4Name: 'Option4 Name',
  RetailImportColumn.option4Value: 'Option4 Value',
  RetailImportColumn.option5Name: 'Option5 Name',
  RetailImportColumn.option5Value: 'Option5 Value',
  RetailImportColumn.sku: 'SKU',
  RetailImportColumn.barcode: 'Barcode',
  RetailImportColumn.costPrice: 'Cost Price',
  RetailImportColumn.sellingPrice: 'Selling Price*',
  RetailImportColumn.mrp: 'MRP',
  RetailImportColumn.stock: 'Stock',
  RetailImportColumn.minStock: 'Min Stock',
};

/// Display label for one header cell.
///
/// Two columns are named differently per country, and both keep their canonical
/// spelling in [kRetailImportHeaders] as the storage-side name:
///  * the tariff code — HSN in India, HTS in the US, CN/TARIC across the EU;
///  * the tax — GST in India, VAT across the EU/UK, Sales Tax in the US.
///
/// Every country's spelling is accepted on read via [_headerAliases], so a
/// template generated in one country still imports on a device set to another.
String retailImportHeaderLabel(RetailImportColumn column) => switch (column) {
  RetailImportColumn.hsnCode => TariffCodeRule.label,
  RetailImportColumn.taxRate => '${TaxLabelRule.name} Rate',
  _ => kRetailImportHeaders[column]!,
};

/// The ordered header row, for the template builder.
List<String> get kRetailImportHeaderRow =>
    RetailImportColumn.values.map(retailImportHeaderLabel).toList(
          growable: false,
        );

/// Extra spellings accepted when reading a hand-made file. The canonical header
/// always matches first; these only widen what a shop is allowed to type.
const Map<String, RetailImportColumn> _headerAliases = {
  'productname': RetailImportColumn.name,
  'itemname': RetailImportColumn.name,
  'productcode': RetailImportColumn.sku,
  'price': RetailImportColumn.sellingPrice,
  'sellprice': RetailImportColumn.sellingPrice,
  'cost': RetailImportColumn.costPrice,
  'openingstock': RetailImportColumn.stock,
  'qty': RetailImportColumn.stock,
  'quantity': RetailImportColumn.stock,
  'minimumstock': RetailImportColumn.minStock,
  'reorderpoint': RetailImportColumn.minStock,
  'uom': RetailImportColumn.unit,
  'unitofmeasure': RetailImportColumn.unit,
  'expiry': RetailImportColumn.expiryDate,
  // Every country's name for the tax column, for the same reason as the tariff
  // codes below — the header is written as "GST Rate" / "VAT Rate" / "Sales Tax
  // Rate" depending on where the template was generated. See
  // [retailImportHeaderLabel].
  'tax': RetailImportColumn.taxRate,
  'taxpercent': RetailImportColumn.taxRate,
  'taxpercentage': RetailImportColumn.taxRate,
  'gst': RetailImportColumn.taxRate,
  'gstrate': RetailImportColumn.taxRate,
  'vat': RetailImportColumn.taxRate,
  'vatrate': RetailImportColumn.taxRate,
  'salestax': RetailImportColumn.taxRate,
  'salestaxrate': RetailImportColumn.taxRate,
  // Every country's name for the tariff-code column, so a template downloaded
  // in one country still imports on a device set to another. See
  // [retailImportHeaderLabel].
  'hsn': RetailImportColumn.hsnCode,
  'hsncode': RetailImportColumn.hsnCode,
  'hs': RetailImportColumn.hsnCode,
  'hscode': RetailImportColumn.hsnCode,
  'hts': RetailImportColumn.hsnCode,
  'htscode': RetailImportColumn.hsnCode,
  'commodity': RetailImportColumn.hsnCode,
  'commoditycode': RetailImportColumn.hsnCode,
  'tariff': RetailImportColumn.hsnCode,
  'tariffcode': RetailImportColumn.hsnCode,
  'hstariffcode': RetailImportColumn.hsnCode,
  'ahtn': RetailImportColumn.hsnCode,
  'ahtncode': RetailImportColumn.hsnCode,
  'hsahtncode': RetailImportColumn.hsnCode,
  'customscode': RetailImportColumn.hsnCode,
  'hscustomscode': RetailImportColumn.hsnCode,
  'cn': RetailImportColumn.hsnCode,
  'cncode': RetailImportColumn.hsnCode,
  'taric': RetailImportColumn.hsnCode,
  'tariccode': RetailImportColumn.hsnCode,
  'cntariccode': RetailImportColumn.hsnCode,
};

/// The one spelling of a tax dropdown entry: `"GST (5%)"`, `"VAT (12.5%)"`.
///
/// Shared by the template builder (which writes it) and
/// `BulkImportStore._resolveTaxFromLabel` (which matches it back to a Tax
/// entity by exact string). Keeping the two ends on one function is what stops
/// a rate rendering as `5.0` on one side and `5` on the other — a mismatch
/// there still imports, but silently drops the `taxId` link and keeps only the
/// raw rate.
///
/// A whole rate loses its `.0`; a fractional one keeps its digits.
String retailTaxLabel(String name, num rate) {
  final value = rate.toDouble();
  final text = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  return '$name ($text%)';
}

/// Reduces a header cell to a comparison key: case, spacing, punctuation and
/// the `*` required-marker all stop mattering.
String _headerKey(String raw) =>
    raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

/// Resolves a column to its index within one particular file.
class _HeaderMap {
  final Map<RetailImportColumn, int> _byColumn;

  const _HeaderMap(this._byColumn);

  /// Builds a map from [headerRow], falling back to [_legacyPositions] for any
  /// column the row does not name. A row is only trusted as headers when it
  /// names at least Handle, Name and Selling Price — otherwise the file has no
  /// header row worth reading and everything stays positional, exactly as the
  /// importer behaved before.
  ///
  /// The fallback targets the ORIGINAL layout, not the current one: a file the
  /// parser cannot read the headers of is an old or hand-made file, and the
  /// current template's own instructions tell shops not to delete row 1.
  factory _HeaderMap.from(List<dynamic> headerRow) {
    final found = <RetailImportColumn, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final key = _headerKey(headerRow[i].toString());
      if (key.isEmpty) continue;
      RetailImportColumn? column;
      for (final entry in kRetailImportHeaders.entries) {
        if (_headerKey(entry.value) == key) {
          column = entry.key;
          break;
        }
      }
      column ??= _headerAliases[key];
      // First occurrence wins, so a stray duplicate header cannot shadow the
      // real column.
      if (column != null && !found.containsKey(column)) found[column] = i;
    }

    final recognised =
        found.containsKey(RetailImportColumn.handle) &&
        found.containsKey(RetailImportColumn.name) &&
        found.containsKey(RetailImportColumn.sellingPrice);
    if (!recognised) return _HeaderMap.positional();

    for (final column in RetailImportColumn.values) {
      found.putIfAbsent(column, () => _legacyPositions[column] ?? -1);
    }
    return _HeaderMap(found);
  }

  factory _HeaderMap.positional() => _HeaderMap({
    for (final c in RetailImportColumn.values) c: _legacyPositions[c] ?? -1,
  });

  int indexOf(RetailImportColumn column) => _byColumn[column]!;

  String cell(List<dynamic> row, RetailImportColumn column) {
    final i = indexOf(column);
    if (i < 0 || i >= row.length) return '';
    return row[i].toString().trim();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results
// ─────────────────────────────────────────────────────────────────────────────

/// Errors reject; notices are informational and still import.
enum RetailImportSeverity { error, notice }

/// One finding, always anchored to the sheet row the shop can go and fix.
class RetailImportIssue {
  /// 1-based row number, as Excel shows it.
  final int rowNumber;
  final String column;
  final String message;
  final RetailImportSeverity severity;

  const RetailImportIssue({
    required this.rowNumber,
    required this.column,
    required this.message,
    this.severity = RetailImportSeverity.error,
  });

  bool get isError => severity == RetailImportSeverity.error;

  @override
  String toString() => column.isEmpty
      ? 'Row $rowNumber: $message'
      : 'Row $rowNumber ($column): $message';
}

/// One validated variant row.
class RetailImportVariantRow {
  final int rowNumber;
  final String? sku;
  final String? barcode;
  final double? costPrice;
  final double sellingPrice;
  final double? mrp;
  final double stockQty;
  final double minStock;
  final Map<String, String> attributes;

  const RetailImportVariantRow({
    required this.rowNumber,
    required this.sellingPrice,
    required this.stockQty,
    required this.minStock,
    required this.attributes,
    this.sku,
    this.barcode,
    this.costPrice,
    this.mrp,
  });

  /// Order-independent, case-insensitive identity of this variant's attribute
  /// combination — two variants of one product may not share it.
  String get attributeKey => attributeSignature(attributes);
}

/// Canonical key for an attribute combination. Shared with the store so the
/// in-file check and the against-the-catalogue check agree on what counts as
/// "the same variant".
String attributeSignature(Map<String, String>? attributes) {
  if (attributes == null || attributes.isEmpty) return '';
  final parts =
      attributes.entries
          .map(
            (e) =>
                '${e.key.trim().toLowerCase()}=${e.value.trim().toLowerCase()}',
          )
          .toList()
        ..sort();
  return parts.join('|');
}

/// One product's worth of rows: the parent row's product-level values plus
/// every variant row sharing its Handle.
class RetailImportGroup {
  final String handle;
  final int parentRowNumber;
  final String name;
  final String categoryName;
  final String? description;
  final String taxLabel;
  final String? hsnCode;

  /// Canonical [kItemUnits] value. Product-level and applied to every variant —
  /// see `add_product_screen.dart:522-543`, which force-writes the screen's one
  /// value onto all of them on save. A per-variant column would be flattened by
  /// the first edit-and-save.
  final String unit;

  /// ISO8601 at local midnight, or null for "never expires".
  final String? expiryDate;

  final List<RetailImportVariantRow> variants;

  const RetailImportGroup({
    required this.handle,
    required this.parentRowNumber,
    required this.name,
    required this.categoryName,
    required this.unit,
    required this.variants,
    this.description,
    this.taxLabel = '',
    this.hsnCode,
    this.expiryDate,
  });

  /// Derived from [unit], never imported independently, so "decimal quantity on
  /// a pcs product" is not expressible in the first place.
  bool get isDecimalQuantity => unit != 'piece';

  /// Mirrors the pre-existing rule: more than one row, or an option present.
  bool get hasVariants =>
      variants.length > 1 || variants.any((v) => v.attributes.isNotEmpty);
}

/// How one group's rows divide once an existing product of the same name is
/// found: [toCreate] are genuinely new variants, [alreadyPresent] are ones the
/// product already has and which must be skipped rather than duplicated.
class RetailImportVariantSplit {
  final List<RetailImportVariantRow> toCreate;
  final List<RetailImportVariantRow> alreadyPresent;

  const RetailImportVariantSplit({
    required this.toCreate,
    required this.alreadyPresent,
  });
}

/// Decides which of [group]'s variants a product already holding
/// [existingKeys] still needs. Pure, so the "existing product + new variant"
/// and "existing product + existing variant" rules are testable without Hive.
RetailImportVariantSplit splitAgainstExisting(
  RetailImportGroup group,
  Set<String> existingKeys,
) {
  final toCreate = <RetailImportVariantRow>[];
  final alreadyPresent = <RetailImportVariantRow>[];
  // Tracks keys added during this split too, so two identical rows cannot both
  // slip through when the product did not have that combination before.
  final seen = <String>{...existingKeys};

  for (final variant in group.variants) {
    if (seen.add(variant.attributeKey)) {
      toCreate.add(variant);
    } else {
      alreadyPresent.add(variant);
    }
  }
  return RetailImportVariantSplit(
    toCreate: toCreate,
    alreadyPresent: alreadyPresent,
  );
}

/// Everything one parse produced.
class RetailImportParseResult {
  /// Groups with no errors — the only ones that may be written.
  final List<RetailImportGroup> groups;

  /// Errors and notices, in row order.
  final List<RetailImportIssue> issues;

  /// Handles rejected outright, for the summary count.
  final int rejectedGroupCount;

  /// Data rows seen, excluding header and instruction rows.
  final int dataRowCount;

  const RetailImportParseResult({
    required this.groups,
    required this.issues,
    required this.rejectedGroupCount,
    required this.dataRowCount,
  });

  List<RetailImportIssue> get errors => issues.where((i) => i.isError).toList();

  List<RetailImportIssue> get notices =>
      issues.where((i) => !i.isError).toList();

  int get variantCount => groups.fold(0, (sum, g) => sum + g.variants.length);

  Set<String> get categoryNames =>
      groups.map((g) => g.categoryName).where((c) => c.isNotEmpty).toSet();

  bool get hasAnythingToImport => groups.isNotEmpty;
}

/// The catalogue rules the parser cannot know on its own. The defaults answer
/// "nothing exists yet", which is what a pure unit test wants.
class RetailImportCatalogue {
  /// True when [barcode] already belongs to a variant in the database.
  final bool Function(String barcode) isBarcodeTaken;

  /// Attribute signatures already used by an existing product of this name, or
  /// null when no such product exists. Used only to warn during the preview —
  /// the store re-checks at write time.
  final Set<String>? Function(String productName) existingVariantKeys;

  const RetailImportCatalogue({
    required this.isBarcodeTaken,
    required this.existingVariantKeys,
  });

  static final RetailImportCatalogue empty = RetailImportCatalogue(
    isBarcodeTaken: (_) => false,
    existingVariantKeys: (_) => null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Parser
// ─────────────────────────────────────────────────────────────────────────────

class RetailImportParser {
  const RetailImportParser._();

  /// Parses and validates the whole sheet WITHOUT writing anything.
  ///
  /// [rows] is the raw sheet including its header row, exactly as
  /// `BulkImportStore.parsedRows` holds it. Row numbers in the returned issues
  /// are 1-based so they line up with what Excel shows.
  static RetailImportParseResult parse(
    List<List<dynamic>> rows, {
    RetailImportCatalogue? catalogue,
  }) {
    final cat = catalogue ?? RetailImportCatalogue.empty;
    final issues = <RetailImportIssue>[];

    if (rows.isEmpty) {
      return const RetailImportParseResult(
        groups: [],
        issues: [],
        rejectedGroupCount: 0,
        dataRowCount: 0,
      );
    }

    final headers = _HeaderMap.from(rows.first);

    // Row 1 is headers. The downloaded template adds a yellow instruction row
    // at row 2; a hand-typed file has none, so it is detected rather than
    // assumed.
    var firstDataIndex = 1;
    if (rows.length > 1 && _looksLikeInstructionRow(rows[1], headers)) {
      firstDataIndex = 2;
    }

    // Grouping preserves first-seen order so the log reads top-to-bottom.
    final grouped = <String, List<_ParsedRow>>{};
    final order = <String>[];
    var dataRowCount = 0;

    for (var i = firstDataIndex; i < rows.length; i++) {
      final row = rows[i];
      final rowNumber = i + 1;
      if (row.every((c) => c.toString().trim().isEmpty)) continue;
      dataRowCount++;

      final handle = headers.cell(row, RetailImportColumn.handle);
      if (handle.isEmpty) {
        // These previously vanished without a trace.
        issues.add(
          RetailImportIssue(
            rowNumber: rowNumber,
            column: 'Handle',
            message: 'Handle is required — row skipped.',
          ),
        );
        continue;
      }

      final key = handle.toLowerCase();
      grouped
          .putIfAbsent(key, () {
            order.add(key);
            return <_ParsedRow>[];
          })
          .add(_ParsedRow(rowNumber, row, handle));
    }

    final groups = <RetailImportGroup>[];
    // Barcodes must be unique across the WHOLE file, not just within a group.
    final seenBarcodes = <String, int>{};
    var rejected = 0;

    for (final key in order) {
      final groupIssues = <RetailImportIssue>[];
      final group = _buildGroup(
        grouped[key]!,
        headers,
        cat,
        seenBarcodes,
        groupIssues,
      );
      issues.addAll(groupIssues);
      if (group == null || groupIssues.any((i) => i.isError)) {
        rejected++;
      } else {
        groups.add(group);
      }
    }

    issues.sort((a, b) => a.rowNumber.compareTo(b.rowNumber));

    return RetailImportParseResult(
      groups: groups,
      issues: issues,
      rejectedGroupCount: rejected,
      dataRowCount: dataRowCount,
    );
  }

  /// True when row 2 is the template's yellow instruction row rather than data.
  ///
  /// A non-numeric Selling Price alone is NOT enough to decide this: a single
  /// product whose price is mistyped would then be classified as instructions
  /// and vanish without a word. So corroboration is required — the instruction
  /// row also carries prose in the other numeric columns ("Optional",
  /// "Optional, defaults to 0"), which real data never does.
  ///
  /// When in doubt the row is treated as DATA, so the worst case is a visible
  /// row error rather than a silently dropped product.
  static bool _looksLikeInstructionRow(List<dynamic> row, _HeaderMap headers) {
    final price = headers.cell(row, RetailImportColumn.sellingPrice);
    if (price.isEmpty || _number(price) != null) return false;

    const corroborating = [
      RetailImportColumn.costPrice,
      RetailImportColumn.mrp,
      RetailImportColumn.stock,
      RetailImportColumn.minStock,
    ];
    final prose = corroborating.where((c) {
      final cell = headers.cell(row, c);
      return cell.isNotEmpty && _number(cell) == null;
    }).length;

    return prose >= 2;
  }

  static RetailImportGroup? _buildGroup(
    List<_ParsedRow> rows,
    _HeaderMap headers,
    RetailImportCatalogue catalogue,
    Map<String, int> seenBarcodes,
    List<RetailImportIssue> issues,
  ) {
    final parent = rows.first;

    void error(int rowNumber, String column, String message) => issues.add(
      RetailImportIssue(rowNumber: rowNumber, column: column, message: message),
    );

    void notice(int rowNumber, String column, String message) => issues.add(
      RetailImportIssue(
        rowNumber: rowNumber,
        column: column,
        message: message,
        severity: RetailImportSeverity.notice,
      ),
    );

    final name = headers.cell(parent.cells, RetailImportColumn.name);
    if (name.isEmpty) {
      error(
        parent.rowNumber,
        'Name',
        'Product Name is required on the first row of each Handle.',
      );
    }

    // ── Product-level values, parent row only ────────────────────────────────
    final categoryName = headers.cell(
      parent.cells,
      RetailImportColumn.category,
    );
    final description = headers.cell(
      parent.cells,
      RetailImportColumn.description,
    );
    final taxLabel = headers.cell(parent.cells, RetailImportColumn.taxRate);
    final hsnCode = headers.cell(parent.cells, RetailImportColumn.hsnCode);

    final rawUnit = headers.cell(parent.cells, RetailImportColumn.unit);
    var unit = 'piece';
    if (rawUnit.isNotEmpty) {
      final normalised = normalizeItemUnit(rawUnit);
      if (normalised == null) {
        error(
          parent.rowNumber,
          'Unit',
          'Unrecognised unit "$rawUnit" — use one of: ${kItemUnits.join(', ')}.',
        );
      } else {
        unit = normalised;
      }
    }
    final isDecimal = unit != 'piece';

    final rawExpiry = headers.cell(parent.cells, RetailImportColumn.expiryDate);
    String? expiryDate;
    if (rawExpiry.isNotEmpty) {
      final parsed = parseImportDate(rawExpiry);
      if (parsed == null) {
        error(
          parent.rowNumber,
          'Expiry Date',
          'Could not read "$rawExpiry" as a date — use YYYY-MM-DD.',
        );
      } else {
        expiryDate = parsed.toIso8601String();
      }
    }

    // Later rows of the same Handle cannot carry different product-level
    // values; say so rather than silently using the parent's.
    for (final row in rows.skip(1)) {
      void warnIfDifferent(RetailImportColumn column, String parentValue) {
        final value = headers.cell(row.cells, column);
        if (value.isEmpty) return;
        if (value.toLowerCase() == parentValue.toLowerCase()) return;
        notice(
          row.rowNumber,
          retailImportHeaderLabel(column).replaceAll('*', ''),
          'Product-level value "$value" ignored — the first row of '
          '"${parent.handle}" applies to the whole product.',
        );
      }

      warnIfDifferent(RetailImportColumn.unit, rawUnit);
      warnIfDifferent(RetailImportColumn.expiryDate, rawExpiry);
      warnIfDifferent(RetailImportColumn.taxRate, taxLabel);
      warnIfDifferent(RetailImportColumn.hsnCode, hsnCode);
    }

    // ── Variant rows ─────────────────────────────────────────────────────────
    final variants = <RetailImportVariantRow>[];
    final seenAttributeKeys = <String, int>{};
    final existingKeys = name.isEmpty
        ? null
        : catalogue.existingVariantKeys(name);

    // Five option TYPES per product. Storage is not the limit — a variant's
    // attributes are a plain map, and the importer mints any attribute it has
    // not seen — so this is only how wide the sheet is willing to be. More
    // option VALUES (S/M/L/XL) never needs another pair; it needs another ROW.
    const optionColumns = [
      (
        RetailImportColumn.option1Name,
        RetailImportColumn.option1Value,
        'Option1',
      ),
      (
        RetailImportColumn.option2Name,
        RetailImportColumn.option2Value,
        'Option2',
      ),
      (
        RetailImportColumn.option3Name,
        RetailImportColumn.option3Value,
        'Option3',
      ),
      (
        RetailImportColumn.option4Name,
        RetailImportColumn.option4Value,
        'Option4',
      ),
      (
        RetailImportColumn.option5Name,
        RetailImportColumn.option5Value,
        'Option5',
      ),
    ];

    for (final row in rows) {
      final n = row.rowNumber;

      final sellingPrice = _requireNumber(
        headers.cell(row.cells, RetailImportColumn.sellingPrice),
        'Selling Price',
        n,
        issues,
        required: true,
      );
      final costPrice = _requireNumber(
        headers.cell(row.cells, RetailImportColumn.costPrice),
        'Cost Price',
        n,
        issues,
      );
      final mrp = _requireNumber(
        headers.cell(row.cells, RetailImportColumn.mrp),
        'MRP',
        n,
        issues,
      );
      final stock = _requireNumber(
        headers.cell(row.cells, RetailImportColumn.stock),
        'Stock',
        n,
        issues,
        wholeOnly: !isDecimal,
        unit: unit,
      );
      final minStock = _requireNumber(
        headers.cell(row.cells, RetailImportColumn.minStock),
        'Min Stock',
        n,
        issues,
        wholeOnly: !isDecimal,
        unit: unit,
      );

      // ── Attributes ────────────────────────────────────────────────────────
      final attributes = <String, String>{};
      for (final (nameCol, valueCol, label) in optionColumns) {
        final attrName = headers.cell(row.cells, nameCol);
        final attrValue = headers.cell(row.cells, valueCol);
        if (attrName.isEmpty && attrValue.isEmpty) continue;
        if (attrName.isEmpty || attrValue.isEmpty) {
          error(
            n,
            '$label Name/Value',
            '$label needs both a name and a value '
                '(got name "$attrName", value "$attrValue").',
          );
          continue;
        }
        if (attributes.keys.any(
          (k) => k.toLowerCase() == attrName.toLowerCase(),
        )) {
          error(
            n,
            '$label Name',
            'Option "$attrName" is used twice on this row.',
          );
          continue;
        }
        attributes[attrName] = attrValue;
      }

      final signature = attributeSignature(attributes);
      final firstSeenAt = seenAttributeKeys[signature];
      if (firstSeenAt != null) {
        error(
          n,
          'Options',
          signature.isEmpty
              ? 'Handle "${parent.handle}" has more than one row with no options '
                    '— give each variant its own Option values.'
              : 'This variant combination is already on row $firstSeenAt of '
                    '"${parent.handle}".',
        );
      } else {
        seenAttributeKeys[signature] = n;
      }

      // An identical variant already in the catalogue is NOT an error — the
      // store skips it and says so.
      if (existingKeys != null && existingKeys.contains(signature)) {
        notice(
          n,
          'Options',
          'This variant already exists on "$name" — it will be skipped.',
        );
      }

      // ── Barcode ───────────────────────────────────────────────────────────
      final barcode = headers.cell(row.cells, RetailImportColumn.barcode);
      if (barcode.isNotEmpty) {
        final key = barcode.toLowerCase();
        final duplicateOf = seenBarcodes[key];
        if (duplicateOf != null) {
          error(
            n,
            'Barcode',
            'Barcode "$barcode" is already used on row $duplicateOf of this file.',
          );
        } else {
          seenBarcodes[key] = n;
          if (catalogue.isBarcodeTaken(barcode)) {
            error(
              n,
              'Barcode',
              'Barcode "$barcode" already belongs to another product.',
            );
          }
        }
      }

      final sku = headers.cell(row.cells, RetailImportColumn.sku);

      if (sellingPrice != null) {
        variants.add(
          RetailImportVariantRow(
            rowNumber: n,
            sku: sku.isEmpty ? null : sku,
            barcode: barcode.isEmpty ? null : barcode,
            costPrice: costPrice,
            sellingPrice: sellingPrice,
            mrp: mrp,
            stockQty: stock ?? 0,
            minStock: minStock ?? 5,
            attributes: attributes,
          ),
        );
      }
    }

    if (name.isEmpty || variants.isEmpty) return null;

    return RetailImportGroup(
      handle: parent.handle,
      parentRowNumber: parent.rowNumber,
      name: name,
      categoryName: categoryName,
      description: description.isEmpty ? null : description,
      taxLabel: taxLabel,
      hsnCode: hsnCode.isEmpty ? null : hsnCode,
      unit: unit,
      expiryDate: expiryDate,
      variants: variants,
    );
  }

  /// Strict numeric read. A blank optional cell is null; anything unreadable or
  /// negative is an ERROR, never a silent 0.0.
  static double? _requireNumber(
    String raw,
    String column,
    int rowNumber,
    List<RetailImportIssue> issues, {
    bool required = false,
    bool wholeOnly = false,
    String unit = 'piece',
  }) {
    if (raw.isEmpty) {
      if (required) {
        issues.add(
          RetailImportIssue(
            rowNumber: rowNumber,
            column: column,
            message: '$column is required.',
          ),
        );
      }
      return null;
    }
    final value = _number(raw);
    if (value == null) {
      issues.add(
        RetailImportIssue(
          rowNumber: rowNumber,
          column: column,
          message:
              'Could not read "$raw" as a number — digits only, '
              'no currency symbols or thousands separators.',
        ),
      );
      return null;
    }
    if (value < 0) {
      issues.add(
        RetailImportIssue(
          rowNumber: rowNumber,
          column: column,
          message: '$column cannot be negative (got $raw).',
        ),
      );
      return null;
    }
    if (wholeOnly && value != value.roundToDouble()) {
      issues.add(
        RetailImportIssue(
          rowNumber: rowNumber,
          column: column,
          message:
              'This product is sold in whole $unit, so $column must be a '
              'whole number (got $raw). Set Unit to kg/gm/liter/ml to allow '
              'fractions.',
        ),
      );
      return null;
    }
    return value;
  }

  /// Tolerates a currency symbol and stray spaces; deliberately rejects
  /// thousands separators, whose meaning differs by locale.
  ///
  /// Strips EVERY symbol the app can be configured with, not just the four
  /// Latin ones — a UAE or Japanese shop pasting its own symbol used to get a
  /// null price and a silently dropped row.
  static double? _number(String raw) {
    var cleaned = raw.trim();
    for (final info in CurrencyHelper.currencies.values) {
      cleaned = cleaned.replaceAll(info.symbol, '');
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}

/// Reads an import date and normalises it to LOCAL MIDNIGHT — the
/// representation `add_product_screen.dart:525` already writes.
///
/// Accepts `YYYY-MM-DD` and anything `DateTime.tryParse` understands, which
/// covers the ISO strings the `excel` package produces for real date cells.
/// Ambiguous `DD/MM` vs `MM/DD` forms are deliberately rejected rather than
/// guessed — silently reading 03/04 as the wrong month would expire stock on
/// the wrong day.
DateTime? parseImportDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final parsed =
      DateTime.tryParse(text) ??
      DateTime.tryParse(RegExp(r'\d{4}-\d{2}-\d{2}').stringMatch(text) ?? '');
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

class _ParsedRow {
  final int rowNumber;
  final List<dynamic> cells;
  final String handle;
  const _ParsedRow(this.rowNumber, this.cells, this.handle);
}
