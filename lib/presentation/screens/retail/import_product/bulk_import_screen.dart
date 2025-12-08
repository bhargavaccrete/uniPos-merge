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
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Bulk Import Products"),
        backgroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Observer(
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
      ),
    );
  }

  Widget _buildUploadView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Template Format Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'File Format Requirements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Supported formats: Excel (.xlsx, .xls) or CSV (.csv)',
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Required columns (in order):',
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
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
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('CSV Template Example'),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            'Copy this and save as a .csv file:\n\n'
                            'Handle,Name,Category,Description,Option1 Name,Option1 Value,Option2 Name,Option2 Value,Option3 Name,Option3 Value,Cost Price,Selling Price,Stock,Barcode,Min Stock\n'
                            'product1,Laptop,Electronics,Gaming Laptop,,,,,,,800,1200,10,LAP001,5\n'
                            'product2,Mouse,Electronics,Wireless Mouse,,,,,,,10,25,50,MOU001,10\n'
                            'tshirt,T-Shirt,Clothing,Cotton T-Shirt,Size,Small,Color,Red,,,5,15,20,TS-RED-S,5\n'
                            'tshirt,T-Shirt,Clothing,Cotton T-Shirt,Size,Medium,Color,Red,,,5,15,15,TS-RED-M,5\n'
                            'tshirt,T-Shirt,Clothing,Cotton T-Shirt,Size,Large,Color,Blue,,,6,16,10,TS-BLU-L,5',
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
                  icon: const Icon(Icons.content_copy),
                  label: const Text('Show CSV Example'),
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
                    SnackBar(content: Text(_store.successMessage!)),
                  );
                }
                if (_store.errorMessage != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_store.errorMessage!),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.file_download),
              label: const Text("Download Excel Template"),
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
              icon: const Icon(Icons.folder_open),
              label: const Text("Select File"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Test button to add sample products
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final productStore = locator<ProductStore>();

                // Add test product directly
                final testProduct = ProductModel(
                  productId: 'test-${DateTime.now().millisecondsSinceEpoch}',
                  productName: 'Test Product ${DateTime.now().millisecondsSinceEpoch}',
                  category: 'Test Category',
                  hasVariants: false,
                  productType: 'simple',
                  createdAt: DateTime.now().toIso8601String(),
                  updateAt: DateTime.now().toIso8601String(),
                );

                await productStore.addProduct(testProduct);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Test product added! Total: ${productStore.products.length}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.bug_report),
            label: const Text("Test: Add Sample Product"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
          if (_store.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _store.errorMessage!,
                        style: const TextStyle(color: Colors.red),
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(step, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
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
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Previewing ${dataRows.length} products (${headers.length} columns). Please verify data before confirming.",
                  style: const TextStyle(color: Colors.blue),
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
                  columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
                  rows: dataRows.take(50).map((row) { // Show max 50 for preview
                    return DataRow(
                      cells: row.map((cell) => DataCell(Text(cell.toString()))).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _store.clear,
                child: const Text("Cancel"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _store.importData,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Confirm Import"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: _store.progress),
            const SizedBox(height: 20),
            Text(
              "Importing... ${(_store.progress * 100).toStringAsFixed(0)}%",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _store.logMessages.length,
                itemBuilder: (context, index) {
                  final msg = _store.logMessages[index];
                  final isError = msg.startsWith("Error");
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      msg,
                      style: TextStyle(
                        color: isError ? Colors.red : Colors.green,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _store.successMessage!,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
                child: const Text("Done - Go Back to Product List"),
              ),
          ],
        ),
      ),
    );
  }
}
