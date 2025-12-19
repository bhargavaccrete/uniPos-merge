import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/domain/store/retail/product_store.dart';
import 'package:unipos/stores/import_product/bulk_import_store.dart';
import 'package:unipos/util/color.dart';

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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Bulk Import Products",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Observer(
        builder: (_) {
          if (_store.isProcessing) {
            return _buildProcessingView();
          }

          if (_store.parsedRows.isNotEmpty) {
            return _buildPreviewView();
          }

          return _buildUploadView();
        },
      ),
    );
  }

  Widget _buildUploadView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Template Format Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withOpacity(0.3), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'File Format Requirements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Supported formats: Excel (.xlsx, .xls) or CSV (.csv)',
                  style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Required columns (in order):',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '1. Handle (Product group ID)\n'
                  '2. Name (Product name - required)\n'
                  '3. Category\n'
                  '4. Description\n'
                  '5-10. Option Name/Value pairs (for variants)\n'
                  '11. Cost Price\n'
                  '12. Selling Price (required)\n'
                  '13. Stock\n'
                  '14. Barcode/SKU\n'
                  '15. Min Stock',
                  style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: const Text(
                          'CSV Template Example',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            'Copy this and save as a .csv file:\n\n'
                            'Handle,Name,Category,Description,Option1 Name,Option1 Value,Option2 Name,Option2 Value,Option3 Name,Option3 Value,Cost Price,Selling Price,Stock,Barcode,Min Stock\n'
                            'product1,Laptop,Electronics,Gaming Laptop,,,,,,,800,1200,10,LAP001,5\n'
                            'product2,Mouse,Electronics,Wireless Mouse,,,,,,,10,25,50,MOU001,10\n'
                            'tshirt,T-Shirt,Clothing,Cotton T-Shirt,Size,Small,Color,Red,,,5,15,20,TS-RED-S,5\n'
                            'tshirt,T-Shirt,Clothing,Cotton T-Shirt,Size,Medium,Color,Red,,,5,15,15,TS-RED-M,5\n'
                            'tshirt,T-Shirt,Clothing,Cotton T-Shirt,Size,Large,Color,Blue,,,6,16,10,TS-BLU-L,5',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(Icons.content_copy, size: 18, color: AppColors.info),
                  label: Text(
                    'Show CSV Example',
                    style: TextStyle(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildStepCard(
            step: "1",
            title: "Download Template",
            description: "Get the Excel template with sample data and correct format.",
            icon: Icons.download,
            action: ElevatedButton.icon(
              onPressed: _store.isLoading ? null : () async {
                await _store.downloadTemplate();
                if (_store.successMessage != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_store.successMessage!),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                if (_store.errorMessage != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_store.errorMessage!),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.file_download, size: 20),
              label: const Text("Download Excel Template"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildStepCard(
            step: "2",
            title: "Upload & Import",
            description: "Select your filled Excel/CSV file to begin importing.",
            icon: Icons.upload_file,
            action: ElevatedButton.icon(
              onPressed: _store.isLoading ? null : _store.pickAndParseFile,
              icon: const Icon(Icons.folder_open, size: 20),
              label: const Text("Select File"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
          if (_store.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.danger.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.danger, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _store.errorMessage!,
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String description,
    required IconData icon,
    required Widget action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: Text(
                  step,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B6B6B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewView() {
    // Headers are first row
    final headers = _store.parsedRows.first.map((e) => e.toString()).toList();
    final dataRows = _store.parsedRows.skip(1).toList();

    // Debug: Print preview data
    print('_buildPreviewView: Headers = $headers');
    print('_buildPreviewView: Data rows count = ${dataRows.length}');
    if (dataRows.isNotEmpty) {
      print('_buildPreviewView: First data row = ${dataRows.first}');
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: AppColors.info.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Previewing ${dataRows.length} products (${headers.length} columns). Please verify data before confirming.",
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: headers.map((h) => DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  )).toList(),
                  rows: dataRows.take(50).map((row) {
                    return DataRow(
                      cells: row.map((cell) => DataCell(
                        Text(
                          cell.toString(),
                          style: const TextStyle(
                            color: Color(0xFF6B6B6B),
                            fontSize: 13,
                          ),
                        ),
                      )).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _store.clear,
                  child: const Text(
                    "Cancel",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _store.importData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Confirm Import",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: _store.progress,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              "Importing... ${(_store.progress * 100).toStringAsFixed(0)}%",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _store.logMessages.length,
                itemBuilder: (context, index) {
                  final msg = _store.logMessages[index];
                  final isError = msg.startsWith("✗");
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      msg,
                      style: TextStyle(
                        color: isError ? AppColors.danger : AppColors.success,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Show success message
            if (_store.progress >= 1.0 && _store.successMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _store.successMessage!,
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (_store.progress >= 1.0 || _store.errorMessage != null)
              ElevatedButton(
                onPressed: () async {
                  print('Done button: Clearing state and reloading products...');

                  // Reload products in ProductStore BEFORE clearing
                  try {
                    final productStore = locator<ProductStore>();
                    print('Done button: Reloading ProductStore...');
                    await productStore.loadProducts();
                    await productStore.loadCategories();
                    print('Done button: Loaded ${productStore.products.length} products');
                    print('Done button: Loaded ${productStore.categories.length} categories');
                  } catch (e) {
                    print('Done button: Error reloading: $e');
                  }

                  // Clear state after loading
                  _store.clear(); // Reset state (sets isProcessing=false)

                  if (mounted) {
                    print('Done button: Navigating back to product list');
                    Navigator.pop(context); // Go back
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Done - Go Back to Product List",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
