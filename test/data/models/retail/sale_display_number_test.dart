import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';

/// `displayNumber` is the one thing every customer-facing surface reads, so its
/// fallback has to hold for sales written before invoice numbering existed.
void main() {
  SaleModel sale({String saleId = 'e7fe242f-1cb3-4a0e-9f11-2b7c5d8e0a91',
      String? invoiceNumber}) {
    const iso = '2026-09-07T15:58:00.000';
    return SaleModel(
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      totalItems: 1,
      subtotal: 200,
      discountAmount: 0,
      taxAmount: 0,
      totalAmount: 200,
      paymentType: 'cash',
      date: iso,
      createdAt: iso,
      updatedAt: iso,
    );
  }

  test('shows the invoice number when the sale carries one', () {
    expect(sale(invoiceNumber: 'INV-00001').displayNumber, 'INV-00001');
  });

  test('a credit note shows its own series', () {
    expect(
      sale(saleId: 'RTN_abc', invoiceNumber: 'CRN-00007').displayNumber,
      'CRN-00007',
    );
  });

  test('a sale predating numbering falls back to a short reference', () {
    // Never blank, and never the full 36-character UUID.
    expect(sale().displayNumber, 'E7FE242F-1CB3');
  });

  test('an empty or blank number is treated as absent', () {
    expect(sale(invoiceNumber: '').displayNumber, 'E7FE242F-1CB3');
    expect(sale(invoiceNumber: '   ').displayNumber, 'E7FE242F-1CB3');
  });

  test('copyWith carries the number across', () {
    final updated = sale(invoiceNumber: 'INV-00001').copyWith(paidAmount: 50);
    expect(updated.displayNumber, 'INV-00001');
  });

  test('the number survives a map round-trip', () {
    final original = sale(invoiceNumber: 'INV-00123');
    final restored = SaleModel.fromMap(original.toMap());
    expect(restored.invoiceNumber, 'INV-00123');
    expect(restored.saleId, original.saleId);
  });
}
