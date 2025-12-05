import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../../util/restaurant/responsive_helper.dart';

/// Bottom sheet for selecting image source (Gallery/Search)
class ImagePickerSheet extends StatelessWidget {
  final Function(File) onImageSelected;
  final bool isForCategory;

  const ImagePickerSheet({
    super.key,
    required this.onImageSelected,
    this.isForCategory = false,
  });

  static Future<File?> show(BuildContext context, {bool isForCategory = false}) async {
    File? selectedFile;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return ImagePickerSheet(
          isForCategory: isForCategory,
          onImageSelected: (file) {
            selectedFile = file;
          },
        );
      },
    );

    return selectedFile;
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) {
      Navigator.pop(context);
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/product_images');
    if (!imageDir.existsSync()) imageDir.createSync(recursive: true);

    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final newPath = '${imageDir.path}/$fileName';

    final savedImage = await File(pickedFile.path).copy(newPath);

    onImageSelected(savedImage);
    Navigator.pop(context);
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
  final File? selectedImage;
  final VoidCallback onTap;
  final String uploadLabel;
  final String sizeHint;

  const ImageUploader({
    super.key,
    this.selectedImage,
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
            child: selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      selectedImage!,
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
