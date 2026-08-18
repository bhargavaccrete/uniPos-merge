import 'package:flutter/foundation.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/util/common/loyalty_points.dart';
import 'package:uuid/uuid.dart';


/// Service for handling sale returns and refunds
/// Manages stock adjustments, negative sales entries, and customer updates
///
/// NOTE ON MONEY: a return deliberately does NOT go through
/// `RetailBillingService`. It refunds what was actually charged, so every figure
/// is derived from the original sale's STORED values (pro-rated by the returned
/// quantity). Recomputing would refund a different amount than was taken if a
/// tax rate or the tax mode changed since the sale.
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
        attributes: item.attributes,
        price: item.price,
        qty: item.qty, // Keep positive for stock restoration
        discountAmount: item.discountAmount,
        gstRate: item.gstRate,
        barcode: item.barcode,
        hsnCode: item.hsnCode,
        // Carry the ORIGINAL line's cost, never today's. A return has to cancel
        // out against the sale it reverses, and it can only do that if both
        // sides are costed identically.
        costPrice: item.costPrice,
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
      // Deduct exactly what this amount granted, using the shared earn rule —
      // a local `/10` here silently drifts if the rate ever changes.
      final pointsToDeduct = LoyaltyPoints.earnedFor(originalSale.totalAmount);
      await customerStore.updateAfterPurchase(
        originalSale.customerId!,
        -originalSale.totalAmount, // Negative amount
        -pointsToDeduct, // Negative points
      );
    }

    await _recordCashRefundMovement(
      refundMethod: refundMethod,
      amount: originalSale.totalAmount,
      returnSaleId: returnSaleId,
    );

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
        attributes: originalItem.attributes,
        price: originalItem.price,
        qty: returnQty,
        discountAmount: itemDiscount,
        gstRate: originalItem.gstRate,
        barcode: originalItem.barcode,
        hsnCode: originalItem.hsnCode,
        // See the full-return path: a partial return must be costed exactly as
        // the line it reverses.
        costPrice: originalItem.costPrice,
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
        attributes: item.attributes,
        price: item.price,
        qty: item.qty,
        discountAmount: item.discountAmount,
        gstRate: item.gstRate,
        barcode: item.barcode,
        hsnCode: item.hsnCode,
        costPrice: item.costPrice,
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
      final pointsToDeduct = LoyaltyPoints.earnedFor(returnTotal);
      await customerStore.updateAfterPurchase(
        originalSale.customerId!,
        -returnTotal, // Negative amount
        -pointsToDeduct, // Negative points
      );
    }

    await _recordCashRefundMovement(
      refundMethod: refundMethod,
      amount: returnTotal,
      returnSaleId: returnSaleId,
    );

    return returnSaleId;
  }


  /// Cash refund method that physically empties the drawer. Everything else
  /// (card, UPI, and any method added later) settles outside the till.
  static const String cashRefundMethod = 'cash';

  /// Movement type used ONLY for refund audit rows.
  ///
  /// Deliberately not 'out': every existing consumer filters movements by
  /// exact type equality (`m.type == 'in' / 'out' / 'opening' / 'adjustment'`),
  /// so a distinct type is invisible to all of them. The drawer and EOD derive
  /// their refund figure from the return SALES instead, and skip these rows —
  /// that is what stops a refund being counted twice.
  static const String refundMovementType = 'refund';

  /// Audit-only trail for a cash refund. Never blocks the return: the money has
  /// already been handed back and the totals are derived from the return sale,
  /// so a failure here loses the audit row, not the figure.
  Future<void> _recordCashRefundMovement({
    required String refundMethod,
    required double amount,
    required String returnSaleId,
  }) async {
    if (refundMethod.toLowerCase().trim() != cashRefundMethod) return;
    if (amount <= 0) return;

    try {
      await cashMovementStore.addMovement(
        type: refundMovementType,
        amount: amount,
        reason: 'Sale Refund',
        note: 'Return $returnSaleId',
      );
    } catch (e) {
      debugPrint('Cash refund movement not recorded: $e');
    }
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