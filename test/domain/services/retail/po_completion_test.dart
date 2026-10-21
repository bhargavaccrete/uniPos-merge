import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/inventory_loss_model_178.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_item_model_175.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_item_model_177.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';

/// PO COMPLETION — decided PER ITEM, never on the PO's totals.
///
/// The rule: a PO is `fullyCompleted` only when EVERY line satisfies
/// `received >= ordered - 1e-6`, and the order has something ordered at all.
/// Any receipt short of that with at least one unit in is `partiallyCompleted`;
/// nothing received leaves it `sent`.
///
/// The bug this replaces summed quantities, so a surplus on one line covered a
/// shortage on another — and because `canReceive` is `sent ||
/// partiallyCompleted`, the wrongly-completed PO also left the receiving flow
/// with goods still outstanding.
///
/// Driven through `confirmGRN`, the public entry point that calls
/// `_updatePOStatusAfterGRN`.
void main() {
  late Directory tempDir;
  final day = DateTime(2026, 4, 20, 10);

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('po_completion_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<PurchaseOrderModel>(HiveBoxNames.purchaseOrders);
    await Hive.openBox<PurchaseOrderItemModel>(
        HiveBoxNames.purchaseOrderItems);
    await Hive.openBox<GRNModel>(HiveBoxNames.grns);
    await Hive.openBox<GRNItemModel>(HiveBoxNames.grnItems);
    await Hive.openBox<PurchaseReturnModel>(HiveBoxNames.purchaseReturns);
    await Hive.openBox<PurchaseReturnItemModel>(
        HiveBoxNames.purchaseReturnItems);
    await Hive.openBox<SupplierClaimModel>(HiveBoxNames.supplierClaims);
    await Hive.openBox<SupplierClaimItemModel>(HiveBoxNames.supplierClaimItems);
    await Hive.openBox<InventoryLossModel>(HiveBoxNames.inventoryLosses);

    locator.registerLazySingleton<PurchaseOrderStore>(
        () => PurchaseOrderStore());
    locator.registerLazySingleton<DamagedGoodsStore>(() => DamagedGoodsStore());
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A sent PO with the given lines: `{poItemId: orderedQty}`.
  Future<void> seedPO(String poId, Map<String, double> lines) async {
    final iso = day.toIso8601String();
    await Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).put(
      poId,
      PurchaseOrderModel(
        poId: poId,
        poNumber: poId,
        supplierId: 'SUP-1',
        supplierName: 'Acme',
        expectedDeliveryDate: iso,
        totalItems: lines.values.fold(0.0, (s, q) => s + q),
        estimatedTotal: 1000,
        status: POStatus.sent.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
    final box =
        Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems);
    for (final e in lines.entries) {
      await box.put(
        e.key,
        PurchaseOrderItemModel(
          poItemId: e.key,
          poId: poId,
          variantId: 'V-${e.key}',
          productId: 'P-${e.key}',
          productName: e.key,
          orderedQty: e.value,
          createdAt: iso,
        ),
      );
    }
  }

  /// A DRAFT GRN plus its lines: `{poItemId: receivedQty}`. Confirm it with
  /// [confirm] to trigger the status update.
  Future<void> seedDraftGRN(String grnId, String poId,
      Map<String, double> lines) async {
    final iso = day.toIso8601String();
    await Hive.box<GRNModel>(HiveBoxNames.grns).put(
      grnId,
      GRNModel(
        grnId: grnId,
        grnNumber: grnId,
        poId: poId,
        poNumber: poId,
        supplierId: 'SUP-1',
        supplierName: 'Acme',
        receivedDate: iso,
        totalOrderedQty: lines.values.fold(0.0, (s, q) => s + q),
        totalReceivedQty: lines.values.fold(0.0, (s, q) => s + q),
        totalAmount: 100,
        status: GRNStatus.draft.name,
        createdAt: iso,
        updatedAt: iso,
      ),
    );
    final box = Hive.box<GRNItemModel>(HiveBoxNames.grnItems);
    for (final e in lines.entries) {
      await box.put(
        '$grnId-${e.key}',
        GRNItemModel(
          grnItemId: '$grnId-${e.key}',
          grnId: grnId,
          poItemId: e.key,
          variantId: 'V-${e.key}',
          productId: 'P-${e.key}',
          productName: e.key,
          orderedQty: e.value,
          receivedQty: e.value,
          acceptedQty: e.value,
          damagedQty: 0,
          costPrice: 10,
          totalAmount: e.value * 10,
          createdAt: iso,
        ),
      );
    }
  }

  Future<void> confirm(String grnId) async {
    await purchaseOrderStore.loadPurchaseOrders();
    await purchaseOrderStore.loadGRNs();
    await purchaseOrderStore.confirmGRN(grnId);
  }

  POStatus statusOf(String poId) =>
      Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders)
          .get(poId)!
          .statusEnum;

  // ── Single line ────────────────────────────────────────────────────────

  test('1 single line fully received → Completed', () async {
    await seedPO('PO-1', {'A': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  test('2 single line short → Partially Received', () async {
    await seedPO('PO-1', {'A': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 4});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.partiallyCompleted);
  });

  // ── Multi-line ─────────────────────────────────────────────────────────

  test('3 every line satisfied → Completed', () async {
    await seedPO('PO-1', {'A': 10, 'B': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10, 'B': 10});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  test('4 THE BUG: A 15/10 with B 5/10 is Partial, not Completed', () async {
    // Totals are 20 of 20, which the old rule read as complete — while five
    // units of B had never arrived and the PO could no longer be received
    // against.
    await seedPO('PO-1', {'A': 10, 'B': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 15, 'B': 5});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.partiallyCompleted,
        reason: 'a surplus on A must not satisfy the shortage on B');
    // And it can still be received against — the point of the fix.
    final po = Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders)
        .get('PO-1')!;
    expect(po.canReceive, isTrue);
  });

  test('one line untouched keeps the PO Partial', () async {
    await seedPO('PO-1', {'A': 10, 'B': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.partiallyCompleted);
  });

  // ── Over-receipt ───────────────────────────────────────────────────────

  test('5 over-receipt satisfies its OWN line → Completed', () async {
    await seedPO('PO-1', {'A': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 12});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  test('over-receipt on every line → Completed', () async {
    await seedPO('PO-1', {'A': 10, 'B': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 11, 'B': 12});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  // ── Multiple GRNs ──────────────────────────────────────────────────────

  test('6 multi-GRN progression: sent → partial → completed', () async {
    await seedPO('PO-1', {'A': 10, 'B': 10});
    expect(statusOf('PO-1'), POStatus.sent);

    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10});
    await confirm('GRN-1');
    expect(statusOf('PO-1'), POStatus.partiallyCompleted);

    await seedDraftGRN('GRN-2', 'PO-1', {'B': 10});
    await confirm('GRN-2');
    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  test('one line filled across three receipts', () async {
    await seedPO('PO-1', {'A': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 3});
    await confirm('GRN-1');
    await seedDraftGRN('GRN-2', 'PO-1', {'A': 4});
    await confirm('GRN-2');
    expect(statusOf('PO-1'), POStatus.partiallyCompleted);

    await seedDraftGRN('GRN-3', 'PO-1', {'A': 3});
    await confirm('GRN-3');
    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  // ── GRN status ─────────────────────────────────────────────────────────

  test('7 confirming a draft GRN is what advances the status', () async {
    await seedPO('PO-1', {'A': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10});
    // Not yet confirmed.
    await purchaseOrderStore.loadPurchaseOrders();
    expect(statusOf('PO-1'), POStatus.sent);

    await confirm('GRN-1');
    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  test('8 a draft GRN contributes nothing to completion', () async {
    await seedPO('PO-1', {'A': 10, 'B': 10});
    await seedDraftGRN('GRN-DRAFT', 'PO-1', {'B': 10}); // never confirmed
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.partiallyCompleted,
        reason: 'B is only on an unconfirmed receipt');
  });

  test('8b a cancelled GRN contributes nothing', () async {
    await seedPO('PO-1', {'A': 10, 'B': 10});
    await seedDraftGRN('GRN-X', 'PO-1', {'B': 10});
    await Hive.box<GRNModel>(HiveBoxNames.grns).put(
      'GRN-X',
      Hive.box<GRNModel>(HiveBoxNames.grns)
          .get('GRN-X')!
          .copyWith(status: GRNStatus.cancelled.name),
    );
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.partiallyCompleted);
  });

  // ── Decimal quantities ─────────────────────────────────────────────────

  test('9 decimals: 10.5 of 10.5 → Completed', () async {
    await seedPO('PO-1', {'A': 10.5});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10.5});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  test('9 decimals: 10 of 10.5 → Partial', () async {
    await seedPO('PO-1', {'A': 10.5});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.partiallyCompleted);
  });

  test('9 decimals: 10.5 of 10 → Completed (over-receipt)', () async {
    await seedPO('PO-1', {'A': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10.5});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  test('10 three receipts of 3.5 fill an order of 10.5', () async {
    // 3.5 is exactly representable in binary (7/2), so this particular sum is
    // exact — it passes on the arithmetic alone. The tolerance is proven by the
    // 3.3 case below, where the sum genuinely falls short.
    await seedPO('PO-1', {'A': 10.5});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 3.5});
    await confirm('GRN-1');
    await seedDraftGRN('GRN-2', 'PO-1', {'A': 3.5});
    await confirm('GRN-2');
    await seedDraftGRN('GRN-3', 'PO-1', {'A': 3.5});
    await confirm('GRN-3');

    expect(statusOf('PO-1'), POStatus.fullyCompleted);
  });

  test('10b the tolerance covers a sum that float arithmetic leaves short',
      () async {
    // 3.3 is NOT exactly representable: 3.3 + 3.3 + 3.3 == 9.899999999999999,
    // so a bare `>=` reads a fully-received order as short. This is the case
    // the 1e-6 tolerance exists for.
    expect(3.3 + 3.3 + 3.3 >= 9.9, isFalse,
        reason: 'the exact comparison the tolerance forgives');

    await seedPO('PO-1', {'A': 9.9});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 3.3});
    await confirm('GRN-1');
    await seedDraftGRN('GRN-2', 'PO-1', {'A': 3.3});
    await confirm('GRN-2');
    await seedDraftGRN('GRN-3', 'PO-1', {'A': 3.3});
    await confirm('GRN-3');

    expect(statusOf('PO-1'), POStatus.fullyCompleted,
        reason: 'without the tolerance this would stay Partially Received');
  });

  test('the tolerance does not mask a real shortage', () async {
    await seedPO('PO-1', {'A': 10.5});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 10.49});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.partiallyCompleted,
        reason: '0.01 short is short; only float noise is forgiven');
  });

  // ── Defensive guards ───────────────────────────────────────────────────

  test('11 a zero-ordered PO never auto-completes', () async {
    // Not creatable through the UI — this is legacy/restore protection.
    await seedPO('PO-1', {'A': 0});
    await seedDraftGRN('GRN-1', 'PO-1', {'A': 0});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.sent,
        reason: '0 >= 0 used to mark this Completed');
  });

  test('12 a PO with no items never auto-completes', () async {
    await seedPO('PO-1', {});
    await seedDraftGRN('GRN-1', 'PO-1', {'GHOST': 5});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.sent);
  });

  test('a receipt for a line that is not on the PO cannot complete it',
      () async {
    await seedPO('PO-1', {'A': 10});
    await seedDraftGRN('GRN-1', 'PO-1', {'GHOST': 99});
    await confirm('GRN-1');

    expect(statusOf('PO-1'), POStatus.sent,
        reason: 'line A has received nothing');
  });

  // ── Reports ────────────────────────────────────────────────────────────

  test('13 PO Status report counts still reconcile with stored statuses',
      () async {
    await seedPO('PO-DONE', {'A': 10});
    await seedDraftGRN('G-DONE', 'PO-DONE', {'A': 10});
    await confirm('G-DONE');

    await seedPO('PO-PART', {'A': 10, 'B': 10});
    await seedDraftGRN('G-PART', 'PO-PART', {'A': 15, 'B': 5});
    await confirm('G-PART');

    await seedPO('PO-SENT', {'A': 10});

    await purchaseOrderStore.loadPurchaseOrders();
    await purchaseOrderStore.loadGRNs();
    await damagedGoodsStore.loadAll();

    final start = DateTime(2026, 4, 1);
    final end = DateTime(2026, 5, 1);
    final svc = ReportService();
    final pending = await svc.getPurchaseOrderStatusReport(POStatus.sent,
        startDate: start, endDate: end);
    final partial = await svc.getPurchaseOrderStatusReport(
        POStatus.partiallyCompleted,
        startDate: start,
        endDate: end);
    final completed = await svc.getPurchaseOrderStatusReport(
        POStatus.fullyCompleted,
        startDate: start,
        endDate: end);
    final summary =
        await svc.getPurchaseSummaryReport(startDate: start, endDate: end);
    final counts = summary['countByStatus'] as Map<String, int>;

    expect(pending.length, counts['sent']);
    expect(partial.length, counts['partiallyCompleted']);
    expect(completed.length, counts['fullyCompleted']);

    // The A15/B5 order now lands in Partially Received, where it belongs.
    expect(pending.length, 1);
    expect(partial.length, 1);
    expect(completed.length, 1);
    expect(partial.single['poId'], 'PO-PART');
  });
}
