import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:unipos/util/common/image_picker_service.dart';
import 'package:unipos/util/color.dart';

/// Universal image picker widget that works on web and mobile
/// Replaces the old File-based approach with Uint8List
class UniversalImagePicker {
  /// Show bottom sheet to select image source
  /// Returns Uint8List or null
  static Future<Uint8List?> showPicker(
    BuildContext context, {
    bool showCameraOption = true,
    Color? primary,
  }) async {
    if (kIsWeb || !showCameraOption) {
      // On web or if camera disabled, go directly to gallery
      return await ImagePickerService.pickImageFromGallery();
    }

    // On mobile, show options dialog
    return await showModalBottomSheet<Uint8List>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOption(
                    context,
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () async {
                      final bytes = await ImagePickerService.pickImageFromGallery();
                      Navigator.pop(context, bytes);
                    },
                    color: AppColors.primary ,
                  ),
                  if (!kIsWeb)
                    _buildOption(
                      context,
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () async {
                        final bytes = await ImagePickerService.pickImageFromCamera();
                        Navigator.pop(context, bytes);
                      },
                      color: AppColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 50,
              color: color ?? Colors.blue,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable image upload widget with preview
/// Works with Uint8List instead of File
class UniversalImageUploader extends StatelessWidget {
  final Uint8List? imageBytes;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String uploadLabel;
  final String sizeHint;
  final double? height;
  final Color? borderColor;
  final Color? iconColor;

  const UniversalImageUploader({
    super.key,
    this.imageBytes,
    required this.onTap,
    this.onDelete,
    this.uploadLabel = 'Upload Image',
    this.sizeHint = 'Recommended: 600x400',
    this.height = 200,
    this.borderColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor ?? Colors.grey,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(10),
              color: imageBytes != null ? Colors.black : Colors.grey.shade100,
            ),
            child: imageBytes != null
                ? Stack(
                    children: [
                      // Image preview
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          imageBytes!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      // Delete button
                      if (onDelete != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: onDelete,
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image,
                        color: iconColor ?? Colors.grey,
                        size: 60,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        uploadLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        sizeHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
          ),
          if (imageBytes == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Upload Image (png, jpg, jpeg) up to 3mb',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}