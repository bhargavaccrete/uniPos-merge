import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';

/// The accrue-in-full purchasing rule.
///
/// A goods receipt bills the supplier for EVERYTHING delivered, so the GRN
/// matches their invoice. `acceptedQty` only decides what enters stock. Damaged
/// units are recovered afterwards — by a return's credit note or a settled
/// claim — or absorbed as a loss when nothing comes back.
///
/// The old code billed `acceptedQty`, which under-stated the liability for
/// claims and write-offs and made `InventoryLoss.lossValue` a phantom loss.
///
/// Both credit decisions are pure statics precisely so they can be exercised
/// here without Hive or the service locator.
void main() {
  const cost = 100.0;

  GRNItemModel receipt({
    int received = 100,
    int damaged = 0,
    DamagedHandling? handling,
  }) =>
      GRNItemModel.create(
        grnId: 'grn-1',
        poItemId: 'poi-1',
        variantId: 'v-1',
        productId: 'p-1',
        orderedQty: 100,
        receivedQty: received,
        acceptedQty: received - damaged,
        damagedQty: damaged > 0 ? damaged : null,
        damagedHandling: handling,
        costPrice: cost,
      );

  group('GRN billing — 100 received @ ₹100, 10 damaged', () {
    test('no damage: stock and bill agree', () {
      final item = receipt();

      expect(item.acceptedQty, 100);
      expect(item.totalAmount, 10000.0, reason: 'inventory value');
      expect(item.billableQty, 100);
      expect(item.billableAmount, 10000.0, reason: 'supplier is owed');
    });

    test('return to supplier: still billed in full, credited later', () {
      final item = receipt(damaged: 10, handling: DamagedHandling.returnToSupplier);

      expect(item.acceptedQty, 90);
      expect(item.totalAmount, 9000.0);
      // NOT 9,000. The supplier delivered 100 and invoices 100; the ₹1,000 comes
      // back when their credit note is recorded, not by shrinking this bill.
      expect(item.billableAmount, 10000.0);
      expect(item.damagedAmount, 1000.0);
    });

    test('keep for claim: billed in full, credited only if settled', () {
      final item = receipt(damaged: 10, handling: DamagedHandling.keepForClaim);

      expect(item.acceptedQty, 90);
      expect(item.totalAmount, 9000.0);
      expect(item.billableAmount, 10000.0);
    });

    test('write off: billed in full, nothing ever comes back', () {
      final item = receipt(damaged: 10, handling: DamagedHandling.writeOff);

      expect(item.acceptedQty, 90);
      expect(item.totalAmount, 9000.0);
      expect(item.billableAmount, 10000.0);
    });

    test('billing is identical across every handling choice', () {
      // The whole point of the fix: handling picks which document is raised,
      // never how much the supplier is owed for the delivery.
      final amounts = [
        null,
        DamagedHandling.returnToSupplier,
        DamagedHandling.keepForClaim,
        DamagedHandling.writeOff,
      ].map((h) => receipt(damaged: 10, handling: h).billableAmount).toSet();

      expect(amounts, {10000.0});
    });

    test('partial delivery bills only what arrived', () {
      final item = receipt(received: 60, damaged: 10, handling: DamagedHandling.writeOff);

      expect(item.acceptedQty, 50);
      expect(item.billableQty, 60);
      expect(item.billableAmount, 6000.0);
      expect(item.shortageQty, 40, reason: '40 units still outstanding on the PO');
    });

    test('no cost price means no billable amount', () {
      final item = GRNItemModel.create(
        grnId: 'grn-1',
        poItemId: 'poi-1',
        variantId: 'v-1',
        productId: 'p-1',
        orderedQty: 10,
        receivedQty: 10,
        acceptedQty: 10,
      );

      expect(item.billableQty, 10);
      expect(item.billableAmount, isNull);
    });
  });

  group('Purchase return credit', () {
    PurchaseReturnModel makeReturn({bool credited = false}) =>
        PurchaseReturnModel.create(
          returnNumber: 'PR-1',
          grnId: 'grn-1',
          grnNumber: 'GRN-1',
          poId: 'po-1',
          poNumber: 'PO-1',
          supplierId: 's-1',
          totalQty: 10,
          totalAmount: 1000,
        ).copyWith(creditApplied: credited ? true : null);

    test('credit note reduces the balance by the full return value', () {
      expect(
        PurchaseReturnModel.creditAdjustment(makeReturn(), null),
        -1000.0,
      );
    });

    test('a partial credit note only credits what the supplier allowed', () {
      expect(
        PurchaseReturnModel.creditAdjustment(makeReturn(), 600),
        -600.0,
      );
    });

    test('recording the same credit note twice credits once', () {
      final credited = makeReturn(credited: true);

      expect(PurchaseReturnModel.creditAdjustment(credited, null), 0.0);
      expect(PurchaseReturnModel.creditAdjustment(credited, 600), 0.0);
    });
  });

  group('Supplier claim credit', () {
    SupplierClaimModel makeClaim({
      SupplierClaimStatus status = SupplierClaimStatus.pending,
      bool credited = false,
    }) =>
        SupplierClaimModel.create(
          claimNumber: 'CLM-1',
          grnId: 'grn-1',
          grnNumber: 'GRN-1',
          poId: 'po-1',
          poNumber: 'PO-1',
          supplierId: 's-1',
          totalQty: 10,
          totalAmount: 1000,
        ).copyWith(
          status: status.name,
          creditApplied: credited ? true : null,
        );

    test('settling credits the claim value', () {
      final approved = makeClaim(status: SupplierClaimStatus.approved);

      expect(
        SupplierClaimModel.claimBalanceAdjustment(
          approved,
          SupplierClaimStatus.settled,
        ),
        -1000.0,
      );
    });

    test('approval alone moves no money', () {
      // The supplier has agreed, not paid.
      expect(
        SupplierClaimModel.claimBalanceAdjustment(
          makeClaim(),
          SupplierClaimStatus.approved,
        ),
        0.0,
      );
    });

    test('rejection leaves the full amount payable', () {
      expect(
        SupplierClaimModel.claimBalanceAdjustment(
          makeClaim(),
          SupplierClaimStatus.rejected,
        ),
        0.0,
      );
    });

    test('settling the same claim twice credits once', () {
      final settled = makeClaim(
        status: SupplierClaimStatus.settled,
        credited: true,
      );

      expect(
        SupplierClaimModel.claimBalanceAdjustment(
          settled,
          SupplierClaimStatus.settled,
        ),
        0.0,
        reason: '₹1,000 must not come off the balance a second time',
      );
    });
  });

  group('Rejected claim write-off guard', () {
    SupplierClaimModel claim({
      required SupplierClaimStatus status,
      bool writtenOff = false,
    }) =>
        SupplierClaimModel.create(
          claimNumber: 'CLM-1',
          grnId: 'grn-1',
          grnNumber: 'GRN-1',
          poId: 'po-1',
          poNumber: 'PO-1',
          supplierId: 's-1',
          totalQty: 10,
          totalAmount: 1000,
        ).copyWith(
          status: status.name,
          lossRecorded: writtenOff ? true : null,
        );

    test('a rejected claim is eligible for write-off exactly once', () {
      expect(claim(status: SupplierClaimStatus.rejected).isLossRecorded, isFalse);
      expect(
        claim(status: SupplierClaimStatus.rejected, writtenOff: true)
            .isLossRecorded,
        isTrue,
      );
    });

    test('flags default to false on records written before they existed', () {
      final legacy = claim(status: SupplierClaimStatus.pending);

      expect(legacy.creditApplied, isNull);
      expect(legacy.isCreditApplied, isFalse);
      expect(legacy.isLossRecorded, isFalse);
    });
  });
}
