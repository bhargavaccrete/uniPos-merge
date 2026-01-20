import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/expensemodel_315.dart';
import '../../../data/repositories/restaurant/expense_category_repository.dart';

part 'expense_category_store.g.dart';

class ExpenseCategoryStore = _ExpenseCategoryStore with _$ExpenseCategoryStore;

abstract class _ExpenseCategoryStore with Store {
  final ExpenseCategoryRepository _repository;

  _ExpenseCategoryStore(this._repository);

  @observable
  ObservableList<ExpenseCategory> categories = ObservableList<ExpenseCategory>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  // Computed properties
  @computed
  List<ExpenseCategory> get filteredCategories {
    if (searchQuery.isEmpty) return categories;
    final lowercaseQuery = searchQuery.toLowerCase();
    return categories
        .where((category) => category.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  @computed
  List<ExpenseCategory> get enabledCategories =>
      categories.where((cat) => cat.isEnabled).toList();

  @computed
  int get totalCategories => categories.length;

  // Actions
  @action
  Future<void> loadCategories() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedCategories = await _repository.getAllExpenseCategories();
      categories = ObservableList.of(loadedCategories);
    } catch (e) {
      errorMessage = 'Failed to load expense categories: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadCategories();
  }

  @action
  Future<bool> addCategory(ExpenseCategory category) async {
    try {
      await _repository.addExpenseCategory(category);
      categories.add(category);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add expense category: $e';
      return false;
    }
  }

  @action
  Future<ExpenseCategory?> getCategoryById(String id) async {
    try {
      return await _repository.getExpenseCategoryById(id);
    } catch (e) {
      errorMessage = 'Failed to get expense category: $e';
      return null;
    }
  }

  @action
  Future<bool> updateCategory(ExpenseCategory updatedCategory) async {
    try {
      await _repository.updateExpenseCategory(updatedCategory);
      final index = categories.indexWhere((c) => c.id == updatedCategory.id);
      if (index != -1) {
        categories[index] = updatedCategory;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update expense category: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteCategory(String id) async {
    try {
      await _repository.deleteExpenseCategory(id);
      categories.removeWhere((c) => c.id == id);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete expense category: $e';
      return false;
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}