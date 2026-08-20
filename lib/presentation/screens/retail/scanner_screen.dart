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
      // The scan window is a Rect in the scanner's own layout space, so it has
      // to be measured rather than guessed — and the old fixed 260px frame
      // overflowed narrow phones.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final Size previewSize = constraints.biggest;
          final double windowWidth =
              (previewSize.width * 0.75).clamp(200.0, 320.0);
          final Rect scanWindow = Rect.fromCenter(
            center: previewSize.center(Offset.zero),
            width: windowWidth,
            // Landscape ratio — retail barcodes (EAN/UPC/Code128) are wide.
            height: windowWidth * 0.5,
          );

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                // Without this the detector reads the FULL camera frame and the
                // green frame is decoration only — a barcode anywhere in view
                // was captured. Same guard the POS scanner already has
                // (posscreen.dart `_buildScannerContainer`).
                scanWindow: scanWindow,
                scanWindowUpdateThreshold: 10,
                onDetect: _onDetect,
              ),
              // Draws the border at EXACTLY the rect the detector filters on and
              // dims the rest, so what the user aims at is what actually scans.
              Positioned.fill(
                child: ScanWindowOverlay(
                  controller: _controller,
                  scanWindow: scanWindow,
                  borderColor: AppColors.success,
                  borderWidth: 3,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
