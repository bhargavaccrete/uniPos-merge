import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';
import 'package:uuid/uuid.dart';


/// Service for handling sale returns and refunds
/// Manages stock adjustments, negative sales entries, and customer updates
class ReturnService {
  static const _uuid = Uuid();

  /// Process a full sale return (all items)
  /// Returns the created return transaction ID
  Future<String> processFullReturn({
    required String originalSaleId,
    required String refundMethod, // cash, card, upi
    String? returnReason,
  }) async {
    // 1. Get original sale
    final originalSale = await saleStore.getSaleById(originalSaleId);
    if (originalSale == null) {
      throw Exception('Original sale not found');
    }

    if (originalSale.isReturn ?? false) {
      throw Exception('Cannot return a return transaction');
    }

    // 2. Get all items from original sale
    final originalItems = await saleItemRepository.getItemsBySaleId(originalSaleId);
    if (originalItems.isEmpty) {
      throw Exception('No items found in original sale');
    }

    // 3. Create return sale (negative amounts)
    final returnSaleId = 'RTN_${_uuid.v4()}';
    final returnSale = SaleModel.create(
      saleId: returnSaleId,
      customerId: originalSale.customerId,
      totalItems: originalSale.totalItems,
      subtotal: -originalSale.subtotal, // Negative
      discountAmount: -originalSale.discountAmount, // Negative
      taxAmount: -originalSale.taxAmount, // Negative
      totalAmount: -originalSale.totalAmount, // Negative
      paymentType: refundMethod,
      isReturn: true,
      originalSaleId: originalSaleId,
    );

    await saleStore.addSale(returnSale);

    // 4. Create return sale items (negative quantities for accounting, positive for stock)
    final returnItems = <SaleItemModel>[];
    for (var item in originalItems) {
      final returnItem = SaleItemModel.create(
        saleId: returnSaleId,
        varianteId: item.varianteId,
        productId: item.productId,
        productName: item.productName ?? '',
        size: item.size,
        color: item.color,
        weight: item.weight,
        price: item.price,
        qty: item.qty, // Keep positive for stock restoration
        discountAmount: item.discountAmount,
        gstRate: item.gstRate,
        barcode: item.barcode,
        hsnCode: item.hsnCode,
      );
      returnItems.add(returnItem);
    }

    await saleItemRepository.addSaleItems(returnItems);

    // 5. Restore stock for all items
    for (var item in originalItems) {
      final variant = await productStore.getVariantById(item.varianteId);
      if (variant != null) {
        final newStock = variant.stockQty + item.qty; // Add back to stock
        await productStore.updateVariantStock(item.varianteId, newStock);
      }
    }

    // 6. Update customer points (deduct points if customer exists)
    if (originalSale.customerId != null) {
      final pointsToDeduct = (originalSale.totalAmount / 10).floor();
      await customerStoreRestail.updateAfterPurchase(
        originalSale.customerId!,
        -originalSale.totalAmount, // Negative amount
        -pointsToDeduct, // Negative points
      );
    }

    return returnSaleId;
  }

  /// Process partial return (selected items only)
  /// Returns the created return transaction ID
  Future<String> processPartialReturn({
    required String originalSaleId,
    required Map<String, int> itemsToReturn, // variantId -> quantity
    required String refundMethod,
    String? returnReason,
  }) async {
    // 1. Get original sale
    final originalSale = await saleStore.getSaleById(originalSaleId);
    if (originalSale == null) {
      throw Exception('Original sale not found');
    }

    if (originalSale.isReturn ?? false) {
      throw Exception('Cannot return a return transaction');
    }

    // 2. Get original items
    final originalItems = await saleItemRepository.getItemsBySaleId(originalSaleId);
    if (originalItems.isEmpty) {
      throw Exception('No items found in original sale');
    }

    // 3. Validate return quantities
    for (var entry in itemsToReturn.entries) {
      final variantId = entry.key;
      final returnQty = entry.value;

      final originalItem = originalItems.firstWhere(
        (item) => item.varianteId == variantId,
        orElse: () => throw Exception('Item $variantId not found in original sale'),
      );

      if (returnQty > originalItem.qty) {
        throw Exception('Cannot return more than purchased quantity');
      }

      if (returnQty <= 0) {
        throw Exception('Return quantity must be positive');
      }
    }

    // 4. Calculate return totals
    double returnSubtotal = 0;
    double returnDiscountAmount = 0;
    double returnTaxAmount = 0;
    int totalReturnItems = 0;

    final returnItems = <SaleItemModel>[];

    for (var entry in itemsToReturn.entries) {
      final variantId = entry.key;
      final returnQty = entry.value;

      final originalItem = originalItems.firstWhere(
        (item) => item.varianteId == variantId,
      );

      // Calculate proportional amounts
      final itemSubtotal = originalItem.price * returnQty;
      final itemDiscount = (originalItem.discountAmount ?? 0) * (returnQty / originalItem.qty);
      final itemTax = (originalItem.taxAmount ?? 0) * (returnQty / originalItem.qty);

      returnSubtotal += itemSubtotal;
      returnDiscountAmount += itemDiscount;
      returnTaxAmount += itemTax;
      totalReturnItems += returnQty;

      // Create return item
      final returnItem = SaleItemModel.create(
        saleId: '', // Will be set after creating return sale
        varianteId: variantId,
        productId: originalItem.productId,
        productName: originalItem.productName ?? '',
        size: originalItem.size,
        color: originalItem.color,
        weight: originalItem.weight,
        price: originalItem.price,
        qty: returnQty,
        discountAmount: itemDiscount,
        gstRate: originalItem.gstRate,
        barcode: originalItem.barcode,
        hsnCode: originalItem.hsnCode,
      );

      returnItems.add(returnItem);
    }

    // 5. Create return sale
    final returnSaleId = 'RTN_${_uuid.v4()}';
    final returnTotal = returnSubtotal - returnDiscountAmount + returnTaxAmount;

    final returnSale = SaleModel.create(
      saleId: returnSaleId,
      customerId: originalSale.customerId,
      totalItems: totalReturnItems,
      subtotal: -returnSubtotal, // Negative
      discountAmount: -returnDiscountAmount, // Negative
      taxAmount: -returnTaxAmount, // Negative
      totalAmount: -returnTotal, // Negative
      paymentType: refundMethod,
      isReturn: true,
      originalSaleId: originalSaleId,
    );

    await saleStore.addSale(returnSale);

    // 6. Update return items with correct saleId and save
    final updatedReturnItems = returnItems.map((item) {
      return SaleItemModel.create(
        saleId: returnSaleId,
        varianteId: item.varianteId,
        productId: item.productId,
        productName: item.productName ?? '',
        size: item.size,
        color: item.color,
        weight: item.weight,
        price: item.price,
        qty: item.qty,
        discountAmount: item.discountAmount,
        gstRate: item.gstRate,
        barcode: item.barcode,
        hsnCode: item.hsnCode,
      );
    }).toList();

    await saleItemRepository.addSaleItems(updatedReturnItems);

    // 7. Restore stock for returned items
    for (var returnItem in updatedReturnItems) {
      final variant = await productStore.getVariantById(returnItem.varianteId);
      if (variant != null) {
        final newStock = variant.stockQty + returnItem.qty;
        await productStore.updateVariantStock(returnItem.varianteId, newStock);
      }
    }

    // 8. Update customer points (deduct proportional points)
    if (originalSale.customerId != null) {
      final pointsToDeduct = (returnTotal / 10).floor();
      await customerStoreRestail.updateAfterPurchase(
        originalSale.customerId!,
        -returnTotal, // Negative amount
        -pointsToDeduct, // Negative points
      );
    }

    return returnSaleId;
  }

  /// Check if a sale can be returned
  Future<bool> canReturnSale(String saleId) async {
    final sale = await saleStore.getSaleById(saleId);
    if (sale == null) return false;

    // Cannot return a return transaction
    if (sale.isReturn ?? false) return false;

    // Can add more business rules here:
    // - Time limit (e.g., within 30 days)
    // - Already returned check
    // etc.

    return true;
  }

  /// Get all returns for a specific original sale
  Future<List<SaleModel>> getReturnsForSale(String originalSaleId) async {
    final allSales = await saleStore.getAllSales();
    return allSales
        .where((sale) => (sale.isReturn ?? false) && sale.originalSaleId == originalSaleId)
        .toList();
  }

  /// Get total returned amount for a sale
  Future<double> getTotalReturnedAmount(String originalSaleId) async {
    final returns = await getReturnsForSale(originalSaleId);
    return returns.fold<double>(0.0, (sum, returnSale) => sum + returnSale.totalAmount.abs());
  }

  /// Check if all items have been returned
  Future<bool> isFullyReturned(String originalSaleId) async {
    final originalSale = await saleStore.getSaleById(originalSaleId);
    if (originalSale == null) return false;

    final totalReturned = await getTotalReturnedAmount(originalSaleId);
    return totalReturned >= originalSale.totalAmount;
  }
}