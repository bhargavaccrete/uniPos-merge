import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/import/restaurant_bulk_import_service_v3.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

/// Test screen for V3 Bulk Import with Phase 1 improvements
class BulkImportTestScreenV3 extends StatefulWidget {
  const BulkImportTestScreenV3({Key? key}) : super(key: key);

  @override
  State<BulkImportTestScreenV3> createState() => _BulkImportTestScreenV3State();
}

class _BulkImportTestScreenV3State extends State<BulkImportTestScreenV3> {
  final RestaurantBulkImportServiceV3 _importService = RestaurantBulkImportServiceV3();

  bool _isLoading = false;
  String _statusMessage = '';
  int _progressCurrent = 0;
  int _progressTotal = 100;
  ImportResultV3? _lastResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Bulk Import',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.headingFontSize(context),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: Padding(
        padding: AppResponsive.screenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: AppResponsive.shadowBlurRadius(context),
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: AppResponsive.cardPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                          ),
                          child: Icon(
                            Icons.rocket_launch,
                            color: AppColors.primary,
                            size: AppResponsive.iconSize(context),
                          ),
                        ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        Text(
                          'Enhanced Features',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    _buildFeatureLine(context, Icons.check_circle, 'Row-level validation'),
                    _buildFeatureLine(context, Icons.check_circle, 'Auto-category creation'),
                    _buildFeatureLine(context, Icons.check_circle, 'In-memory caching'),
                    _buildFeatureLine(context, Icons.check_circle, 'Image URL download'),
                    _buildFeatureLine(context, Icons.check_circle, 'Progress callbacks'),
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
                onPressed: _isLoading ? null : _downloadTemplate,
                icon: Icon(Icons.download, size: AppResponsive.iconSize(context)),
                label: Text(
                  'Download Template',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.buttonFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
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
                onPressed: _isLoading ? null : _startImport,
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

            // Progress Section
            if (_isLoading) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: AppResponsive.shadowBlurRadius(context),
                      offset: Offset(0, 2),
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
                          value: _progressTotal > 0
                              ? _progressCurrent / _progressTotal
                              : null,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 8,
                        ),
                      ),
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      Text(
                        _statusMessage,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_progressTotal > 0) ...[
                        SizedBox(height: AppResponsive.smallSpacing(context)),
                        Text(
                          '$_progressCurrent / $_progressTotal',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Results Section
            if (_lastResult != null) ...[
              AppResponsive.verticalSpace(context, size: SpacingSize.large),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: AppResponsive.shadowBlurRadius(context),
                        offset: Offset(0, 2),
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
                                color: (_lastResult!.success
                                        ? AppColors.success
                                        : AppColors.danger)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                              ),
                              child: Icon(
                                _lastResult!.success
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _lastResult!.success
                                    ? AppColors.success
                                    : AppColors.danger,
                                size: AppResponsive.largeIconSize(context),
                              ),
                            ),
                            SizedBox(width: AppResponsive.mediumSpacing(context)),
                            Text(
                              'Import Results',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.subheadingFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: AppResponsive.largeSpacing(context) * 2,
                          thickness: 1,
                          color: AppColors.divider,
                        ),
                        Text(
                          _lastResult!.getSummary(),
                          style: GoogleFonts.robotoMono(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Instructions
            if (!_isLoading && _lastResult == null) ...[
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
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                          _buildInstructionStep(
                            context,
                            '1',
                            'Download Template',
                            'Get the enhanced Excel template with CategoryName and ImageURL columns',
                          ),
                          _buildInstructionStep(
                            context,
                            '2',
                            'Edit Items Sheet',
                            'Use category names (e.g., "Pizza") instead of IDs\n'
                            'Add image URLs (e.g., https://example.com/image.jpg)\n'
                            'Fill in all required fields',
                          ),
                          _buildInstructionStep(
                            context,
                            '3',
                            'Import File',
                            'Click import and select your Excel file\n'
                            'Watch real-time progress updates\n'
                            'Categories will be auto-created if needed',
                          ),
                          _buildInstructionStep(
                            context,
                            '4',
                            'Review Results',
                            'Check imported items count\n'
                            'Verify auto-created categories\n'
                            'Review any validation errors',
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
    );
  }

  Widget _buildFeatureLine(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppResponsive.smallSpacing(context),
        top: AppResponsive.smallSpacing(context),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.success,
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                    color: Colors.black87,
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

  Future<void> _downloadTemplate() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating template...';
      _lastResult = null;
    });

    try {
      final result = await _importService.downloadTemplate();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });

        if (result.contains('Error')) {
          NotificationService.instance.showError(result);
        } else {
          NotificationService.instance.showSuccess(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });

        NotificationService.instance.showError('Error: $e');
      }
    }
  }

  Future<void> _startImport() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Picking file...';
      _progressCurrent = 0;
      _progressTotal = 100;
      _lastResult = null;
    });

    try {
      // Create service with progress callback
      final serviceWithProgress = RestaurantBulkImportServiceV3(
        onProgress: (current, total, message) {
          if (mounted) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
              _statusMessage = message;
            });
          }
        },
      );

      // Pick and parse file
      setState(() => _statusMessage = 'Parsing Excel file...');
      final sheets = await serviceWithProgress.pickAndParseFile();

      if (sheets.isEmpty) {
        throw Exception('No file selected or failed to parse');
      }

      // Import data
      setState(() => _statusMessage = 'Starting import...');
      final result = await serviceWithProgress.importData(sheets);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastResult = result;
          _statusMessage = result.success
              ? 'Import completed successfully!'
              : 'Import completed with errors';
        });

        // Show summary dialog
        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });

        NotificationService.instance.showError('Import failed: $e');
      }
    }
  }

  void _showResultDialog(ImportResultV3 result) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
              decoration: BoxDecoration(
                color: (result.success ? AppColors.success : AppColors.danger)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
              ),
              child: Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? AppColors.success : AppColors.danger,
                size: AppResponsive.iconSize(context),
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Text(
              'Import Complete',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultItem(
                context,
                Icons.inventory,
                'Items Imported',
                '${result.itemsImported}',
                AppColors.primary,
              ),
              if (result.categoriesAutoCreated > 0)
                _buildResultItem(
                  context,
                  Icons.category,
                  'Categories Created',
                  '${result.categoriesAutoCreated}',
                  AppColors.success,
                ),
              if (result.imagesDownloaded > 0)
                _buildResultItem(
                  context,
                  Icons.image,
                  'Images Downloaded',
                  '${result.imagesDownloaded}',
                  AppColors.info,
                ),
              if (result.failedRows.isNotEmpty)
                _buildResultItem(
                  context,
                  Icons.error_outline,
                  'Failed Rows',
                  '${result.failedRows.length}',
                  AppColors.danger,
                ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Text(
                'See full results below for details.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.largeSpacing(context),
                vertical: AppResponsive.mediumSpacing(context),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
