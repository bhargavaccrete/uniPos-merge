import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../data/repositories/restaurant/variant_repository.dart';

part 'variant_store.g.dart';

class VariantStore = _VariantStore with _$VariantStore;

abstract class _VariantStore with Store {
  final VariantRepository _variantRepository = locator<VariantRepository>();

  final ObservableList<VariantModel> variants = ObservableList<VariantModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  _VariantStore() {
    _init();
  }

  Future<void> _init() async {
    await loadVariants();
  }

  @computed
  int get variantCount => variants.length;

  @action
  Future<void> loadVariants() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = _variantRepository.getAllVariants();
      variants.clear();
      variants.addAll(loaded);
    } catch (e) {
      errorMessage = 'Failed to load variants: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addVariant(VariantModel variant) async {
    try {
      await _variantRepository.addVariant(variant);
      variants.add(variant);
    } catch (e) {
      errorMessage = 'Failed to add variant: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateVariant(VariantModel variant) async {
    try {
      await _variantRepository.updateVariant(variant);
      final index = variants.indexWhere((v) => v.id == variant.id);
      if (index != -1) {
        variants[index] = variant;
      }
    } catch (e) {
      errorMessage = 'Failed to update variant: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteVariant(String id) async {
    try {
      await _variantRepository.deleteVariant(id);
      variants.removeWhere((variant) => variant.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete variant: $e';
      rethrow;
    }
  }

  VariantModel? getVariantById(String id) {
    try {
      return variants.firstWhere((variant) => variant.id == id);
    } catch (e) {
      return null;
    }
  }
}