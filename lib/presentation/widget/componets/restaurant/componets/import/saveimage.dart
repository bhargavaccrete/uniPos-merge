// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as path;
//
// /// Copies the image from a temporary path to a permanent one in the app's documents directory.
// Future<String?> saveImagePermanently(String temporaryImagePath) async {
//   try {
//     // 1. Get the directory where we can save files permanently.
//     final directory = await getApplicationDocumentsDirectory();
//
//     // 2. Generate a unique file name to avoid conflicts.
//     final String fileName = path.basename(temporaryImagePath);
//
//     // 3. Create a new path in the documents directory.
//     final String permanentPath = path.join(directory.path, fileName);
//
//     // 4. Copy the file from the temporary path to the new path.
//     final File newFile = await File(temporaryImagePath).copy(permanentPath);
//
//     // 5. Return the new, permanent path.
//     return newFile.path;
//   } catch (e) {
//     print('Error saving image: $e');
//     return null;
//   }
// }