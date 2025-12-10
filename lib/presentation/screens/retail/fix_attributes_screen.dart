import 'package:flutter/material.dart';
import 'package:unipos/core/init/hive_init.dart';

/// Temporary screen to fix "bad element" attribute errors
/// Navigate here if you're getting "bad state bad element" errors
class FixAttributesScreen extends StatefulWidget {
  const FixAttributesScreen({Key? key}) : super(key: key);

  @override
  State<FixAttributesScreen> createState() => _FixAttributesScreenState();
}

class _FixAttributesScreenState extends State<FixAttributesScreen> {
  bool _isResetting = false;
  String? _message;
  bool _success = false;

  Future<void> _resetAttributes() async {
    setState(() {
      _isResetting = true;
      _message = null;
      _success = false;
    });

    try {
      await HiveInit.resetAttributeBoxes();

      setState(() {
        _success = true;
        _message = 'Attribute boxes reset successfully!\n\nPlease restart the app completely for changes to take effect.';
      });

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Success!'),
              ],
            ),
            content: const Text(
              'Attribute boxes have been reset.\n\n'
              'IMPORTANT: Close and restart the app completely now.\n\n'
              'After restart, you can:\n'
              '1. Import your Excel file again\n'
              '2. Create attributes normally\n'
              '3. Use attributes in Add Product screen',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _success = false;
        _message = 'Error resetting boxes: $e';
      });
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Attribute Errors'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              'Fix "Bad Element" Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'If you\'re seeing "bad state bad element" errors when creating or viewing attributes, use this tool to reset the attribute database.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'WARNING',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This will delete ALL attribute data including:\n'
                    '• All global attributes (Size, Color, etc.)\n'
                    '• All attribute values\n'
                    '• Product-attribute assignments\n\n'
                    'Your products and variants will NOT be deleted,\n'
                    'but you will need to re-import or recreate attributes.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_message != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _success ? Colors.green.shade50 : Colors.red.shade50,
                  border: Border.all(
                    color: _success ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _success ? Icons.check_circle : Icons.error,
                      color: _success ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _message!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _isResetting ? null : _resetAttributes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isResetting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 16),
                        Text('Resetting...'),
                      ],
                    )
                  : const Text(
                      'Reset Attribute Boxes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              'After resetting:\n'
              '1. Restart the app completely\n'
              '2. Re-import your product Excel file\n'
              '3. Attributes will be recreated automatically',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}