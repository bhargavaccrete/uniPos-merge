import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/presentation/screens/retail/eod_screen.dart';
import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/retail/expiry_date_field.dart';
import 'package:billberrylite/domain/services/retail/expiry_status.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/presentation/screens/retail/checkout_screen.dart';
import 'package:billberrylite/presentation/screens/retail/parked_sales_screen.dart';
import 'package:billberrylite/presentation/widget/retail/variant_picker_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/retail/price_override_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/retail/cart_quantity_field.dart';
import 'package:billberrylite/domain/services/retail/price_override_service.dart';
import 'package:billberrylite/domain/services/retail/line_discount_service.dart';
import 'package:billberrylite/domain/services/retail/retail_billing_service.dart'
    show DiscountType;
import 'package:billberrylite/presentation/widget/componets/retail/line_discount_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/retail/quick_item_dialog.dart';
import 'package:billberrylite/domain/services/retail/quick_item_service.dart';
import '../../../../core/di/service_locator.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/domain/services/retail/hold_sale_service.dart';
import 'package:billberrylite/presentation/widget/restaurant/opening_balance_dialog.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/presentation/widget/componets/common/weight_item_dialog.dart';

/// House card elevation — the same soft lift ReportCard/parked sales use.
///
/// Static blur: this is a top-level `const`, so there is no `BuildContext` to
/// resolve `AppResponsive.shadowBlurRadius` against.
const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
];

// Values in this file that stay STATIC on purpose, so they don't read as
// misses in the next sweep:
//
// * `BorderRadius.circular(10)` on every button, chip and menu — the house
//   "rectangular buttons, radius 10" rule. Laddering it would make buttons
//   8 on a phone and 12 on desktop.
// * The category dropdown's `height: 56`, `horizontal: 14` and `circular(12)`
//   — deliberately matched to `AppTextField`, which is NOT responsive.
//   Laddering them would desync the dropdown from the fields beside it.
// * Gaps below 8 (`SizedBox(4)`, `SizedBox(6)`, `vertical: 2`, `top: 4`) —
//   `smallSpacing` starts at 8, so snapping would double or triple them.
// * Hairlines and affordances: divider `height: 1`, borders `1` / `1.5`,
//   `circular(2)` and the sheet's 40×4 grab handle.
// * The 40×40 scanner button — a tap target, sized for the finger rather
//   than the breakpoint.
// * `_CartColumns` — sized from measured PANE width instead; see that class.

/// Why the POS is refusing to open billing. The blocking screen reads this to
/// name the actual problem instead of always offering "Start Day".
enum _BillingBlock {
  /// A session from an earlier day is still open — settle it first.
  eodPending,

  /// No session at all yet.
  dayNotStarted,
}

/// Column geometry for the cart table (header row + line list).
///
/// Bucketed on the MEASURED pane width, never `AppResponsive`'s screen
/// breakpoints. The cart is a `flex:` pane — 60% of the tablet tree, 65% of the
/// desktop one — so a 600px tablet hands it only ~360px while `AppResponsive`
/// still reports "tablet". Screen-derived widths reserved 254px of that for the
/// fixed columns and left the product name **49px**, about four characters.
///
/// The header and the list must resolve ONE instance of this, in a
/// `LayoutBuilder` that wraps both. That shared instance is the only thing
/// keeping each label above the cell it names.
class _CartColumns {
  const _CartColumns._({
    required this.listPad,
    required this.cardPad,
    required this.gap,
    required this.price,
    required this.stacked,
  });

  /// Whether the line renders as two rows rather than one table row.
  ///
  /// True for the narrow bucket, i.e. any pane under 480 — the same boundary
  /// the paddings already use, so there is no second threshold to keep in sync.
  ///
  /// The cutoff is arithmetic, not taste: [qty] + [actions] + a 74px total
  /// claim 238px before the name gets anything. A 320px pane left the name
  /// **34px**, and even 360px only reached 74px. The columnar table is a
  /// ≥480px affordance; below that the card stacks.
  final bool stacked;

  /// Padding on the cart `ListView`.
  final double listPad;

  /// Padding inside each line card.
  final double cardPad;

  /// Space between columns.
  final double gap;

  /// Line-total column. Never below 74: a 60px cell clipped "₹2000.00" onto a
  /// second line.
  final double price;

  /// The quantity stepper: two 32px keys, a 52px field, and the two 4px gaps
  /// between them. Dictated by `CartQuantityStepperButton` and
  /// `CartQuantityField` — if either widget's width changes, change this too.
  static const double qty = 32 + 4 + 52 + 4 + 32; // 124

  /// Slot for the per-line overflow menu. This is a COLUMN, not blank space:
  /// the header reserves it so everything to its left stays aligned.
  static const double actions = 40;

  /// Header padding has to clear the list's padding AND the card's, or every
  /// label sits `cardPad` to the left of the value it names.
  double get sidePad => listPad + cardPad;

  static _CartColumns of(double paneWidth) {
    if (paneWidth < 480) {
      return const _CartColumns._(
        listPad: 8,
        cardPad: 10,
        gap: 6,
        price: 74,
        stacked: true,
      );
    }
    if (paneWidth < 760) {
      return const _CartColumns._(
        listPad: 12,
        cardPad: 12,
        gap: 8,
        price: 74,
        stacked: false,
      );
    }
    return const _CartColumns._(
      listPad: 16,
      cardPad: 12,
      gap: 12,
      price: 84,
      stacked: false,
    );
  }
}

class RetailPosScreen extends StatefulWidget {
  const RetailPosScreen({super.key});

  @override
  State<RetailPosScreen> createState() => _RetailPosScreenState();
}

class _RetailPosScreenState extends State<RetailPosScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Search hits, and the category filter, as NOTIFIERS rather than `setState`
  /// fields.
  ///
  /// Both only affect the search/browse pane, but `setState` rebuilds the whole
  /// POS — the tab strip, every visible cart line (each one ~470 lines of
  /// widget code) and the summary — on every keystroke, every chip tap and
  /// every add to cart (which calls [_clearSearch]). Re-creating the cart-side
  /// `Observer`s that way re-runs their builders too, so being observers buys
  /// them no protection from a parent rebuild. Driving the left pane from a
  /// notifier keeps the right pane out of these three paths entirely.
  ///
  /// "Show results" is DERIVED from this list being non-empty — the same rule
  /// the old `_showSearchResults` field was assigned, so a query that matches
  /// nothing still falls back to the browse pane.
  final ValueNotifier<List<ProductModel>> _searchResults =
      ValueNotifier<List<ProductModel>>(const []);

  /// Category filter for the browse pane. Null means "All".
  final ValueNotifier<String?> _browseCategoryId = ValueNotifier<String?>(null);

  bool _isInitialized = false;
  bool _isScannerActive = false;
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;

  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _initializeStores();
    _loadCategoryNames();
  }

  Future<void> _loadCategoryNames() async {
    await categoryStore.loadCategories();
    if (!mounted) return;
    setState(() {});
  }

  /// Resolve a product's category id to its display name.
  ///
  /// Delegates rather than keeping a local id→name map: that map fell back to
  /// the raw id, so a product whose category had been deleted showed a blank
  /// tile subtitle (its id is `''`), and it could go stale against the store.
  /// `categoryNameById` is a memoised computed, so this is no slower.
  String _categoryName(String categoryId) =>
      categoryStore.displayNameFor(categoryId);

  /// Shown when billing can't start and there's nowhere to go back to. No
  /// AppBar back arrow — there is no previous screen, and offering one here is
  /// what used to dump the user back into onboarding.
  ///
  /// Says WHICH problem it is. A pending End of Day used to render the
  /// "Start the day" copy, so a shop that had simply forgotten to close
  /// yesterday was told to start a day the guard would refuse to start — and
  /// the button re-ran the same failing check.
  Widget _buildBillingBlocked(BuildContext context) {
    final eodPending = _billingBlock == _BillingBlock.eodPending;

    Future<void> retry() async {
      setState(() => _billingBlock = null);
      await _initializeStores();
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Billing',
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: AppResponsive.padding(context),
          child: AppEmptyState(
            icon: eodPending
                ? Icons.nights_stay_outlined
                : Icons.wb_sunny_outlined,
            title: eodPending
                ? 'Close the previous day first'
                : 'Start the day to begin billing',
            message: eodPending
                ? 'A day is still open from earlier. Complete End of Day to '
                      'settle its cash, then start today.'
                : "Record your opening cash balance so the day's sales and "
                      'cash drawer reconcile at End of Day.',
            action: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: AppResponsive.buttonHeight(context),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (eodPending) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RetailEODScreen(),
                          ),
                        );
                        // The day may now be closed — re-run the gates so the
                        // start-day prompt follows immediately.
                        if (mounted) await retry();
                        return;
                      }
                      await retry();
                    },
                    icon: Icon(
                      eodPending ? Icons.nights_stay : Icons.play_arrow,
                    ),
                    label: Text(
                      eodPending ? 'Complete End of Day' : 'Start Day',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.buttonFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    RouteNames.retailMenu,
                  ),
                  child: Text(
                    'Go to Dashboard',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Why billing is unavailable, when there is no screen to fall back to (POS
  /// is the first screen after setup). Renders a blocking state with a retry
  /// rather than exiting the app to onboarding.
  ///
  /// It carries the REASON, not just a flag: one shared "Start the day" screen
  /// was shown for every gate failure, so a shop whose previous day was never
  /// closed was told to start a day it could not start — and the button just
  /// re-ran the same failing gate.
  _BillingBlock? _billingBlock;

  /// Gates checked when ENTERING billing, not when leaving it.
  ///
  /// Blocking here means the user finds out before scanning a cart they can't
  /// settle. A cart already in progress is deliberately never blocked at
  /// checkout — that would strand work the user has already done.
  ///
  /// Entitlement gate mirrors restaurant's billing-entrance check: retail
  /// enforces once a manifest is present (see `PlanEnforce._bypassed`); until
  /// then it's a no-op, so this is safe on an unlicensed retail device.
  Future<bool> _passesBillingGates() async {
    if (!mounted) return false;
    // Cleared on every run so a reason can never outlive the condition that
    // set it — a retry that now passes must not leave the blocking screen armed.
    _billingBlock = null;

    // Plan gate — billing module must be included in the plan.
    if (!PlanEnforce.allows(RetailEntKeys.billing)) {
      if (mounted) {
        NotificationService.instance.showError(
          'Billing isn’t included in your current plan.',
        );
      }
      return false;
    }

    // End of Day pending → no new sales until it is completed.
    //
    // Both checks, because they answer different questions: `isEodStrictly-
    // Pending` is a DURATION rule (session older than the auto-close window,
    // and off entirely when that setting is disabled), while `hasPendingEOD` is
    // a CALENDAR rule (the open session belongs to an earlier day). A shop that
    // opened at 9 AM and returns at 8 AM the next morning trips the second but
    // not the first, and used to be allowed to keep billing into yesterday's
    // session.
    if (await DayManagementService.isEodStrictlyPending() ||
        await DayManagementService.hasPendingEOD()) {
      if (mounted) {
        NotificationService.instance.showError(
          'Complete End of Day for the previous day first.',
        );
      }
      _billingBlock = _BillingBlock.eodPending;
      return false;
    }

    // No day open yet → offer to start it right here rather than bouncing the
    // user out to Settings. Uses the same opening-balance dialog as restaurant,
    // so both verticals start a day the same way.
    if (!await DayManagementService.isDayStarted()) {
      if (!mounted) return false;
      final started = await promptStartDay(context);
      if (started != true) {
        if (mounted) {
          NotificationService.instance.showError(
            'Start the day to begin billing',
          );
        }
        _billingBlock = _BillingBlock.dayNotStarted;
        return false;
      }
    }

    return true;
  }

  Future<void> _initializeStores() async {
    await Future.delayed(Duration.zero);

    try {
      // Touch the stores so DI resolution failures surface here rather than
      // mid-render.
      productStore;
      cartStore;
      holdSaleStore;

      if (!await _passesBillingGates()) {
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          // Came here from the dashboard — go back where they were.
          Navigator.of(context).pop();
        } else {
          // Straight after setup the wizard pushReplacement's onto this screen,
          // so POS is the bottom of the stack. Popping would drop the user back
          // into onboarding (create store / restore backup). Show a blocking
          // state instead — whichever one the gate set.
          setState(() => _billingBlock ??= _BillingBlock.dayNotStarted);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _checkAndShowWelcomeDialog();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error initializing POS: $e');
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _checkAndShowWelcomeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('first_time_pos_v2') ?? true;

    if (isFirstTime && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _showWelcomeDialog();
        await prefs.setBool('first_time_pos_v2', false);
      }
    }
  }

  Future<void> _showWelcomeDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppDialogShell(
        title: 'Welcome to Your POS!',
        subtitle: 'Your store is ready — here\'s how to get started',
        accent: AppColors.primary,
        icon: Icons.celebration,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeStep(
              context,
              Icons.qr_code_scanner,
              'Scan Barcodes',
              'Use the scanner button to quickly add products',
            ),
            _buildWelcomeStep(
              context,
              Icons.search,
              'Search Products',
              'Type product names in the search bar',
            ),
            _buildWelcomeStep(
              context,
              Icons.add_shopping_cart,
              'Add to Cart',
              'Tap on products to add them to your cart',
            ),
            _buildWelcomeStep(
              context,
              Icons.pause_circle_outline,
              'Hold Sales',
              'Park incomplete sales and restore them later',
            ),
            _buildWelcomeStep(
              context,
              Icons.payment,
              'Checkout',
              'Process payments and complete transactions',
            ),
          ],
        ),
        actions: [
          appDialogPrimaryButton(
            label: 'Get Started',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.largeSpacing(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Icon(
              icon,
              size: AppResponsive.iconSize(context),
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchResults.dispose();
    _browseCategoryId.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      _searchResults.value = const [];
      return;
    }

    _searchResults.value = await productStore.searchProducts(query);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchResults.value = const [];
  }

  /// Gate on expired goods, asked once per add.
  ///
  /// Returns true when the sale may proceed. Only [RetailExpiryStatus.expired]
  /// asks — expiring-soon and expiring-today are badged on the row and the cart
  /// line but never interrupt, because stock is still legally sellable on its
  /// expiry date and a prompt at every scan would be dismissed by reflex.
  ///
  /// Deliberately NOT a hard block: shops clear near-date stock at a discount,
  /// and refusing outright would strand it with no override. The confirmation
  /// makes selling expired goods a deliberate act, which is the actual goal.
  ///
  /// Judged on the exact VARIANT being sold, not the product — warning about a
  /// product while selling a perfectly good variant of it teaches cashiers to
  /// tap through the warning.
  Future<bool> _confirmExpiredSale(
    ProductModel product,
    VarianteModel variant,
  ) async {
    final status = productStore.expiryStatusForVariant(variant);
    if (status != RetailExpiryStatus.expired) return true;
    if (!mounted) return false;

    final expiry = variant.expiryDateTime;
    return showAppConfirmDialog(
      context: context,
      title: 'Expired stock',
      message: expiry == null
          ? '${product.productName} is past its expiry date. Sell it anyway?'
          : '${product.productName} expired on '
                '${kExpiryDateFormat.format(expiry)}. Sell it anyway?',
      confirmLabel: 'Sell anyway',
      cancelLabel: 'Cancel',
      accent: AppColors.danger,
      icon: Icons.event_busy_rounded,
    );
  }

  /// How many of [variant] to add.
  ///
  /// A piece product is always 1 — the tap-adds-one behaviour is untouched. A
  /// variant flagged `isDecimalQuantity` (loose goods sold by kg/ml) instead
  /// opens the SAME weight sheet restaurant uses, so the cashier can enter what
  /// the scale says, or an amount and let the weight be derived.
  ///
  /// Returns null when the sheet was dismissed, meaning "don't add anything".
  Future<double?> _resolveQuantity(
    ProductModel product,
    VarianteModel variant,
  ) async {
    if (!variant.isDecimalQuantity) return 1;
    if (!mounted) return null;

    final selection = await showWeightItemDialog(
      context,
      name: product.productName,
      unitPrice: variant.sellingPrice ?? variant.mrp ?? 0,
      unit: variant.unit,
      stockQuantity: variant.stockQty,
      // `cartStore.addItem` already refuses `requestedQty > stockQty`, so the
      // sheet enforcing the same rule changes nothing about what can be sold —
      // it just reports it here, beside the numbers, instead of as a toast
      // after the sheet has closed and the entry is lost.
      trackInventory: true,
    );
    return selection?.quantity;
  }

  Future<void> _onProductSelected(ProductModel product) async {
    // Inactive variants stay in the catalogue but never reach a till.
    final variants = (await productStore.getVariantsForProduct(
      product.productId,
    )).where(productStore.isSellable).toList();

    if (variants.isEmpty) {
      if (mounted) {
        NotificationService.instance.showWarning(
          'No variants available for this product',
        );
      }
      return;
    }

    if (variants.length == 1) {
      if (!await _confirmExpiredSale(product, variants.first)) return;
      final qty = await _resolveQuantity(product, variants.first);
      if (qty == null) return;
      final result = await cartStore.addItemToTab(
        product,
        variants.first,
        qty: qty,
      );
      _clearSearch();
      if (mounted) {
        if (result.success) {
          NotificationService.instance.showSuccess(
            '${product.productName} added to cart',
          );
        } else {
          NotificationService.instance.showWarning(
            result.errorMessage ?? 'Cannot add item',
          );
        }
      }
    } else {
      _clearSearch();
      _showVariantSelectionDialog(product, variants);
    }
  }

  Future<void> _handleBarcodeScanned(String barcode) async {
    if (barcode.isEmpty) return;

    // Debouncing: Prevent scanning the same barcode within 2 seconds
    final now = DateTime.now();
    if (_lastScannedBarcode == barcode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }

    _lastScannedBarcode = barcode;
    _lastScanTime = now;

    final variant = await productStore.findVariantByBarcode(barcode);

    if (variant != null && !productStore.isSellable(variant)) {
      if (mounted) {
        NotificationService.instance.showWarning(
          'This variant is inactive and cannot be sold',
        );
      }
      return;
    }

    if (variant != null) {
      final product = await productStore.findByBarcode(barcode);

      if (product != null) {
        // The scan path adds directly, so it needs the same gate as a tap —
        // and a scan is the likeliest way perishable stock reaches the till.
        if (!await _confirmExpiredSale(product, variant)) {
          if (mounted) _clearSearch();
          return;
        }
        final qty = await _resolveQuantity(product, variant);
        if (qty == null) {
          if (mounted) _clearSearch();
          return;
        }
        final result = await cartStore.addItemToTab(product, variant, qty: qty);

        if (mounted) {
          _clearSearch();
          if (result.success) {
            NotificationService.instance.showSuccess(
              '${product.productName} ${_getVariantDisplayName(variant)} added to cart',
            );
          } else {
            NotificationService.instance.showWarning(
              result.errorMessage ?? 'Cannot add item',
            );
          }
        }
      }
    } else {
      // Any unrecognised code reaches the not-found flow, numeric or not.
      //
      // This used to be gated on `RegExp(r'^\d+$')`, which silently swallowed
      // every alphanumeric scan — no cart line, no dialog, not even a message.
      // Internally generated Code 128 values ("BB0000000042") and the import
      // template's own samples ("TS-RED-S") are alphanumeric, so a scanned label
      // simply vanished.
      if (mounted) {
        _showProductNotFoundDialog(barcode);
        _clearSearch();
      }
    }
  }

  void _showVariantSelectionDialog(
    ProductModel product,
    List<VarianteModel> variants,
  ) async {
    final selectedVariant = await VariantPickerDialog.show(
      context: context,
      product: product,
      variants: variants,
    );

    if (selectedVariant != null && mounted) {
      if (!await _confirmExpiredSale(product, selectedVariant)) return;
      final qty = await _resolveQuantity(product, selectedVariant);
      if (qty == null) return;
      final result = await cartStore.addItemToTab(
        product,
        selectedVariant,
        qty: qty,
      );
      if (result.success) {
        NotificationService.instance.showSuccess(
          '${product.productName} ${selectedVariant.shortDescription} added to cart',
        );
      } else {
        NotificationService.instance.showWarning(
          result.errorMessage ?? 'Cannot add item',
        );
      }
    }
  }

  String _getVariantDisplayName(VarianteModel variant) {
    final label = attributeStore.describeAttributes(
      attributeStore.attributesOf(variant),
      separator: ' • ',
    );
    return label.isEmpty ? 'Default' : label;
  }

  Future<void> _holdCurrentSale() async {
    if (cartStore.itemCount == 0) {
      NotificationService.instance.showWarning(
        'Cart is empty. Nothing to hold.',
      );
      return;
    }

    String? note;
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      // Scope disposes the controller when the route pops — disposing it in a
      // .then() races the dialog's own teardown.
      builder: (context) => DialogDisposeScope(
        disposables: [noteController],
        child: AppDialogShell(
          title: 'Hold Sale',
          subtitle: 'Park this cart to settle it later',
          accent: AppColors.warning,
          icon: Icons.pause_circle_outline,
          body: AppTextField(
            controller: noteController,
            label: 'Reason',
            hint: 'e.g. customer fetching wallet',
            icon: Icons.notes_rounded,
            maxLines: 2,
            minLines: 2,
          ),
          actions: [
            appDialogCancelButton(context),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            appDialogPrimaryButton(
              label: 'Hold',
              color: AppColors.warning,
              onPressed: () => Navigator.pop(context, noteController.text),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    note = result.trim().isEmpty ? null : result.trim();

    try {
      await HoldSaleService.park(note: note);
      NotificationService.instance.showWarning('Sale parked successfully!');
    } catch (e) {
      NotificationService.instance.showError('Error parking sale: $e');
    }
  }

  void _toggleScanner() {
    setState(() {
      _isScannerActive = !_isScannerActive;
      if (_isScannerActive) {
        _scannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          autoStart: true,
        );
      } else {
        _scannerController?.dispose();
        _scannerController = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_billingBlock != null) return _buildBillingBlocked(context);

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(
          title: 'Billing',
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              Text(
                'Initializing POS...',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // One layout tree per screen type, driven by AppResponsive so the swap
    // point matches the breakpoints the shared components use internally.
    // The old `Responsive` widget breaks at 850/1100 while AppResponsive breaks
    // at 600/1024, which left a dead zone rendering the mobile tree with tablet
    // paddings.
    final Widget body;
    switch (AppResponsive.getScreenType(context)) {
      case ScreenType.desktop:
        body = _buildDesktopLayout(context);
        break;
      case ScreenType.tablet:
        body = _buildTabletLayout(context);
        break;
      case ScreenType.mobile:
        body = _buildMobileLayout(context);
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: _buildAppBar(context),
      body: MoneyScope(child: body),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return buildPrimaryAppBar(
      title: 'Billing',
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pushReplacementNamed(context, RouteNames.retailMenu);
        },
        tooltip: 'Back to Home',
      ),
      actions: [
        Observer(
          builder: (context) => Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.pause_circle_outline),
                tooltip: 'View parked sales',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ParkedSalesScreen(),
                    ),
                  );
                },
              ),
              if (holdSaleStore.holdSaleCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${holdSaleStore.holdSaleCount}',
                      style: GoogleFonts.poppins(
                        color: AppColors.white,
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Observer(
          builder: (context) => IconButton(
            icon: const Icon(Icons.pause),
            tooltip: 'Hold current sale',
            onPressed: cartStore.itemCount > 0 ? _holdCurrentSale : null,
          ),
        ),
        // Sell something the catalogue does not carry. Lives on the shared
        // AppBar so mobile, tablet and desktop all get it from one place.
        IconButton(
          icon: const Icon(Icons.add_shopping_cart_outlined),
          tooltip: 'Add quick item',
          onPressed: _openQuickItem,
        ),
      ],
    );
  }

  /// Type an ad-hoc line straight into the cart.
  ///
  /// No permission gate: unlike price override and line discount, this does not
  /// move money off a settled figure — the cashier is quoting a price for
  /// something that was never priced.
  Future<void> _openQuickItem() async {
    // The tax dropdown reads `taxStore.taxes`, which is otherwise only loaded by
    // the settings and product screens — without this the POS would offer an
    // empty rate list on a cold start.
    await taxStore.loadTaxes();
    // Resolved HERE, not inside the dialog: a DropdownButtonFormField seeds its
    // selection on first build only, so a rate arriving from an async lookup
    // after that build would never show as selected.
    final defaultGstRate = await gstService.getDefaultGstRate();
    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (_) => MoneyScope(
        child: QuickItemDialog(
          defaultGstRate: defaultGstRate,
          money: formatMoney,
          onApply:
              ({
                required String name,
                required double price,
                required double gstRate,
                required int qty,
              }) async {
                final result = await cartStore.addQuickItemToTab(
                  name: name,
                  price: price,
                  gstRate: gstRate,
                  qty: qty,
                );
                return result.success
                    ? null
                    : (result.errorMessage ?? 'Could not add the item');
              },
        ),
      ),
    );
  }

  /// Mobile is one column, so search results genuinely replace the cart here —
  /// but the summary below still has nothing to do with them, so it stays
  /// OUTSIDE the builder.
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildSearchBarWithScanner(context),
        Expanded(
          child: _buildSearchOrElse(
            (context) => Column(
              children: [
                _buildTabBar(),
                if (_isScannerActive) _buildScannerContainer(),
                Expanded(child: _buildCartTable(context)),
              ],
            ),
          ),
        ),
        _buildSimpleSummary(context),
      ],
    );
  }

  /// Search hits when there are any, [otherwise] when there are not.
  ///
  /// The ONE place the search notifier is listened to. Callers put it under an
  /// [Expanded] — the results list fills whatever box it is handed rather than
  /// returning an `Expanded` of its own, so the same builder drops into a pane
  /// (tablet/desktop) or into the main column (mobile).
  Widget _buildSearchOrElse(WidgetBuilder otherwise) {
    return ValueListenableBuilder<List<ProductModel>>(
      valueListenable: _searchResults,
      builder: (context, results, _) =>
          results.isEmpty ? otherwise(context) : _buildSearchResults(results),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildSearchBarWithScanner(context),
              Expanded(
                child: _buildSearchOrElse(
                  (context) => Container(
                    color: AppColors.white,
                    child: _buildBrowsePane(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: AppColors.divider),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildTabBar(),
              if (_isScannerActive) _buildScannerContainer(),
              Expanded(child: _buildCartTable(context)),
              _buildSimpleSummary(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 35,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                right: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: AppResponsive.padding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Search',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      _buildSearchBarWithScanner(context),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.divider,
                ),
                Expanded(child: _buildSearchOrElse(_buildBrowsePane)),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 65,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Shopping Cart',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: AppResponsive.mediumSpacing(context)),
                    Observer(
                      builder: (context) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppResponsive.borderRadius(context),
                          ),
                        ),
                        child: Text(
                          '${cartStore.itemCount} items',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isScannerActive) _buildScannerContainer(),
              Expanded(child: _buildCartTable(context)),
              _buildSimpleSummary(context),
            ],
          ),
        ),
      ],
    );
  }

  /*----------------------------------SCANNER CONTAINER ----------------------------------*/

  /// Fraction of the preview box the scan window covers. The camera still
  /// fills the whole box (BoxFit.cover), but detection is clipped to this rect.
  static const double _scanWindowWidthFactor = 0.82;
  static const double _scanWindowHeightFactor = 0.58;

  Widget _buildScannerContainer() {
    return Container(
      height: AppResponsive.getValue(
        context,
        mobile: 150.0,
        tablet: 180.0,
        desktop: 210.0,
      ),
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        // The scan window is a Rect in the scanner's own layout space, so it
        // has to be measured, not guessed. The old fixed 250×100 frame also
        // overflowed on narrow phones.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size previewSize = constraints.biggest;
            final Rect scanWindow = Rect.fromCenter(
              center: previewSize.center(Offset.zero),
              width: previewSize.width * _scanWindowWidthFactor,
              height: previewSize.height * _scanWindowHeightFactor,
            );

            return Stack(
              children: [
                if (_scannerController != null) ...[
                  MobileScanner(
                    controller: _scannerController!,
                    // Without this the detector reads the FULL camera frame and
                    // the frame below is decoration only — a barcode anywhere in
                    // view got added to the cart.
                    scanWindow: scanWindow,
                    scanWindowUpdateThreshold: 10,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final value = barcode.rawValue;
                        if (value == null) continue;
                        if (!_isInsideScanWindow(
                          barcode,
                          capture.size,
                          scanWindow,
                          previewSize,
                        )) {
                          continue;
                        }
                        _handleBarcodeScanned(value);
                      }
                    },
                  ),
                  // Dims everything outside the window and draws the border at
                  // exactly the rect the detector filters on, so what the
                  // cashier sees is what actually scans.
                  Positioned.fill(
                    child: ScanWindowOverlay(
                      controller: _scannerController!,
                      scanWindow: scanWindow,
                      borderColor: AppColors.success,
                      borderWidth: 3,
                      borderRadius: BorderRadius.circular(
                        AppResponsive.borderRadius(context),
                      ),
                    ),
                  ),
                ],
                Positioned(
                  bottom: 5,
                  left: 0,
                  right: 0,
                  child: Text(
                    "Align barcode within frame",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.white,
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 0,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.white,
                      size: AppResponsive.iconSize(context),
                    ),
                    onPressed: _toggleScanner,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Web fallback for [MobileScanner.scanWindow].
  ///
  /// Android/iOS/desktop drop out-of-window barcodes natively; the web
  /// implementation of `updateScanWindow` is a documented no-op, so there the
  /// rect has to be enforced here. Anything we can't measure passes through —
  /// a missed scan is worse than a loose one.
  bool _isInsideScanWindow(
    Barcode barcode,
    Size imageSize,
    Rect scanWindow,
    Size previewSize,
  ) {
    if (!kIsWeb) return true;
    if (imageSize.isEmpty || barcode.corners.isEmpty) return true;

    // Both the window and the barcode get expressed as fractions of the camera
    // texture — the widget and the texture are different sizes.
    final Rect window =
        ScanWindowUtils.calculateScanWindowRelativeToTextureInPercentage(
          BoxFit.cover,
          scanWindow,
          textureSize: imageSize,
          widgetSize: previewSize,
        );

    double sumX = 0;
    double sumY = 0;
    for (final corner in barcode.corners) {
      sumX += corner.dx;
      sumY += corner.dy;
    }
    final int count = barcode.corners.length;

    return window.contains(
      Offset(sumX / count / imageSize.width, sumY / count / imageSize.height),
    );
  }

  /*----------------------------------SEARCH BAR----------------------------------*/
  Widget _buildSearchBarWithScanner(BuildContext context) {
    return Container(
      // color: AppColors.danger,
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.padding(context).left,
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            // Driven by the CONTROLLER, not by screen state: the clear button
            // used to appear only because _onSearchChanged called setState, and
            // that setState is exactly what this pass removed. A
            // TextEditingController is itself a ValueNotifier, so the field
            // tracks its own text.
            //
            // The whole field is rebuilt rather than just the icon, because
            // `suffixIcon` must stay NULL when there is no text — a non-null
            // placeholder would reserve Material's 48x48 suffix box and eat
            // that much width off an empty search bar.
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) =>
                  // AppTextField also routes through the on-screen
                  // VisualKeyboard when that setting is on — the raw field here
                  // never did, so retail cashiers silently lost a feature
                  // restaurant has.
                  AppTextField(
                    controller: _searchController,
                    hint: 'Search product or enter barcode...',
                    icon: Icons.search,
                    onChanged: _onSearchChanged,
                    onFieldSubmitted: (submitted) async {
                      if (submitted.isNotEmpty) {
                        await _handleBarcodeScanned(submitted);
                      }
                    },
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.textSecondary,
                              size: AppResponsive.smallIconSize(context),
                            ),
                            onPressed: _clearSearch,
                          ),
                  ),
            ),
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: _isScannerActive ? AppColors.danger : AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                _isScannerActive ? Icons.close : Icons.qr_code_scanner,
                color: AppColors.white,
                size: AppResponsive.iconSize(context),
              ),
              padding: EdgeInsets.zero,
              onPressed: _toggleScanner,
              tooltip: _isScannerActive ? 'Close Scanner' : 'Open Scanner',
            ),
          ),
        ],
      ),
    );
  }

  /// Takes its [results] rather than reading the notifier, so the one listener
  /// in [_buildSearchOrElse] stays the only subscription. Returns a plain box,
  /// NOT an `Expanded` — the caller decides how it is sized.
  Widget _buildSearchResults(List<ProductModel> results) {
    return Container(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.padding(context).left,
              vertical: AppResponsive.smallSpacing(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${results.length} products found',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: _clearSearch,
                  child: Text(
                    'Back to Cart',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
          Expanded(
            child: ListView.builder(
              padding: AppResponsive.cardPadding(context),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final product = results[index];
                return _buildProductSearchItem(product);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSearchItem(ProductModel product) {
    // Reads the observable variant list synchronously — a FutureBuilder here
    // re-queried Hive on every rebuild and flashed zero stock for a frame.
    return Observer(
      builder: (context) {
        final variants = productStore.variantsFor(product.productId);
        final firstVariant = variants.isNotEmpty ? variants.first : null;

        double price = 0;
        if (firstVariant != null) {
          price = firstVariant.effectivePrice;
        }

        if (price == 0) {
          price = product.defaultPrice ?? product.defaultMrp ?? 0;
        }

        final stock = variants.fold<double>(0.0, (sum, v) => sum + v.stockQty);

        return Container(
          margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
            border: Border.all(color: AppColors.divider, width: 0.5),
            boxShadow: _cardShadow,
          ),
          child: InkWell(
            onTap: () => _onProductSelected(product),
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              child: Row(
                children: [
                  Container(
                    width: AppResponsive.avatarSize(context),
                    height: AppResponsive.avatarSize(context),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppResponsive.smallBorderRadius(context),
                      ),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                      size: AppResponsive.iconSize(context),
                    ),
                  ),
                  SizedBox(width: AppResponsive.mediumSpacing(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // One Text, not a Row of three — separate Texts can't
                        // ellipsize, so this overflowed in the narrow search
                        // pane of the tablet/desktop split.
                        Text(
                          variants.length > 1
                              ? '${_categoryName(product.category)} · ${variants.length} variants'
                              : _categoryName(product.category),
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Expiry, seen BEFORE the item is added. Product-level
                        // (most urgent across variants) because that is what
                        // this row represents; the exact variant is judged
                        // again on add. Renders nothing when not alerting.
                        Builder(
                          builder: (_) {
                            final expiry = productStore.expiryStatusForProduct(
                              product.productId,
                            );
                            if (!expiry.isAlerting) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: ExpiryStatusPill(status: expiry),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(price),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: stock > 0
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppResponsive.smallBorderRadius(context),
                          ),
                        ),
                        child: Text(
                          stock > 0 ? 'Stock: $stock' : 'Out of stock',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            fontWeight: FontWeight.w500,
                            color: stock > 0
                                ? AppColors.primary
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: AppResponsive.smallSpacing(context)),
                  Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: AppResponsive.iconSize(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /*----------------------------------BROWSE PANE ----------------------------------*/

  /// Target width of one browse tile; column count is derived from it.
  static const double _browseTileWidth = 130;

  /// What the tablet/desktop search pane shows before anything is typed.
  ///
  /// That pane is 40% of the tablet tree and 35% of the desktop one, and it
  /// held a permanent "Search for products" empty state — a third of the till
  /// doing nothing until the cashier typed.
  ///
  /// It costs NO new billing logic: a tile calls [_onProductSelected], the same
  /// entry point the search rows and the scanner already use, so the variant
  /// picker, the expired-stock gate, the loose-goods weight sheet and cart
  /// errors all behave exactly as before.
  ///
  /// Mobile never reaches this — it has no split pane.
  Widget _buildBrowsePane(BuildContext context) {
    return Observer(
      builder: (context) {
        final products = productStore.products;
        if (products.isEmpty) {
          return const AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products yet',
            message: 'Products you add will be browsable here',
          );
        }

        // Only categories that actually carry a product — an empty chip is a
        // dead tap.
        final usedIds = products.map((p) => p.category).toSet();
        final categories = categoryStore.categories
            .where((c) => usedIds.contains(c.id))
            .toList();

        // The filter sits INSIDE the Observer: a chip tap then rebuilds only
        // this strip and grid, not the catalogue scan above it and not the cart
        // pane beside it. Catalogue edits still land, because they rebuild the
        // Observer, which rebuilds this.
        return ValueListenableBuilder<String?>(
          valueListenable: _browseCategoryId,
          builder: (context, categoryId, _) {
            final visible = categoryId == null
                ? products.toList()
                : products.where((p) => p.category == categoryId).toList();

            return Column(
              children: [
                _buildBrowseChips(context, categories, categoryId),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.divider,
                ),
                Expanded(child: _buildBrowseGrid(context, visible)),
              ],
            );
          },
        );
      },
    );
  }

  /// Category filter strip. Deliberately styled like the cart tab chips —
  /// same radius, padding and 160px cap — so the two strips read as one family.
  Widget _buildBrowseChips(
    BuildContext context,
    List<Category> categories,
    String? selectedId,
  ) {
    Widget chip(String label, String? id) {
      final selected = selectedId == id;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _browseCategoryId.value = id,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceMedium,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.white,
      padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('All', null),
            ...categories.map((c) => chip(c.name, c.id)),
          ],
        ),
      ),
    );
  }

  /// Tile grid.
  ///
  /// Columns come from the MEASURED pane width, not the screen: this sits in a
  /// `flex:` pane, so screen breakpoints would over-count columns exactly the
  /// way they did for the cart table.
  Widget _buildBrowseGrid(BuildContext context, List<ProductModel> products) {
    if (products.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing in this category',
        message: 'Pick another category, or use search',
      );
    }

    final spacing = AppResponsive.gridSpacing(context);
    final pad = AppResponsive.smallSpacing(context);
    // A grid cell is a FIXED height, so this is sized for the tallest tile
    // (icon chip + two-line name + price) and the tile keeps static internal
    // padding. Growing that padding is what re-triggers BOTTOM OVERFLOWED.
    final extent = AppResponsive.getValue(
      context,
      mobile: 128.0,
      tablet: 138.0,
      desktop: 150.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth - pad * 2;
        final columns = ((avail + spacing) / (_browseTileWidth + spacing))
            .floor()
            .clamp(2, 5);

        return GridView.builder(
          padding: EdgeInsets.all(pad),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: extent,
          ),
          itemBuilder: (context, i) => _buildBrowseTile(context, products[i]),
        );
      },
    );
  }

  /// One browse tile. Price is derived the same way the search row derives it,
  /// so the two never disagree about what a product costs.
  Widget _buildBrowseTile(BuildContext context, ProductModel product) {
    return Observer(
      builder: (context) {
        final variants = productStore.variantsFor(product.productId);
        final first = variants.isNotEmpty ? variants.first : null;
        var price = first?.effectivePrice ?? 0;
        if (price == 0) {
          price = product.defaultPrice ?? product.defaultMrp ?? 0;
        }
        final stock = variants.fold<double>(0.0, (s, v) => s + v.stockQty);
        final outOfStock = stock <= 0;
        final radius = BorderRadius.circular(
          AppResponsive.borderRadius(context),
        );

        return Material(
          color: AppColors.white,
          borderRadius: radius,
          child: InkWell(
            // The add path is shared with search and scan — nothing about
            // variants, expiry or loose goods is re-implemented here.
            onTap: () => _onProductSelected(product),
            borderRadius: radius,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: AppColors.divider, width: 0.5),
                boxShadow: _cardShadow,
              ),
              // Static: fixed-height cell, see _buildBrowseGrid.
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppResponsive.smallBorderRadius(context),
                          ),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                          size: AppResponsive.smallIconSize(context),
                        ),
                      ),
                      const Spacer(),
                      if (outOfStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppResponsive.smallBorderRadius(context),
                            ),
                          ),
                          child: Text(
                            'Out',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The cart table: header row and line list sized from ONE measurement.
  ///
  /// Both halves take the same [_CartColumns], resolved here from the pane's
  /// real width. Resolving it separately at each call site is what let the
  /// labels drift off their cells.
  Widget _buildCartTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _CartColumns.of(constraints.maxWidth);
        return Column(
          children: [
            // A stacked card has no columns to label, so the header goes with
            // it rather than sitting there wrapping to "Item Na me".
            if (!cols.stacked) ...[
              _buildHeaderRow(context, cols),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
              ),
            ],
            Expanded(child: _buildSimpleCart(context, cols)),
          ],
        );
      },
    );
  }

  Widget _buildHeaderRow(BuildContext context, _CartColumns cols) {
    final labelStyle = GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );

    return Container(
      color: AppColors.white,
      // sidePad, not listPad: the rows below sit inside a card that adds its
      // own padding, so a bare 20 put every label left of its column.
      padding: EdgeInsets.fromLTRB(cols.sidePad, 12, cols.sidePad, 12),
      child: Row(
        children: [
          Expanded(child: Text('Item Name', style: labelStyle)),
          SizedBox(width: cols.gap),
          SizedBox(
            width: _CartColumns.qty,
            child: Text(
              'Quantity',
              textAlign: TextAlign.center,
              style: labelStyle,
            ),
          ),
          SizedBox(width: cols.gap),
          SizedBox(
            width: cols.price,
            child: Text('Price', style: labelStyle, textAlign: TextAlign.right),
          ),
          // Reserves the overflow-menu column — see _CartColumns.actions.
          const SizedBox(width: _CartColumns.actions),
        ],
      ),
    );
  }

  Widget _buildSimpleCart(BuildContext context, _CartColumns cols) {
    return Observer(
      builder: (context) {
        if (cartStore.itemCount == 0) {
          return const AppEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Cart is empty',
            message: 'Scan or search items to add',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(cols.listPad),
          itemCount: cartStore.itemCount,
          itemBuilder: (context, index) {
            return Observer(
              builder: (context) {
                if (index >= cartStore.items.length) {
                  return const SizedBox.shrink();
                }
                final item = cartStore.items[index];

                return Container(
                  margin: EdgeInsets.only(
                    bottom: AppResponsive.mediumSpacing(context),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                    boxShadow: _cardShadow,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(cols.cardPad),
                    child: cols.stacked
                        ? _buildStackedLine(context, item, cols)
                        : _buildColumnarLine(context, item, cols),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Table row: name | qty | total | menu, aligned to the header above it.
  Widget _buildColumnarLine(
    BuildContext context,
    CartItemModel item,
    _CartColumns cols,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _lineName(context, item),
              const SizedBox(height: 4),
              _buildLinePrice(context, item),
              _lineExpiryPill(item),
            ],
          ),
        ),
        SizedBox(width: cols.gap),
        // Fixed to the same constant the header reserves, so the two can
        // never drift apart.
        SizedBox(
          width: _CartColumns.qty,
          child: _lineQtyControls(context, item),
        ),
        SizedBox(width: cols.gap),
        SizedBox(width: cols.price, child: _lineTotal(context, item)),
        SizedBox(width: _CartColumns.actions, child: _buildLineActions(item)),
      ],
    );
  }

  /// Two-row card for panes narrower than [_CartColumns.stackBelow].
  ///
  /// The columnar row cannot fit there and no amount of padding tuning saves
  /// it: the stepper alone is 124px, and with the total and the menu the fixed
  /// columns claim 244px. On a 320px phone that left the product NAME 34px —
  /// the header wrapped to "Item Na me" and names broke mid-word.
  ///
  /// Stacking gives the name the full card width. The header row is dropped
  /// with it, because it has nothing left to label.
  Widget _buildStackedLine(
    BuildContext context,
    CartItemModel item,
    _CartColumns cols,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _lineName(context, item)),
            SizedBox(width: cols.gap),
            SizedBox(width: cols.price, child: _lineTotal(context, item)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLinePrice(context, item),
                  _lineExpiryPill(item),
                ],
              ),
            ),
            SizedBox(width: cols.gap),
            SizedBox(
              width: _CartColumns.qty,
              child: _lineQtyControls(context, item),
            ),
            SizedBox(
              width: _CartColumns.actions,
              child: _buildLineActions(item),
            ),
          ],
        ),
      ],
    );
  }

  Widget _lineName(BuildContext context, CartItemModel item) => Text(
    cartStore.getDisplayName(item),
    style: GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );

  Widget _lineTotal(BuildContext context, CartItemModel item) => Text(
    formatMoney(item.total),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.right,
    style: GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );

  /// Expiry warning for a cart line.
  ///
  /// The search row is gone once the item is in the cart, so without this the
  /// warning disappears exactly when the customer is standing there. Judged per
  /// variant, like the add-time gate. Renders nothing when not alerting.
  Widget _lineExpiryPill(CartItemModel item) {
    final variant = productStore.variants
        .where((v) => v.varianteId == item.variantId)
        .firstOrNull;
    if (variant == null) return const SizedBox.shrink();
    final status = productStore.expiryStatusForVariant(variant);
    if (!status.isAlerting) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ExpiryStatusPill(status: status),
    );
  }

  Widget _lineQtyControls(BuildContext context, CartItemModel item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CartQuantityStepperButton(
          icon: Icons.remove_rounded,
          color: AppColors.textSecondary,
          onTap: () => cartStore.decrementQuantityInTab(item.variantId),
        ),
        const SizedBox(width: 4),
        // Keyed by cart line: the list is dynamic, and an unkeyed field would
        // carry one line's controller (and half-typed text) onto another after
        // a removal.
        CartQuantityField(
          key: ValueKey(item.cartItemId),
          qty: item.qty,
          // Only a loose-goods line may take a fraction; a piece line keeps
          // its digits-only keypad.
          allowDecimal:
              productStore.variants
                  .where((v) => v.varianteId == item.variantId)
                  .firstOrNull
                  ?.isDecimalQuantity ??
              false,
          onSubmitted: (qty) => _applyTypedQuantity(item, qty),
        ),
        const SizedBox(width: 4),
        CartQuantityStepperButton(
          icon: Icons.add_rounded,
          color: AppColors.primary,
          onTap: () async {
            final result = await cartStore.incrementQuantityInTab(
              item.variantId,
            );
            if (!result.success && mounted) {
              NotificationService.instance.showWarning(
                result.errorMessage ?? 'Cannot add more items',
              );
            }
          },
        ),
      ],
    );
  }

  /// One +/- key of the cart stepper. Kept as a real tap target (32×34) so a
  /// cashier isn't hunting for a 14px icon mid-queue.
  /// Apply a typed cart quantity. Returns whether it took effect, so the field
  /// can snap back when it did not.
  ///
  /// A submitted 0 removes the line — the same outcome as decrementing from 1 —
  /// so it is confirmed first: typing a digit is a much easier slip than
  /// pressing − repeatedly, and the line may carry a negotiated price override
  /// that would be lost with it.
  Future<bool> _applyTypedQuantity(CartItemModel item, double qty) async {
    if (qty == 0) {
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: 'Remove item?',
        message:
            'A quantity of 0 removes ${cartStore.getDisplayName(item)} from the bill.',
        confirmLabel: 'Remove',
        icon: Icons.delete_outline_rounded,
        accent: AppColors.danger,
      );
      if (!confirmed) return false;
    }

    final result = await cartStore.setQuantityInTab(item.variantId, qty);
    if (!result.success && mounted) {
      NotificationService.instance.showWarning(
        result.errorMessage ?? 'Could not set that quantity',
      );
    }
    return result.success;
  }

  /// '10' rather than '10.0' for a whole-number percentage.
  static String _trimPct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Overflow menu for one cart line: Price Override, Discount, Remove.
  ///
  /// Replaces the old bare delete icon, in the same 40px slot the header already
  /// reserves. Follows the retail house pattern (`inventory_screen`,
  /// `product_detail_screen`, `supplier_list_screen`, `purchase_order_list_screen`
  /// …): a `more_vert` `PopupMenuButton` whose admin-only entries are simply NOT
  /// BUILT for a non-admin, rather than shown and refused.
  Widget _buildLineActions(CartItemModel item) {
    // A quick item has no catalogue price to override — the cashier typed the
    // price it is selling at. Discount and Remove stay: both are meaningful on
    // an ad-hoc line.
    final canOverride =
        PriceOverrideService.canOverride &&
        !QuickItemService.isQuickItem(item.variantId);
    final canDiscount = LineDiscountService.canDiscount;

    return PopupMenuButton<String>(
      tooltip: 'Line options',
      icon: Icon(
        Icons.more_vert,
        size: AppResponsive.iconSize(context),
        color: AppColors.textSecondary,
      ),
      padding: EdgeInsets.zero,
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) async {
        switch (value) {
          case 'override':
            await _openPriceOverride(item);
            break;
          case 'discount':
            await _openLineDiscount(item);
            break;
          case 'remove':
            await cartStore.removeItemFromTab(item.variantId);
            break;
        }
      },
      itemBuilder: (context) => [
        if (canOverride)
          PopupMenuItem(
            value: 'override',
            child: Row(
              children: [
                Icon(
                  Icons.sell_outlined,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.primary,
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text('Price Override'),
              ],
            ),
          ),
        if (canDiscount)
          PopupMenuItem(
            value: 'discount',
            child: Row(
              children: [
                Icon(
                  Icons.percent_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.primary,
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text('Discount'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: AppResponsive.smallIconSize(context),
                color: AppColors.danger,
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Text('Remove'),
            ],
          ),
        ),
      ],
    );
  }

  /// Open the line-discount dialog for one cart line.
  ///
  /// The variant is re-read here rather than cached on the cart row: its cost
  /// price is the below-cost floor, and it lives on the variant.
  Future<void> _openLineDiscount(CartItemModel item) async {
    if (!LineDiscountService.canDiscount) return;

    final isQuick = QuickItemService.isQuickItem(item.variantId);
    // A quick item has no catalogue row by design, so its lookup miss is
    // expected rather than the "someone deleted this product" case below.
    final variant = isQuick
        ? null
        : await productStore.getVariantById(item.variantId);
    if (!mounted) return;

    if (!isQuick && variant == null) {
      NotificationService.instance.showError(
        'Variant no longer exists — remove this line and re-add it.',
      );
      return;
    }

    await showDialog<bool>(
      context: context,
      builder: (_) => MoneyScope(
        child: LineDiscountDialog(
          item: item,
          variant: variant,
          money: formatMoney,
          onApply:
              ({
                required DiscountType type,
                required double value,
                required String reason,
                String? note,
              }) async {
                final result = await cartStore.setLineDiscountInTab(
                  variantId: item.variantId,
                  type: type,
                  value: value,
                  reason: reason,
                  note: note,
                );
                return result.success
                    ? null
                    : (result.errorMessage ?? 'Could not apply discount');
              },
        ),
      ),
    );
  }

  /// Cart line price. Tapping it opens the override dialog — making the price
  /// itself the control, rather than adding a competing action button beside
  /// Delete. Non-admins get a plain label: the action is HIDDEN, not shown and
  /// refused, matching the stock-adjustment precedent.
  Widget _buildLinePrice(BuildContext context, CartItemModel item) {
    final overridden = item.isPriceOverridden;
    // Matches the overflow menu: no catalogue price behind a quick item, so the
    // price is a plain label rather than a control.
    final canOverride =
        PriceOverrideService.canOverride &&
        !QuickItemService.isQuickItem(item.variantId);

    // A Wrap, NOT a Row. With an override AND a line discount this line carries
    // four pieces ("~~2000~~ 1600 ✏ -320.00 (20%)"), which on a phone exceeds
    // the name column's share and made a Row overflow by ~60px. Wrapping lets it
    // flow onto a second line instead of clipping, and costs no height when it
    // fits.
    final priceText = Wrap(
      spacing: 5,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (overridden)
          Text(
            formatMoney(item.originalPrice!),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          formatMoney(item.price),
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: overridden ? FontWeight.w700 : FontWeight.w400,
            color: overridden ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
        if (canOverride)
          Icon(
            Icons.edit_outlined,
            size: AppResponsive.smallFontSize(context),
            color: AppColors.primary,
          ),
        // This line's own discount. The line total to the right stays GROSS,
        // mirroring the receipt, and this is what explains the gap.
        if (item.hasLineDiscount)
          Text(
            '-${formatMoney(item.lineDiscountAmount!)}'
            '${item.lineDiscountType == 'percentage' && item.lineDiscountValue != null ? ' (${_trimPct(item.lineDiscountValue!)}%)' : ''}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
      ],
    );

    if (!canOverride) return priceText;

    return InkWell(
      onTap: () => _openPriceOverride(item),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: priceText,
      ),
    );
  }

  /// Open the override dialog for one cart line.
  ///
  /// The variant is re-read here rather than cached on the cart row: MRP and
  /// cost are the validation ceilings and floors, and they live on the variant.
  Future<void> _openPriceOverride(CartItemModel item) async {
    if (!PriceOverrideService.canOverride) return;

    final variant = await productStore.getVariantById(item.variantId);
    if (!mounted) return;

    if (variant == null) {
      NotificationService.instance.showError(
        'Variant no longer exists — remove this line and re-add it.',
      );
      return;
    }

    await showDialog<bool>(
      context: context,
      builder: (_) => MoneyScope(
        child: PriceOverrideDialog(
          item: item,
          variant: variant,
          money: formatMoney,
          onApply:
              ({
                required double newPrice,
                required String reason,
                String? note,
              }) async {
                final result = await cartStore.overrideLinePriceInTab(
                  variantId: item.variantId,
                  newPrice: newPrice,
                  reason: reason,
                  note: note,
                );
                return result.success
                    ? null
                    : (result.errorMessage ?? 'Could not apply price');
              },
        ),
      ),
    );
  }

  /// Caption above the footer total. Named for the country's tax and silent
  /// when the business is not registered for tax at all.
  String get _totalCaption {
    if (!TaxFeature.enabled || retailCartStore.bill.totalGst <= 0) {
      return 'Total';
    }
    return retailCartStore.bill.isTaxInclusive
        ? 'Total (incl. ${TaxLabelRule.name})'
        : 'Total (with ${TaxLabelRule.name})';
  }

  Widget _buildSimpleSummary(BuildContext context) {
    return Observer(
      builder: (context) {
        if (cartStore.itemCount == 0) {
          return const SizedBox.shrink();
        }

        // Show the SAME figure the checkout screen will charge. This used to be
        // cartStore.totalPrice, which excludes GST — so the customer saw one
        // number here and a larger one at payment.
        final totalPrice = retailCartStore.bill.grandTotal;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.mediumSpacing(context),
            vertical: AppResponsive.smallSpacing(context),
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(
              top: BorderSide(color: AppColors.divider, width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Items count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        size: AppResponsive.smallIconSize(context),
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${cartStore.itemCount}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                // Total price
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Say WHY the total differs from the line prices. On an
                        // exclusive bill the footer is the sum plus tax, which
                        // read as an unexplained jump; on an inclusive one it
                        // matches, and saying so is still worth a word.
                        _totalCaption,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        formatMoney(totalPrice),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkout button
                SizedBox(
                  height: AppResponsive.buttonHeight(context),
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CheckoutScreen(),
                        ),
                      );

                      if (result == true && mounted) {
                        NotificationService.instance.showSuccess(
                          'Checkout completed successfully!',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Checkout',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          size: AppResponsive.smallIconSize(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /*----------------------------------TAB BAR ----------------------------------*/
  Widget _buildTabBar() {
    return Observer(
      builder: (context) {
        return Container(
          height: AppResponsive.getValue(
            context,
            mobile: 48.0,
            tablet: 52.0,
            desktop: 56.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Tabs. Flexible + shrinkWrap so the strip is only as wide as the
              // tabs themselves — Expanded reserved the whole row, stranding the
              // New button at the far right with a gap in between. It still
              // scrolls once the tabs outgrow the available width.
              Flexible(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  itemCount: cartStore.tabs.length,
                  itemBuilder: (context, index) {
                    final tab = cartStore.tabs[index];
                    final isActive = cartStore.activeTabIndex == index;
                    final itemCount = tab.totalItems;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await cartStore.switchTab(index);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            // "Tab 1" + count + close needs nowhere near 100px;
                            // the old floor padded every tab out and pushed the
                            // strip wide. A customer name still gets room to 160.
                            constraints: const BoxConstraints(
                              minWidth: 0,
                              maxWidth: 160,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.surfaceMedium,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    // Position-derived — see CartStore.tabLabel.
                                    cartStore.tabLabel(index),
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.smallFontSize(
                                        context,
                                      ),
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isActive
                                          ? AppColors.white
                                          : AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (itemCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.white.withValues(
                                              alpha: 0.25,
                                            )
                                          : AppColors.primary.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$itemCount',
                                      style: GoogleFonts.poppins(
                                        fontSize: AppResponsive.captionFontSize(
                                          context,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        color: isActive
                                            ? AppColors.white
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                if (cartStore.tabs.length > 1) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () async {
                                      await cartStore.closeTab(index);
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: AppResponsive.smallIconSize(
                                        context,
                                      ),
                                      color: isActive
                                          ? AppColors.white.withValues(
                                              alpha: 0.8,
                                            )
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // New Tab Button
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await cartStore.createNewTab();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: AppResponsive.smallIconSize(context),
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'New',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /*----------------------------------PRODUCT NOT FOUND DIALOG ----------------------------------*/
  Future<void> _showProductNotFoundDialog(String barcode) async {
    final addIt = await showAppConfirmDialog(
      context: context,
      title: 'Product Not Found',
      message:
          'No product found for barcode:\n$barcode\n\n'
          'Would you like to add this product?',
      confirmLabel: 'Add Product',
      accent: AppColors.warning,
      icon: Icons.search_off,
    );
    if (addIt && mounted) {
      await _showAddProductBottomSheet(barcode);
    }
  }

  /*----------------------------------ADD PRODUCT BOTTOM SHEET ----------------------------------*/
  Future<void> _showAddProductBottomSheet(String barcode) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final mrpController = TextEditingController();
    final stockController = TextEditingController(text: '1');

    await categoryStore.loadCategories();
    if (!mounted) return;

    List<Category> categories = categoryStore.categories.toList();
    String selectedCategory = categories.isNotEmpty ? categories.first.id : '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: AppResponsive.bottomSheetMaxHeight(context),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppResponsive.largeBorderRadius(context)),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.padding(context).left,
                  vertical: AppResponsive.largeSpacing(context),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        AppResponsive.smallSpacing(context),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppResponsive.smallBorderRadius(context),
                        ),
                      ),
                      child: Icon(
                        Icons.add_box,
                        color: AppColors.primary,
                        size: AppResponsive.iconSize(context),
                      ),
                    ),
                    SizedBox(width: AppResponsive.mediumSpacing(context)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Product',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.headingFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Quick add with scanned barcode',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barcode display
                      Container(
                        padding: AppResponsive.cardPadding(context),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            AppResponsive.smallBorderRadius(context),
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.qr_code,
                              color: AppColors.primary,
                              size: AppResponsive.iconSize(context),
                            ),
                            SizedBox(
                              width: AppResponsive.mediumSpacing(context),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scanned Barcode',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.smallFontSize(
                                      context,
                                    ),
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  barcode,
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.subheadingFontSize(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),
                      // AppTextField renders its own label + required marker —
                      // a Text above each field would print it twice.
                      AppTextField(
                        controller: nameController,
                        label: 'Product Name',
                        hint: 'Enter product name',
                        icon: Icons.inventory_2_outlined,
                        required: true,
                        autofocus: true,
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      // Keyed by category id, not name — two categories can
                      // share a display name. Styled to match AppTextField.
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.category_outlined,
                              color: AppColors.primary,
                              size: AppResponsive.iconSize(context),
                            ),
                            SizedBox(
                              width: AppResponsive.mediumSpacing(context),
                            ),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedCategory.isEmpty
                                      ? null
                                      : selectedCategory,
                                  isExpanded: true,
                                  hint: Text(
                                    'Category *',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.bodyFontSize(
                                        context,
                                      ),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                  items: categories.map((Category category) {
                                    return DropdownMenuItem<String>(
                                      value: category.id,
                                      child: Text(
                                        category.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.bodyFontSize(
                                            context,
                                          ),
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(
                                        () => selectedCategory = newValue,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: priceController,
                              label: 'Selling Price',
                              hint: '0.00',
                              required: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              prefixWidget: Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 4,
                                ),
                                child: Text(CurrencyHelper.currentSymbol),
                              ),
                            ),
                          ),
                          SizedBox(width: AppResponsive.mediumSpacing(context)),
                          Expanded(
                            child: AppTextField(
                              controller: mrpController,
                              label: 'MRP',
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              prefixWidget: Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 4,
                                ),
                                child: Text(CurrencyHelper.currentSymbol),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      AppTextField(
                        controller: stockController,
                        label: 'Stock Quantity',
                        hint: '1',
                        required: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom buttons
              Container(
                padding: AppResponsive.padding(context),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.divider, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: AppResponsive.shadowBlurRadius(context),
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        appDialogCancelButton(context),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        appDialogPrimaryButton(
                          label: 'Add to Cart',
                          onPressed: () async {
                            await _handleAddProduct(
                              context,
                              barcode,
                              nameController.text,
                              selectedCategory,
                              priceController.text,
                              mrpController.text,
                              stockController.text,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*----------------------------------HANDLE ADD PRODUCT ----------------------------------*/
  Future<void> _handleAddProduct(
    BuildContext bottomSheetContext,
    String barcode,
    String name,
    String category,
    String price,
    String mrp,
    String stock,
  ) async {
    // Validation
    if (name.trim().isEmpty) {
      NotificationService.instance.showWarning('Please enter product name');
      return;
    }

    if (price.trim().isEmpty) {
      NotificationService.instance.showWarning('Please enter selling price');
      return;
    }

    try {
      final (product, variant) = await productStore.createSimpleProduct(
        name: name.trim(),
        categoryId: category,
        barcode: barcode,
        sellingPrice: double.parse(price.trim()),
        mrp: mrp.trim().isEmpty ? null : double.parse(mrp.trim()),
        stockQty: double.parse(stock.trim().isEmpty ? '1' : stock.trim()),
      );

      final result = await cartStore.addItemToTab(product, variant);

      // Close bottom sheet — check the SHEET's context, not this State's;
      // the sheet can be dismissed while the screen behind it is still mounted.
      if (bottomSheetContext.mounted) {
        Navigator.pop(bottomSheetContext);
      }

      // Show success message
      if (mounted) {
        if (result.success) {
          NotificationService.instance.showSuccess(
            '${product.productName} added to cart!',
          );
        } else {
          NotificationService.instance.showWarning(
            result.errorMessage ?? 'Product added but could not add to cart',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error adding product: $e');
      }
    }
  }
}
