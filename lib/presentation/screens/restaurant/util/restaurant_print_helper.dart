import 'package:flutter/material.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/ordermodel_309.dart';
import 'package:unipos/data/models/retail/hive_model/customer_model_208.dart';
import 'package:unipos/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';
import 'package:unipos/domain/services/retail/print_service.dart';
import 'package:unipos/domain/services/retail/receipt_pdf_service.dart';
import 'package:unipos/domain/services/retail/store_settings_service.dart';
import 'package:unipos/domain/services/restaurant/cart_calculation_service.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/customerdetails.dart'; // Import for DiscountType

class RestaurantPrintHelper {
  
  static Future<void> printOrderReceipt({
    required BuildContext context,
    required OrderModel order,
    required CartCalculationService calculations,
  }) async {
    try {
      final storeSettings = StoreSettingsService();
      
      // 1. Fetch Store Details
      final storeName = await storeSettings.getStoreName() ?? 'Restaurant';
      final storeAddress = await storeSettings.getFormattedAddress();
      final storePhone = await storeSettings.getStorePhone();
      final storeEmail = await storeSettings.getStoreEmail();
      final storeGst = await storeSettings.getGSTNumber();

      // 2. Map Items (Adapter: CartItem -> SaleItemModel)
      final saleItems = order.items.map((item) {
        // Calculate tax for this item if possible, otherwise distribute total tax
        final itemTaxRate = (item.taxRate ?? 0) * 100;

        // Format extras with quantities for display
        String? extrasInfo;
        if (item.extras != null && item.extras!.isNotEmpty) {
          // Group extras by name and count them
          Map<String, Map<String, dynamic>> groupedExtras = {};

          for (var extra in item.extras!) {
            final displayName = extra['displayName'] ?? extra['name'] ?? 'Unknown';
            final price = extra['price']?.toDouble() ?? 0.0;
            final quantity = extra['quantity']?.toInt() ?? 1;

            String key = '$displayName-${price.toStringAsFixed(2)}';

            if (groupedExtras.containsKey(key)) {
              groupedExtras[key]!['quantity'] = (groupedExtras[key]!['quantity'] as int) + quantity;
            } else {
              groupedExtras[key] = {
                'displayName': displayName,
                'price': price,
                'quantity': quantity,
              };
            }
          }

          // Build display string
          extrasInfo = groupedExtras.entries.map((entry) {
            final data = entry.value;
            final int qty = data['quantity'] as int;
            final String name = data['displayName'] as String;
            final double price = data['price'] as double;

            if (qty > 1) {
              return '${qty}x $name(₹${price.toStringAsFixed(2)})';
            } else {
              return '$name(₹${price.toStringAsFixed(2)})';
            }
          }).join(', ');

          if (extrasInfo!.isNotEmpty) {
            extrasInfo = 'Extras: $extrasInfo';
          }
        }

        // Format choices for display
        String? choicesInfo;
        if (item.choiceNames != null && item.choiceNames!.isNotEmpty) {
          choicesInfo = 'Add-ons: ${item.choiceNames!.join(', ')}';
        }

        // Combine extras and choices into weight field for display
        String? additionalInfo;
        if (extrasInfo != null && choicesInfo != null) {
          additionalInfo = '$choicesInfo | $extrasInfo';
        } else if (extrasInfo != null) {
          additionalInfo = extrasInfo;
        } else if (choicesInfo != null) {
          additionalInfo = choicesInfo;
        }

        return SaleItemModel.create(
          saleId: order.id,
          varianteId: item.id, // Use item.id as variant ID since CartItem doesn't have explicit variantId field
          productId: item.productId,
          productName: item.title,
          size: item.variantName, // Use size field for variant name
          weight: additionalInfo, // Use weight field to store extras and choices info
          price: item.price,
          qty: item.quantity,
          discountAmount: 0, // Item level discount not typically stored in restaurant cart
          gstRate: itemTaxRate,
          // Note: total field in create() is calculated
        );
      }).toList();

      // 3. Create Sale Model (Adapter: OrderModel -> SaleModel)
      // Use KOT number for invoice ID if available
      final invoiceId = order.kotNumbers.isNotEmpty 
          ? 'KOT-${order.kotNumbers.first}' 
          : order.id.substring(0, 8).toUpperCase();

      final saleModel = SaleModel.createWithGst(
        saleId: invoiceId,
        customerId: order.customerName.isNotEmpty ? 'GUEST' : null, 
        totalItems: order.items.length,
        subtotal: calculations.subtotal,
        discountAmount: calculations.discountAmount,
        totalTaxableAmount: calculations.subtotal, // Approximation for now
        totalGstAmount: calculations.totalGST,
        grandTotal: calculations.grandTotal,
        paymentType: order.paymentMethod ?? 'Cash',
        isReturn: false,
      );

      // 4. Create Customer Model (Adapter)
      CustomerModel? customerModel;
      if (order.customerName.isNotEmpty) {
        customerModel = CustomerModel(
          customerId: 'GUEST',
          name: order.customerName,
          phone: order.customerNumber,
          email: order.customerEmail,
          address: '', 
          totalPurchaseAmount: 0, // Fixed: totalSales -> totalPurchaseAmount
          pointsBalance: 0,
          // creditBalance: 0, // Removed: Not in constructor or named parameter default is 0.0
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
      }

      // 5. Create ReceiptData (Internal use for validation/debugging if needed,
      // but primarily we pass fields to showPrintOptionsDialog)
      final receiptData = ReceiptData(
        sale: saleModel,
        items: saleItems,
        customer: customerModel,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeEmail: storeEmail,
        gstNumber: storeGst,
        // Restaurant-specific fields
        orderType: order.orderType,
        tableNo: order.tableNo,
      );

      // 6. Show Print Options
      final printService = locator<PrintService>();
      
      // Fixed: Pass individual parameters instead of ReceiptData object
      await printService.showPrintOptionsDialog(
        context: context,
        sale: receiptData.sale,
        items: receiptData.items,
        customer: receiptData.customer,
        storeName: receiptData.storeName,
        storeAddress: receiptData.storeAddress,
        storePhone: receiptData.storePhone,
        storeEmail: receiptData.storeEmail,
        gstNumber: receiptData.gstNumber,
      );
      
    } catch (e) {
      debugPrint('Error preparing receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preparing receipt: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Helper to print from Takeaway screen (Partial/Active Order)
  static Future<void> printBillForActiveOrder({
    required BuildContext context,
    required OrderModel order,
    required List<CartItem> currentItems, // Items might be modified in cart
  }) async {
     // ✅ FIX: Use saved values from order to ensure correct totals
     final bool isDelivery = order.orderType.toLowerCase().contains('delivery');

     // Recalculate based on current items with saved discount and charges
     final calculations = CartCalculationService(
      items: currentItems,
      discountType: DiscountType.amount,
      discountValue: order.discount ?? 0,
      serviceChargePercentage: isDelivery ? 0 : (order.serviceCharge ?? 0),
      deliveryCharge: isDelivery ? (order.serviceCharge ?? 0) : 0,
      isDeliveryOrder: isDelivery,
    );

    await printOrderReceipt(
      context: context,
      order: order, // Uses ID and customer details from order
      calculations: calculations,
    );
  }
}
