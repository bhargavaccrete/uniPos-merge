import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../data/repositories/restaurant/variant_repository.dart';

part 'variant_store.g.dart';

class VariantStore = _VariantStore with _$VariantStore;

abstract class _VariantStore with Store {
  final VariantRepositoryRes _repository;

  _VariantStore(this._repository);

  @observable
  ObservableList<VariantModel> variants = ObservableList<VariantModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  // Computed properties
  @computed
  List<VariantModel> get filteredVariants {
    if (searchQuery.isEmpty) return variants;
    final lowercaseQuery = searchQuery.toLowerCase();
    return variants
        .where((variant) => variant.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  @computed
  int get totalVariants => variants.length;

  // Actions
  @action
  Future<void> loadVariants() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedVariants = await _repository.getAllVariants();
      variants = ObservableList.of(loadedVariants);
    } catch (e) {
      errorMessage = 'Failed to load variants: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadVariants();
  }

  @action
  Future<bool> addVariant(VariantModel variant) async {
    try {
      await _repository.addVariant(variant);
      variants.add(variant);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add variant: $e';
      return false;
    }
  }

  @action
  Future<VariantModel?> getVariantById(String id) async {
    try {
      return await _repository.getVariantById(id);
    } catch (e) {
      errorMessage = 'Failed to get variant: $e';
      return null;
    }
  }

  @action
  Future<bool> updateVariant(VariantModel updatedVariant) async {
    try {
      await _repository.updateVariant(updatedVariant);
      final index = variants.indexWhere((v) => v.id == updatedVariant.id);
      if (index != -1) {
        variants[index] = updatedVariant;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update variant: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteVariant(String id) async {
    try {
      await _repository.deleteVariant(id);
      variants.removeWhere((v) => v.id == id);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete variant: $e';
      return false;
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void clearFilters() {
    searchQuery = '';
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}