import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../core/di/service_locator.dart';
import '../componets/Button.dart';
import 'image_picker_sheet.dart';

/// Dialog for adding a new category
class AddCategoryDialog extends StatefulWidget {
  final VoidCallback? onCategoryAdded;

  const AddCategoryDialog({
    super.key,
    this.onCategoryAdded,
  });

  /// Show the add category dialog
  static Future<bool> show(BuildContext context, {VoidCallback? onCategoryAdded}) async {
    bool wasAdded = false;

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return AddCategoryDialog(
          onCategoryAdded: () {
            wasAdded = true;
            onCategoryAdded?.call();
          },
        );
      },
    );

    return wasAdded;
  }

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _categoryNameController = TextEditingController();
  Uint8List? _selectedImageBytes;

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final bytes = await ImagePickerSheet.show(context, isForCategory: true);
    if (bytes != null) {
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _addCategory() async {
    if (_categoryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name cannot be Empty')),
      );
      return;
    }

    String? imagePath;
    if (_selectedImageBytes != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final imageDir = Directory('${appDir.path}/category_images');
        if (!imageDir.existsSync()) await imageDir.create(recursive: true);
        
        final fileName = 'cat_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${imageDir.path}/$fileName');
        await file.writeAsBytes(_selectedImageBytes!);
        imagePath = file.path;
      } catch (e) {
        debugPrint('Error saving category image: $e');
      }
    }

    final newCategory = Category(
      imagePath: imagePath,
      id: const Uuid().v4(),
      name: _categoryNameController.text.trim(),
      createdTime: DateTime.now(),
      editCount: 0,
    );

    await categoryStore.addCategory(newCategory);

    widget.onCategoryAdded?.call();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Category',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Divider(),
            const SizedBox(height: 10),
            TextField(
              controller: _categoryNameController,
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                border: const OutlineInputBorder(),
                labelText: "Category Name",
              ),
            ),
            const SizedBox(height: 15),
            _buildImageUploader(),
            const SizedBox(height: 8),
            Text(
              'Upload Image (png, jpg, jpeg) up to 3mb',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 20),
            CommonButton(
              onTap: _addCategory,
              width: double.infinity,
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Add Category',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploader() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _selectedImageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _selectedImageBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image, color: Colors.grey, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Upload Category Image',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '600X400',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  )
                ],
              ),
      ),
    );
  }
}