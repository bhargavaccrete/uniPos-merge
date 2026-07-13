import 'dart:typed_data';
import 'dart:ui' as ui;

/// Converts a store-logo image (PNG/JPG bytes) into ESC/POS raster bytes so it
/// can be printed on a direct thermal printer (the ESC/POS path can't render
/// image widgets like the PDF path — it needs a monochrome bitmap + the
/// `GS v 0` raster command).
///
/// Uses `dart:ui` for decode/resize (no extra package). Best-effort: returns
/// null on any failure so a bad logo never blocks the receipt from printing.
class EscPosImage {
  EscPosImage._();

  /// Encodes [imageBytes] to an ESC/POS `GS v 0` raster, resized to exactly
  /// [targetWidth] printer dots (e.g. 384 @58mm / 576 @80mm for a full receipt,
  /// ~240/360 for just a logo).
  static Future<List<int>?> toRaster(
    Uint8List imageBytes, {
    required int targetWidth,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: targetWidth,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final int w = image.width;
      final int h = image.height;
      image.dispose();
      if (byteData == null) return null;

      final rgba = byteData.buffer.asUint8List();
      final int bytesPerRow = (w + 7) >> 3; // 8 horizontal pixels per byte
      final raster = Uint8List(bytesPerRow * h);

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int i = (y * w + x) * 4;
          final int a = rgba[i + 3];
          // Perceptual luminance; transparent pixels treated as white (skipped).
          final double lum =
              0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
          if (a >= 128 && lum < 128) {
            // Dark pixel → set the bit (1 = print a dot).
            raster[y * bytesPerRow + (x >> 3)] |= (0x80 >> (x & 7));
          }
        }
      }

      // GS v 0 — print raster bitmap: m=0 (normal), width in BYTES, height in dots.
      return <int>[
        0x1D, 0x76, 0x30, 0x00,
        bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
        h & 0xFF, (h >> 8) & 0xFF,
        ...raster,
      ];
    } catch (_) {
      return null; // never block printing on a logo conversion failure
    }
  }
}
