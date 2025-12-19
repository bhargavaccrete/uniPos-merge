// Web-specific file download functionality
// This file is only imported on web platforms

import 'dart:convert';
import 'dart:html' as html;

/// Downloads a file in the browser
void downloadFile(String filename, String jsonString) {
  final bytes = utf8.encode(jsonString);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}