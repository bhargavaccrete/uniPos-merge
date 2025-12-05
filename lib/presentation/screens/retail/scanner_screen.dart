import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final String? code = capture.barcodes.first.rawValue;
          if (code != null) {
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}
