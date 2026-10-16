import 'package:flutter/foundation.dart';
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
import 'grn_receiving_service.dart';

/// Deducts stock for a completed retail sale.
///
/// Every retail stock change writes a [StockMovementModel]: sales (here),
/// returns ([restockForReturn]), opening stock and edits
/// (`ProductStore.addVariant/updateVariant` via [recordMovement]), receipts
/// (`GrnReceivingService`), adjustments and stock takes
/// ([StockAdjustmentService]), kit assembly and exchanges. This centralizes
/// sale-time deduction so it logs the same way, and gives bundle/kit cascade logic (see
/// docs/retail_inventory_system_plan.md) a service layer to hang off instead
/// of growing inside the checkout screen. Mirrors restaurant's
/// `InventoryService.deductStockForOrder`.
class RetailInventoryService {
  RetailInventoryService._();

  static final StockMovementRepository _movements = StockMovementRepository();

  /// Retail sells in whole units — same convention as [StockAdjustmentService].
  static const String _unit = 'pcs';

  /// With [saleId], every row gets a deterministic id
  /// (`sale_<saleId>_<cartItemId>`, plus the component for a bundle) and a
  /// line whose row already exists is skipped — so re-running the deduction
  /// for the same sale after a mid-way failure applies only what is missing.
  static Future<void> deductStockForSale(
    List<CartItemModel> cartItems, {
    String? saleId,
  }) async {
    final staffName = authService.currentUsername ?? 'Staff';
    final sessionId = await DayManagementService.getCurrentSessionId();

    for (final item in cartItems) {
      final lineKey = saleId == null ? null : 'sale_${saleId}_${item.cartItemId}';
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
          lineKey: lineKey,
        );
        continue;
      }

      if (lineKey != null && _movements.contains(lineKey)) continue;
      final variant = await productStore.getVariantById(item.variantId);
      if (variant == null) continue;

      // Never clamped: selling past zero (allow-when-out, or a race) leaves a
      // negative count, so the row reconciles and the shortfall stays visible
      // for the next stock take. Same as restaurant's applyStockDelta.
      final finalStock = variant.stockQty - item.qty;
      await productStore.updateVariantStock(item.variantId, finalStock);

      final label = product != null && variant.hasAttributes
          ? '${product.productName} (${variant.variantDescription})'
          : (product?.productName ?? item.productName);

      await _movements.saveMovement(StockMovementModel(
        id: lineKey ?? const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: item.productId,
        variantId: item.variantId,
        itemName: label,
        type: 'out',
        quantity: item.qty.toDouble(),
        balanceAfter: finalStock.toDouble(),
        reason: 'Sale',
        unit: variant.isDecimalQuantity ? variant.effectiveUnit : _unit,
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
    String? lineKey,
  }) async {
    final RetailBundleModel? bundle = bundleRepository.getBundleForVariant(bundleVariantId);
    if (bundle == null || !bundle.hasComponents) return; // unconfigured bundle — nothing to deduct

    for (final component in bundle.components) {
      final rowId =
          lineKey == null ? null : '${lineKey}_${component.componentVariantId}';
      if (rowId != null && _movements.contains(rowId)) continue;
      final variant = await productStore.getVariantById(component.componentVariantId);
      if (variant == null) continue;

      final deductQty = saleQty * component.quantity;
      final finalStock = variant.stockQty - deductQty; // not clamped — see above
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
        id: rowId ?? const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: variant.productId,
        variantId: variant.varianteId,
        itemName: label,
        type: 'out',
        quantity: deductQty.toDouble(),
        balanceAfter: finalStock.toDouble(),
        reason: 'Sale (bundle: ${bundleProduct.productName})',
        unit: variant.isDecimalQuantity ? variant.effectiveUnit : _unit,
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

  /// A bundle variant with no bundle row, or an empty one. Selling it would
  /// deduct nothing (see [_deductBundleComponents]), so the cart refuses it
  /// outright — even when the product allows selling out of stock.
  static bool isUnconfiguredBundle(ProductModel product, VarianteModel variant) {
    if (!product.isBundle) return false;
    final bundle = bundleRepository.getBundleForVariant(variant.varianteId);
    return bundle == null || !bundle.hasComponents;
  }

  /// Product-level sellable total for list/tile display: bundles count what
  /// their components support, everything else its own stock.
  static double totalAvailableToSell(
    ProductModel product,
    List<VarianteModel> variants,
  ) =>
      variants.fold(0.0, (sum, v) => sum + calculateAvailableToSell(product, v));

  /// Puts returned goods back on the shelf and logs each restock. A bundle
  /// holds no stock of its own, so its return restores the components the
  /// sale deducted (current recipe, `qty × component.quantity` each); anything
  /// else is credited to its own variant. A bundle with no configured
  /// components deducted nothing at sale time, so nothing is restored.
  static Future<void> restockForReturn({
    required String productId,
    required String variantId,
    required double qty,
    String reason = 'Return',
    String? note,
  }) async {
    Future<void> credit(String id, double add) async {
      final variant = await productStore.getVariantById(id);
      if (variant == null) return;
      final newStock = variant.stockQty + add;
      await productStore.updateVariantStock(id, newStock);
      await recordMovement(
        variant: variant,
        type: 'in',
        quantity: add,
        balanceAfter: newStock,
        reason: reason,
        note: note,
      );
    }

    final product = productStore.getProductById(productId);
    if (product != null && product.isBundle) {
      final bundle = bundleRepository.getBundleForVariant(variantId);
      if (bundle == null || !bundle.hasComponents) return;
      for (final component in bundle.components) {
        await credit(component.componentVariantId, qty * component.quantity);
      }
      return;
    }
    await credit(variantId, qty);
  }

  /// Takes goods off the shelf outside checkout (an exchange's replacement)
  /// and logs each deduction — the counterpart of [restockForReturn]. A
  /// bundle holds no stock of its own, so it deducts its components
  /// (`qty × component.quantity`); anything else its own variant. Not
  /// clamped, same as a sale.
  static Future<void> deductStock({
    required String productId,
    required String variantId,
    required double qty,
    required String reason,
    String? note,
  }) async {
    Future<void> take(String id, double amount) async {
      final variant = await productStore.getVariantById(id);
      if (variant == null) return;
      final newStock = variant.stockQty - amount;
      await productStore.updateVariantStock(id, newStock);
      await recordMovement(
        variant: variant,
        type: 'out',
        quantity: amount,
        balanceAfter: newStock,
        reason: reason,
        note: note,
      );
    }

    final product = productStore.getProductById(productId);
    if (product != null && product.isBundle) {
      final bundle = bundleRepository.getBundleForVariant(variantId);
      if (bundle == null || !bundle.hasComponents) return;
      for (final component in bundle.components) {
        await take(component.componentVariantId, qty * component.quantity);
      }
      return;
    }
    await take(variantId, qty);
  }

  /// Writes one stock-history row for a change that has ALREADY been applied.
  ///
  /// The shared shape for writers that have no document of their own to hang
  /// the row off (opening stock, edits, returns). Never throws: the stock has
  /// moved either way, and failing the caller over its audit row would be
  /// worse than a missing row, which the debug log still reports.
  static Future<void> recordMovement({
    required VarianteModel variant,
    required String type,
    required double quantity,
    required double balanceAfter,
    required String reason,
    String? note,
  }) async {
    try {
      final product = productStore.getProductById(variant.productId);
      final name = product?.productName ?? 'Item';
      await _movements.saveMovement(StockMovementModel(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: variant.productId,
        variantId: variant.varianteId,
        itemName: variant.hasAttributes
            ? '$name (${variant.variantDescription})'
            : name,
        type: type,
        quantity: quantity,
        balanceAfter: balanceAfter,
        reason: reason,
        note: note,
        unit: variant.isDecimalQuantity ? variant.effectiveUnit : _unit,
        staffName: authService.currentUsername ?? 'Staff',
        sessionId: await DayManagementService.getCurrentSessionId(),
      ));
    } catch (e) {
      debugPrint('Stock movement not recorded ($reason): $e');
    }
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

    // What one kit costs to build — the components it consumes, at their
    // cost. Null when any component has no cost: an unknown is not ₹0.
    double? unitCost = 0;

    for (final component in bundle.components) {
      final variant = await productStore.getVariantById(component.componentVariantId);
      if (variant == null) continue;

      final componentCost = variant.costPrice;
      if (componentCost == null || componentCost <= 0) {
        unitCost = null;
      } else if (unitCost != null) {
        unitCost += componentCost * component.quantity;
      }

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

    // Roll the batch's component cost into the kit's cost, averaged with the
    // kits already on hand — the same rule a goods receipt uses. The kit's
    // cost used to stay whatever was typed, so kit sales froze a made-up cost
    // into profit.
    final newKitCost = GrnReceivingService.weightedAverageCost(
      onHand: kitVariant?.stockQty ?? 0,
      currentCost: kitVariant?.costPrice,
      receivedQty: batchQty.toDouble(),
      receiptCost: unitCost,
    );
    await productStore.updateVariantStock(kitVariantId, newKitStock);
    if (newKitCost != null && newKitCost != kitVariant?.costPrice) {
      await productStore.updateVariantCostPrice(kitVariantId, newKitCost);
    }

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
