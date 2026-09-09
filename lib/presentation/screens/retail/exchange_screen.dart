import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/retail/exchange_summary_card.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/short_ref.dart';

/// Take one item back from a settled sale and give a different one out.
///
/// One generic flow for every retail store type — there is deliberately no
/// Garment/Footwear/Sports variation.
///
/// V1 is one returned line and one replacement variant. The screen never does
/// money maths of its own: it asks [ExchangeService.quote] for the figures, so
/// what the cashier is shown is exactly what will be written.
class ExchangeScreen extends StatefulWidget {
  final String saleId;

  const ExchangeScreen({super.key, required this.saleId});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  final ExchangeService _exchangeService = ExchangeService();
  final ReturnService _returnService = ReturnService();

  SaleModel? _sale;
  List<SaleItemModel> _saleItems = [];

  /// Units of each variant still returnable — every quantity control is capped
  /// by this, so the same goods can never come back twice.
  Map<String, double> _remaining = {};

  SaleItemModel? _returnedItem;
  double _returnQty = 1;
  VarianteModel? _replacement;

  /// Types the returned quantity for a loose-goods line. A stepper cannot reach
  /// 1.75, so those lines get a field instead.
  final TextEditingController _qtyController = TextEditingController();

  String _paymentMethod = 'cash';

  /// The live quote. Recomputed whenever a choice changes, never derived here.
  ExchangeQuote? _quote;
  String? _quoteError;

  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final sale = await saleStore.getSaleById(widget.saleId);
      final items = await saleStore.getItemsForSale(widget.saleId);
      final remaining = await _returnService.remainingReturnable(widget.saleId);

      // Preselect when only one line can be exchanged — the common case.
      final returnable = items
          .where((i) => (remaining[i.varianteId] ?? 0) > 0)
          .toList();

      setState(() {
        _sale = sale;
        _saleItems = items;
        _remaining = remaining;
        // Set through the helper so a loose-goods line starts at its full
        // remaining amount rather than at 1.
        _selectReturnedItem(returnable.length == 1 ? returnable.first : null);
        _isLoading = false;
      });

      if (_returnedItem != null) await _refreshQuote();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        NotificationService.instance.showError('Error loading sale: $e');
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  double _remainingFor(SaleItemModel item) => _remaining[item.varianteId] ?? 0;

  /// The catalogue variant behind a sale line. Looked up by hand rather than
  /// through the async `getVariantById`, because build-time code needs it.
  VarianteModel? _variantFor(String variantId) {
    for (final v in productStore.variants) {
      if (v.varianteId == variantId) return v;
    }
    return null;
  }

  /// Whether the line being returned is sold in fractional amounts.
  bool get _returnedIsDecimal {
    final item = _returnedItem;
    if (item == null) return false;
    return _variantFor(item.varianteId)?.isDecimalQuantity ?? false;
  }

  /// Selects the line coming back and picks a sensible starting quantity.
  ///
  /// A loose-goods line defaults to the WHOLE remaining amount: 1.75 L of milk
  /// was sold as one indivisible purchase, so "1 of 1.75" is not a quantity the
  /// cashier meant. A piece line still starts at 1, capped by what is left.
  void _selectReturnedItem(SaleItemModel? item) {
    _returnedItem = item;

    if (item == null) {
      _returnQty = 1;
      _qtyController.text = '';
      return;
    }

    final max = _remainingFor(item);
    final isDecimal = _variantFor(item.varianteId)?.isDecimalQuantity ?? false;

    _returnQty = isDecimal ? max : (max < 1 ? max : 1);
    _qtyController.text = formatQty(_returnQty);
  }

  List<SaleItemModel> get _returnableItems =>
      _saleItems.where((i) => _remainingFor(i) > 0).toList();

  bool get _ready => _returnedItem != null && _replacement != null;

  /// Ask the service to price the current selection. The screen holds no
  /// pricing logic of its own — that is what stops the displayed figure
  /// drifting from the committed one.
  Future<void> _refreshQuote() async {
    if (!_ready) {
      setState(() {
        _quote = null;
        _quoteError = null;
      });
      return;
    }

    try {
      final q = await _exchangeService.quote(
        originalSaleId: widget.saleId,
        returnedVariantId: _returnedItem!.varianteId,
        returnQty: _returnQty,
        replacementVariantId: _replacement!.varianteId,
      );
      if (!mounted) return;
      setState(() {
        _quote = q;
        _quoteError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _quoteError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickReturnedItem() async {
    final picked = await showDialog<SaleItemModel>(
      context: context,
      builder: (_) =>
          _ReturnedItemPicker(items: _returnableItems, remaining: _remaining),
    );
    if (picked == null) return;
    setState(() => _selectReturnedItem(picked));
    await _refreshQuote();
  }

  Future<void> _pickReplacement() async {
    final picked = await showDialog<VarianteModel>(
      context: context,
      builder: (_) => const _ReplacementPicker(),
    );
    if (picked == null) return;
    setState(() => _replacement = picked);
    await _refreshQuote();
  }

  Future<void> _setQty(double qty) async {
    setState(() => _returnQty = qty);
    await _refreshQuote();
  }

  Future<void> _complete() async {
    final quote = _quote;
    if (quote == null || _isProcessing) return;

    // Plan gate — an exchange is a return plus a sale, so it rides the same
    // entitlement returns do. No-op until a retail manifest is present.
    if (!PlanEnforce.allows(RetailEntKeys.billingReturns)) {
      NotificationService.instance.showError(
        'Exchanges aren’t included in your current plan.',
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Complete exchange?',
      message: _confirmMessage(quote),
      confirmLabel: 'Complete Exchange',
      accent: AppColors.primary,
      icon: Icons.swap_horiz_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    final result = await _exchangeService.processExchange(
      originalSaleId: widget.saleId,
      returnedVariantId: _returnedItem!.varianteId,
      returnQty: _returnQty,
      replacementVariantId: _replacement!.varianteId,
      paymentMethod: _paymentMethod,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() => _isProcessing = false);
      NotificationService.instance.showError(result.error ?? 'Exchange failed');
      return;
    }

    Navigator.pop(context, true);
    NotificationService.instance.showSuccess(
      'Exchange complete • ${result.exchangeGroupId}',
    );
  }

  String _confirmMessage(ExchangeQuote quote) {
    final buffer = StringBuffer();
    if (quote.customerPays) {
      buffer.write(
        'Collect ${formatMoney(quote.differenceAmount)} '
        'by ${_paymentMethod.toUpperCase()}. ',
      );
    } else if (quote.customerRefunded) {
      buffer.write(
        'Refund ${formatMoney(quote.differenceAmount)} '
        'by ${_paymentMethod.toUpperCase()}. ',
      );
    } else {
      buffer.write('Nothing to collect or refund. ');
    }

    if (quote.appliedToDue > 0) {
      buffer.write(
        '${formatMoney(quote.appliedToDue)} of the return comes off the '
        'outstanding due. ',
      );
    }

    buffer.write('Stock moves both ways. This cannot be undone.');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Exchange',
        titleFontSize: AppResponsive.subheadingFontSize(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
          ? _error('Sale not found')
          : _returnableItems.isEmpty
          ? _error('Everything on this sale has already been returned')
          : SingleChildScrollView(
              child: AppResponsive.constrainedContent(
                context: context,
                alignment: Alignment.topCenter,
                maxWidth: AppResponsive.maxCardWidth(context),
                child: Column(
                  children: [
                    _originalCard(),
                    _returningCard(),
                    _replacementCard(),
                    if (_quoteError != null) _errorBanner(_quoteError!),
                    if (_quote != null) ...[
                      ExchangeSummaryCard(quote: _quote!),
                      if (!_quote!.isEven) _paymentCard(),
                    ],
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                  ],
                ),
              ),
            ),
      bottomNavigationBar:
          _sale != null && !_isLoading && _returnableItems.isNotEmpty
          ? _completeButton()
          : null,
    );
  }

  Widget _error(String message) => Center(
    child: Padding(
      padding: AppResponsive.padding(context),
      child: AppEmptyState(icon: Icons.swap_horiz_rounded, title: message),
    ),
  );

  Widget _card({required Widget child}) => Container(
    margin: AppResponsive.padding(context),
    padding: AppResponsive.padding(context),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      border: Border.all(color: AppColors.divider),
    ),
    child: child,
  );

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _originalCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Original Sale'),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _row('Bill', _sale!.displayNumber),
        _row('Paid By', _sale!.paymentType.toUpperCase()),
        _row('Amount', formatMoney(_sale!.totalAmount)),
        if (_sale!.dueAmount > 0)
          _row(
            'Outstanding',
            formatMoney(_sale!.dueAmount),
            accent: AppColors.warning,
          ),
      ],
    ),
  );

  Widget _returningCard() {
    final item = _returnedItem;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Returning')),
              if (_returnableItems.length > 1)
                TextButton(
                  onPressed: _pickReturnedItem,
                  child: Text(item == null ? 'Select' : 'Change'),
                ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          if (item == null)
            _placeholder('Choose the item coming back', _pickReturnedItem)
          else ...[
            Text(
              item.productName ?? 'Item',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            _attributes(item),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _qtyStepper(item),
          ],
        ],
      ),
    );
  }

  Widget _replacementCard() {
    final variant = _replacement;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Replacement')),
              if (variant != null)
                TextButton(
                  onPressed: _pickReplacement,
                  child: const Text('Change'),
                ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          if (variant == null)
            _placeholder('Choose any item to give out', _pickReplacement)
          else ...[
            Text(
              productStore.getProductById(variant.productId)?.productName ??
                  'Item',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (variant.variantDescription.isNotEmpty)
              Text(
                variant.variantDescription,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              '${formatMoney(variant.effectivePrice)} · '
              '${formatQtyWithUnit(variant.stockQty, variant.effectiveUnit)} '
              'in stock',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder(String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(
      AppResponsive.smallBorderRadius(context),
    ),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.mediumSpacing(context),
        vertical: AppResponsive.mediumSpacing(context),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.primary,
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _attributes(SaleItemModel item) {
    final text = attributeStore.describeAttributes(
      item.attributes,
      size: item.size,
      color: item.color,
      labelled: false,
    );
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.smallFontSize(context),
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _qtyStepper(SaleItemModel item) {
    final max = _remainingFor(item);
    final alreadyReturned = item.qty - max;
    final unit = _variantFor(item.varianteId)?.effectiveUnit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_returnedIsDecimal)
          _decimalQtyField(max, unit)
        else
          Row(
            children: [
              Text(
                'Qty',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _returnQty > 1
                    ? () => _setQty(_returnQty - 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                '${formatQty(_returnQty)} / ${formatQty(max)}',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                // Compares the RESULT against the cap. `_returnQty < max` let a
                // line with 1.75 remaining step from 1 to 2 — more than was
                // ever sold.
                onPressed: _returnQty + 1 <= max
                    ? () => _setQty(_returnQty + 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        if (alreadyReturned > 0) ...[
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            '${formatQty(alreadyReturned)} already returned',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  /// Typed quantity for a loose-goods line, capped at what is still
  /// returnable. Anything above the cap is pulled back to it as you type,
  /// rather than being refused on save.
  Widget _decimalQtyField(double max, String? unit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            controller: _qtyController,
            label:
                'Quantity${unit != null && unit.isNotEmpty ? ' ($unit)' : ''}',
            icon: Icons.scale_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (raw) {
              final parsed = double.tryParse(raw.trim());
              if (parsed == null || parsed <= 0) return;
              if (parsed > max) {
                _qtyController.text = formatQty(max);
                _qtyController.selection = TextSelection.collapsed(
                  offset: _qtyController.text.length,
                );
                _setQty(max);
                return;
              }
              _setQty(parsed);
            },
          ),
        ),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        Padding(
          padding: EdgeInsets.only(top: AppResponsive.mediumSpacing(context)),
          child: Text(
            'of ${formatQtyWithUnit(max, unit)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_quote!.customerPays ? 'Collect By' : 'Refund By'),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        Wrap(
          spacing: 8,
          children: [
            _methodChip('cash', '💵 Cash'),
            _methodChip('card', '💳 Card'),
            _methodChip('upi', '📱 UPI'),
          ],
        ),
      ],
    ),
  );

  Widget _methodChip(String value, String label) => ChoiceChip(
    label: Text(label),
    labelStyle: GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
    ),
    selected: _paymentMethod == value,
    onSelected: (_) => setState(() => _paymentMethod = value),
  );

  Widget _errorBanner(String message) => Container(
    margin: AppResponsive.padding(context),
    padding: EdgeInsets.symmetric(
      horizontal: AppResponsive.mediumSpacing(context),
      vertical: AppResponsive.smallSpacing(context),
    ),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(
        AppResponsive.smallBorderRadius(context),
      ),
      border: Border.all(color: AppColors.danger),
    ),
    child: Row(
      children: [
        Icon(
          Icons.error_outline,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.danger,
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _row(String label, String value, {Color? accent}) => Padding(
    padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: AppResponsive.bodyFontSize(context),
          ),
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: AppResponsive.bodyFontSize(context),
              color: accent,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _completeButton() {
    final enabled = _quote != null && !_isProcessing;
    return SafeArea(
      child: Padding(
        padding: AppResponsive.padding(context),
        child: SizedBox(
          width: double.infinity,
          height: AppResponsive.buttonHeight(context),
          child: ElevatedButton.icon(
            onPressed: enabled ? _complete : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.swap_horiz_rounded),
            label: Text(
              _isProcessing ? 'Processing…' : 'Complete Exchange',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Which line of the bill is coming back. Only shown when more than one is
/// still returnable.
class _ReturnedItemPicker extends StatelessWidget {
  final List<SaleItemModel> items;
  final Map<String, double> remaining;

  const _ReturnedItemPicker({required this.items, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: 'Item Being Returned',
      accent: AppColors.primary,
      icon: Icons.assignment_return_rounded,
      body: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            final left = remaining[item.varianteId] ?? 0;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.productName ?? 'Item',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
              subtitle: Text(
                '${formatQty(left)} of ${formatQty(item.qty)} still '
                'returnable · ${formatMoney(item.price)} each',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () => Navigator.pop(context, item),
            );
          },
        ),
      ),
      actions: [appDialogCancelButton(context, label: 'Close')],
    );
  }
}

/// Any active variant with stock. Search matches product name, variant
/// description, SKU and barcode, so a scanned code finds its item.
class _ReplacementPicker extends StatefulWidget {
  const _ReplacementPicker();

  @override
  State<_ReplacementPicker> createState() => _ReplacementPickerState();
}

class _ReplacementPickerState extends State<_ReplacementPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Only what can actually be sold: active, in stock, priced.
  List<VarianteModel> get _candidates {
    final query = _query.toLowerCase().trim();
    return productStore.variants.where((v) {
      if (v.status.toLowerCase().trim() != 'active') return false;
      if (v.stockQty <= 0) return false;
      if (v.effectivePrice <= 0) return false;
      if (query.isEmpty) return true;

      final name = productStore.getProductById(v.productId)?.productName ?? '';
      return name.toLowerCase().contains(query) ||
          v.variantDescription.toLowerCase().contains(query) ||
          (v.sku ?? '').toLowerCase().contains(query) ||
          (v.barcode ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;

    return AppDialogShell(
      title: 'Replacement Item',
      accent: AppColors.primary,
      icon: Icons.swap_horiz_rounded,
      body: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(
          children: [
            AppTextField(
              controller: _searchController,
              hint: 'Search or scan a barcode…',
              icon: Icons.search_rounded,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: candidates.isEmpty
                  ? const AppEmptyState(
                      dense: true,
                      icon: Icons.search_off_rounded,
                      title: 'Nothing in stock matches',
                    )
                  : ListView.separated(
                      itemCount: candidates.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final v = candidates[index];
                        final name =
                            productStore
                                .getProductById(v.productId)
                                ?.productName ??
                            'Item';
                        final description = v.variantDescription;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            description.isEmpty ? name : '$name · $description',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: AppResponsive.bodyFontSize(context),
                            ),
                          ),
                          subtitle: Text(
                            '${formatMoney(v.effectivePrice)} · '
                            '${formatQtyWithUnit(v.stockQty, v.effectiveUnit)} '
                            'in stock',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, v),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [appDialogCancelButton(context, label: 'Close')],
    );
  }
}
