/*
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FullScreenScanner extends StatefulWidget {
  const FullScreenScanner({super.key});

  @override
  State<FullScreenScanner> createState() => _FullScreenScannerState();
}

class _FullScreenScannerState extends State<FullScreenScanner> {
  final MobileScannerController controller =
  MobileScannerController(
    autoStart: true,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool scanned = false;
  bool torchOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// ================= CAMERA VIEW =================
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (scanned) return;

              final barcode = capture.barcodes.first.rawValue;
              if (barcode != null && barcode.isNotEmpty) {
                scanned = true;

                // Return scanned barcode to previous screen
                Navigator.pop(context, barcode);
              }
            },
          ),

          /// ================= SCAN LINE =================
          Center(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              color: Colors.redAccent,
            ),
          ),

          /// ================= TOP BAR =================
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          /// ================= BOTTOM CONTROLS =================
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                /// FLASHLIGHT
                IconButton(
                  icon: Icon(
                    torchOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    controller.toggleTorch();
                    setState(() => torchOn = !torchOn);
                  },
                ),

                /// CANCEL
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
*/
