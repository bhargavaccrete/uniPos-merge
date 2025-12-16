// Web-specific implementation using HTML APIs
// This file is used on web platform
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadBackupFile(List<int> bytes, String fileName) {
  // Web-specific download using HTML anchor element
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  // Clean up the URL after a short delay
  Future.delayed(const Duration(milliseconds: 100), () {
    html.Url.revokeObjectUrl(url);
  });
}