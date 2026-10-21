/// Decode caps for `Image.memory`.
///
/// These bound the DECODED bitmap, which `width:`/`height:` do not — those set
/// the layout box while Flutter still decodes the image at its native size and
/// scales it down to paint. A 4000x3000 photo decodes to roughly 48 MB of
/// raster per visible tile regardless of how small the widget is.
///
/// Passing `cacheWidth` alone (never both) keeps the decode proportional, so
/// aspect ratio under `BoxFit.cover`/`contain` is unchanged.
///
/// Values are deliberately generous against the logical sizes they serve, so a
/// 3x-DPI screen still has more source pixels than it paints.
class ImageDecodeSizes {
  ImageDecodeSizes._();

  /// List/avatar thumbnails — rendered at 40-58 logical px.
  static const int thumbnail = 256;

  /// Menu and product grid cards — rendered at up to ~250 logical px wide.
  static const int gridTile = 640;

  /// Form previews — rendered 160-280 logical px tall, full width.
  static const int preview = 1024;
}
