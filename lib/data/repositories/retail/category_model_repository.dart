import 'package:hive/hive.dart';
import '../../models/retail/hive_model/category_model_215.dart';
import 'package:uuid/uuid.dart';

/// Repository for CategoryModel with GST support
class CategoryModelRepository {
  late Box<CategoryModel> _categoryBox;

  CategoryModelRepository() {
    _categoryBox = Hive.box<CategoryModel>('category_models');
  }

  /// Get all categories
  Future<List<CategoryModel>> getAllCategories() async {
    return _categoryBox.values.toList();
  }

  /// Get category by ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      return _categoryBox.values.firstWhere((c) => c.categoryId == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Get category by name
  Future<CategoryModel?> getCategoryByName(String categoryName) async {
    try {
      return _categoryBox.values.firstWhere(
        (c) => c.categoryName.toLowerCase() == categoryName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Add a new category
  Future<void> addCategory(CategoryModel category) async {
    await _categoryBox.put(category.categoryId, category);
  }

  /// Update a category
  Future<void> updateCategory(CategoryModel category) async {
    await _categoryBox.put(category.categoryId, category);
  }

  /// Delete a category
  Future<void> deleteCategory(String categoryId) async {
    await _categoryBox.delete(categoryId);
  }

  /// Update GST rate for a category
  Future<void> updateGstRate(String categoryId, double gstRate) async {
    final category = await getCategoryById(categoryId);
    if (category != null) {
      final updated = category.copyWith(gstRate: gstRate);
      await updateCategory(updated);
    }
  }

  /// Get GST rate for category name (for products that use string category)
  Future<double?> getGstRateByName(String categoryName) async {
    final category = await getCategoryByName(categoryName);
    return category?.gstRate;
  }

  /// Clear all categories
  Future<void> clearAll() async {
    await _categoryBox.clear();
  }

  /// Add default categories with common GST rates
  Future<void> addDefaultCategories() async {
    if (_categoryBox.isEmpty) {
      const uuid = Uuid();
      final defaults = [
        CategoryModel.create(
          categoryId: uuid.v4(),
          categoryName: 'Electronics',
          gstRate: 18,
          description: 'Electronic items and gadgets',
        ),
        CategoryModel.create(
          categoryId: uuid.v4(),
          categoryName: 'Clothing',
          gstRate: 5,
          description: 'Apparel and garments',
        ),
        CategoryModel.create(
          categoryId: uuid.v4(),
          categoryName: 'Groceries',
          gstRate: 0,
          description: 'Food and grocery items',
        ),
        CategoryModel.create(
          categoryId: uuid.v4(),
          categoryName: 'Footwear',
          gstRate: 12,
          description: 'Shoes and footwear',
        ),
        CategoryModel.create(
          categoryId: uuid.v4(),
          categoryName: 'Cosmetics',
          gstRate: 28,
          description: 'Beauty and personal care',
        ),
        CategoryModel.create(
          categoryId: uuid.v4(),
          categoryName: 'Uncategorized',
          gstRate: 0,
          description: 'Default category',
        ),
      ];

      for (var category in defaults) {
        await addCategory(category);
      }
    }
  }

  /// Migrate from old string categories to CategoryModel
  Future<void> migrateFromStringCategories(List<String> oldCategories) async {
    const uuid = Uuid();
    for (var categoryName in oldCategories) {
      final existing = await getCategoryByName(categoryName);
      if (existing == null) {
        final category = CategoryModel.create(
          categoryId: uuid.v4(),
          categoryName: categoryName,
          gstRate: 0, // Default to 0%, admin can set later
        );
        await addCategory(category);
      }
    }
  }
}