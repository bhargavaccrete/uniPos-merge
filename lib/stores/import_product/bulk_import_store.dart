import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:mobx/mobx.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/services/retail/retail_import_schema.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/presentation/screens/retail/import_product/retail_import_template_builder.dart';
import 'package:uuid/uuid.dart';

part 'bulk_import_store.g.dart';

/// Turns a picked CSV/XLSX file into raw rows.
///
/// A plain class rather than members of [BulkImportStore] because Dart does not
/// inherit statics through the `class X = _X with _$X` MobX alias — and these
/// need to be reachable (and testable) without constructing a store.
class RetailImportFileReader {
  RetailImportFileReader._();

  /// Reads a CSV file into raw rows. Static and public so the read path is
  /// testable without a file picker.
  static List<List<dynamic>> csvRows(Uint8List bytes) {
    var content = utf8.decode(bytes, allowMalformed: true);
    // Normalise line endings so the converter sees a single EOL form.
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final table = const CsvToListConverter(
      eol: '\n',
      // Keep everything as strings; the parser owns number handling so a
      // stray "1,200" is reported rather than silently reinterpreted.
      shouldParseNumbers: false,
    ).convert(content);

    return table
        .where((row) => row.any((cell) => cell.toString().trim().isNotEmpty))
        .toList();
  }

  /// Reads the Products sheet of an XLSX/XLS file into raw rows.
  static List<List<dynamic>> excelRows(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];

    // Product data lives specifically in "Products", not whichever sheet comes
    // first (that is "Instructions", which silently made every import fail).
    var table = excel.tables['Products'];
    if (table == null) {
      final match = excel.tables.keys.firstWhere(
        (name) => name.toLowerCase() == 'products',
        orElse: () => excel.tables.keys.first,
      );
      table = excel.tables[match];
    }
    if (table == null) return const [];

    final rows = <List<dynamic>>[];
    for (final row in table.rows) {
      final cells = row.map(_cellText).toList();
      if (cells.any((c) => c.toString().isNotEmpty)) rows.add(cells);
    }
    return rows;
  }

  static String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value.toString();
    if (value is DateCellValue) {
      // Rendered as an ISO date so parseImportDate reads it without guessing.
      return DateTime(
        value.year,
        value.month,
        value.day,
      ).toIso8601String().split('T').first;
    }
    if (value is DateTimeCellValue) {
      return DateTime(
        value.year,
        value.month,
        value.day,
      ).toIso8601String().split('T').first;
    }
    return value.toString();
  }
}

/// Counts a finished import, for the results panel.
class RetailImportOutcome {
  final int productsCreated;
  final int productsUpdated;
  final int variantsImported;
  final int variantsSkipped;
  final int rowsRejected;
  final int productsBlockedByLimit;
  final int groupsFailed;

  const RetailImportOutcome({
    this.productsCreated = 0,
    this.productsUpdated = 0,
    this.variantsImported = 0,
    this.variantsSkipped = 0,
    this.rowsRejected = 0,
    this.productsBlockedByLimit = 0,
    this.groupsFailed = 0,
  });

  bool get hadProblems =>
      rowsRejected > 0 || groupsFailed > 0 || productsBlockedByLimit > 0;
}

/// What happened to one Handle group.
enum _GroupResult { created, updated, blockedByLimit, failed }

class BulkImportStore = _BulkImportStore with _$BulkImportStore;

abstract class _BulkImportStore with Store {
  late final VariantRepository _variantRepository;

  _BulkImportStore() {
    // Lazy initialization to prevent early Hive access
    _variantRepository = VariantRepository();
  }

  AttributeStore get _attributeStore => locator<AttributeStore>();

  // ── Observables ───────────────────────────────────────────────────────────

  @observable
  bool isLoading = false;

  @observable
  bool isProcessing = false;

  @observable
  String? errorMessage;

  @observable
  String? successMessage;

  @observable
  double progress = 0.0;

  @observable
  ObservableList<List<dynamic>> parsedRows = ObservableList<List<dynamic>>();

  /// The validated view of [parsedRows]. Produced at pick time so the confirm
  /// dialog can show real row-level errors BEFORE anything is written.
  @observable
  RetailImportParseResult? preview;

  /// Counts of the last completed import.
  @observable
  RetailImportOutcome? outcome;

  @observable
  ObservableList<String> logMessages = ObservableList<String>();

  // ── Template ──────────────────────────────────────────────────────────────

  /// Generate and save the template (Excel .xlsx).
  @action
  Future<String?> downloadTemplate() async {
    isLoading = true;
    errorMessage = null;
    try {
      // Built with Syncfusion xlsio so Category/Tax/Unit get real Excel
      // dropdowns (live-seeded from the shop's own categories and taxes) —
      // same technique as the restaurant side's ImportTemplateBuilder.
      final bytes = RetailImportTemplateBuilder().build();

      const fileName = 'product_import_template.xlsx';

      if (kIsWeb) {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes),
        );
        successMessage = result != null
            ? 'Template downloaded successfully.'
            : 'Download cancelled.';
        return result;
      } else if (Platform.isAndroid || Platform.isIOS) {
        // On Android/iOS bytes are required; FilePicker writes the file itself.
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes),
        );
        successMessage = result != null
            ? 'Template saved to Downloads.'
            : 'Download cancelled.';
        return result;
      } else {
        // Desktop: the picker returns a path, we write the bytes.
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
        if (result != null) {
          await File(result).writeAsBytes(bytes);
          successMessage = 'Template saved successfully.';
        } else {
          successMessage = 'Download cancelled.';
        }
        return result;
      }
    } catch (e) {
      errorMessage = 'Failed to generate template: $e';
      return null;
    } finally {
      isLoading = false;
    }
  }

  // ── Pick + parse ──────────────────────────────────────────────────────────

  /// Pick a file, read it, then validate every row WITHOUT writing anything.
  @action
  Future<void> pickAndParseFile() async {
    isLoading = true;
    errorMessage = null;
    parsedRows.clear();
    preview = null;
    outcome = null;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null) return; // user cancelled

      final file = result.files.first;
      final extension = file.extension?.toLowerCase() ?? '';

      Uint8List? fileBytes = file.bytes;
      // Desktop/native sometimes gives a path instead of bytes.
      if (fileBytes == null && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }
      if (fileBytes == null) {
        throw Exception('Could not read file data. Please try again.');
      }

      if (extension == 'csv') {
        parsedRows.addAll(RetailImportFileReader.csvRows(fileBytes));
      } else if (extension == 'xlsx' || extension == 'xls') {
        parsedRows.addAll(RetailImportFileReader.excelRows(fileBytes));
      } else {
        throw Exception('Unsupported file format: $extension');
      }

      if (parsedRows.length < 2) {
        errorMessage = 'File is empty or missing headers.';
        return;
      }

      final parsed = RetailImportParser.parse(
        parsedRows.toList(),
        catalogue: _catalogue(),
      );
      preview = parsed;

      if (!parsed.hasAnythingToImport) {
        errorMessage = parsed.errors.isEmpty
            ? 'No product rows found in this file.'
            : 'Nothing can be imported — ${parsed.errors.length} row '
                  '${parsed.errors.length == 1 ? 'problem' : 'problems'} '
                  'need fixing first.';
        return;
      }

      successMessage =
          'Loaded ${parsed.groups.length} products / ${parsed.variantCount} '
          'variants. Review and confirm.';
    } catch (e) {
      errorMessage = 'Error parsing file: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Catalogue-aware rules handed to the pure parser.
  RetailImportCatalogue _catalogue() => RetailImportCatalogue(
    // Reads the BOX, not the MobX list, which goes stale mid-import.
    isBarcodeTaken: (barcode) => _variantRepository.isBarcodeTaken(barcode),
    existingVariantKeys: (name) {
      final product = _findProductByName(name);
      if (product == null) return null;
      return _existingVariantKeys(product.productId);
    },
  );

  // ── Import ────────────────────────────────────────────────────────────────

  /// Write the validated groups. Nothing here re-validates row shape — that
  /// already happened in [pickAndParseFile], which is what keeps a half-written
  /// product from ever reaching the box.
  @action
  Future<void> importData() async {
    final parsed = preview;
    if (parsed == null || parsed.groups.isEmpty) {
      errorMessage = 'No data to import';
      return;
    }

    isProcessing = true;
    progress = 0.0;
    logMessages.clear();
    errorMessage = null;
    successMessage = null;
    outcome = null;

    if (!TaxFeature.enabled) {
      logMessages.add(
        'ℹ Tax data in file ignored — tax is disabled for this business.',
      );
    }

    // Every parse-time finding is surfaced before the first write, so a
    // rejected row is never invisible.
    for (final issue in parsed.issues) {
      logMessages.add('${issue.isError ? '✗' : 'ℹ'} $issue');
    }

    // Attributes must be loaded before we start matching names against them.
    try {
      await _attributeStore.loadAttributes();
    } catch (_) {
      // Continue anyway — attributes are created as needed.
    }

    var created = 0;
    var updated = 0;
    var variantsImported = 0;
    var variantsSkipped = 0;
    var blockedByLimit = 0;
    var failed = 0;

    try {
      var processed = 0;
      for (final group in parsed.groups) {
        try {
          final before = _variantsAdded;
          final result = await _processGroup(group);
          variantsImported += _variantsAdded - before;

          switch (result) {
            case _GroupResult.created:
              created++;
              logMessages.add('✓ Imported "${group.name}"');
            case _GroupResult.updated:
              updated++;
              logMessages.add('✓ Updated "${group.name}"');
            case _GroupResult.blockedByLimit:
              blockedByLimit++;
            case _GroupResult.failed:
              failed++;
          }
          variantsSkipped += _variantsSkippedInGroup;
        } catch (e) {
          failed++;
          logMessages.add(
            '✗ Row ${group.parentRowNumber}: "${group.name}" was not '
            'imported — $e',
          );
        }

        processed++;
        progress = processed / parsed.groups.length;
      }

      // Re-read from the boxes. ProductStore.addVariant mirrors the variant it
      // was HANDED into its list, but VariantRepository writes a prepared copy
      // — so a barcode minted for a blank cell exists on disk and not in
      // memory until this runs.
      await productStore.loadProducts();
      await productStore.loadVariants();

      if (blockedByLimit > 0) {
        final limit = productStore.productLimit;
        logMessages.add(
          '✗ Product limit reached'
          '${limit == null ? '' : ' (${productStore.products.length} of $limit)'}'
          ' — $blockedByLimit '
          '${blockedByLimit == 1 ? 'product was' : 'products were'} not '
          'imported. Upgrade your plan to add more.',
        );
      }

      outcome = RetailImportOutcome(
        productsCreated: created,
        productsUpdated: updated,
        variantsImported: variantsImported,
        variantsSkipped: variantsSkipped,
        rowsRejected: parsed.errors.length,
        productsBlockedByLimit: blockedByLimit,
        groupsFailed: failed,
      );

      successMessage = outcome!.hadProblems
          ? 'Import finished with issues — $created created, $updated updated.'
          : 'Import completed! $created products imported.';
    } catch (e) {
      errorMessage = 'Import failed: $e';
    }
    // isProcessing stays true so the user lands on the results screen; clear()
    // resets it when they press Done.
  }

  /// Variants written so far this import — a running total so each group's
  /// contribution can be measured without threading a result object through.
  int _variantsAdded = 0;
  int _variantsSkippedInGroup = 0;

  Future<_GroupResult> _processGroup(RetailImportGroup group) async {
    _variantsSkippedInGroup = 0;

    final existing = _findProductByName(group.name);
    if (existing != null) return _appendToExistingProduct(existing, group);

    // Bulk import is an entrance like any other: it may not exceed the plan's
    // product cap just because it writes in a loop.
    if (!productStore.canAddProduct) return _GroupResult.blockedByLimit;

    final categoryId = await _resolveCategoryId(group.categoryName);
    final tax = _resolveTaxFromLabel(group.taxLabel);
    final productId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    final product = ProductModel(
      productId: productId,
      productName: group.name,
      description: group.description,
      category: categoryId,
      hasVariants: group.hasVariants,
      brandName: '',
      hsnCode: group.hsnCode,
      gstRate: tax.gstRate,
      taxId: tax.taxId,
      createdAt: now,
      updateAt: now,
      productType: group.hasVariants ? 'variable' : 'simple',
    );

    await productStore.addProduct(product);

    try {
      await _linkAttributes(productId, group);
      for (final row in group.variants) {
        await _createVariant(
          productId: productId,
          categoryName: group.categoryName,
          row: row,
          taxId: tax.taxId,
          gstRate: tax.gstRate,
          unit: group.unit,
          isDecimalQuantity: group.isDecimalQuantity,
          expiryDate: group.expiryDate,
        );
      }
    } catch (e) {
      // Compensating delete: a product with only some of its variants is worse
      // than no product at all, and there is no cross-box transaction to lean
      // on. deleteProduct cascades its variants.
      await productStore.deleteProduct(productId);
      rethrow;
    }

    return _GroupResult.created;
  }

  /// Adds this group's genuinely new variants to a product that already exists.
  ///
  /// The product itself is left alone — an import that adds variants must not
  /// silently rewrite the shop's tax, HSN, unit or expiry settings. The new
  /// variants therefore inherit the EXISTING product's unit/expiry/tax so the
  /// product stays internally consistent with what the edit screen shows.
  Future<_GroupResult> _appendToExistingProduct(
    ProductModel product,
    RetailImportGroup group,
  ) async {
    final siblings = productStore.variantsFor(product.productId);
    final split = splitAgainstExisting(
      group,
      _existingVariantKeys(product.productId),
    );

    for (final row in split.alreadyPresent) {
      _variantsSkippedInGroup++;
      logMessages.add(
        'ℹ Row ${row.rowNumber}: this variant already exists on '
        '"${product.productName}" — skipped.',
      );
    }

    if (split.toCreate.isEmpty) return _GroupResult.updated;

    // Inherit from the product's existing stock, not from the file.
    final template = siblings.isNotEmpty ? siblings.first : null;
    final unit = template?.effectiveUnit ?? group.unit;
    final isDecimal = template?.isDecimalQuantity ?? group.isDecimalQuantity;
    final expiryDate = template?.expiryDate ?? group.expiryDate;
    final taxId = product.taxId;
    final gstRate = product.gstRate;

    if (template != null && unit != group.unit) {
      logMessages.add(
        'ℹ Row ${group.parentRowNumber}: "${product.productName}" is already '
        'sold in $unit — the file\'s "${group.unit}" was ignored.',
      );
    }

    final writtenIds = <String>[];
    try {
      await _linkAttributes(product.productId, group);
      for (final row in split.toCreate) {
        final id = await _createVariant(
          productId: product.productId,
          categoryName: group.categoryName,
          row: row,
          taxId: taxId,
          gstRate: gstRate,
          unit: unit,
          isDecimalQuantity: isDecimal,
          expiryDate: expiryDate,
        );
        writtenIds.add(id);
      }
    } catch (e) {
      // Roll back only what this group added — the product and its original
      // variants were here first and must survive.
      for (final id in writtenIds) {
        await productStore.deleteVariant(id);
      }
      rethrow;
    }

    // Structural correction only: a product that now holds more than one
    // variant genuinely IS variable, and screens branch on this.
    final total = productStore.variantsFor(product.productId).length;
    if (total > 1 && !product.isVariable) {
      await productStore.updateProduct(
        product.copyWith(hasVariants: true, productType: 'variable'),
      );
    }

    return _GroupResult.updated;
  }

  /// Writes one variant. Returns its id so a failed group can be rolled back.
  Future<String> _createVariant({
    required String productId,
    required String categoryName,
    required RetailImportVariantRow row,
    required String? taxId,
    required double? gstRate,
    required String unit,
    required bool isDecimalQuantity,
    required String? expiryDate,
  }) async {
    final variantId = const Uuid().v4();

    // A blank barcode is left blank on purpose: VariantRepository.addVariant
    // mints a BB-prefixed Code 128 value for it, which is the one place that
    // knows the sequence. Minting one here would duplicate that logic.
    final variant = VarianteModel.create(
      varianteId: variantId,
      productId: productId,
      sku: row.sku ?? await _generateSku(categoryName),
      barcode: row.barcode,
      costPrice: row.costPrice,
      // The column labelled "Selling Price" must land in sellingPrice — that is
      // what the cart bills (sellingPrice ?? mrp ?? 0).
      sellingPrice: row.sellingPrice,
      mrp: row.mrp,
      stockQty: row.stockQty,
      minStock: row.minStock,
      customAttributes: row.attributes.isEmpty ? null : row.attributes,
      status: 'active',
      taxId: taxId,
      taxRate: gstRate,
      isDecimalQuantity: isDecimalQuantity,
      unit: unit,
      expiryDate: expiryDate,
    );

    final result = await productStore.addVariant(variant);
    if (!result.success) {
      // Previously this result was discarded, so a refused variant vanished
      // while its row still reported success.
      throw Exception('row ${row.rowNumber}: ${result.errorMessage}');
    }

    _variantsAdded++;
    return variantId;
  }

  /// Mints a SKU the same way Add Variant does. Non-fatal: a variant without a
  /// SKU is far better than a lost product.
  Future<String?> _generateSku(String categoryName) async {
    try {
      return await skuGeneratorService.generate(
        categoryName.isEmpty ? null : categoryName,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Lookups ───────────────────────────────────────────────────────────────

  /// Case-insensitive product-name match — the same rule the restaurant
  /// importer uses. Handle is only a grouping key and is never stored, so the
  /// name is the only thing a re-import can match on.
  ProductModel? _findProductByName(String name) {
    final target = name.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final product in productStore.products) {
      if (product.productName.trim().toLowerCase() == target) return product;
    }
    return null;
  }

  Set<String> _existingVariantKeys(String productId) => productStore
      .variantsFor(productId)
      .map((v) => attributeSignature(v.customAttributes))
      .toSet();

  /// Finds or creates the category, falling back to "Uncategorized".
  Future<String> _resolveCategoryId(String categoryName) async {
    final wanted = categoryName.trim().isEmpty
        ? 'Uncategorized'
        : categoryName.trim();

    Category? existing;
    for (final category in categoryStore.categories) {
      if (category.name.toLowerCase() == wanted.toLowerCase()) {
        existing = category;
        break;
      }
    }
    if (existing != null) return existing.id;

    final created = Category(
      id: const Uuid().v4(),
      name: wanted,
      createdTime: DateTime.now(),
    );
    final ok = await categoryStore.addCategory(created);
    if (ok) return created.id;

    // addCategory refuses duplicates and plan-capped adds; re-look-up covers
    // the duplicate case, and an empty id leaves the product uncategorised
    // rather than failing the whole import.
    for (final category in categoryStore.categories) {
      if (category.name.toLowerCase() == wanted.toLowerCase()) {
        return category.id;
      }
    }
    return '';
  }

  /// Resolves a "Name (Rate%)" dropdown label back to the shared Tax entity's
  /// id + percentage. Falls back to the trailing "(NN%)" as a raw rate when no
  /// exact match is found (the owner typed something not in the dropdown).
  ({String? taxId, double? gstRate}) _resolveTaxFromLabel(String label) {
    if (label.isEmpty || !TaxFeature.enabled) {
      return (taxId: null, gstRate: null);
    }

    for (final tax in taxStore.taxes) {
      final rate = tax.taxperecentage ?? 0;
      if (label == '${tax.taxname} ($rate%)') {
        return (taxId: tax.id, gstRate: rate);
      }
    }

    final match = RegExp(r'\(([\d.]+)%\)').firstMatch(label);
    final rate = match != null
        ? double.tryParse(match.group(1)!)
        : double.tryParse(label);
    return (taxId: null, gstRate: rate);
  }

  // ── Attributes ────────────────────────────────────────────────────────────

  /// Creates any missing attribute/value and assigns the set to the product.
  Future<void> _linkAttributes(
    String productId,
    RetailImportGroup group,
  ) async {
    final valueIdsByAttribute = <String, Set<String>>{};

    for (final row in group.variants) {
      for (final entry in row.attributes.entries) {
        final attributeId = await _ensureAttribute(entry.key);
        if (attributeId == null) continue;
        final valueId = await _ensureAttributeValue(attributeId, entry.value);
        if (valueId == null) continue;
        valueIdsByAttribute.putIfAbsent(attributeId, () => {}).add(valueId);
      }
    }

    if (valueIdsByAttribute.isEmpty) return;

    final assignments = valueIdsByAttribute.entries
        .map(
          (e) => {
            'attributeId': e.key,
            'valueIds': e.value.toList(),
            'usedForVariants': true,
            'isVisible': true,
          },
        )
        .toList();

    try {
      await _attributeStore.assignAttributesToProduct(productId, assignments);
    } catch (_) {
      // Attribute taxonomy is a convenience layer; the variants themselves
      // already carry customAttributes, so this must not fail the import.
    }
  }

  Future<String?> _ensureAttribute(String name) async {
    final wanted = name.trim().toLowerCase();

    AttributeModel? find() {
      for (final attribute in _attributeStore.attributes) {
        if (attribute.name.toLowerCase() == wanted) return attribute;
      }
      return null;
    }

    final existing = find();
    if (existing != null) return existing.attributeId;

    try {
      await _attributeStore.addAttribute(name.trim());
    } catch (_) {
      // Fall through — the re-look-up below covers an add that raced.
    }
    return find()?.attributeId;
  }

  Future<String?> _ensureAttributeValue(
    String attributeId,
    String value,
  ) async {
    final wanted = value.trim().toLowerCase();

    String? find() {
      for (final entry in _attributeStore.getValuesForAttribute(attributeId)) {
        if (entry.value.toLowerCase() == wanted) return entry.valueId;
      }
      return null;
    }

    final existing = find();
    if (existing != null) return existing;

    try {
      await _attributeStore.addValue(attributeId, value.trim());
    } catch (_) {
      // Fall through — re-look-up below.
    }
    return find();
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  @action
  void clear() {
    parsedRows.clear();
    logMessages.clear();
    preview = null;
    outcome = null;
    errorMessage = null;
    successMessage = null;
    progress = 0.0;
    isProcessing = false;
    _variantsAdded = 0;
    _variantsSkippedInGroup = 0;
  }
}
