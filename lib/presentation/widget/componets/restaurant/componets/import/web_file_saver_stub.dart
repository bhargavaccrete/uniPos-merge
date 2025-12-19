// Stub for non-web platforms
// This file is imported on mobile/desktop platforms where dart:html is not available

/// Downloads a file in the browser (stub for non-web platforms)
void downloadFile(String filename, String jsonString) {
  throw UnsupportedError('downloadFile is only supported on web platforms');
}