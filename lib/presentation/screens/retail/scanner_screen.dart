import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';

/// Full-screen barcode scanner that returns the scanned code to its caller.
///
/// [onDetect] is a stream — it fires repeatedly while a barcode stays in frame.
/// Popping on every detection popped the *calling* screen too, which is why a
/// scan used to land you two screens back with no barcode captured. [_handled]
/// makes the pop one-shot; the POS solves the same problem with a time window
/// (`posscreen.dart`) because its scanner stays open across many scans.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere(
          (value) => value != null && value.trim().isNotEmpty,
          orElse: () => null,
        );
    if (code == null) return;

    _handled = true;
    // Stop the camera before popping so no further frames are delivered to a
    // disposed route.
    _controller.stop();
    if (mounted) Navigator.of(context).pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: buildPrimaryAppBar(
        title: 'Scan Barcode',
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Aiming frame, same treatment as the POS scanner overlay.
          Center(
            child: Container(
              width: 260,
              height: 130,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.success, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
