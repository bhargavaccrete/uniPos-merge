import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';

import '../../../../domain/services/restaurant/comprehensive_data_generator.dart';
import 'package:billberrylite/domain/services/restaurant/history_data_generator.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_data_generator.dart';
import 'package:billberrylite/domain/services/restaurant/setup_data_generator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

class DataGeneratorScreen extends StatefulWidget {
  const DataGeneratorScreen({super.key});

  @override
  State<DataGeneratorScreen> createState() => _DataGeneratorScreenState();
}

class _DataGeneratorScreenState extends State<DataGeneratorScreen> {
  // Controllers for input fields
  final TextEditingController _categoriesController = TextEditingController(
    text: '20',
  );
  final TextEditingController _itemsController = TextEditingController(
    text: '500',
  );
  final TextEditingController _tablesController = TextEditingController(
    text: '50',
  );
  final TextEditingController _staffController = TextEditingController(
    text: '20',
  );
  final TextEditingController _customersController = TextEditingController(
    text: '200',
  );
  final TextEditingController _historyDaysController = TextEditingController(
    text: '30',
  );
  final TextEditingController _ordersPerDayController = TextEditingController(
    text: '60',
  );
  final TextEditingController _purchaseOrdersController = TextEditingController(
    text: '40',
  );
  final ValueNotifier<String> _progress = ValueNotifier('');

  bool _isGenerating = false;
  bool _isClearing = false;
  bool _isLoadingStats = false;
  bool _includeImages = false;
  Map<String, int> _stats = {};
  Map<String, String> _fileSizes = {};
  Map<String, dynamic>? _lastGenerationResults;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = {
        ...ComprehensiveDataGenerator.getAllStats(),
        ...ComprehensiveDataGenerator.getExtraStats(),
      };
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
        customers: int.tryParse(_customersController.text) ?? 200,
        historyDays: int.tryParse(_historyDaysController.text) ?? 30,
        ordersPerDay: int.tryParse(_ordersPerDayController.text) ?? 60,
        purchaseOrders: int.tryParse(_purchaseOrdersController.text) ?? 40,
        onProgress: (m) => _progress.value = m,
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
        _showSnackBar(
          '❌ Generation failed: ${results['error']}',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Clear All Data?',
      message:
          'This will permanently delete ALL test data from all Hive boxes. This action cannot be undone.\n\nAre you sure?',
      confirmLabel: 'Delete All',
      accent: Colors.red,
      icon: Icons.delete_forever_rounded,
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
    if (isError) {
      NotificationService.instance.showError(message);
    } else {
      NotificationService.instance.showSuccess(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Performance Test Data Generator',
        titleFontSize: isTablet ? 22 : 18,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 8),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoadingStats ? null : _loadStats,
              tooltip: 'Refresh Stats',
            ),
          ),
        ],
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        maxWidth: AppResponsive.maxContentWidth(context),
        alignment: Alignment.topCenter,
        child: _isGenerating || _isClearing
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(
                      _isGenerating
                          ? 'Generating data...\nThis may take a while for large datasets'
                          : 'Clearing all data...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 18 : 16,
                        color: Colors.black87,
                      ),
                    ),
                    if (_isGenerating) ...[
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: _progress,
                        builder: (_, msg, _) => Text(
                          msg,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                    if (_lastGenerationResults != null)
                      const SizedBox(height: 20),
                    _buildStatsCard(),
                    const SizedBox(height: 20),
                    _buildFileSizesCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              Text(
                'Performance Testing Tool',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Generate test data for all Hive boxes\n'
            '• Configure the amount of data for each box\n'
            '• Monitor insertion speed and file sizes\n'
            '• Test performance with large datasets (50,000+ records)',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure Data Counts',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInputField('Categories', _categoriesController, Icons.category),
          _buildInputField('Items', _itemsController, Icons.restaurant_menu),
          _buildInputField('Tables', _tablesController, Icons.table_restaurant),
          _buildInputField('Staff', _staffController, Icons.people),
          _buildInputField('Customers', _customersController, Icons.person),
          _buildInputField(
            'Sales history (days, up to yesterday)',
            _historyDaysController,
            Icons.history,
          ),
          _buildInputField(
            'Orders per day (average)',
            _ordersPerDayController,
            Icons.receipt_long,
          ),
          _buildInputField(
            'Purchase orders (suppliers, GRN, recipes; 0 = skip inventory)',
            _purchaseOrdersController,
            Icons.inventory_2,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTextField(
        controller: controller,
        keyboardType: TextInputType.number,
        label: label,
        icon: icon,
      ),
    );
  }

  Widget _buildImageOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 12),
              Text(
                'Image Generation Options',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text('Include Images for Items'),
            subtitle: Text(
              _includeImages
                  ? 'All items will have 400x400px placeholder images with vibrant colors and gradients'
                  : 'Items will be generated without images',
              style: TextStyle(fontSize: AppResponsive.smallFontSize(context)),
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
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.orange.shade700,
                      ),
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
                  Text(
                    '• 400x400px high-quality images\n'
                    '• 15 vibrant color variations\n'
                    '• Gradient backgrounds\n'
                    '• Decorative shapes and borders\n'
                    '• Tests app performance with image data\n'
                    '• Tests import/export with larger file sizes',
                    style: TextStyle(
                      fontSize: AppResponsive.smallFontSize(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text(
              'Generate Test Data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _isGenerating || _isClearing ? null : _clearAllData,
            icon: const Icon(Icons.delete_forever, size: 20),
            label: Text(
              'Clear All Data',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.bold,
                    color: success
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (success) ...[
              _buildResultRow(
                '⏱️ Total Time',
                '${results['totalTime']}ms (${(results['totalTime'] / 1000).toStringAsFixed(2)}s)',
              ),
              if (results['setup'] is SetupDataResult)
                ..._buildSetupRows(results['setup'] as SetupDataResult),
              const Divider(height: 24),
              if (results['inventory'] is InventoryDataResult) ...[
                ..._buildInventoryRows(
                    results['inventory'] as InventoryDataResult),
                const Divider(height: 24),
              ],
              if (results['history'] is HistoryDataResult)
                ..._buildHistoryRows(results['history'] as HistoryDataResult),
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

  static const _setupLabels = {
    'taxes': 'Taxes',
    'variants': 'Variants',
    'choices': 'Choices',
    'extras': 'Extras',
    'categories': 'Categories',
    'items': 'Items',
    'tables': 'Tables',
    'staff': 'Staff',
    'customers': 'Customers',
  };

  List<Widget> _buildSetupRows(SetupDataResult setup) {
    final small = TextStyle(
      fontSize: AppResponsive.smallFontSize(context),
      color: AppColors.textSecondary,
    );
    return [
      for (final e in _setupLabels.entries)
        if (setup.counts[e.key] case final c?) ...[
          _buildResultRow(
            '📁 ${e.value}',
            [
              '${c.added} added',
              if (c.reused > 0) '${c.reused} reused',
              if (c.skipped > 0) '${c.skipped} skipped',
            ].join(' · '),
          ),
          if (c.reason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 8),
              child: Text(c.reason!, style: small.copyWith(color: Colors.orange.shade800)),
            ),
        ],
      if (setup.staffLogins.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          'Staff logins',
          style: TextStyle(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        for (final login in setup.staffLogins) Text(login, style: small),
      ],
    ];
  }

  List<Widget> _buildInventoryRows(InventoryDataResult inv) {
    final warn = TextStyle(
      fontSize: AppResponsive.smallFontSize(context),
      color: Colors.orange.shade800,
    );
    return [
      _buildResultRow(
        '🥕 Raw / semi-finished',
        '${inv.rawMaterials} · ${inv.semiFinished}',
      ),
      _buildResultRow('📖 Recipes', '${inv.recipes}'),
      _buildResultRow('🚚 Suppliers', '${inv.suppliers}'),
      _buildResultRow(
        '📦 POs · GRNs',
        '${inv.purchaseOrders} · ${inv.grns} (${inv.partialGrns} partial)',
      ),
      _buildResultRow('⚠️ Damaged lines', '${inv.damagedLines}'),
      _buildResultRow(
        '↩️ Credit notes · returns cancelled',
        '${inv.creditNotes} · ${inv.returnsCancelled}',
      ),
      _buildResultRow(
        '📝 Claims settled · rejected',
        '${inv.claimsSettled} · ${inv.claimsRejected}',
      ),
      _buildResultRow('💳 Supplier payments', '${inv.payments}'),
      _buildResultRow('🍳 Production batches', '${inv.productions}'),
      _buildResultRow('🔧 Stock adjustments', '${inv.adjustments}'),
      _buildResultRow('📋 Stock take lines', '${inv.stockTakeLines}'),
      for (final w in inv.warnings.take(5)) Text(w, style: warn),
      if (inv.warnings.length > 5)
        Text('…and ${inv.warnings.length - 5} more warnings', style: warn),
    ];
  }

  List<Widget> _buildHistoryRows(HistoryDataResult h) {
    final warn = TextStyle(
      fontSize: AppResponsive.smallFontSize(context),
      color: Colors.orange.shade800,
    );
    return [
      if (h.skippedReason != null) Text(h.skippedReason!, style: warn),
      _buildResultRow('📅 Days (sessions + EOD)', '${h.days} · ${h.eodReports} EOD'),
      _buildResultRow('🧾 Orders', '${h.orders}', highlight: true),
      _buildResultRow('💰 Net sales', h.grossSales.toStringAsFixed(2)),
      _buildResultRow(
        '↩️ Refunds',
        '${h.fullRefunds} full · ${h.partialRefunds} partial',
      ),
      _buildResultRow('🚫 Voided (unpaid)', '${h.voids}'),
      _buildResultRow('💸 Expenses', '${h.expenses}'),
      _buildResultRow('💵 Cash movements', '${h.cashMovements}'),
      _buildResultRow('👤 Shifts', '${h.shifts}'),
      _buildResultRow('⭐ Customers with visits', '${h.customersUpdated}'),
      _buildResultRow(
        '⏱️ EOD generation',
        h.eodReports > 0
            ? '${h.eodTimeMs}ms · ${(h.eodTimeMs / h.eodReports).toStringAsFixed(0)}ms/day'
            : 'N/A',
      ),
      if (h.ordersCappedByPlan > 0)
        Text(
          '${h.ordersCappedByPlan} orders not created — plan bills-per-day limit',
          style: warn,
        ),
      if (h.eodCashMismatches > 0)
        Text(
          '${h.eodCashMismatches} EOD(s) expected cash differs from the generator’s own total — check those days in Day-wise Closing',
          style: warn,
        ),
    ];
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
    final setup = results['setup'];
    final int setupRecords = setup is SetupDataResult
        ? setup.counts.values.fold(0, (sum, c) => sum + c.added)
        : 0;
    final history = results['history'];
    final int totalRecords = setupRecords +
        (history is HistoryDataResult
            ? history.orders +
                history.eodReports +
                history.expenses +
                history.cashMovements +
                history.shifts +
                history.days
            : 0);

    final timeInSeconds = (results['totalTime'] ?? 0) / 1000;
    final recordsPerSecond = timeInSeconds > 0
        ? (totalRecords / timeInSeconds).toStringAsFixed(0)
        : 'N/A';
    final avgPerRecord = totalRecords > 0
        ? '${(timeInSeconds * 1000 / totalRecords).toStringAsFixed(2)}ms'
        : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 Performance Metrics',
          style: TextStyle(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildResultRow('Total Records', '$totalRecords'),
        if (results['setupTime'] != null)
          _buildResultRow('Setup data time', '${results['setupTime']}ms'),
        _buildResultRow('Records/Second', recordsPerSecond),
        _buildResultRow('Average per Record', avgPerRecord),
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
            Text(
              '📊 Current Data Statistics',
              style: TextStyle(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.bold,
              ),
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
            Text(
              '💾 Hive Box File Sizes',
              style: TextStyle(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.bold,
              ),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
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
        totalBytes +=
            double.parse(size.replaceAll(' GB', '')) * 1024 * 1024 * 1024;
      } else if (size.endsWith('B') &&
          !size.contains('K') &&
          !size.contains('M')) {
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
      totalSize =
          '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total Size',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppResponsive.subheadingFontSize(context),
          ),
        ),
        Text(
          totalSize,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppResponsive.subheadingFontSize(context),
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
    _customersController.dispose();
    _historyDaysController.dispose();
    _ordersPerDayController.dispose();
    _purchaseOrdersController.dispose();
    _progress.dispose();
    super.dispose();
  }
}
