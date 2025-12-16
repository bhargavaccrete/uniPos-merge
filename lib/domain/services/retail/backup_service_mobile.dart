// Mobile-specific implementation (no web APIs)
// This file is used on Android/iOS platforms

void downloadBackupFile(List<int> bytes, String fileName) {
  // Mobile platforms don't need special download handling
  // Files are saved directly to storage
  throw UnimplementedError('Direct download not needed on mobile platforms');
}