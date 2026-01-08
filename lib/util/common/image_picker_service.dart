import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Shared image picker service for both web and mobile
/// Returns image as Uint8List which works universally
class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery
  /// Returns null if user cancels or error occurs
  static Future<Uint8List?> pickImageFromGallery({
    int imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (image != null) {
        return await image.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Pick image from camera (mobile only, returns null on web)
  /// Returns null if user cancels or error occurs
  static Future<Uint8List?> pickImageFromCamera({
    int imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (image != null) {
        return await image.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  /// Show dialog to choose between gallery and camera
  /// Returns selected image bytes or null
  static Future<Uint8List?> pickImageWithDialog({
    required Function(ImageSource) showSourceDialog,
    int imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      // This would be implemented by the caller to show their own dialog
      // For now, defaults to gallery
      return await pickImageFromGallery(
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      print('Error in pickImageWithDialog: $e');
      return null;
    }
  }

  /// Pick image and compress to specific size
  /// Useful for logos and thumbnails
  static Future<Uint8List?> pickLogoImage() async {
    return await pickImageFromGallery(
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );
  }

  /// Pick image for products (higher quality)
  static Future<Uint8List?> pickProductImage() async {
    return await pickImageFromGallery(
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
  }

  /// Pick image for categories/items
  static Future<Uint8List?> pickCategoryImage() async {
    return await pickImageFromGallery(
      imageQuality: 80,
      maxWidth: 600,
      maxHeight: 600,
    );
  }
}