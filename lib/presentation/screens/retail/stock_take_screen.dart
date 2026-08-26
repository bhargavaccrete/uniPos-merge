import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/stock_take_item_model_181.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../domain/services/common/notification_service.dart';
import '../../widget/componets/retail/stock_take_commit_dialog.dart';
import 'scanner_screen.dart';

/// Counting screen for one draft stock take.
///
/// Counting is data entry and nothing more — stock does not move until Apply.
/// That separation is what lets a shop count a shelf over an hour, keep selling
/// while they do it, and still get an honest variance at the end.
///
/// A completed take opens here read-only, as its own record.
class StockTakeScreen extends StatefulWidget {
  final String takeId;

  const StockTakeScreen({super.key, required this.takeId});

  @override
  State<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends State<StockTakeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    stockTakeStore.openTake(widget.takeId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    // The next screen must not inherit this count.
    stockTakeStore.closeTake();
    super.dispose();
  }

  bool get _isEditable => stockTakeStore.currentTake?.isEditable ?? false;

  // ==================== COUNTING ====================

  /// Variants matching the search box, excluding ones already counted — a
  /// counted line is edited in the list below, not added again.
  ///
  /// Bundle products are excluded entirely — a bundle carries no physical
  /// stock of its own (its availability is computed live from components),
  /// so counting it would be meaningless and would confuse staff.
  List<VarianteModel> get _searchResults {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final counted =
        stockTakeStore.currentItems.map((i) => i.variantId).toSet();

    return productStore.variants.where((v) {
      if (counted.contains(v.varianteId)) return false;
      final product = productStore.products
          .where((p) => p.productId == v.productId)
          .firstOrNull;
      if (product?.isBundle ?? false) return false;
      final name = (product?.productName ?? '').toLowerCase();
      final sku = (v.sku ?? '').toLowerCase();
      final barcode = (v.barcode ?? '').toLowerCase();
      return name.contains(query) ||
          sku.contains(query) ||
          barcode.contains(query);
    }).take(20).toList();
  }

  Future<void> _scanAndCount() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    final variant = productStore.variants
        .where((v) => v.barcode == barcode.trim())
        .firstOrNull;

    if (variant == null) {
      NotificationService.instance.showError('No product for that barcode.');
      return;
    }

    final product = productStore.products
        .where((p) => p.productId == variant.productId)
        .firstOrNull;
    if (product?.isBundle ?? false) {
      NotificationService.instance.showError(
        'Bundles have no physical stock of their own — nothing to count.',
      );
      return;
    }

    await _promptCount(variant);
  }

  /// Asks for the counted quantity. Pre-filled with the existing count when
  /// re-counting, and left blank on a first count so the system figure is never
  /// accepted by accident — that would record a false zero-variance line.
  Future<void> _promptCount(VarianteModel variant) async {
    final existing = stockTakeStore.currentItems
        .where((i) => i.variantId == variant.varianteId)
        .firstOrNull;

    final product = productStore.products
        .where((p) => p.productId == variant.productId)
        .firstOrNull;

    final counted = await showDialog<double>(
      context: context,
      builder: (_) => _CountEntryDialog(
        productName: product?.productName ?? 'Product',
        variantInfo:
            variant.hasAttributes ? variant.variantDescription : null,
        systemQty: variant.stockQty,
        initialCount: existing?.countedQty,
        allowDecimal: variant.isDecimalQuantity,
      ),
    );

    if (counted == null || !mounted) return;

    final ok = await stockTakeStore.countVariant(
      variant: variant,
      countedQty: counted,
    );

    if (!mounted) return;
    if (ok) {
      _searchController.clear();
      setState(() {});
    } else {
      NotificationService.instance
          .showError(stockTakeStore.errorMessage ?? 'Count failed.');
    }
  }

  Future<void> _removeLine(StockTakeItemModel line) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Remove line?',
      message: '${line.productName ?? 'This line'} will be dropped from the '
          'count. Stock is not affected.',
      confirmLabel: 'Remove',
      accent: AppColors.danger,
    );
    if (!confirmed) return;

    final ok = await stockTakeStore.removeLine(line.takeItemId);
    if (!mounted) return;
    if (!ok) {
      NotificationService.instance
          .showError(stockTakeStore.errorMessage ?? 'Could not remove line.');
    }
  }

  // ==================== COMMIT ====================

  Future<void> _apply() async {
    if (stockTakeStore.varianceLineCount == 0) {
      NotificationService.instance.showError(
        'Every counted line matches the system — nothing to apply.',
      );
      return;
    }

    final choice = await StockTakeCommitDialog.show(
      context,
      varianceLines: stockTakeStore.varianceLineCount,
      shortageQty: stockTakeStore.shortageQty,
      excessQty: stockTakeStore.excessQty,
      netValue: stockTakeStore.netVarianceValue,
    );
    if (choice == null || !mounted) return;

    final result = await stockTakeStore.commit(
      reason: choice.reason,
      note: choice.note,
    );

    if (!mounted) return;

    if (!result.success) {
      NotificationService.instance
          .showError(result.errorMessage ?? 'Apply failed.');
      return;
    }

    final net = result.netQty;
    final sign = net > 0 ? '+' : '';
    var message =
        '${result.appliedLines} lines applied ($sign$net units)';
    if (result.isPartial) {
      message += ' - ${result.failedLines.length} could not be applied';
    }
    NotificationService.instance.showSuccess(message);

    if (result.isPartial) await _showFailures(result.failedLines);
  }

  /// Names the lines that did not apply. A silent partial commit would leave a
  /// shop believing its count landed in full.
  Future<void> _showFailures(List<String> failed) async {
    await showAppErrorDialog(
      context: context,
      title: 'Some lines were not applied',
      errors: failed,
      message: 'Their stock moved after they were counted, or the product no '
          'longer exists. Recount these in a new stock take.',
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final take = stockTakeStore.currentTake;

        return Scaffold(
          backgroundColor: AppColors.surfaceLight,
          appBar: buildPrimaryAppBar(
            title: take?.takeNumber ?? 'Stock Take',
            actions: [
              if (_isEditable)
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Scan to count',
                  onPressed: _scanAndCount,
                ),
            ],
          ),
          body: SafeArea(
            child: MoneyScope(
              child: stockTakeStore.isLoading && take == null
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : take == null
                      ? const AppEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Stock take not found',
                        )
                      : _buildBody(context),
            ),
          ),
          bottomNavigationBar: _isEditable ? _buildApplyBar(context) : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildHeaderBand(context),
        if (_isEditable) _buildSearch(context),
        if (_isEditable && _searchResults.isNotEmpty)
          _buildSearchResults(context),
        Expanded(child: _buildLines(context)),
      ],
    );
  }

  Widget _buildHeaderBand(BuildContext context) {
    final take = stockTakeStore.currentTake!;
    final net = stockTakeStore.netVarianceQty;

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
        AppResponsive.padding(context).left,
        12,
        AppResponsive.padding(context).left,
        AppResponsive.smallSpacing(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  take.scopeNote?.isNotEmpty ?? false
                      ? take.scopeNote!
                      : 'Full count',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _statusChip(context, take.statusDisplay, take.isCompleted),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'By ${take.countedBy} - ${_formatDate(take.createdAt)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            children: [
              _metric(context, 'Counted',
                  '${stockTakeStore.countedLineCount}', AppColors.textPrimary),
              _metric(context, 'Variances',
                  '${stockTakeStore.varianceLineCount}', AppColors.warning),
              _metric(
                context,
                'Net Units',
                net == 0 ? '0' : (net > 0 ? '+$net' : '$net'),
                net == 0
                    ? AppColors.textSecondary
                    : (net > 0 ? AppColors.success : AppColors.danger),
              ),
              _metric(
                context,
                'Value',
                formatMoney(stockTakeStore.netVarianceValue),
                stockTakeStore.netVarianceValue < 0
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String label, bool completed) {
    final color = completed ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _metric(
      BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    final side = AppResponsive.padding(context).left;
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(side, 0, side, 12),
      child: AppTextField(
        controller: _searchController,
        hint: 'Search product, SKU or barcode to count...',
        icon: Icons.search_rounded,
        onChanged: (_) => setState(() {}),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  size: AppResponsive.smallIconSize(context),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              )
            : null,
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final results = _searchResults;
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      color: AppColors.white,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: results.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, i) {
          final variant = results[i];
          final product = productStore.products
              .where((p) => p.productId == variant.productId)
              .firstOrNull;
          return ListTile(
            dense: true,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    product?.productName ?? 'Product',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (product?.isRepack ?? false) ...[
                  const SizedBox(width: 6),
                  const _KitBadge(),
                ],
              ],
            ),
            subtitle: Text(
              variant.hasAttributes
                  ? variant.variantDescription
                  : 'System: ${variant.stockQty} pcs',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.primary),
            onTap: () => _promptCount(variant),
          );
        },
      ),
    );
  }

  Widget _buildLines(BuildContext context) {
    final lines = stockTakeStore.currentItems;

    if (lines.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_outlined,
        title: 'Nothing counted yet',
        message: _isEditable
            ? 'Search or scan a product above to record what you counted. '
                'Stock does not move until you apply.'
            : 'This stock take has no lines.',
      );
    }

    return ListView.builder(
      padding: AppResponsive.padding(context),
      itemCount: lines.length,
      itemBuilder: (context, i) => _buildLineCard(context, lines[i]),
    );
  }

  Widget _buildLineCard(BuildContext context, StockTakeItemModel line) {
    final variance = line.variance;
    final color = variance == 0
        ? AppColors.textSecondary
        : (variance > 0 ? AppColors.success : AppColors.danger);
    final product = productStore.products
        .where((p) => p.productId == line.productId)
        .firstOrNull;
    final isRepack = product?.isRepack ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
        border: Border.all(
          color: variance == 0 ? AppColors.divider : color.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            line.productName ?? 'Unknown product',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isRepack) ...[
                          const SizedBox(width: 6),
                          const _KitBadge(),
                        ],
                      ],
                    ),
                    if (line.variantInfo?.isNotEmpty ?? false)
                      Text(
                        line.variantInfo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              // Editable-only, same guard the menu had.
              if (_isEditable) ...[
                const SizedBox(width: 6),
                RowActionButton(
                  icon: Icons.refresh_rounded,
                  color: AppColors.primary,
                  tooltip: 'Recount',
                  onTap: () {
                    final variant = productStore.variants
                        .where((v) => v.varianteId == line.variantId)
                        .firstOrNull;
                    if (variant != null) _promptCount(variant);
                  },
                ),
                const SizedBox(width: 6),
                RowActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  tooltip: 'Remove Line',
                  onTap: () => _removeLine(line),
                ),
              ],
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            children: [
              _lineStat(context, 'System', '${line.systemQty}',
                  AppColors.textSecondary),
              _lineStat(context, 'Counted', '${line.countedQty}',
                  AppColors.textPrimary),
              _lineStat(
                context,
                'Variance',
                variance == 0
                    ? '0'
                    : (variance > 0 ? '+$variance' : '$variance'),
                color,
              ),
              _lineStat(
                context,
                line.appliedQty == null ? 'Value' : 'Applied',
                line.appliedQty == null
                    ? formatMoney(line.varianceValue)
                    : '${line.appliedQty}',
                line.appliedQty == null ? AppColors.textSecondary : color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineStat(
      BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyBar(BuildContext context) {
    return Observer(
      builder: (context) {
        final variances = stockTakeStore.varianceLineCount;
        final committing = stockTakeStore.isCommitting;

        return Container(
          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    variances == 0
                        ? 'No variances to apply'
                        : '$variances line${variances == 1 ? '' : 's'} will '
                            'adjust stock',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (variances == 0 || committing) ? null : _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.divider,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    committing ? 'Applying...' : 'Apply Count',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }
}

/// Asks for a counted quantity, showing what the system currently believes.
///
/// The system figure is displayed but the field starts blank on a first count:
/// pre-filling it would let a distracted user accept the system number and
/// record a false "counted, no variance" line, which is worse than not counting
/// the item at all.
class _CountEntryDialog extends StatefulWidget {
  final String productName;
  final String? variantInfo;
  final double systemQty;
  final double? initialCount;

  /// Whether this variant may be counted in fractions (loose goods).
  final bool allowDecimal;

  const _CountEntryDialog({
    required this.productName,
    this.variantInfo,
    required this.systemQty,
    this.initialCount,
    this.allowDecimal = false,
  });

  @override
  State<_CountEntryDialog> createState() => _CountEntryDialogState();
}

class _CountEntryDialogState extends State<_CountEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialCount == null
          ? ''
          : formatQty(widget.initialCount!),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _counted => widget.allowDecimal
      ? double.tryParse(_controller.text.trim())
      : int.tryParse(_controller.text.trim())?.toDouble();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _counted);
  }

  @override
  Widget build(BuildContext context) {
    final counted = _counted;
    final variance = counted == null ? null : counted - widget.systemQty;

    return AppDialogShell(
      title: 'Counted Quantity',
      subtitle: widget.variantInfo == null
          ? widget.productName
          : '${widget.productName} - ${widget.variantInfo}',
      accent: AppColors.primary,
      icon: Icons.inventory_2_outlined,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System says ${widget.systemQty} pcs',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _controller,
              label: 'Counted',
              hint: 'Enter what you counted',
              icon: Icons.pin_outlined,
              required: true,
              autofocus: true,
              keyboardType: widget.allowDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: [
                if (widget.allowDecimal)
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                else
                  FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Required';
                if (widget.allowDecimal
                    ? double.tryParse(text) == null
                    : int.tryParse(text) == null) {
                  return 'Enter a number';
                }
                return null;
              },
            ),
            if (variance != null && variance != 0) ...[
              SizedBox(height: AppResponsive.smallSpacing(context)),
              Text(
                variance > 0
                    ? '$variance more than the system expects'
                    : '${variance.abs()} missing'
                        ' against the system',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: variance > 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(label: 'Save Count', onPressed: _submit),
      ],
    );
  }
}

/// Marks a row as an assembled/kit item — its stock is real (unlike a
/// bundle), but it is normally replenished by assembling components, not by
/// a purchase. Counting staff should know a shortage here is not restocked
/// the usual way. Visual style matches `_StockModeBadge` in bundles_screen.
class _KitBadge extends StatelessWidget {
  const _KitBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.build_circle_outlined,
            size: 13,
            color: AppColors.info,
          ),
          const SizedBox(width: 4),
          Text(
            'Kit',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}
