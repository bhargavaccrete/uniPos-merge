import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
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
        builder: (_) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppResponsive.isMobile(context) ? double.infinity : 680,
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
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
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
                            padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
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
                                    fontSize: AppResponsive.subheadingFontSize(context),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: AppResponsive.smallSpacing(context) / 2),
                                Text(
                                  'Add your whole catalog at once, including variants. Categories are created automatically as needed.',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.smallFontSize(context),
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
                      icon: Icon(Icons.download, size: AppResponsive.iconSize(context)),
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
                          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                        ),
                      ),
                    ),
                  ),
                  AppResponsive.verticalSpace(context, size: SpacingSize.medium),

                  // Import Button
                  SizedBox(
                    width: double.infinity,
                    height: AppResponsive.buttonHeight(context),
                    child: ElevatedButton.icon(
                      onPressed: _store.isLoading ? null : _startImport,
                      icon: Icon(Icons.upload_file, size: AppResponsive.iconSize(context)),
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
                          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
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
                        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
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
                              borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                              child: LinearProgressIndicator(
                                value: _store.progress,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 8,
                              ),
                            ),
                            SizedBox(height: AppResponsive.mediumSpacing(context)),
                            Text(
                              _store.logMessages.isNotEmpty ? _store.logMessages.last : 'Importing…',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: AppResponsive.smallSpacing(context)),
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
                          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: AppResponsive.shadowBlurRadius(context),
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
                                    padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                                    decoration: BoxDecoration(
                                      color: (_failedCount == 0 ? AppColors.success : AppColors.danger)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                    ),
                                    child: Icon(
                                      _failedCount == 0 ? Icons.check_circle : Icons.error,
                                      color: _failedCount == 0 ? AppColors.success : AppColors.danger,
                                      size: AppResponsive.largeIconSize(context),
                                    ),
                                  ),
                                  SizedBox(width: AppResponsive.mediumSpacing(context)),
                                  Text(
                                    'Import Results',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.subheadingFontSize(context),
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
                              _buildResultItem(context, Icons.inventory_2_rounded, 'Products Imported',
                                  '$_successCount', AppColors.primary),
                              if (_failedCount > 0) ...[
                                _buildResultItem(context, Icons.error_outline_rounded, 'Failed Rows',
                                    '$_failedCount', AppColors.danger),
                                _buildFailedRowsDetail(context),
                              ],
                              if (_notices.isNotEmpty) ...[
                                _buildResultItem(context, Icons.info_outline_rounded, 'Notices',
                                    '${_notices.length}', AppColors.warning),
                                _buildNoticesDetail(context),
                              ],
                              SizedBox(height: AppResponsive.largeSpacing(context)),
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
                                      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                                    ),
                                  ),
                                  child: Text(
                                    'Done',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                    AppResponsive.verticalSpace(context, size: SpacingSize.large),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
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
                                      padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                                      ),
                                      child: Icon(
                                        Icons.info_outline,
                                        color: AppColors.info,
                                        size: AppResponsive.iconSize(context),
                                      ),
                                    ),
                                    SizedBox(width: AppResponsive.mediumSpacing(context)),
                                    Text(
                                      'How to Use',
                                      style: GoogleFonts.poppins(
                                        fontSize: AppResponsive.subheadingFontSize(context),
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppResponsive.largeSpacing(context)),
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

  int get _successCount => _store.logMessages.where((m) => m.startsWith('✓')).length;
  int get _failedCount => _store.logMessages.where((m) => m.startsWith('✗')).length;
  List<String> get _notices =>
      _store.logMessages.where((m) => !m.startsWith('✓') && !m.startsWith('✗')).toList();

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
            width: AppResponsive.getValue(context, mobile: 32.0, tablet: 36.0, desktop: 40.0),
            height: AppResponsive.getValue(context, mobile: 32.0, tablet: 36.0, desktop: 40.0),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
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

  /// Counts distinct products (Handle) and categories from the parsed rows,
  /// for the pre-import confirm dialog. Pure UI-layer computation over the
  /// store's existing public `parsedRows` — no store changes.
  ({int products, int categories}) _countsFromParsedRows() {
    final dataRows = _store.parsedRows.skip(1);
    final handles = <String>{};
    final categories = <String>{};
    for (final row in dataRows) {
      if (row.isEmpty) continue;
      final handle = row[0].toString().trim();
      if (handle.isNotEmpty) handles.add(handle);
      if (row.length > 2) {
        final category = row[2].toString().trim();
        if (category.isNotEmpty) categories.add(category);
      }
    }
    return (products: handles.length, categories: categories.length);
  }

  Future<bool> _confirmImport(int productCount, int categoryCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialogShell(
        title: 'Confirm Import',
        accent: AppColors.primary,
        icon: Icons.inventory_2_rounded,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found in this file:',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildResultItem(context, Icons.inventory_2_rounded, 'Products',
                '$productCount', AppColors.primary),
            _buildResultItem(context, Icons.category_rounded, 'Categories',
                '$categoryCount', AppColors.success),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              'New products, variants, and categories will be created. Continue?',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          appDialogCancelButton(ctx, label: 'Cancel'),
          const SizedBox(width: 12),
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

    if (_store.parsedRows.isEmpty) return; // user cancelled the file picker

    final counts = _countsFromParsedRows();
    final confirmed = await _confirmImport(counts.products, counts.categories);
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

  /// Expandable list of failed rows (each ✗ log line already contains the
  /// handle + error reason).
  Widget _buildFailedRowsDetail(BuildContext context) {
    final failed = _store.logMessages.where((m) => m.startsWith('✗')).toList();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
        title: Text(
          'View failed rows',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w500,
            color: AppColors.danger,
          ),
        ),
        children: failed.map((f) {
          return Container(
            margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
              border: Border.all(color: AppColors.danger.withOpacity(0.2)),
            ),
            child: Text(
              f,
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

  /// Expandable list of import notices (e.g. "tax disabled for this business").
  Widget _buildNoticesDetail(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
        title: Text(
          'View notices',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w500,
            color: AppColors.warning,
          ),
        ),
        children: _notices.map((w) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context) / 2),
            child: Text(
              w,
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
