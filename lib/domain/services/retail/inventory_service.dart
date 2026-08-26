import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/models/retail/hive_model/cart_model_202.dart';
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/models/retail/hive_model/bundle_model.dart';
import '../../../data/models/retail/hive_model/kit_assembly_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../restaurant/day_management_service.dart';

/// Deducts stock for a completed retail sale.
///
/// Before this service, `checkout_screen.dart` mutated `variant.stockQty`
/// directly with no audit row — the one gap in an otherwise fully-logged
/// retail stock ledger (manual adjustments and returns both write a
/// [StockMovementModel] via [StockAdjustmentService]/`return_service.dart`;
/// only the sale path didn't). This centralizes sale-time deduction so it
/// logs the same way, and gives bundle/kit cascade logic (see
/// docs/retail_inventory_system_plan.md) a service layer to hang off instead
/// of growing inside the checkout screen. Mirrors restaurant's
/// `InventoryService.deductStockForOrder`.
class RetailInventoryService {
  RetailInventoryService._();

  static final StockMovementRepository _movements = StockMovementRepository();

  /// Retail sells in whole units — same convention as [StockAdjustmentService].
  static const String _unit = 'pcs';

  static Future<void> deductStockForSale(List<CartItemModel> cartItems) async {
    final staffName = authService.currentUsername ?? 'Staff';
    final sessionId = await DayManagementService.getCurrentSessionId();

    for (final item in cartItems) {
      ProductModel? product;
      try {
        product = productStore.products.firstWhere(
          (p) => p.productId == item.productId,
        );
      } catch (_) {}

      // Bundle products have no stock of their own — cascade the deduction
      // into their components instead. See
      // docs/retail_inventory_system_plan.md §3.2.
      if (product != null && product.isBundle) {
        await _deductBundleComponents(
          bundleProduct: product,
          bundleVariantId: item.variantId,
          saleQty: item.qty,
          staffName: staffName,
          sessionId: sessionId,
        );
        continue;
      }

      final variant = await productStore.getVariantById(item.variantId);
      if (variant == null) continue;

      final newStock = variant.stockQty - item.qty;
      final finalStock = newStock < 0 ? 0.0 : newStock;
      await productStore.updateVariantStock(item.variantId, finalStock);

      final label = product != null && variant.hasAttributes
          ? '${product.productName} (${variant.variantDescription})'
          : (product?.productName ?? item.productName);

      await _movements.saveMovement(StockMovementModel(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: item.productId,
        variantId: item.variantId,
        itemName: label,
        type: 'out',
        quantity: item.qty.toDouble(),
        balanceAfter: finalStock.toDouble(),
        reason: 'Sale',
        unit: _unit,
        staffName: staffName,
        sessionId: sessionId,
      ));
    }
  }

  /// Expands a bundle's sale into deductions against its components (one
  /// level deep — a component must be a `standard` variant, never itself
  /// `bundle`/`repack`, enforced at the picker level in the Bundle Builder
  /// UI). Logs one [StockMovementModel] per component with a reason that
  /// traces back to the bundle, mirroring restaurant's
  /// `InventoryService._deductRecipeIngredients`.
  static Future<void> _deductBundleComponents({
    required ProductModel bundleProduct,
    required String bundleVariantId,
    required double saleQty,
    required String staffName,
    required String? sessionId,
  }) async {
    final RetailBundleModel? bundle = bundleRepository.getBundleForVariant(bundleVariantId);
    if (bundle == null || !bundle.hasComponents) return; // unconfigured bundle — nothing to deduct

    for (final component in bundle.components) {
      final variant = await productStore.getVariantById(component.componentVariantId);
      if (variant == null) continue;

      final deductQty = saleQty * component.quantity;
      final newStock = variant.stockQty - deductQty;
      final finalStock = newStock < 0 ? 0.0 : newStock;
      await productStore.updateVariantStock(component.componentVariantId, finalStock);

      String label = variant.sku ?? component.componentVariantId;
      try {
        final componentProduct = productStore.products.firstWhere(
          (p) => p.productId == variant.productId,
        );
        label = variant.hasAttributes
            ? '${componentProduct.productName} (${variant.variantDescription})'
            : componentProduct.productName;
      } catch (_) {}

      await _movements.saveMovement(StockMovementModel(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: variant.productId,
        variantId: variant.varianteId,
        itemName: label,
        type: 'out',
        quantity: deductQty.toDouble(),
        balanceAfter: finalStock.toDouble(),
        reason: 'Sale (bundle: ${bundleProduct.productName})',
        unit: _unit,
        staffName: staffName,
        sessionId: sessionId,
      ));
    }
  }

  /// Live "N can be sold" count for a bundle-type variant — the minimum,
  /// across its bundle's components, of how many bundles current component
  /// stock supports. Mirrors restaurant's
  /// `InventoryService.calculateAvailableToMake`. Returns 0 if the variant
  /// has no bundle configured or a component is out of stock/missing.
  static double calculateAvailableToSell(ProductModel product, VarianteModel variant) {
    if (!product.isBundle) return variant.stockQty;
    final RetailBundleModel? bundle = bundleRepository.getBundleForVariant(variant.varianteId);
    if (bundle == null || !bundle.hasComponents) return 0;

    double? minBundles;
    for (final component in bundle.components) {
      if (component.quantity <= 0) continue;
      VarianteModel? componentVariant;
      try {
        componentVariant = productStore.variants.firstWhere(
          (v) => v.varianteId == component.componentVariantId,
        );
      } catch (_) {
        return 0; // a required component no longer exists — can't be sold
      }
      final bundlesFromThisComponent =
          (componentVariant.stockQty ~/ component.quantity).toDouble();
      minBundles = minBundles == null
          ? bundlesFromThisComponent
          : (bundlesFromThisComponent < minBundles ? bundlesFromThisComponent : minBundles);
    }
    if (minBundles == null) return 0; // no valid components — nothing sellable
    return minBundles < 0 ? 0 : minBundles;
  }

  /// Assembles one batch of a repack/kit variant from its components:
  /// validates every component has enough stock (all-or-nothing — no
  /// partial deduction on shortage), deducts each component, credits the
  /// kit variant's own stock by [batchQty], logs a StockMovementModel per
  /// component plus one for the assembled variant, and writes an
  /// append-only [RetailKitAssemblyModel] row linking every movement. Throws
  /// [Exception] with a user-facing message on validation failure. Mirrors
  /// restaurant's `InventoryService.produceBatch`. See
  /// docs/retail_inventory_system_plan.md §3.2.
  static Future<RetailKitAssemblyModel> assembleKit({
    required ProductModel kitProduct,
    required String kitVariantId,
    required int batchQty,
  }) async {
    if (batchQty <= 0) {
      throw Exception('Batch quantity must be greater than zero.');
    }
    final RetailBundleModel? bundle = bundleRepository.getBundleForVariant(kitVariantId);
    if (bundle == null || !bundle.hasComponents) {
      throw Exception('${kitProduct.productName} has no components configured.');
    }

    // Validate stock availability up front so assembly is all-or-nothing.
    final List<String> shortages = [];
    for (final component in bundle.components) {
      final variant = await productStore.getVariantById(component.componentVariantId);
      if (variant == null) {
        shortages.add('a required component no longer exists');
        continue;
      }
      final required = component.quantity * batchQty;
      if (variant.stockQty < required) {
        shortages.add(
          '${variant.sku ?? component.componentVariantId} '
          '(need $required, have ${variant.stockQty})',
        );
      }
    }
    if (shortages.isNotEmpty) {
      throw Exception('Insufficient stock: ${shortages.join(', ')}');
    }

    final staffName = authService.currentUsername ?? 'Staff';
    final sessionId = await DayManagementService.getCurrentSessionId();
    final movementIds = <String>[];

    for (final component in bundle.components) {
      final variant = await productStore.getVariantById(component.componentVariantId);
      if (variant == null) continue;

      final deductQty = component.quantity * batchQty;
      final newStock = variant.stockQty - deductQty;
      await productStore.updateVariantStock(component.componentVariantId, newStock);

      String label = variant.sku ?? component.componentVariantId;
      try {
        final componentProduct = productStore.products.firstWhere(
          (p) => p.productId == variant.productId,
        );
        label = variant.hasAttributes
            ? '${componentProduct.productName} (${variant.variantDescription})'
            : componentProduct.productName;
      } catch (_) {}

      final movementId = const Uuid().v4();
      await _movements.saveMovement(StockMovementModel(
        id: movementId,
        timestamp: DateTime.now(),
        itemId: variant.productId,
        variantId: variant.varianteId,
        itemName: label,
        type: 'out',
        quantity: deductQty.toDouble(),
        balanceAfter: newStock.toDouble(),
        reason: 'Assembly (${kitProduct.productName})',
        unit: _unit,
        staffName: staffName,
        sessionId: sessionId,
      ));
      movementIds.add(movementId);
    }

    final kitVariant = await productStore.getVariantById(kitVariantId);
    final newKitStock = (kitVariant?.stockQty ?? 0) + batchQty;
    await productStore.updateVariantStock(kitVariantId, newKitStock);

    final producedMovementId = const Uuid().v4();
    await _movements.saveMovement(StockMovementModel(
      id: producedMovementId,
      timestamp: DateTime.now(),
      itemId: kitProduct.productId,
      variantId: kitVariantId,
      itemName: kitProduct.productName,
      type: 'in',
      quantity: batchQty.toDouble(),
      balanceAfter: newKitStock.toDouble(),
      reason: 'Assembly batch',
      unit: _unit,
      staffName: staffName,
      sessionId: sessionId,
    ));
    movementIds.add(producedMovementId);

    final assembly = RetailKitAssemblyModel(
      id: const Uuid().v4(),
      bundleId: bundle.id,
      variantId: kitVariantId,
      productName: kitProduct.productName,
      batchQty: batchQty,
      assembledTime: DateTime.now(),
      assembledBy: staffName,
      movementIds: movementIds,
    );
    await kitAssemblyRepository.saveAssembly(assembly);

    return assembly;
  }

  /// Reverses [assembleKit] — breaks [batchQty] units of an assembled
  /// repack/kit variant back down into its components. Used when an
  /// assembled kit needs to be undone (e.g. a customer return of the kit
  /// SKU, or a packing mistake) without losing the components' value.
  ///
  /// All-or-nothing like the forward direction: validates the kit variant
  /// actually has [batchQty] units on hand before touching any stock.
  static Future<RetailKitAssemblyModel> disassembleKit({
    required ProductModel kitProduct,
    required String kitVariantId,
    required int batchQty,
  }) async {
    if (batchQty <= 0) {
      throw Exception('Batch quantity must be greater than zero.');
    }
    final RetailBundleModel? bundle = bundleRepository.getBundleForVariant(kitVariantId);
    if (bundle == null || !bundle.hasComponents) {
      throw Exception('${kitProduct.productName} has no components configured.');
    }

    final kitVariant = await productStore.getVariantById(kitVariantId);
    final kitStock = kitVariant?.stockQty ?? 0;
    if (kitStock < batchQty) {
      throw Exception(
        'Not enough assembled stock: need $batchQty, have $kitStock.',
      );
    }

    final staffName = authService.currentUsername ?? 'Staff';
    final sessionId = await DayManagementService.getCurrentSessionId();
    final movementIds = <String>[];

    // Kit stock first, mirroring assembleKit's component-then-produced order
    // reversed: the kit is what's being consumed here.
    final newKitStock = kitStock - batchQty;
    await productStore.updateVariantStock(kitVariantId, newKitStock);

    final consumedMovementId = const Uuid().v4();
    await _movements.saveMovement(StockMovementModel(
      id: consumedMovementId,
      timestamp: DateTime.now(),
      itemId: kitProduct.productId,
      variantId: kitVariantId,
      itemName: kitProduct.productName,
      type: 'out',
      quantity: batchQty.toDouble(),
      balanceAfter: newKitStock.toDouble(),
      reason: 'Disassembly batch',
      unit: _unit,
      staffName: staffName,
      sessionId: sessionId,
    ));
    movementIds.add(consumedMovementId);

    for (final component in bundle.components) {
      final variant = await productStore.getVariantById(component.componentVariantId);
      if (variant == null) continue;

      final restoreQty = component.quantity * batchQty;
      final newStock = variant.stockQty + restoreQty;
      await productStore.updateVariantStock(component.componentVariantId, newStock);

      String label = variant.sku ?? component.componentVariantId;
      try {
        final componentProduct = productStore.products.firstWhere(
          (p) => p.productId == variant.productId,
        );
        label = variant.hasAttributes
            ? '${componentProduct.productName} (${variant.variantDescription})'
            : componentProduct.productName;
      } catch (_) {}

      final movementId = const Uuid().v4();
      await _movements.saveMovement(StockMovementModel(
        id: movementId,
        timestamp: DateTime.now(),
        itemId: variant.productId,
        variantId: variant.varianteId,
        itemName: label,
        type: 'in',
        quantity: restoreQty.toDouble(),
        balanceAfter: newStock.toDouble(),
        reason: 'Disassembly (${kitProduct.productName})',
        unit: _unit,
        staffName: staffName,
        sessionId: sessionId,
      ));
      movementIds.add(movementId);
    }

    final disassembly = RetailKitAssemblyModel(
      id: const Uuid().v4(),
      bundleId: bundle.id,
      variantId: kitVariantId,
      productName: kitProduct.productName,
      batchQty: batchQty,
      assembledTime: DateTime.now(),
      assembledBy: staffName,
      movementIds: movementIds,
      isReversal: true,
    );
    await kitAssemblyRepository.saveAssembly(disassembly);

    return disassembly;
  }
}
