import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unipos/util/color.dart';
import '../../../../../util/common/app_responsive.dart';

/// Bottom sheet for selecting image source (Gallery)
class ImagePickerSheet extends StatelessWidget {
  final Function(Uint8List) onImageSelected;

  const ImagePickerSheet({
    super.key,
    required this.onImageSelected,
  });

  static Future<Uint8List?> show(BuildContext context) async {
    Uint8List? selectedBytes;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return ImagePickerSheet(
          onImageSelected: (bytes) {
            selectedBytes = bytes;
          },
        );
      },
    );

    return selectedBytes;
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      final Uint8List bytes = await pickedFile.readAsBytes();

      // Validate image size (3MB = 3 * 1024 * 1024 bytes)
      const maxSizeInBytes = 3 * 1024 * 1024;
      if (bytes.length > maxSizeInBytes) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Image size must be less than 3MB. Please choose a smaller image.'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      onImageSelected(bytes);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (context.mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Row(
               children: [
                 Icon(Icons.error_outline, color: Colors.white),
                 SizedBox(width: 12),
                 Text('Failed to pick image. Please try again.'),
               ],
             ),
             backgroundColor: Colors.red,
             behavior: SnackBarBehavior.floating,
           ),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 20),
          // Image source option
          _buildOption(
            context,
            icon: Icons.photo_library,
            label: 'From Gallery',
            onTap: () => _pickImage(context, ImageSource.gallery),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable image upload widget with preview
class ImageUploader extends StatelessWidget {
  final Uint8List? imageBytes;
  final VoidCallback onTap;
  final String uploadLabel;
  final String sizeHint;

  const ImageUploader({
    super.key,
    this.imageBytes,
    required this.onTap,
    this.uploadLabel = 'Upload Image',
    this.sizeHint = '600X400',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: AppResponsive.height(context, 0.12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      imageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image, color: Colors.grey, size: 40),
                      const SizedBox(height: 5),
                      Text(
                        uploadLabel,
                        style: TextStyle(
                          fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.4, desktop: 16.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        sizeHint,
                        style: TextStyle(
                          fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.2, desktop: 14.4),
                          color: Colors.grey.shade600,
                        ),
                      )
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload Image (png, jpg, jpeg) up to 3mb',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: AppResponsive.getValue(context, mobile: 11.0, tablet: 12.1, desktop: 13.2),
            ),
          )
        ],
      ),
    );
  }
}