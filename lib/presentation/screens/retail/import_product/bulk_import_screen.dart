import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/retail/retail_import_schema.dart';
import 'package:billberrylite/stores/import_product/bulk_import_store.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

/// Bulk import products from Excel/CSV — same visual shell as restaurant's
/// [RestaurantBulkImportScreen], bound to retail's own [BulkImportStore]
/// (variant/attribute-taxonomy import logic stays entirely separate; only
/// the UI is shared).
class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({Key? key}) : super(key: key);

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final BulkImportStore _store = BulkImportStore();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Bulk Import Products',
        titleFontSize: AppResponsive.headingFontSize(context),
      ),
      body: Observer(
        // topCenter, not Center: the Column shrink-wraps, so Center would
        // float the whole page in the vertical middle.
        builder: (_) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppResponsive.maxCardWidth(context),
            ),
            child: Padding(
              padding: AppResponsive.screenPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero intro
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(
                        AppResponsive.borderRadius(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: AppResponsive.shadowBlurRadius(context),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: AppResponsive.cardPadding(context),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              AppResponsive.mediumSpacing(context),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppResponsive.smallBorderRadius(context),
                              ),
                            ),
                            child: Icon(
                              Icons.upload_file_rounded,
                              color: AppColors.primary,
                              size: AppResponsive.largeIconSize(context),
                            ),
                          ),
                          SizedBox(width: AppResponsive.mediumSpacing(context)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Import products from Excel',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.subheadingFontSize(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      AppResponsive.smallSpacing(context) / 2,
                                ),
                                Text(
                                  'Add your whole catalog at once, including variants. Categories are created automatically as needed.',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.smallFontSize(
                                      context,
                                    ),
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppResponsive.verticalSpace(context, size: SpacingSize.large),

                  // Download Template Button
                  SizedBox(
                    width: double.infinity,
                    height: AppResponsive.buttonHeight(context),
                    child: ElevatedButton.icon(
                      onPressed: _store.isLoading ? null : _downloadTemplate,
                      icon: Icon(
                        Icons.download,
                        size: AppResponsive.iconSize(context),
                      ),
                      label: Text(
                        'Download Template',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.buttonFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppResponsive.borderRadius(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppResponsive.verticalSpace(
                    context,
                    size: SpacingSize.medium,
                  ),

                  // Import Button
                  SizedBox(
                    width: double.infinity,
                    height: AppResponsive.buttonHeight(context),
                    child: ElevatedButton.icon(
                      onPressed: _store.isLoading ? null : _startImport,
                      icon: Icon(
                        Icons.upload_file,
                        size: AppResponsive.iconSize(context),
                      ),
                      label: Text(
                        'Pick Excel and Import',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.buttonFontSize(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppResponsive.borderRadius(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppResponsive.verticalSpace(context, size: SpacingSize.large),

                  // Progress Section (mid-import)
                  if (_store.isProcessing && _store.progress < 1.0) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: AppResponsive.shadowBlurRadius(context),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: AppResponsive.cardPadding(context),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppResponsive.smallBorderRadius(context),
                              ),
                              child: LinearProgressIndicator(
                                value: _store.progress,
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.1,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            SizedBox(
                              height: AppResponsive.mediumSpacing(context),
                            ),
                            Text(
                              _store.logMessages.isNotEmpty
                                  ? _store.logMessages.last
                                  : 'Importing…',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                              height: AppResponsive.smallSpacing(context),
                            ),
                            Text(
                              '${(_store.progress * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Results Section (import finished)
                  if (_store.isProcessing && _store.progress >= 1.0) ...[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(
                            AppResponsive.borderRadius(context),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: AppResponsive.shadowBlurRadius(
                                context,
                              ),
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          padding: AppResponsive.cardPadding(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      AppResponsive.smallSpacing(context),
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (!_hadProblems
                                                  ? AppColors.success
                                                  : AppColors.danger)
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppResponsive.smallBorderRadius(
                                          context,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      !_hadProblems
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: !_hadProblems
                                          ? AppColors.success
                                          : AppColors.danger,
                                      size: AppResponsive.largeIconSize(
                                        context,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: AppResponsive.mediumSpacing(context),
                                  ),
                                  Text(
                                    'Import Results',
                                    style: GoogleFonts.poppins(
                                      fontSize:
                                          AppResponsive.subheadingFontSize(
                                            context,
                                          ),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(
                                height: AppResponsive.largeSpacing(context) * 2,
                                thickness: 1,
                                color: AppColors.divider,
                              ),
                              // Every number the import produced is shown, so
                              // nothing that happened to the file is invisible.
                              _buildResultItem(
                                context,
                                Icons.inventory_2_rounded,
                                'Products Created',
                                '${_outcome.productsCreated}',
                                AppColors.primary,
                              ),
                              if (_outcome.productsUpdated > 0)
                                _buildResultItem(
                                  context,
                                  Icons.playlist_add_check_rounded,
                                  'Existing Products Updated',
                                  '${_outcome.productsUpdated}',
                                  AppColors.primary,
                                ),
                              _buildResultItem(
                                context,
                                Icons.style_rounded,
                                'Variants Imported',
                                '${_outcome.variantsImported}',
                                AppColors.success,
                              ),
                              if (_outcome.variantsSkipped > 0)
                                _buildResultItem(
                                  context,
                                  Icons.skip_next_rounded,
                                  'Variants Already Present',
                                  '${_outcome.variantsSkipped}',
                                  AppColors.warning,
                                ),
                              if (_outcome.rowsRejected > 0)
                                _buildResultItem(
                                  context,
                                  Icons.rule_rounded,
                                  'Rows Rejected',
                                  '${_outcome.rowsRejected}',
                                  AppColors.danger,
                                ),
                              if (_outcome.productsBlockedByLimit > 0)
                                _buildResultItem(
                                  context,
                                  Icons.lock_outline_rounded,
                                  'Blocked by Product Limit',
                                  '${_outcome.productsBlockedByLimit}',
                                  AppColors.danger,
                                ),
                              if (_outcome.groupsFailed > 0)
                                _buildResultItem(
                                  context,
                                  Icons.error_outline_rounded,
                                  'Products Failed',
                                  '${_outcome.groupsFailed}',
                                  AppColors.danger,
                                ),
                              if (_failedLines.isNotEmpty)
                                _buildFailedRowsDetail(context),
                              if (_notices.isNotEmpty) ...[
                                _buildResultItem(
                                  context,
                                  Icons.info_outline_rounded,
                                  'Notices',
                                  '${_notices.length}',
                                  AppColors.warning,
                                ),
                                _buildNoticesDetail(context),
                              ],
                              SizedBox(
                                height: AppResponsive.largeSpacing(context),
                              ),
                              SizedBox(
                                width: double.infinity,
                                height: AppResponsive.buttonHeight(context),
                                child: ElevatedButton(
                                  onPressed: _onDone,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppResponsive.borderRadius(context),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Done',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Instructions
                  if (!_store.isProcessing) ...[
                    AppResponsive.verticalSpace(
                      context,
                      size: SpacingSize.large,
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(
                            AppResponsive.borderRadius(context),
                          ),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Padding(
                          padding: AppResponsive.cardPadding(context),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                        AppResponsive.smallSpacing(context),
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppResponsive.smallBorderRadius(
                                            context,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.info_outline,
                                        color: AppColors.info,
                                        size: AppResponsive.iconSize(context),
                                      ),
                                    ),
                                    SizedBox(
                                      width: AppResponsive.mediumSpacing(
                                        context,
                                      ),
                                    ),
                                    Text(
                                      'How to Use',
                                      style: GoogleFonts.poppins(
                                        fontSize:
                                            AppResponsive.subheadingFontSize(
                                              context,
                                            ),
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: AppResponsive.largeSpacing(context),
                                ),
                                _buildInstructionStep(
                                  context,
                                  '1',
                                  'Download Template',
                                  'Get the Excel template with real Category and Tax Rate dropdowns, seeded from your existing data.',
                                ),
                                _buildInstructionStep(
                                  context,
                                  '2',
                                  'Fill in Products',
                                  'Give variants of the same product the same Handle (e.g. "tshirt") across multiple rows.\n'
                                      'Use Option Name/Value pairs (e.g. Size/Medium) for each variant.\n'
                                      'Tax Rate only needs to be set on a group\'s first row.',
                                ),
                                _buildInstructionStep(
                                  context,
                                  '3',
                                  'Import File',
                                  'Click import and select your filled Excel/CSV file.\n'
                                      'Review the item/category counts before confirming.\n'
                                      'Categories and attributes are auto-created if needed.',
                                ),
                                _buildInstructionStep(
                                  context,
                                  '4',
                                  'Review Results',
                                  'Check the number of products imported.\n'
                                      'Review any failed rows and their reasons.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Counts of the finished import. Empty until [BulkImportStore.importData]
  /// completes, which is also the only time the results panel is shown.
  RetailImportOutcome get _outcome =>
      _store.outcome ?? const RetailImportOutcome();

  bool get _hadProblems => _outcome.hadProblems;

  List<String> get _failedLines =>
      _store.logMessages.where((m) => m.startsWith('✗')).toList();

  List<String> get _notices =>
      _store.logMessages.where((m) => m.startsWith('ℹ')).toList();

  Widget _buildInstructionStep(
    BuildContext context,
    String number,
    String title,
    String description,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.largeSpacing(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppResponsive.getValue(
              context,
              mobile: 32.0,
              tablet: 36.0,
              desktop: 40.0,
            ),
            height: AppResponsive.getValue(
              context,
              mobile: 32.0,
              tablet: 36.0,
              desktop: 40.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppResponsive.smallSpacing(context) / 2),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Preview of what the file will do, shown BEFORE anything is written.
  ///
  /// Every row problem is listed with its sheet row number here rather than
  /// after the fact, so a shop can close the dialog, fix the spreadsheet and
  /// try again without having half-imported it.
  Future<bool> _confirmImport(RetailImportParseResult parsed) async {
    final errors = parsed.errors;
    final notices = parsed.notices;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialogShell(
        title: 'Review Import',
        accent: errors.isEmpty ? AppColors.primary : AppColors.warning,
        icon: Icons.inventory_2_rounded,
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to import:',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildResultItem(
                  context,
                  Icons.inventory_2_rounded,
                  'Products',
                  '${parsed.groups.length}',
                  AppColors.primary,
                ),
                _buildResultItem(
                  context,
                  Icons.style_rounded,
                  'Variants',
                  '${parsed.variantCount}',
                  AppColors.success,
                ),
                _buildResultItem(
                  context,
                  Icons.category_rounded,
                  'Categories',
                  '${parsed.categoryNames.length}',
                  AppColors.success,
                ),
                if (errors.isNotEmpty) ...[
                  _buildResultItem(
                    context,
                    Icons.rule_rounded,
                    'Rows with errors',
                    '${errors.length}',
                    AppColors.danger,
                  ),
                  _buildIssueList(
                    context,
                    'View rows that will NOT be imported',
                    errors.map((e) => e.toString()).toList(),
                    AppColors.danger,
                  ),
                ],
                if (notices.isNotEmpty)
                  _buildIssueList(
                    context,
                    'View ${notices.length} notice${notices.length == 1 ? '' : 's'}',
                    notices.map((n) => n.toString()).toList(),
                    AppColors.warning,
                  ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                Text(
                  errors.isEmpty
                      ? 'Products, variants and any missing categories will be '
                            'created. Continue?'
                      : 'Only the rows above without errors will be imported. '
                            'Fix the file and re-import to add the rest. Continue?',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          appDialogCancelButton(ctx, label: 'Cancel'),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          appDialogPrimaryButton(
            label: 'Import',
            onPressed: () => Navigator.pop(ctx, true),
            color: AppColors.primary,
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Collapsed list of row-level findings, shared by the preview dialog and
  /// the results panel.
  Widget _buildIssueList(
    BuildContext context,
    String title,
    List<String> lines,
    Color accent,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: EdgeInsets.only(
          bottom: AppResponsive.smallSpacing(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w500,
            color: accent,
          ),
        ),
        children: lines.map((line) {
          return Container(
            width: double.infinity,
            margin: EdgeInsets.only(
              bottom: AppResponsive.smallSpacing(context),
            ),
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
              border: Border.all(color: accent.withOpacity(0.2)),
            ),
            child: Text(
              line,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    await _store.downloadTemplate();
    if (!mounted) return;
    if (_store.successMessage != null) {
      NotificationService.instance.showSuccess(_store.successMessage!);
    }
    if (_store.errorMessage != null) {
      NotificationService.instance.showError(_store.errorMessage!);
    }
  }

  Future<void> _startImport() async {
    await _store.pickAndParseFile();
    if (!mounted) return;

    if (_store.errorMessage != null) {
      NotificationService.instance.showError(_store.errorMessage!);
      return;
    }

    final parsed = _store.preview;
    // Null means the user cancelled the file picker; an empty group list means
    // the file was read but nothing in it is importable — pickAndParseFile has
    // already set errorMessage in that case.
    if (parsed == null || !parsed.hasAnythingToImport) return;

    final confirmed = await _confirmImport(parsed);
    if (!confirmed) {
      _store.clear();
      return;
    }

    await _store.importData();
  }

  Future<void> _onDone() async {
    try {
      final productStore = locator<ProductStore>();
      await productStore.loadProducts();
      await categoryStore.loadCategories();
    } catch (_) {}

    _store.clear();
    if (mounted) Navigator.pop(context);
  }

  /// Expandable list of the products that could not be written. Each line
  /// already carries its row number and the reason.
  Widget _buildFailedRowsDetail(BuildContext context) => _buildIssueList(
    context,
    'View failed rows',
    _failedLines,
    AppColors.danger,
  );

  /// Expandable list of import notices (skipped duplicate variants, ignored
  /// product-level values, "tax disabled for this business", and so on).
  Widget _buildNoticesDetail(BuildContext context) =>
      _buildIssueList(context, 'View notices', _notices, AppColors.warning);

  Widget _buildResultItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      child: Row(
        children: [
          Icon(icon, size: AppResponsive.iconSize(context), color: color),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
