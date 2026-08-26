import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/constants/label_layouts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../../domain/services/common/notification_service.dart';
import '../../../../domain/services/retail/barcode_generator_service.dart';
import '../../../../domain/services/retail/label_pdf_service.dart';
import '../../../../domain/services/retail/print_service.dart';

/// Pick variants, set how many labels each needs, then preview or print.
///
/// **One sheet serves both entry points.** Variant ⋮ passes a single variant
/// (pre-selected, checkbox hidden); Product ⋮ passes them all with nothing
/// selected. Two widgets would duplicate the copies field, the stock fill, the
/// total and the preview — and then drift.
///
/// Admin-only; the caller must HIDE its menu entry when
/// `BarcodeLabelPermission.canPrint` is false rather than showing and refusing.
Future<void> showPrintLabelsSheet({
  required BuildContext context,
  required ProductModel product,
  required List<VarianteModel> variants,
  required String Function(double) money,
  bool preselectAll = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PrintLabelsSheet(
      product: product,
      variants: variants,
      money: money,
      preselectAll: preselectAll,
    ),
  );
}

class PrintLabelsSheet extends StatefulWidget {
  final ProductModel product;
  final List<VarianteModel> variants;

  /// Money formatter from the caller's MoneyScope, so the sheet cannot render a
  /// different currency symbol from the screen behind it.
  final String Function(double) money;

  /// True for the single-variant entry point, where selecting is meaningless.
  final bool preselectAll;

  const PrintLabelsSheet({
    super.key,
    required this.product,
    required this.variants,
    required this.money,
    this.preselectAll = false,
  });

  @override
  State<PrintLabelsSheet> createState() => _PrintLabelsSheetState();
}

class _PrintLabelsSheetState extends State<PrintLabelsSheet> {
  static const _layout = kLabelLayout65Up;

  /// Working copies, so a generated barcode shows immediately without forcing
  /// the caller to rebuild.
  late List<VarianteModel> _variants;

  final _selected = <String>{};
  final _counts = <String, int>{};
  final _controllers = <String, TextEditingController>{};

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _variants = List.of(widget.variants);
    for (final v in _variants) {
      _controllers[v.varianteId] = TextEditingController(text: '0');
      _counts[v.varianteId] = 0;
      // The single-variant entry point starts ready to print one label.
      if (widget.preselectAll && _hasBarcode(v)) {
        _selected.add(v.varianteId);
        _counts[v.varianteId] = 1;
        _controllers[v.varianteId]!.text = '1';
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _hasBarcode(VarianteModel v) => (v.barcode?.trim() ?? '').isNotEmpty;

  int get _totalLabels => _selected.fold<int>(
        0,
        (sum, id) => sum + (_counts[id] ?? 0),
      );

  int get _pages => _layout.pagesFor(_totalLabels);

  String _descriptorOf(VarianteModel v) =>
      v.hasAttributes ? v.variantDescription : '';

  // ── Actions ────────────────────────────────────────────────────────────────

  void _toggle(VarianteModel v, bool? on) {
    // A variant with no barcode cannot be printed, so it cannot be selected.
    // Generating one is an explicit act — printing never writes a barcode.
    if (!_hasBarcode(v)) return;
    setState(() {
      final id = v.varianteId;
      if (on ?? false) {
        _selected.add(id);
        if ((_counts[id] ?? 0) == 0) {
          _counts[id] = 1;
          _controllers[id]!.text = '1';
        }
      } else {
        _selected.remove(id);
        _counts[id] = 0;
        _controllers[id]!.text = '0';
      }
    });
  }

  void _setCount(VarianteModel v, String raw) {
    final id = v.varianteId;
    final parsed = int.tryParse(raw.trim()) ?? 0;
    setState(() {
      _counts[id] = parsed;
      // Typing a number is itself an intent to print, so it selects the row —
      // and zeroing it deselects, so the total always matches what is ticked.
      if (parsed > 0 && _hasBarcode(v)) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _fillFromStock(VarianteModel v) {
    if (!_hasBarcode(v)) return;
    final id = v.varianteId;
    setState(() {
      _counts[id] = v.stockQty.round();
      _controllers[id]!.text = v.stockQty.round().toString();
      if (v.stockQty > 0) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _fillAllFromStock() {
    for (final v in _variants) {
      if (_hasBarcode(v)) _fillFromStock(v);
    }
  }

  /// Mint a barcode for one variant. The ONLY write path in this sheet.
  Future<void> _generate(VarianteModel v) async {
    setState(() => _busy = true);
    try {
      final value = await barcodeGeneratorService.next(
        // Ask the box, not the in-memory list.
        isTaken: (code) => variantRepository.isBarcodeTaken(code),
      );

      final updated = v.copyWith(barcode: value);
      final result = await productStore.updateVariant(updated);
      if (!result.success) {
        if (mounted) {
          NotificationService.instance
              .showError(result.errorMessage ?? 'Could not save the barcode.');
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        final i = _variants.indexWhere((x) => x.varianteId == v.varianteId);
        if (i != -1) _variants[i] = updated;
      });
      NotificationService.instance.showSuccess('Barcode $value assigned');
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Could not generate: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<LabelSpec> _buildLabels() {
    final requests = <(LabelSpec, int)>[];
    for (final v in _variants) {
      if (!_selected.contains(v.varianteId)) continue;
      final copies = _counts[v.varianteId] ?? 0;
      if (copies <= 0) continue;
      requests.add((
        LabelSpec(
          productName: widget.product.productName,
          variantDescriptor: _descriptorOf(v),
          barcode: v.barcode?.trim() ?? '',
          mrp: v.mrp,
          sellingPrice: v.sellingPrice,
          brand: widget.product.brandName,
          sku: v.sku,
          hsnCode: v.hsnCode ?? widget.product.hsnCode,
        ),
        copies,
      ));
    }
    return LabelPdfService.expand(requests);
  }

  Future<void> _preview() async {
    final labels = _buildLabels();
    if (labels.isEmpty) {
      NotificationService.instance.showWarning('Select at least one variant.');
      return;
    }
    await PrintService().showLabelPreview(context: context, labels: labels);
  }

  Future<void> _print() async {
    final labels = _buildLabels();
    if (labels.isEmpty) {
      NotificationService.instance.showWarning('Select at least one variant.');
      return;
    }
    setState(() => _busy = true);
    try {
      await PrintService().printLabels(labels);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) NotificationService.instance.showError('Print failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final printable = _variants.where(_hasBarcode).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _grabHandle(),
          _header(context, printable),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.mediumSpacing(context),
                vertical: AppResponsive.smallSpacing(context),
              ),
              itemCount: _variants.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) => _row(context, _variants[i]),
            ),
          ),
          const Divider(height: 1),
          _footer(context),
        ],
      ),
    );
  }

  Widget _grabHandle() => Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(BuildContext context, int printable) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.mediumSpacing(context),
        0,
        AppResponsive.mediumSpacing(context),
        AppResponsive.smallSpacing(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.preselectAll ? 'Print Label' : 'Print Labels',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue<double>(context,
                        mobile: 17, tablet: 19, desktop: 20),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.product.productName,
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
          if (!widget.preselectAll && printable > 1)
            TextButton.icon(
              onPressed: _busy ? null : _fillAllFromStock,
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: Text(
                'Fill from stock',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, VarianteModel v) {
    final id = v.varianteId;
    final has = _hasBarcode(v);
    final descriptor = _descriptorOf(v);
    final label = descriptor.isEmpty ? 'Default' : descriptor;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: Row(
        children: [
          if (!widget.preselectAll)
            SizedBox(
              width: 36,
              child: Checkbox(
                value: _selected.contains(id),
                onChanged: has && !_busy ? (on) => _toggle(v, on) : null,
                activeColor: AppColors.primary,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: has ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                if (has)
                  Text(
                    '${v.barcode!.trim()}   ·   Stock ${v.stockQty}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Text(
                    'No barcode  ·  Stock ${v.stockQty}',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!has)
            TextButton(
              onPressed: _busy ? null : () => _generate(v),
              child: Text(
                'Generate',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else ...[
            if (!widget.preselectAll)
              IconButton(
                tooltip: 'Use stock quantity',
                onPressed: _busy ? null : () => _fillFromStock(v),
                icon: Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            SizedBox(
              width: 62,
              child: AppTextField(
                controller: _controllers[id],
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                textAlign: TextAlign.center,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                onChanged: (raw) => _setCount(v, raw),
                autovalidateMode: AutovalidateMode.disabled,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final total = _totalLabels;
    final pages = _pages;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.mediumSpacing(context),
        AppResponsive.smallSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.mediumSpacing(context) + 8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  total == 0
                      ? 'No labels selected'
                      : 'Total labels: $total',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Page count is shown because 66 labels costs the same as 130 —
              // a whole second sheet — and that should be visible BEFORE
              // printing, not after.
              if (total > 0)
                Text(
                  pages == 1
                      ? '1 sheet of ${_layout.perPage}'
                      : '$pages sheets of ${_layout.perPage}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            children: [
              appDialogCancelButton(context, label: 'Close'),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || total == 0 ? null : _preview,
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: Text(
                    'Preview',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: appDialogPrimaryButton(
                  label: _busy ? 'Working...' : 'Print',
                  onPressed: _busy || total == 0 ? () {} : _print,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
