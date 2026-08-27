import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/purchase_order/purchase_order_list_screen.dart';

void main() {
  group('WhatsApp PO Sharing Utilities', () {
    test('cleanSupplierPhone should format phone numbers correctly', () {
      expect(cleanSupplierPhone('+91 12345 67890'), '911234567890');
      expect(cleanSupplierPhone('123-456-7890'), '1234567890');
      expect(cleanSupplierPhone('(555) 123-4567'), '5551234567');
      expect(cleanSupplierPhone('  +1-800-555-0199  '), '18005550199');
      expect(cleanSupplierPhone(''), '');
    });

    test('buildWhatsAppPOMessage should generate correct pre-filled text with decimal quantities and units', () {
      final po = RestaurantPurchaseOrderModel(
        poId: 'po-1',
        poNumber: 'PO-20260826-001',
        supplierId: 'sup-123',
        supplierName: 'Fresh Farms',
        expectedDeliveryDate: '2026-08-30T10:00:00.000',
        totalItems: 3,
        estimatedTotal: 154.50,
        status: 'sent',
        notes: 'Please deliver fresh products.',
        createdAt: '2026-08-26T12:00:00.000',
        updatedAt: '2026-08-26T12:00:00.000',
      );

      final items = [
        RestaurantPurchaseOrderItemModel(
          poItemId: 'poi-1',
          poId: 'po-1',
          itemId: 'item-1',
          itemName: 'Potato',
          orderedQty: 7.5,
          estimatedPrice: 10.0,
          estimatedTotal: 75.0,
          createdAt: '2026-08-26T12:00:00.000',
        ),
        RestaurantPurchaseOrderItemModel(
          poItemId: 'poi-2',
          poId: 'po-1',
          itemId: 'item-2',
          itemName: 'Oil',
          orderedQty: 2.25,
          estimatedPrice: 20.0,
          estimatedTotal: 45.0,
          createdAt: '2026-08-26T12:00:00.000',
        ),
        RestaurantPurchaseOrderItemModel(
          poItemId: 'poi-3',
          poId: 'po-1',
          itemId: 'item-3',
          itemName: 'Bread',
          orderedQty: 20.0,
          estimatedPrice: 1.725,
          estimatedTotal: 34.50,
          createdAt: '2026-08-26T12:00:00.000',
        ),
      ];

      final allItems = [
        Items(
          id: 'item-1',
          name: 'Potato',
          unit: 'kg',
          productType: 'Raw Material',
          isEnabled: true,
        ),
        Items(
          id: 'item-2',
          name: 'Oil',
          unit: 'liter',
          productType: 'Raw Material',
          isEnabled: true,
        ),
        Items(
          id: 'item-3',
          name: 'Bread',
          unit: 'piece',
          productType: 'Raw Material',
          isEnabled: true,
        ),
      ];

      final message = buildWhatsAppPOMessage(
        po: po,
        items: items,
        allItems: allItems,
      );

      expect(message, contains('Purchase Order: PO-20260826-001'));
      expect(message, contains('Supplier: Fresh Farms'));
      expect(message, contains('Expected Delivery: 30/08/2026'));
      expect(message, contains('Notes: Please deliver fresh products.'));
      expect(message, contains('- Potato — Qty: 7.5 kg'));
      expect(message, contains('- Oil — Qty: 2.25 liter'));
      expect(message, contains('- Bread — Qty: 20 piece'));
      expect(message, contains('Estimated Total:'));
    });
  });
}
