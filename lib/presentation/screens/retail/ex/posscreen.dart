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
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
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
import '../../../../core/di/service_locator.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/domain/services/retail/hold_sale_service.dart';
import 'package:billberrylite/presentation/widget/restaurant/opening_balance_dialog.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';

/// House card elevation — the same soft lift ReportCard/parked sales use.
const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
];

class RetailPosScreen extends StatefulWidget {
  const RetailPosScreen({super.key});

  @override
  State<RetailPosScreen> createState() => _RetailPosScreenState();
}

class _RetailPosScreenState extends State<RetailPosScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _searchResults = [];
  bool _showSearchResults = false;
  bool _isInitialized = false;
  bool _isScannerActive = false;
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;

  MobileScannerController? _scannerController;
  Map<String, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    _initializeStores();
    _loadCategoryNames();
  }

  Future<void> _loadCategoryNames() async {
    await categoryStore.loadCategories();
    final categories = categoryStore.categories;
    if (!mounted) return;
    setState(() {
      _categoryNames = {for (final c in categories) c.id: c.name};
    });
  }

  /// Resolve a product's category id to its display name.
  String _categoryName(String categoryId) =>
      _categoryNames[categoryId] ?? categoryId;

  /// Money string honouring the store's currency + decimal-precision settings.
  /// The whole body sits under [_moneyScope], so these stay live.
  String _money(double amount) => CurrencyHelper.formatAmountWithSymbol(
    amount,
    CurrencyHelper.currentSymbol,
    decimalPlaces: DecimalSettings.precision,
  );

  /// Rebuilds [child] when the currency or decimal precision changes — one
  /// subscription for the screen instead of a nested pair per price label.
  Widget _moneyScope(Widget child) => ValueListenableBuilder<String>(
    valueListenable: CurrencyHelper.currencyNotifier,
    builder: (context, _, _) => ValueListenableBuilder<int>(
      valueListenable: DecimalSettings.precisionNotifier,
      builder: (context, _, _) => child,
    ),
  );

  /// Shown when billing can't start and there's nowhere to go back to. No
  /// AppBar back arrow — there is no previous screen, and offering one here is
  /// what used to dump the user back into onboarding.
  Widget _buildDayNotStarted(BuildContext context) {
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
            icon: Icons.wb_sunny_outlined,
            title: 'Start the day to begin billing',
            message:
                'Record your opening cash balance so the day\'s sales and '
                'cash drawer reconcile at End of Day.',
            action: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: AppResponsive.buttonHeight(context),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => _blockedOnDayStart = false);
                      await _initializeStores();
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      'Start Day',
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

  /// True when billing is unavailable and there is no screen to fall back to
  /// (POS is the first screen after setup). Renders a blocking state with a
  /// retry rather than exiting the app to onboarding.
  bool _blockedOnDayStart = false;

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
    if (await DayManagementService.isEodStrictlyPending()) {
      if (mounted) {
        NotificationService.instance.showError(
          'Day has ended. Complete End of Day to unlock.',
        );
      }
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
          // state instead.
          setState(() => _blockedOnDayStart = true);
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: AppResponsive.iconSize(context),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
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
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final results = await productStore.searchProducts(query);
    setState(() {
      _searchResults = results;
      _showSearchResults = results.isNotEmpty;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showSearchResults = false;
    });
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
      final result = await cartStore.addItemToTab(product, variants.first);
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
        final result = await cartStore.addItemToTab(product, variant);

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
      final isLikelyBarcode = RegExp(r'^\d+$').hasMatch(barcode);
      if (mounted && isLikelyBarcode) {
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
      final result = await cartStore.addItemToTab(product, selectedVariant);
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
            const SizedBox(width: 12),
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
    if (_blockedOnDayStart) return _buildDayNotStarted(context);

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
              const SizedBox(height: 16),
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
      body: _moneyScope(body),
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
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildSearchBarWithScanner(context),
        if (!_showSearchResults) _buildTabBar(),
        if (_showSearchResults)
          _buildSearchResults()
        else ...[
          if (_isScannerActive) _buildScannerContainer(),
          _buildHeaderRow(context),
          const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
          Expanded(child: _buildSimpleCart(context)),
        ],
        _buildSimpleSummary(context),
      ],
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
              if (_showSearchResults)
                _buildSearchResults()
              else
                Expanded(
                  child: Container(
                    color: AppColors.white,
                    child: const AppEmptyState(
                      icon: Icons.search,
                      title: 'Search for products',
                      message: 'Use the search bar or scanner',
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
              _buildHeaderRow(context),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
              ),
              Expanded(child: _buildSimpleCart(context)),
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
                  padding: const EdgeInsets.all(20),
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
                      const SizedBox(height: 12),
                      _buildSearchBarWithScanner(context),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.divider,
                ),
                if (_showSearchResults)
                  _buildSearchResults()
                else
                  const Expanded(
                    child: AppEmptyState(
                      icon: Icons.search,
                      title: 'Search for products',
                      message: 'Use the search bar or scanner',
                    ),
                  ),
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
                    const SizedBox(width: 12),
                    Observer(
                      builder: (context) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
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
              _buildHeaderRow(context),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
              ),
              Expanded(child: _buildSimpleCart(context)),
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
      height: 150,
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
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
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.white,
                      size: 20,
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            // AppTextField also routes through the on-screen VisualKeyboard
            // when that setting is on — the raw field here never did, so
            // retail cashiers silently lost a feature restaurant has.
            child: AppTextField(
              controller: _searchController,
              hint: 'Search product or enter barcode...',
              icon: Icons.search,
              onChanged: _onSearchChanged,
              onFieldSubmitted: (value) async {
                if (value.isNotEmpty) {
                  await _handleBarcodeScanned(value);
                }
              },
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.textSecondary,
                        size: AppResponsive.smallIconSize(context),
                      ),
                      onPressed: _clearSearch,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
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
                size: 20,
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

  Widget _buildSearchResults() {
    return Expanded(
      child: Container(
        color: AppColors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_searchResults.length} products found',
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
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  return _buildProductSearchItem(product);
                },
              ),
            ),
          ],
        ),
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

        final stock = variants.fold<int>(0, (sum, v) => sum + v.stockQty);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 0.5),
            boxShadow: _cardShadow,
          ),
          child: InkWell(
            onTap: () => _onProductSelected(product),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(price),
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
                          borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Item Name',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              'Quantity',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              'Price',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSimpleCart(BuildContext context) {
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
          padding: const EdgeInsets.all(16),
          itemCount: cartStore.itemCount,
          itemBuilder: (context, index) {
            return Observer(
              builder: (context) {
                if (index >= cartStore.items.length) {
                  return const SizedBox.shrink();
                }
                final item = cartStore.items[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                    boxShadow: _cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cartStore.getDisplayName(item),
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _buildLinePrice(context, item),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CartQuantityStepperButton(
                              icon: Icons.remove_rounded,
                              color: AppColors.textSecondary,
                              onTap: () => cartStore
                                  .decrementQuantityInTab(item.variantId),
                            ),
                            const SizedBox(width: 4),
                            // Keyed by cart line: the list is dynamic, and an
                            // unkeyed field would carry one line's controller
                            // (and half-typed text) onto another after a
                            // removal.
                            CartQuantityField(
                              key: ValueKey(item.cartItemId),
                              qty: item.qty,
                              onSubmitted: (qty) =>
                                  _applyTypedQuantity(item, qty),
                            ),
                            const SizedBox(width: 4),
                            CartQuantityStepperButton(
                              icon: Icons.add_rounded,
                              color: AppColors.primary,
                              onTap: () async {
                                final result = await cartStore
                                    .incrementQuantityInTab(item.variantId);
                                if (!result.success && mounted) {
                                  NotificationService.instance.showWarning(
                                    result.errorMessage ??
                                        'Cannot add more items',
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Text(
                            _money(item.total),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppColors.danger,
                            ),
                            onPressed: () {
                              cartStore.removeItemFromTab(item.variantId);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
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
  Future<bool> _applyTypedQuantity(CartItemModel item, int qty) async {
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

  /// Cart line price. Tapping it opens the override dialog — making the price
  /// itself the control, rather than adding a competing action button beside
  /// Delete. Non-admins get a plain label: the action is HIDDEN, not shown and
  /// refused, matching the stock-adjustment precedent.
  Widget _buildLinePrice(BuildContext context, CartItemModel item) {
    final overridden = item.isPriceOverridden;

    final priceText = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overridden) ...[
          Text(
            _money(item.originalPrice!),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 5),
        ],
        Text(
          _money(item.price),
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: overridden ? FontWeight.w700 : FontWeight.w400,
            color: overridden ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
        if (PriceOverrideService.canOverride) ...[
          const SizedBox(width: 5),
          Icon(
            Icons.edit_outlined,
            size: AppResponsive.smallFontSize(context),
            color: AppColors.primary,
          ),
        ],
      ],
    );

    if (!PriceOverrideService.canOverride) return priceText;

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
      builder: (_) => _moneyScope(
        PriceOverrideDialog(
          item: item,
          variant: variant,
          money: _money,
          onApply: ({
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
            return result.success ? null : (result.errorMessage ?? 'Could not apply price');
          },
        ),
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        size: 18,
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
                const SizedBox(width: 12),
                // Total price
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _money(totalPrice),
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
                  height: 44,
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
                        Icon(Icons.arrow_forward, size: 18),
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
          height: 48,
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
                                      size: 16,
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
                          Icon(Icons.add, size: 16, color: AppColors.primary),
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
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add_box,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.qr_code,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
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
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 16),
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
                            const Icon(
                              Icons.category_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
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
                      const SizedBox(height: 16),
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
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 16),
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.divider, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
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
                        const SizedBox(width: 12),
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
        stockQty: int.parse(stock.trim().isEmpty ? '1' : stock.trim()),
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
