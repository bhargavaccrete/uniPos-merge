import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'test_data_generator.dart';

class TestDataScreen extends StatefulWidget {
  const TestDataScreen({super.key});

  @override
  State<TestDataScreen> createState() => _TestDataScreenState();
}

class _TestDataScreenState extends State<TestDataScreen> {
  bool _isLoading = false;
  String _statusMessage = 'Ready to generate test data';
  int _categoryCount = 10;
  int _itemCount = 150;
  bool _includeImages = false;

  Future<void> _generateTestData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = _includeImages
          ? 'Generating test data with images...\nThis may take a while...'
          : 'Generating test data...';
    });

    try {
      await TestDataGenerator.generateCompleteTestData(
        categories: _categoryCount,
        items: _itemCount,
        withImages: _includeImages,
      );

      setState(() {
        _isLoading = false;
        _statusMessage = '✅ Successfully generated $_categoryCount categories and $_itemCount items${_includeImages ? " with images" : ""}!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Test data generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Data?', style: GoogleFonts.poppins()),
        content: Text(
          'This will delete all categories and items. This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Clearing all data...';
    });

    try {
      await TestDataGenerator.clearAllData();

      setState(() {
        _isLoading = false;
        _statusMessage = '✅ All data cleared!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ All data cleared!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ Error: $e';
      });
    }
  }

  void _showStats() {
    TestDataGenerator.printDataStats();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Check console for data statistics')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text('Test Data Generator', style: GoogleFonts.poppins()),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _isLoading ? Icons.hourglass_empty : Icons.info_outline,
                      size: 48,
                      color: Colors.blue,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    if (_isLoading) ...[
                      SizedBox(height: 20),
                      CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            // Configuration Section
            Text(
              'Configuration',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Category Count Slider
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories: $_categoryCount',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    Slider(
                      value: _categoryCount.toDouble(),
                      min: 5,
                      max: 50,
                      divisions: 9,
                      label: _categoryCount.toString(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _categoryCount = value.toInt();
                              });
                            },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 12),

            // Item Count Slider
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items: $_itemCount',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    Slider(
                      value: _itemCount.toDouble(),
                      min: 50,
                      max: 1000,
                      divisions: 19,
                      label: _itemCount.toString(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _itemCount = value.toInt();
                              });
                            },
                    ),
                    Text(
                      'Recommended: 100-500 items for performance testing',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 12),

            // Include Images Toggle
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Include Images',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _includeImages
                                ? 'All items will have colorful placeholder images (400x400px)'
                                : 'No images (faster generation)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _includeImages,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _includeImages = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateTestData,
              icon: Icon(Icons.add_circle),
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Generate Test Data',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showStats,
              icon: Icon(Icons.analytics),
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Show Data Statistics',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ),
            ),

            SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : _clearAllData,
              icon: Icon(Icons.delete_forever),
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Clear All Data',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red),
              ),
            ),

            SizedBox(height: 30),

            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Information',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• Generates random test data for performance and backup testing\n'
                      '• Items will have random prices, categories, variants, and extras\n'
                      '• Enable "Include Images" to test with image data (slower but comprehensive)\n'
                      '• Images are colorful placeholders with gradients and unique designs\n'
                      '• Perfect for testing Import/Export with large datasets\n'
                      '• Use "Clear All Data" to remove test data before production',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
