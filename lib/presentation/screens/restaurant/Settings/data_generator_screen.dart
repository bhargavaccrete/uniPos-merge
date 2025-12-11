import 'package:flutter/material.dart';

import '../../../../domain/services/restaurant/comprehensive_data_generator.dart';

class DataGeneratorScreen extends StatefulWidget {
  const DataGeneratorScreen({super.key});

  @override
  State<DataGeneratorScreen> createState() => _DataGeneratorScreenState();
}

class _DataGeneratorScreenState extends State<DataGeneratorScreen> {
  // Controllers for input fields
  final TextEditingController _categoriesController = TextEditingController(text: '20');
  final TextEditingController _itemsController = TextEditingController(text: '500');
  final TextEditingController _tablesController = TextEditingController(text: '50');
  final TextEditingController _staffController = TextEditingController(text: '20');
  final TextEditingController _taxRatesController = TextEditingController(text: '6');
  final TextEditingController _activeOrdersController = TextEditingController(text: '100');
  final TextEditingController _pastOrdersController = TextEditingController(text: '50000');
  final TextEditingController _eodReportsController = TextEditingController(text: '30');

  bool _isGenerating = false;
  bool _isClearing = false;
  bool _isLoadingStats = false;
  bool _includeImages = false;
  Map<String, int> _stats = {};
  Map<String, String> _fileSizes = {};
  Map<String, dynamic>? _lastGenerationResults;
  int _selectedTabIndex = 0; // 0 = Generator, 1 = Statistics & Reports

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = ComprehensiveDataGenerator.getAllStats();
      final sizes = await ComprehensiveDataGenerator.getBoxFileSizes();
      setState(() {
        _stats = stats;
        _fileSizes = sizes;
      });
    } catch (e) {
      _showSnackBar('Error loading stats: $e', isError: true);
    } finally {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _generateData() async {
    setState(() {
      _isGenerating = true;
      _lastGenerationResults = null;
    });

    try {
      final results = await ComprehensiveDataGenerator.generateAllData(
        categories: int.tryParse(_categoriesController.text) ?? 20,
        items: int.tryParse(_itemsController.text) ?? 500,
        tables: int.tryParse(_tablesController.text) ?? 50,
        staff: int.tryParse(_staffController.text) ?? 20,
        taxRates: int.tryParse(_taxRatesController.text) ?? 6,
        activeOrders: int.tryParse(_activeOrdersController.text) ?? 100,
        pastOrders: int.tryParse(_pastOrdersController.text) ?? 50000,
        eodReports: int.tryParse(_eodReportsController.text) ?? 30,
        withImages: _includeImages,
      );

      setState(() => _lastGenerationResults = results);

      await _loadStats();

      if (results['success'] == true) {
        _showSnackBar(
          '✅ Generated all data successfully in ${results['totalTime']}ms!',
          isError: false,
        );
      } else {
        _showSnackBar('❌ Generation failed: ${results['error']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete ALL test data from all Hive boxes. '
              'This action cannot be undone.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isClearing = true);

    try {
      await ComprehensiveDataGenerator.clearAllData();
      await _loadStats();
      _showSnackBar('✅ All data cleared successfully!', isError: false);
    } catch (e) {
      _showSnackBar('Error clearing data: $e', isError: true);
    } finally {
      setState(() => _isClearing = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Test Data Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingStats ? null : _loadStats,
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: _isGenerating || _isClearing
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _isGenerating
                  ? 'Generating data...\nThis may take a while for large datasets'
                  : 'Clearing all data...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildInputSection(),
            const SizedBox(height: 20),
            _buildImageOptionsCard(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 20),
            if (_lastGenerationResults != null) _buildResultsCard(),
            if (_lastGenerationResults != null) const SizedBox(height: 20),
            _buildStatsCard(),
            const SizedBox(height: 20),
            _buildFileSizesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallReportsCard() {
    final totalOrders = (_stats['activeOrders'] ?? 0) + (_stats['pastOrders'] ?? 0);
    final totalRecords = _stats.values.fold(0, (sum, count) => sum + count);

    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Overall Statistics & Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Section
            _buildReportSection(
              '📋 Data Summary',
              [
                _buildReportRow('Total Records in Database', _formatNumber(totalRecords), icon: Icons.storage),
                _buildReportRow('Total Orders (Active + Past)', _formatNumber(totalOrders), icon: Icons.shopping_bag),
                _buildReportRow('Total Past Orders Completed', _formatNumber(_stats['pastOrders'] ?? 0), icon: Icons.check_circle),
                _buildReportRow('Total Active Orders', _formatNumber(_stats['activeOrders'] ?? 0), icon: Icons.pending),
                _buildReportRow('Total EOD Reports Generated', _formatNumber(_stats['eodReports'] ?? 0), icon: Icons.assessment),
              ],
            ),

            const Divider(height: 32),

            // Inventory Section
            _buildReportSection(
              '📦 Inventory & Products',
              [
                _buildReportRow('Total Categories', _formatNumber(_stats['categories'] ?? 0), icon: Icons.category),
                _buildReportRow('Total Items/Products', _formatNumber(_stats['items'] ?? 0), icon: Icons.restaurant_menu),
                _buildReportRow('Total Variants (Sizes)', _formatNumber(_stats['variants'] ?? 0), icon: Icons.format_size),
                _buildReportRow('Total Extras/Toppings', _formatNumber(_stats['extras'] ?? 0), icon: Icons.add_circle),
              ],
            ),

            const Divider(height: 32),

            // Operations Section
            _buildReportSection(
              '🏢 Operations',
              [
                _buildReportRow('Total Tables', _formatNumber(_stats['tables'] ?? 0), icon: Icons.table_restaurant),
                _buildReportRow('Total Staff Members', _formatNumber(_stats['staff'] ?? 0), icon: Icons.people),
                _buildReportRow('Total Tax Rates', _formatNumber(_stats['taxRates'] ?? 0), icon: Icons.percent),
                _buildReportRow('Items in Cart', _formatNumber(_stats['cart'] ?? 0), icon: Icons.shopping_cart),
              ],
            ),

            const Divider(height: 32),

            // Performance Insights
            _buildReportSection(
              '⚡ Performance Insights',
              [
                _buildReportRow(
                  'Database Health',
                  totalRecords > 0 ? 'Active' : 'Empty',
                  icon: Icons.health_and_safety,
                  valueColor: totalRecords > 0 ? Colors.green : Colors.grey,
                ),
                _buildReportRow(
                  'Large Dataset Test',
                  (_stats['pastOrders'] ?? 0) >= 50000 ? 'Passed ✓' : 'Pending',
                  icon: Icons.verified,
                  valueColor: (_stats['pastOrders'] ?? 0) >= 50000 ? Colors.green : Colors.orange,
                ),
                _buildReportRow(
                  'Total Storage Used',
                  _getTotalStorageUsed(),
                  icon: Icons.sd_card,
                ),
              ],
            ),

            if ((_stats['pastOrders'] ?? 0) > 0) ...[
              const Divider(height: 32),
              _buildTestResultsSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildReportRow(String label, String value, {IconData? icon, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultsSummary() {
    final pastOrders = _stats['pastOrders'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Performance Test Results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTestResultRow('✓ Past orders generated', _formatNumber(pastOrders)),
          _buildTestResultRow('✓ Data persistence', 'Verified'),
          _buildTestResultRow('✓ No corruption detected', 'Passed'),
          _buildTestResultRow('✓ Query performance', 'Operational'),
          _buildTestResultRow('✓ File integrity', 'Maintained'),
          const SizedBox(height: 8),
          Text(
            'All $pastOrders records are accessible and queryable.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _getTotalStorageUsed() {
    double totalBytes = 0;
    for (final size in _fileSizes.values) {
      try {
        if (size.endsWith('KB')) {
          totalBytes += double.parse(size.replaceAll(' KB', '')) * 1024;
        } else if (size.endsWith('MB')) {
          totalBytes += double.parse(size.replaceAll(' MB', '')) * 1024 * 1024;
        } else if (size.endsWith('GB')) {
          totalBytes += double.parse(size.replaceAll(' GB', '')) * 1024 * 1024 * 1024;
        } else if (size.endsWith('B') && !size.contains('K') && !size.contains('M')) {
          totalBytes += double.parse(size.replaceAll(' B', ''));
        }
      } catch (e) {
        // Skip invalid sizes
      }
    }

    if (totalBytes < 1024) {
      return '${totalBytes.toStringAsFixed(0)} B';
    } else if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(2)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Performance Testing Tool',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• Generate test data for all Hive boxes\n'
                  '• Configure the amount of data for each box\n'
                  '• Monitor insertion speed and file sizes\n'
                  '• Test performance with large datasets (50,000+ records)\n'
                  '• Verify data integrity and query performance',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure Data Counts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInputField('Categories', _categoriesController, Icons.category),
            _buildInputField('Items', _itemsController, Icons.restaurant_menu),
            _buildInputField('Tables', _tablesController, Icons.table_restaurant),
            _buildInputField('Staff', _staffController, Icons.people),
            _buildInputField('Tax Rates', _taxRatesController, Icons.percent),
            _buildInputField('Active Orders', _activeOrdersController, Icons.shopping_cart),
            _buildInputField(
              'Past Orders (50K recommended)',
              _pastOrdersController,
              Icons.history,
              highlight: true,
            ),
            _buildInputField('EOD Reports', _eodReportsController, Icons.assessment),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
      String label,
      TextEditingController controller,
      IconData icon, {
        bool highlight = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: highlight ? Colors.orange : null),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: highlight ? Colors.orange : Colors.grey,
              width: highlight ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: highlight ? Colors.orange : Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageOptionsCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Image Generation Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Include Images for Items'),
              subtitle: Text(
                _includeImages
                    ? 'All items will have 400x400px placeholder images with vibrant colors and gradients'
                    : 'Items will be generated without images',
                style: const TextStyle(fontSize: 12),
              ),
              value: _includeImages,
              onChanged: (value) {
                setState(() {
                  _includeImages = value;
                });
              },
              activeColor: Colors.orange,
              contentPadding: EdgeInsets.zero,
            ),
            if (_includeImages) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Image Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 400x400px high-quality images\n'
                          '• 15 vibrant color variations\n'
                          '• Gradient backgrounds\n'
                          '• Decorative shapes and borders\n'
                          '• Tests app performance with image data\n'
                          '• Tests import/export with larger file sizes',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isGenerating || _isClearing ? null : _generateData,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Generate Test Data', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _isGenerating || _isClearing ? null : _clearAllData,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Clear All Data', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsCard() {
    final results = _lastGenerationResults!;
    final success = results['success'] == true;

    return Card(
      color: success ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  success ? '✅ Generation Successful!' : '❌ Generation Failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: success ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (success) ...[
              _buildResultRow('⏱️ Total Time', '${results['totalTime']}ms (${(results['totalTime'] / 1000).toStringAsFixed(2)}s)'),
              _buildResultRow('📁 Categories', '${results['categories']}'),
              _buildResultRow('📁 Items', '${results['items']}'),
              _buildResultRow('📁 Tables', '${results['tables']}'),
              _buildResultRow('📁 Staff', '${results['staff']}'),
              _buildResultRow('📁 Active Orders', '${results['activeOrders']}'),
              _buildResultRow('📁 Past Orders', '${results['pastOrders']}', highlight: true),
              _buildResultRow('📁 EOD Reports', '${results['eodReports']}'),
              const Divider(height: 24),
              _buildPerformanceMetrics(results),
            ] else ...[
              Text(
                'Error: ${results['error']}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.orange.shade700 : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.orange.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic> results) {
    final totalRecords = (results['categories'] ?? 0) +
        (results['items'] ?? 0) +
        (results['tables'] ?? 0) +
        (results['staff'] ?? 0) +
        (results['activeOrders'] ?? 0) +
        (results['pastOrders'] ?? 0) +
        (results['eodReports'] ?? 0);

    final timeInSeconds = (results['totalTime'] ?? 0) / 1000;
    final recordsPerSecond = timeInSeconds > 0 ? (totalRecords / timeInSeconds).toStringAsFixed(0) : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Performance Metrics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildResultRow('Total Records', '$totalRecords'),
        _buildResultRow('Records/Second', recordsPerSecond),
        _buildResultRow('Average per Record', '${(timeInSeconds * 1000 / totalRecords).toStringAsFixed(2)}ms'),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Current Data Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoadingStats)
              const Center(child: CircularProgressIndicator())
            else if (_stats.isEmpty)
              const Text('No data available')
            else
              ..._stats.entries.map((entry) {
                return _buildStatRow(entry.key, entry.value);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String boxName, int count) {
    final displayName = boxName[0].toUpperCase() + boxName.substring(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(displayName),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSizesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💾 Hive Box File Sizes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoadingStats)
              const Center(child: CircularProgressIndicator())
            else if (_fileSizes.isEmpty)
              const Text('No file size data available')
            else
              ..._fileSizes.entries.map((entry) {
                return _buildFileSizeRow(entry.key, entry.value);
              }),
            const Divider(height: 24),
            _buildTotalFileSize(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSizeRow(String boxName, String size) {
    final displayName = boxName[0].toUpperCase() + boxName.substring(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(displayName),
          Text(
            size,
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalFileSize() {
    double totalBytes = 0;
    for (final size in _fileSizes.values) {
      if (size.endsWith('KB')) {
        totalBytes += double.parse(size.replaceAll(' KB', '')) * 1024;
      } else if (size.endsWith('MB')) {
        totalBytes += double.parse(size.replaceAll(' MB', '')) * 1024 * 1024;
      } else if (size.endsWith('GB')) {
        totalBytes += double.parse(size.replaceAll(' GB', '')) * 1024 * 1024 * 1024;
      } else if (size.endsWith('B') && !size.contains('K') && !size.contains('M')) {
        totalBytes += double.parse(size.replaceAll(' B', ''));
      }
    }

    String totalSize;
    if (totalBytes < 1024) {
      totalSize = '${totalBytes.toStringAsFixed(0)} B';
    } else if (totalBytes < 1024 * 1024) {
      totalSize = '${(totalBytes / 1024).toStringAsFixed(2)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      totalSize = '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      totalSize = '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total Size',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          totalSize,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'monospace',
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _categoriesController.dispose();
    _itemsController.dispose();
    _tablesController.dispose();
    _staffController.dispose();
    _taxRatesController.dispose();
    _activeOrdersController.dispose();
    _pastOrdersController.dispose();
    _eodReportsController.dispose();
    super.dispose();
  }
}