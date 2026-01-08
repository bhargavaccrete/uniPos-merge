# Universal Image Picker Usage Guide

This guide shows how to use the universal image picker across retail and restaurant sides.

## ✅ Benefits

- **Works on Web AND Mobile** - No platform-specific code needed
- **Consistent API** - Same usage everywhere
- **Memory-based** - Uses `Uint8List` instead of `File` objects
- **Easy to use** - Simple one-line calls

## 📦 Files Created

1. `lib/util/common/image_picker_service.dart` - Core service
2. `lib/presentation/widget/componets/common/universal_image_picker.dart` - UI widgets

---

## 🔧 Basic Usage

### 1. Pick Image (Simple)

```dart
import 'package:unipos/util/common/image_picker_service.dart';

// Pick any image
final Uint8List? imageBytes = await ImagePickerService.pickImageFromGallery();

if (imageBytes != null) {
  // Use the image bytes
  setState(() {
    _imageBytes = imageBytes;
  });
}
```

### 2. Pick Image with Dialog (Recommended)

```dart
import 'package:unipos/presentation/widget/componets/common/universal_image_picker.dart';

// Show dialog with options (Gallery/Camera on mobile, Gallery only on web)
final Uint8List? imageBytes = await UniversalImagePicker.showPicker(
  context,
  showCameraOption: true,  // Show camera option on mobile
  primaryColor: primarycolor,
);

if (imageBytes != null) {
  setState(() {
    _imageBytes = imageBytes;
  });
}
```

### 3. Display Image Preview

```dart
import 'package:unipos/presentation/widget/componets/common/universal_image_picker.dart';

UniversalImageUploader(
  imageBytes: _imageBytes,  // Your Uint8List? variable
  onTap: () async {
    final bytes = await UniversalImagePicker.showPicker(context);
    if (bytes != null) {
      setState(() {
        _imageBytes = bytes;
      });
    }
  },
  onDelete: () {
    setState(() {
      _imageBytes = null;
    });
  },
  uploadLabel: 'Upload Logo',
  sizeHint: '800x800 recommended',
  height: 200,
  borderColor: primarycolor,
)
```

---

## 📱 Platform Compatibility

### What Works Everywhere:

✅ `ImagePickerService.pickImageFromGallery()` - Gallery picker
✅ `Image.memory(imageBytes)` - Display images
✅ `MemoryImage(imageBytes)` - For decorations
✅ Store as `Uint8List` in variables/state
✅ Save to Hive as `Uint8List`

### Mobile Only:

📱 `ImagePickerService.pickImageFromCamera()` - Camera (returns null on web)
📱 Saving to local file system with `File`

The `UniversalImagePicker.showPicker()` handles this automatically:
- **Web**: Shows only Gallery option
- **Mobile**: Shows Gallery and Camera options

---

## 🏪 Retail Side Examples

### Store Logo Settings

```dart
// In your retail settings screen
Uint8List? _logoBytes;

// Pick logo
final bytes = await ImagePickerService.pickLogoImage();
if (bytes != null) {
  setState(() {
    _logoBytes = bytes;
  });
  // Save to service
  await storeSettingsService.saveLogo(bytes);
}
```

### Product Images

```dart
// In add product screen
Uint8List? _productImage;

// Pick product image
final bytes = await ImagePickerService.pickProductImage();
if (bytes != null) {
  setState(() {
    _productImage = bytes;
  });
}
```

---

## 🍽️ Restaurant Side Examples

### Category Images

```dart
// In category management
import 'package:unipos/presentation/widget/componets/common/universal_image_picker.dart';

Uint8List? _categoryImage;

// Pick image with dialog
final bytes = await UniversalImagePicker.showPicker(
  context,
  primaryColor: primarycolor,
);

if (bytes != null) {
  setState(() {
    _categoryImage = bytes;
  });
}

// Display with preview
UniversalImageUploader(
  imageBytes: _categoryImage,
  onTap: () async {
    final bytes = await UniversalImagePicker.showPicker(context);
    if (bytes != null) {
      setState(() {
        _categoryImage = bytes;
      });
    }
  },
  onDelete: () => setState(() => _categoryImage = null),
  uploadLabel: 'Upload Category Image',
  borderColor: primarycolor,
  iconColor: primarycolor,
)
```

### Item/Menu Images

```dart
// In add item sheet
Uint8List? _itemImage;

UniversalImageUploader(
  imageBytes: _itemImage,
  onTap: () async {
    final bytes = await ImagePickerService.pickProductImage();
    if (bytes != null) {
      setState(() {
        _itemImage = bytes;
      });
    }
  },
  uploadLabel: 'Upload Item Image',
  sizeHint: '600x400 recommended',
)
```

---

## 💾 Storing Images

### In Hive Models

```dart
@HiveType(typeId: XX)
class YourModel {
  @HiveField(0)
  final Uint8List? image;

  YourModel({this.image});
}
```

### In State/MobX Stores

```dart
@observable
Uint8List? imageByte;

@action
void setImage(Uint8List? bytes) {
  imageByte = bytes;
}

@action
Future<void> pickImage() async {
  final bytes = await ImagePickerService.pickImageFromGallery();
  if (bytes != null) {
    setImage(bytes);
  }
}
```

---

## 🔄 Migration from Old File-based Approach

### Before (Mobile Only):
```dart
import 'dart:io';  // ❌ Won't work on web

File? _selectedImage;
final pickedFile = await picker.pickImage(source: ImageSource.gallery);
if (pickedFile != null) {
  _selectedImage = File(pickedFile.path);  // ❌ File-based
}

// Display
Image.file(_selectedImage!)  // ❌ File-based
```

### After (Web + Mobile):
```dart
// ✅ Works everywhere

Uint8List? _imageBytes;
final bytes = await ImagePickerService.pickImageFromGallery();
if (bytes != null) {
  _imageBytes = bytes;  // ✅ Bytes-based
}

// Display
Image.memory(_imageBytes!)  // ✅ Memory-based
```

---

## 🎯 Quick Reference

| Use Case | Method |
|----------|--------|
| Any image | `ImagePickerService.pickImageFromGallery()` |
| Logo (800x800) | `ImagePickerService.pickLogoImage()` |
| Product (1200x1200) | `ImagePickerService.pickProductImage()` |
| Category (600x600) | `ImagePickerService.pickCategoryImage()` |
| Camera (mobile) | `ImagePickerService.pickImageFromCamera()` |
| With dialog | `UniversalImagePicker.showPicker(context)` |
| Preview widget | `UniversalImageUploader(...)` |

---

## ⚠️ Important Notes

1. **Always use `Uint8List`** - Never use `File` objects for cross-platform compatibility
2. **Test on web** - Make sure to test image features on web builds
3. **Image quality** - Adjust `imageQuality` parameter (0-100) to balance size vs quality
4. **Max dimensions** - Use `maxWidth` and `maxHeight` to limit image size
5. **Null safety** - Always check if returned bytes are not null

---

## 🐛 Common Issues

**Issue**: "dart:io not available on web"
**Solution**: Use `Uint8List` instead of `File`, use `Image.memory()` instead of `Image.file()`

**Issue**: Camera not working on web
**Solution**: Camera is mobile-only. The `showPicker()` automatically hides camera option on web.

**Issue**: Images too large
**Solution**: Use the specific picker methods (`pickLogoImage()`, etc.) which have size limits, or pass `maxWidth`/`maxHeight` parameters.