import 'package:flutter/material.dart';
import 'package:unipos/presentation/screens/restaurant/import/restaurant_bulk_import_service_v3.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

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
      appBar: AppBar(
        title: const Text('Bulk Import V3 - Phase 1 Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🚀 Phase 1 Features:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureLine('✅ Row-level validation'),
                    _buildFeatureLine('✅ Auto-category creation'),
                    _buildFeatureLine('✅ In-memory caching'),
                    _buildFeatureLine('✅ Image URL download'),
                    _buildFeatureLine('✅ Progress callbacks'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Download Template Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _downloadTemplate,
              icon: const Icon(Icons.download),
              label: const Text('Download Template V3'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),

            // Import Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _startImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick Excel and Import'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),

            // Progress Section
            if (_isLoading) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _progressTotal > 0
                            ? _progressCurrent / _progressTotal
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      if (_progressTotal > 0)
                        Text(
                          '$_progressCurrent / $_progressTotal',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // Results Section
            if (_lastResult != null) ...[
              const SizedBox(height: 20),
              Expanded(
                child: Card(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _lastResult!.success
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _lastResult!.success
                                  ? Colors.green
                                  : Colors.red,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Import Results',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Text(
                          _lastResult!.getSummary(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
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
              const SizedBox(height: 20),
              Expanded(
                child: Card(
                  color: Colors.grey[100],
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📝 Testing Instructions:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '1. Download Template V3\n'
                            '   - Contains enhanced Items sheet with CategoryName and ImageURL\n\n'
                            '2. Edit the Items sheet:\n'
                            '   - Use category names (e.g., "Pizza") instead of IDs\n'
                            '   - Add image URLs (e.g., https://example.com/image.jpg)\n'
                            '   - Test validation by leaving ItemName empty\n'
                            '   - Test validation by setting Price to 0 or negative\n'
                            '   - Test VegType validation with invalid values\n\n'
                            '3. Import the file:\n'
                            '   - Watch real-time progress\n'
                            '   - See auto-created categories\n'
                            '   - Check downloaded images count\n'
                            '   - Review validation errors for failed rows\n\n'
                            '4. Verify results:\n'
                            '   - Check items were created\n'
                            '   - Verify categories auto-created\n'
                            '   - Check images downloaded to product_images/\n'
                            '   - Review failed rows and error messages',
                            style: TextStyle(fontSize: 13),
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

  Widget _buildFeatureLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
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
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            const Text('Import Complete'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Items Imported: ${result.itemsImported}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (result.categoriesAutoCreated > 0)
                Text(
                  '🎉 Auto-created ${result.categoriesAutoCreated} categories',
                  style: const TextStyle(color: Colors.green),
                ),
              if (result.imagesDownloaded > 0)
                Text(
                  '🖼️ Downloaded ${result.imagesDownloaded} images',
                  style: const TextStyle(color: Colors.blue),
                ),
              if (result.failedRows.isNotEmpty)
                Text(
                  '❌ ${result.failedRows.length} rows failed validation',
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 12),
              const Text(
                'See full results below for details.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
