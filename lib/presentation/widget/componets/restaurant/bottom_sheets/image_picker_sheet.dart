import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../../util/restaurant/responsive_helper.dart';

/// Bottom sheet for selecting image source (Gallery/Search)
class ImagePickerSheet extends StatelessWidget {
  final Function(Uint8List) onImageSelected;
  final bool isForCategory;

  const ImagePickerSheet({
    super.key,
    required this.onImageSelected,
    this.isForCategory = false,
  });

  static Future<Uint8List?> show(BuildContext context, {bool isForCategory = false}) async {
    Uint8List? selectedBytes;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return ImagePickerSheet(
          isForCategory: isForCategory,
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

      onImageSelected(bytes);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (context.mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to add image: $e')),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: ResponsiveHelper.responsiveHeight(context, 0.25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildOption(
              context,
              icon: Icons.photo_library,
              label: 'From Gallery',
              onTap: () => _pickImage(context, ImageSource.gallery),
            ),
            _buildOption(
              context,
              icon: Icons.search,
              label: 'From Search',
              onTap: () {
                // TODO: Implement search functionality
              },
            ),
          ],
        ),
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
      child: Container(
        alignment: Alignment.center,
        width: ResponsiveHelper.responsiveWidth(context, 0.35),
        height: ResponsiveHelper.responsiveHeight(context, 0.2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: primarycolor),
            Text(label),
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
            height: ResponsiveHelper.responsiveHeight(context, 0.12),
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
                          fontSize: ResponsiveHelper.responsiveTextSize(context, 14),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        sizeHint,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.responsiveTextSize(context, 12),
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
              fontSize: ResponsiveHelper.responsiveTextSize(context, 11),
            ),
          )
        ],
      ),
    );
  }
}