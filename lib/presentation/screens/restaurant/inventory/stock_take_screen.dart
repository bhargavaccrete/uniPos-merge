import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/restaurant_stock_take_item_model.dart';
import '../../../../data/models/restaurant/db/restaurant_stock_take_model.dart';
import '../../../../domain/services/common/notification_service.dart';
import '../../../../domain/services/restaurant/stock_adjust_service.dart';

/// 'Stock correction' — bookkeeping fix, no loss recorded. Offered alongside
/// `StockAdjustService.lossReasons` in the commit reason picker.
const String _stockCorrectionReason = 'Stock correction';

/// Counting screen for one draft restaurant stock take (raw material /
/// semi-finished items). Mirrors retail's `StockTakeScreen`.
///
/// Counting is data entry and nothing more — stock does not move until
/// commit. That separation is what lets a kitchen count a storeroom over an
/// hour, keep selling while they do it, and still get an honest variance at
/// the end.
///
/// A completed (or cancelled) take opens here read-only, as its own record.
class RestaurantStockTakeScreen extends StatefulWidget {
  final String takeId;

  const RestaurantStockTakeScreen({super.key, required this.takeId});

  @override
  State<RestaurantStockTakeScreen> createState() =>
      _RestaurantStockTakeScreenState();
}

class _RestaurantStockTakeScreenState
    extends State<RestaurantStockTakeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (itemStore.items.isEmpty) itemStore.loadItems();
    restaurantStockTakeStore.openTake(widget.takeId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    // The next screen must not inherit this count.
    restaurantStockTakeStore.closeTake();
    super.dispose();
  }

  bool get _isEditable =>
      restaurantStockTakeStore.currentTake?.isEditable ?? false;

  // ==================== COUNTING ====================

  /// Raw-material / semi-finished, inventory-tracked items matching the
  /// search box, excluding ones already counted — a counted line is edited
  /// in the list below, not added again.
  List<Items> get _searchResults {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final counted =
        restaurantStockTakeStore.currentItems.map((i) => i.itemId).toSet();

    return itemStore.items.where((item) {
      if (!item.trackInventory) return false;
      if (!(item.isRawMaterial || item.isSemiFinished)) return false;
      if (counted.contains(item.id)) return false;
      return item.name.toLowerCase().contains(query);
    }).take(20).toList();
  }

  String _unitOf(Items item) =>
      item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');

  /// Asks for the counted quantity. Pre-filled with the existing count when
  /// re-counting, and left blank on a first count so the system figure is
  /// never accepted by accident — that would record a false zero-variance
  /// line.
  Future<void> _promptCount(Items item) async {
    final existing = restaurantStockTakeStore.currentItems
        .where((i) => i.itemId == item.id)
        .firstOrNull;

    final counted = await showDialog<double>(
      context: context,
      builder: (_) => _CountEntryDialog(
        itemName: item.name,
        unit: _unitOf(item),
        allowDecimal: item.isSoldByWeight,
        systemQty: item.stockQuantity,
        initialCount: existing?.countedQty,
      ),
    );

    if (counted == null || !mounted) return;

    final ok = await restaurantStockTakeStore.countItem(
      item: item,
      countedQty: counted,
    );

    if (!mounted) return;
    if (ok) {
      _searchController.clear();
      setState(() {});
    } else {
      NotificationService.instance
          .showError(restaurantStockTakeStore.errorMessage ?? 'Count failed.');
    }
  }

  Future<void> _removeLine(RestaurantStockTakeItemModel line) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Remove line?',
      message: '${line.itemName ?? 'This line'} will be dropped from the '
          'count. Stock is not affected.',
      confirmLabel: 'Remove',
      accent: AppColors.danger,
    );
    if (!confirmed) return;

    final ok = await restaurantStockTakeStore.removeLine(line.takeItemId);
    if (!mounted) return;
    if (!ok) {
      NotificationService.instance
          .showError(restaurantStockTakeStore.errorMessage ?? 'Could not remove line.');
    }
  }

  // ==================== COMMIT ====================

  Future<void> _apply() async {
    if (restaurantStockTakeStore.varianceLineCount == 0) {
      NotificationService.instance.showError(
        'Every counted line matches the system — nothing to apply.',
      );
      return;
    }

    final choice = await _CommitDialog.show(
      context,
      varianceLines: restaurantStockTakeStore.varianceLineCount,
      shortageQty: restaurantStockTakeStore.shortageQty,
      excessQty: restaurantStockTakeStore.excessQty,
      netValue: restaurantStockTakeStore.netVarianceValue,
    );
    if (choice == null || !mounted) return;

    final result = await restaurantStockTakeStore.commit(
      shortageReason: choice.reason,
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
    var message = '${result.appliedLines} lines applied ($sign$net units)';
    if (result.isPartial) {
      message += ' - ${result.failedLines.length} could not be applied';
    }
    NotificationService.instance.showSuccess(message);

    if (result.isPartial) await _showFailures(result.failedLines);
  }

  /// Names the lines that did not apply. A silent partial commit would leave
  /// a kitchen believing its count landed in full.
  Future<void> _showFailures(List<String> failed) async {
    await showAppErrorDialog(
      context: context,
      title: 'Some lines were not applied',
      errors: failed,
      message: 'Their stock moved after they were counted, or the item no '
          'longer exists. Recount these in a new stock take.',
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final take = restaurantStockTakeStore.currentTake;

        return Scaffold(
          backgroundColor: AppColors.surfaceLight,
          appBar: buildPrimaryAppBar(title: take?.takeNumber ?? 'Stock Take'),
          body: SafeArea(
            child: MoneyScope(
              child: restaurantStockTakeStore.isLoading && take == null
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
    final take = restaurantStockTakeStore.currentTake!;
    final net = restaurantStockTakeStore.netVarianceQty;

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
              _statusChip(context, take),
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
                  '${restaurantStockTakeStore.countedLineCount}',
                  AppColors.textPrimary),
              _metric(context, 'Variances',
                  '${restaurantStockTakeStore.varianceLineCount}',
                  AppColors.warning),
              _metric(
                context,
                'Net Qty',
                net == 0 ? '0' : (net > 0 ? '+$net' : '$net'),
                net == 0
                    ? AppColors.textSecondary
                    : (net > 0 ? AppColors.success : AppColors.danger),
              ),
              _metric(
                context,
                'Value',
                formatMoney(restaurantStockTakeStore.netVarianceValue),
                restaurantStockTakeStore.netVarianceValue < 0
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, RestaurantStockTakeModel take) {
    final color = take.isCompleted
        ? AppColors.success
        : (take.isCancelled ? AppColors.textSecondary : AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        take.statusDisplay,
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
        hint: 'Search raw material / semi-finished item to count...',
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
          final item = results[i];
          return ListTile(
            dense: true,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _typeBadge(item),
              ],
            ),
            subtitle: Text(
              'System: ${item.stockQuantity} ${_unitOf(item)}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.primary),
            onTap: () => _promptCount(item),
          );
        },
      ),
    );
  }

  Widget _typeBadge(Items item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.isRawMaterial ? 'Raw' : 'Semi',
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.info,
        ),
      ),
    );
  }

  Widget _buildLines(BuildContext context) {
    final lines = restaurantStockTakeStore.currentItems;

    if (lines.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_outlined,
        title: 'Nothing counted yet',
        message: _isEditable
            ? 'Search above to record what you counted. Stock does not '
                'move until you apply.'
            : 'This stock take has no lines.',
      );
    }

    return ListView.builder(
      padding: AppResponsive.padding(context),
      itemCount: lines.length,
      itemBuilder: (context, i) => _buildLineCard(context, lines[i]),
    );
  }

  Widget _buildLineCard(BuildContext context, RestaurantStockTakeItemModel line) {
    final variance = line.variance;
    final color = variance == 0
        ? AppColors.textSecondary
        : (variance > 0 ? AppColors.success : AppColors.danger);
    final item = itemStore.getItemById(line.itemId);
    final unit = item != null ? _unitOf(item) : '';

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
                child: Text(
                  line.itemName ?? 'Unknown item',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_isEditable)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: AppColors.textSecondary),
                  color: AppColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'recount') {
                      if (item != null) _promptCount(item);
                    } else if (value == 'remove') {
                      _removeLine(line);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'recount', child: Text('Recount')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            children: [
              _lineStat(context, 'System', '${line.systemQty} $unit',
                  AppColors.textSecondary),
              _lineStat(context, 'Counted', '${line.countedQty} $unit',
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
        final variances = restaurantStockTakeStore.varianceLineCount;
        final committing = restaurantStockTakeStore.isCommitting;

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
/// The system figure is displayed but the field starts blank on a first
/// count: pre-filling it would let a distracted user accept the system
/// number and record a false "counted, no variance" line, which is worse
/// than not counting the item at all.
class _CountEntryDialog extends StatefulWidget {
  final String itemName;
  final String unit;
  final bool allowDecimal;
  final double systemQty;
  final double? initialCount;

  const _CountEntryDialog({
    required this.itemName,
    required this.unit,
    required this.allowDecimal,
    required this.systemQty,
    this.initialCount,
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
          : (widget.initialCount == widget.initialCount!.roundToDouble()
              ? widget.initialCount!.toStringAsFixed(0)
              : widget.initialCount!.toString()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _counted => double.tryParse(_controller.text.trim());

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
      subtitle: widget.itemName,
      accent: AppColors.primary,
      icon: Icons.inventory_2_outlined,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System says ${widget.systemQty} ${widget.unit}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _controller,
              label: 'Counted (${widget.unit})',
              hint: 'Enter what you counted',
              icon: Icons.pin_outlined,
              required: true,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                  decimal: widget.allowDecimal),
              inputFormatters: widget.allowDecimal
                  ? [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,3}')),
                    ]
                  : [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Required';
                final parsed = double.tryParse(text);
                if (parsed == null) return 'Enter a number';
                if (parsed < 0) return 'Cannot be negative';
                return null;
              },
            ),
            if (variance != null && variance != 0) ...[
              SizedBox(height: AppResponsive.smallSpacing(context)),
              Text(
                variance > 0
                    ? '$variance more than the system expects'
                    : '${variance.abs()} missing against the system',
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

/// What the user chose at the commit prompt.
class _CommitChoice {
  final String reason;
  final String? note;

  const _CommitChoice({required this.reason, this.note});
}

/// Confirms a stock take before it moves any stock, and picks the reason
/// stamped on every *shortage* line.
///
/// **One reason for the whole take, not one per line.** Staff counting a
/// storeroom know why the room is off; they rarely know why each individual
/// item is. Asking per line would produce either a wall of dropdowns or, more
/// likely, the same value repeated without thought.
///
/// Excess lines (counted more than the system expects) always apply as
/// 'Stock correction' regardless of this choice — finding extra stock is
/// never a loss. See `RestaurantStockTakeStore.commit`.
class _CommitDialog extends StatefulWidget {
  final int varianceLines;
  final double shortageQty;
  final double excessQty;
  final double netValue;

  const _CommitDialog({
    required this.varianceLines,
    required this.shortageQty,
    required this.excessQty,
    required this.netValue,
  });

  static Future<_CommitChoice?> show(
    BuildContext context, {
    required int varianceLines,
    required double shortageQty,
    required double excessQty,
    required double netValue,
  }) {
    return showDialog<_CommitChoice>(
      context: context,
      builder: (_) => _CommitDialog(
        varianceLines: varianceLines,
        shortageQty: shortageQty,
        excessQty: excessQty,
        netValue: netValue,
      ),
    );
  }

  @override
  State<_CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends State<_CommitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  /// Defaults to the honest answer: a count found a discrepancy, and unless
  /// the shop says otherwise that is a bookkeeping correction rather than a
  /// loss.
  String _reason = _stockCorrectionReason;

  static final List<String> _reasons = [
    _stockCorrectionReason,
    ...StockAdjustService.lossReasons,
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();
    Navigator.pop(
      context,
      _CommitChoice(reason: _reason, note: note.isEmpty ? null : note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksLoss =
        _reason != _stockCorrectionReason && widget.shortageQty > 0;

    return AppDialogShell(
      title: 'Apply Count',
      subtitle: '${widget.varianceLines} line'
          '${widget.varianceLines == 1 ? '' : 's'} will adjust stock',
      accent: AppColors.primary,
      icon: Icons.playlist_add_check_rounded,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummary(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildReasonDropdown(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _noteController,
              label: 'Note (Optional)',
              hint: 'Added to every adjustment from this count',
              icon: Icons.notes_outlined,
              maxLines: 2,
              minLines: 2,
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _buildConsequence(context, booksLoss),
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(label: 'Apply', onPressed: _submit),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _stat(
            context,
            'Missing',
            '${widget.shortageQty}',
            widget.shortageQty > 0
                ? AppColors.danger
                : AppColors.textSecondary,
          ),
          _stat(
            context,
            'Extra',
            '${widget.excessQty}',
            widget.excessQty > 0 ? AppColors.success : AppColors.textSecondary,
          ),
          _stat(
            context,
            'Net Value',
            formatMoney(widget.netValue),
            widget.netValue < 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _stat(
      BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
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

  Widget _buildReasonDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _reason,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Reason for shortages *',
        labelStyle: GoogleFonts.poppins(
          fontSize: AppResponsive.smallFontSize(context),
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(
          Icons.help_outline_rounded,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        color: AppColors.textPrimary,
      ),
      dropdownColor: AppColors.white,
      items: _reasons
          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _reason = value);
      },
    );
  }

  /// States plainly what Apply is about to do, including that it cannot be
  /// undone — the adjustments become facts in the movement log.
  Widget _buildConsequence(BuildContext context, bool booksLoss) {
    final color = booksLoss ? AppColors.danger : AppColors.textSecondary;
    final text = booksLoss
        ? 'Shortages will be recorded as inventory losses, so their cost '
            'reaches your food-cost and wastage reports. Extra stock found is '
            'never booked as a loss. This cannot be undone — correct a '
            'mistake with a new stock take.'
        : 'Stock will be corrected without recording a loss. This cannot be '
            'undone — correct a mistake with a new stock take.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            booksLoss
                ? Icons.trending_down_rounded
                : Icons.info_outline_rounded,
            size: AppResponsive.smallIconSize(context),
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
