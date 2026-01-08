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
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/customerdetails.dart'; // Import for DiscountType
import 'package:unipos/util/restaurant/staticswitch.dart'; // Import for AppSettings
import 'package:unipos/util/common/currency_helper.dart';

class RestaurantPrintHelper {

  /// Print KOT (Kitchen Order Ticket) for a specific KOT number
  /// This prints only the items for the specified KOT in thermal receipt format
  static Future<void> printKOT({
    required BuildContext context,
    required OrderModel order,
    required int kotNumber,
    bool autoPrint = false,
  }) async {
    try {
      final storeSettings = StoreSettingsService();

      // 1. Fetch Store Details
      final storeName = await storeSettings.getStoreName() ?? 'Restaurant';
      final storeAddress = await storeSettings.getFormattedAddress();
      final storePhone = await storeSettings.getStorePhone();

      // 2. Get items for this specific KOT
      final Map<int, List<CartItem>> itemsByKot = order.getItemsByKot();
      final List<CartItem>? kotItems = itemsByKot[kotNumber];

      if (kotItems == null || kotItems.isEmpty) {
        if (context.mounted && !autoPrint) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No items found for this KOT'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 3. Map Items to SaleItemModel format (for KOT display - NO PRICES)
      final saleItems = kotItems.map((item) {
        // Format extras WITHOUT prices for KOT
        String? extrasInfo;
        if (item.extras != null && item.extras!.isNotEmpty) {
          Map<String, int> groupedExtras = {};

          for (var extra in item.extras!) {
            final displayName = extra['displayName'] ?? extra['name'] ?? 'Unknown';
            final int quantity = (extra['quantity'] ?? 1) is int
                ? (extra['quantity'] ?? 1) as int
                : ((extra['quantity'] ?? 1) as num).toInt();

            if (groupedExtras.containsKey(displayName)) {
              final int currentQty = groupedExtras[displayName]!;
              groupedExtras[displayName] = currentQty + quantity;
            } else {
              groupedExtras[displayName] = quantity;
            }
          }

          extrasInfo = groupedExtras.entries.map((entry) {
            final String name = entry.key;
            final int qty = entry.value;

            if (qty > 1) {
              return '${qty}x $name';
            } else {
              return name;
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

        // Combine extras and choices with instruction
        String? additionalInfo;
        List<String> infoParts = [];
        if (choicesInfo != null) infoParts.add(choicesInfo);
        if (extrasInfo != null) infoParts.add(extrasInfo);
        if (item.instruction != null && item.instruction!.isNotEmpty) {
          infoParts.add('NOTE: ${item.instruction}');
        }

        if (infoParts.isNotEmpty) {
          additionalInfo = infoParts.join(' | ');
        }

        return SaleItemModel.create(
          saleId: order.id,
          varianteId: item.id,
          productId: item.productId,
          productName: item.title,
          size: item.variantName,
          weight: additionalInfo,
          price: 0, // Price set to 0 for KOT - kitchen doesn't need pricing
          qty: item.quantity,
          discountAmount: 0,
          gstRate: 0, // No tax info needed for KOT
        );
      }).toList();

      // 4. Create a minimal SaleModel for KOT (no payment info needed)
      final kotId = 'KOT-$kotNumber';
      final saleModel = SaleModel.createWithGst(
        saleId: kotId,
        customerId: null,
        totalItems: kotItems.length,
        subtotal: 0, // Not needed for KOT
        discountAmount: 0,
        totalTaxableAmount: 0,
        totalGstAmount: 0,
        grandTotal: 0, // Not needed for KOT
        paymentType: 'Pending',
        isReturn: false,
      );

      // 5. Determine order number and if this is an add-on KOT
      final orderNo = order.id.substring(0, 8).toUpperCase(); // Use first 8 chars of order ID
      final isAddonKot = order.kotNumbers.length > 1 && order.kotNumbers.first != kotNumber;

      // 6. Create ReceiptData for KOT
      final receiptData = ReceiptData(
        sale: saleModel,
        items: saleItems,
        customer: null,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeEmail: null,
        gstNumber: null,
        orderType: order.orderType,
        tableNo: order.tableNo,
        // Add KOT-specific info
        kotNumber: kotNumber,
        orderTimestamp: order.timeStamp,
        orderNo: orderNo,
        isAddonKot: isAddonKot,
      );

      // 7. Print or show preview based on autoPrint flag
      final printService = locator<PrintService>();

      if (autoPrint) {
        // Auto-print directly to thermal printer
        await printService.printReceipt(
          context: context,
          sale: receiptData.sale,
          items: receiptData.items,
          format: ReceiptFormat.thermal,
          storeName: receiptData.storeName,
          storeAddress: receiptData.storeAddress,
          storePhone: receiptData.storePhone,
          orderType: receiptData.orderType,
          tableNo: receiptData.tableNo,
          kotNumber: kotNumber,
          orderTimestamp: order.timeStamp,
          orderNo: orderNo,
          isAddonKot: isAddonKot,
        );

        if (context.mounted) {
          NotificationService.instance.showSuccess(
            'KOT #$kotNumber sent to printer',
          );
        }
      } else {
        // Show preview for manual print
        await printService.showPrintPreview(
          context: context,
          sale: receiptData.sale,
          items: receiptData.items,
          format: ReceiptFormat.thermal,
          storeName: receiptData.storeName,
          storeAddress: receiptData.storeAddress,
          storePhone: receiptData.storePhone,
          orderType: receiptData.orderType,
          tableNo: receiptData.tableNo,
          kotNumber: kotNumber,
          orderTimestamp: order.timeStamp,
          orderNo: orderNo,
          isAddonKot: isAddonKot,
        );
      }

    } catch (e) {
      debugPrint('Error printing KOT: $e');
      if (context.mounted && !autoPrint) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing KOT: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> printOrderReceipt({
    required BuildContext context,
    required OrderModel order,
    required CartCalculationService calculations,
    int? billNumber, // Bill number for completed orders (from pastOrderModel)
  }) async {
    try {
      final storeSettings = StoreSettingsService();
      
      // 1. Fetch Store Details
      final storeName = await storeSettings.getStoreName() ?? 'Restaurant';
      final storeAddress = await storeSettings.getFormattedAddress();
      final storePhone = await storeSettings.getStorePhone();
      final storeEmail = await storeSettings.getStoreEmail();
      final storeGst = await storeSettings.getGSTNumber();

      // 2. Group identical items together (same product, variant, extras, choices)
      Map<String, CartItem> groupedItems = {};

      for (var item in order.items) {
        // Create a unique key based on product, variant, extras, and choices
        final extrasKey = item.extras?.map((e) => '${e['name']}_${e['price']}_${e['quantity']}').join('|') ?? '';
        final choicesKey = item.choiceNames?.join('|') ?? '';
        final uniqueKey = '${item.productId}_${item.variantName ?? ''}_${extrasKey}_${choicesKey}';

        if (groupedItems.containsKey(uniqueKey)) {
          // Item already exists, combine quantities and prices
          final existing = groupedItems[uniqueKey]!;
          groupedItems[uniqueKey] = CartItem(
            id: existing.id,
            productId: existing.productId,
            title: existing.title,
            imagePath: existing.imagePath,
            price: existing.price, // Keep unit price same
            quantity: existing.quantity + item.quantity, // Add quantities
            variantName: existing.variantName,
            extras: existing.extras,
            choiceNames: existing.choiceNames,
            taxRate: existing.taxRate,
            instruction: existing.instruction,
          );
        } else {
          // New unique item
          groupedItems[uniqueKey] = item;
        }
      }

      // 3. Map Items (Adapter: CartItem -> SaleItemModel)
      final saleItems = groupedItems.values.map((item) {
        // Calculate tax for this item if possible, otherwise distribute total tax
        final itemTaxRate = (item.taxRate ?? 0) * 100;

        // ✅ FIX: Adjust displayed price based on tax mode
        // In tax-inclusive mode: item.price already includes tax (show as-is)
        // In tax-exclusive mode: item.price includes tax, extract base for display
        double displayPrice = item.price;
        if (!AppSettings.isTaxInclusive && item.taxRate != null && item.taxRate! > 0) {
          // Tax Exclusive: Extract base price from gross price for display
          displayPrice = item.price / (1 + item.taxRate!);
        }

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
              return '${qty}x $name(${CurrencyHelper.currentSymbol}${price.toStringAsFixed(2)})';
            } else {
              return '$name(${CurrencyHelper.currentSymbol}${price.toStringAsFixed(2)})';
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

        // Format variant name with price if variant exists
        String? variantDisplayName;
        if (item.variantName != null && item.variantName!.isNotEmpty) {
          final double vPrice = item.variantPrice ?? 0.0;
          variantDisplayName = '${item.variantName}-${vPrice.toStringAsFixed(0)}rs';
        }

        return SaleItemModel.create(
          saleId: order.id,
          varianteId: item.id, // Use item.id as variant ID since CartItem doesn't have explicit variantId field
          productId: item.productId,
          productName: item.title,
          size: variantDisplayName, // Use formatted variant name with price
          weight: additionalInfo, // Use weight field to store extras and choices info
          price: displayPrice, // ✅ Use adjusted price based on tax mode
          qty: item.quantity,
          discountAmount: 0, // Item level discount not typically stored in restaurant cart
          gstRate: itemTaxRate,
          // Note: total field in create() is calculated
        );
      }).toList();

      // 3. Create Sale Model (Adapter: OrderModel -> SaleModel)
      // Use last KOT number for invoice ID if available, or use order ID
      final invoiceId = order.kotNumbers.isNotEmpty
          ? 'KOT-${order.kotNumbers.last}'
          : order.id.substring(0, 8).toUpperCase();

      // Note: calculations.subtotal is already the base price (without tax)
      // CartCalculationService handles tax extraction for tax-inclusive mode
      // ✅ FIX: Determine payment type based on payment status
      print('🔍 DEBUG PRINT: order.isPaid = ${order.isPaid}');
      print('🔍 DEBUG PRINT: order.paymentMethod = ${order.paymentMethod}');
      String paymentType;
      if (order.isPaid == true) {
        // Order is paid - show actual payment method
        paymentType = order.paymentMethod ?? 'Cash';
      } else {
        // Order is unpaid (running order) - show NOT PAID status
        paymentType = 'NOT PAID';
      }
      print('🔍 DEBUG PRINT: Final paymentType = $paymentType');

      final saleModel = SaleModel.createWithGst(
        saleId: invoiceId,
        customerId: order.customerName.isNotEmpty ? 'GUEST' : null,
        totalItems: order.items.length,
        subtotal: calculations.subtotal,  // Base price (without tax)
        discountAmount: calculations.discountAmount,
        totalTaxableAmount: calculations.subtotal - calculations.discountAmount, // Discounted base
        totalGstAmount: calculations.totalGST,
        grandTotal: calculations.grandTotal,
        paymentType: paymentType,
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
        kotNumbers: order.kotNumbers, // Pass all KOT numbers for customer bill
        billNumber: billNumber, // Pass bill number for completed orders
        itemTotal: calculations.itemTotal, // ✅ Pass pre-calculated item total from CartCalculationService
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
        billNumber: billNumber, // Pass bill number for bill receipts
        kotNumbers: order.kotNumbers, // Pass all KOT numbers to display on bill
        itemTotal: receiptData.itemTotal, // ✅ Pass pre-calculated item total
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
