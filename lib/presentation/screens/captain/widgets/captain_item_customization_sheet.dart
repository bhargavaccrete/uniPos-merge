import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../util/color.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

/// Captain item customization sheet — a faithful CLONE of the POS
/// `ItemOptionsDialog` (+ `WeightItemDialog`) logic, adapted from model objects
/// to the JSON Maps the captain receives over HTTP. Builds and returns a
/// finished [CartItem] so price math lives in exactly one place (no captain↔POS
/// total mismatch). Keep this in sync with item_options_dialog.dart.
///
/// Expected Map shapes (from /captain/menu):
///   item: {id,name,price,taxRate,trackInventory,allowOrderWhenOutOfStock,
///          stockQuantity,isSoldByWeight,unit,extraConstraints:{extraId:{min,max}},
///          defaultChoiceOptionIds:[optId]}
///   variants (resolved): [{id,name,price,stockQuantity,trackInventory}]
///   choices: [{id,name,allowMultipleSelection,choiceOption:[{id,name}]}]
///   extras:  [{Id,Ename,minimum,maximum,topping:[{name,price,isContainSize,variantPrices:{vId:price}}]}]
class CaptainItemCustomizationSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> variants;
  final List<Map<String, dynamic>> choices;
  final List<Map<String, dynamic>> extras;
  final String? categoryName;
  final void Function(CartItem) onAdd;

  const CaptainItemCustomizationSheet({
    super.key,
    required this.item,
    required this.variants,
    required this.choices,
    required this.extras,
    required this.categoryName,
    required this.onAdd,
  });

  @override
  State<CaptainItemCustomizationSheet> createState() =>
      _CaptainItemCustomizationSheetState();
}

class _CaptainItemCustomizationSheetState
    extends State<CaptainItemCustomizationSheet> {
  Map<String, dynamic>? _selectedVariant;
  // choiceId → selected option names
  final Map<String, Set<String>> _selectedChoiceOptions = {};
  // '$groupId::$toppingName' → quantity
  final Map<String, int> _extraQuantities = {};
  final TextEditingController _instructionController = TextEditingController();

  // Non-weight qty
  int _quantity = 1;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final FocusNode _qtyFocus = FocusNode();

  // Weight items
  bool get _isWeight => widget.item['isSoldByWeight'] == true;
  final TextEditingController _weightController = TextEditingController();
  double _weight = 0;

  bool _variantOutOfStock(Map<String, dynamic> v) {
    final track = v['trackInventory'] as bool? ?? false;
    if (!track) return false;
    return ((v['stockQuantity'] as num?)?.toDouble() ?? 0.0) <= 0;
  }

  @override
  void initState() {
    super.initState();
    // Pre-select first in-stock variant (mirrors _prepareVariants).
    if (widget.variants.isNotEmpty) {
      _selectedVariant = widget.variants.firstWhere(
        (v) => !_variantOutOfStock(v),
        orElse: () => widget.variants.first,
      );
    }
    // Pre-select this item's default choice options (mirrors _prepareChoices).
    final defaults = List<String>.from(widget.item['defaultChoiceOptionIds'] ?? const []);
    if (defaults.isNotEmpty) {
      for (final c in widget.choices) {
        final id = c['id'] as String;
        final opts = List<Map<String, dynamic>>.from(c['choiceOption'] as List? ?? []);
        for (final o in opts) {
          if (defaults.contains(o['id'])) {
            (_selectedChoiceOptions[id] ??= {}).add(o['name'] as String? ?? '');
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _instructionController.dispose();
    _qtyController.dispose();
    _qtyFocus.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ── Helpers cloned from item_options_dialog ────────────────────────────────

  String _extraKey(String groupId, String name) => '$groupId::$name';

  double _toppingPrice(Map<String, dynamic> t) {
    final base = (t['price'] as num?)?.toDouble() ?? 0.0;
    if (_selectedVariant != null && t['isContainSize'] == true && t['variantPrices'] != null) {
      final vp = Map<String, dynamic>.from(t['variantPrices'] as Map);
      final p = (vp[_selectedVariant!['id']] as num?)?.toDouble();
      if (p != null) return p;
    }
    return base;
  }

  // Toppings visible for the current variant (size-bound ones need a price>0
  // for the selected variant) — mirrors _buildExtraSection's filter.
  List<Map<String, dynamic>> _visibleToppings(Map<String, dynamic> group) {
    final toppings = List<Map<String, dynamic>>.from(group['topping'] as List? ?? []);
    return toppings.where((t) {
      if (t['isContainSize'] == true) {
        if (_selectedVariant != null && t['variantPrices'] != null) {
          final vp = Map<String, dynamic>.from(t['variantPrices'] as Map);
          final p = (vp[_selectedVariant!['id']] as num?)?.toDouble() ?? 0.0;
          return p > 0;
        }
        return false;
      }
      return true;
    }).toList();
  }

  int _groupCount(Map<String, dynamic> group) {
    final id = group['Id'] as String? ?? '';
    int count = 0;
    for (final t in (group['topping'] as List? ?? [])) {
      count += _extraQuantities[_extraKey(id, t['name'] as String? ?? '')] ?? 0;
    }
    return count;
  }

  ({int min, int max}) _constraints(Map<String, dynamic> group) {
    final id = group['Id'] as String? ?? '';
    final perItem = (widget.item['extraConstraints'] as Map?)?[id];
    int? min, max;
    if (perItem is Map) {
      min = (perItem['min'] as num?)?.toInt();
      max = (perItem['max'] as num?)?.toInt();
    }
    min ??= (group['minimum'] as num?)?.toInt() ?? 0;
    max ??= (group['maximum'] as num?)?.toInt() ?? 0;
    return (min: min, max: max);
  }

  List<String> _unmetRequirements() {
    final unmet = <String>[];
    for (final g in widget.extras) {
      final c = _constraints(g);
      if (c.min > 0 && _groupCount(g) < c.min) {
        unmet.add('${g['Ename']} (min ${c.min})');
      }
    }
    return unmet;
  }

  // Per-unit price (mirrors _recalculateTotal; ×weight for weight items).
  double get _unitPrice {
    double base = _selectedVariant != null
        ? (_selectedVariant!['price'] as num?)?.toDouble() ?? 0.0
        : (widget.item['price'] as num?)?.toDouble() ?? 0.0;
    if (_isWeight) base = base * (_weight <= 0 ? 0 : _weight);
    double extras = 0;
    for (final g in widget.extras) {
      final id = g['Id'] as String? ?? '';
      for (final t in (g['topping'] as List? ?? [])) {
        final q = _extraQuantities[_extraKey(id, t['name'] as String? ?? '')] ?? 0;
        if (q > 0) extras += _toppingPrice(Map<String, dynamic>.from(t)) * q;
      }
    }
    return base + extras;
  }

  String _formatWeightDisplay(double weight, String? unit) {
    final unitStr = unit?.toUpperCase() ?? '';
    if (unitStr.contains('GM') || unitStr.contains('GRAM')) {
      return weight == weight.toInt()
          ? '${weight.toInt()}$unitStr'
          : '${weight.toStringAsFixed(1)}$unitStr';
    }
    if (unitStr.contains('KG') || unitStr.contains('KILOGRAM')) {
      if (weight < 1) {
        final grams = weight * 1000;
        return grams == grams.toInt()
            ? '${grams.toInt()}GM'
            : '${grams.toStringAsFixed(1)}GM';
      }
      return '${weight.toStringAsFixed(weight == weight.toInt() ? 0 : 2)}$unitStr';
    }
    return weight == weight.toInt()
        ? '${weight.toInt()}$unitStr'
        : '${weight.toStringAsFixed(2)}$unitStr';
  }

  void _onVariantSelected(Map<String, dynamic> v) {
    setState(() {
      _selectedVariant = v;
      // Drop selected size-bound toppings unavailable for the new variant.
      for (final g in widget.extras) {
        final id = g['Id'] as String? ?? '';
        for (final t in (g['topping'] as List? ?? [])) {
          if (t['isContainSize'] == true) {
            final vp = t['variantPrices'] == null
                ? const {}
                : Map<String, dynamic>.from(t['variantPrices'] as Map);
            if (!vp.containsKey(v['id'])) {
              _extraQuantities[_extraKey(id, t['name'] as String? ?? '')] = 0;
            }
          }
        }
      }
    });
  }

  void _submit() {
    final unmet = _unmetRequirements();
    if (unmet.isNotEmpty) {
      _showRequiredDialog(unmet);
      return;
    }
    if (_isWeight && _weight <= 0) {
      _showRequiredDialog(['Enter a valid weight']);
      return;
    }

    // Build choiceNames + extras list (mirror _confirmAndAddItem).
    final choiceNames = _selectedChoiceOptions.values.expand((s) => s).toSet().toList();

    final extrasList = <Map<String, dynamic>>[];
    for (final g in widget.extras) {
      final id = g['Id'] as String? ?? '';
      final ename = g['Ename'] as String? ?? '';
      for (final t in (g['topping'] as List? ?? [])) {
        final name = t['name'] as String? ?? '';
        final q = _extraQuantities[_extraKey(id, name)] ?? 0;
        if (q <= 0) continue;
        extrasList.add({
          'name': name,
          'displayName': ename.isNotEmpty ? '$ename - $name' : name,
          'price': _toppingPrice(Map<String, dynamic>.from(t)),
          'categoryName': ename,
          'categoryId': id,
          'quantity': q,
        });
      }
    }

    final cart = CartItem(
      id: const Uuid().v4(),
      productId: widget.item['id'] as String,
      title: widget.item['name'] as String? ?? '',
      price: _unitPrice,
      quantity: _isWeight ? 1 : _quantity,
      categoryName: widget.categoryName,
      variantName: _selectedVariant?['name'] as String?,
      variantPrice: (_selectedVariant?['price'] as num?)?.toDouble(),
      choiceNames: choiceNames.isEmpty ? null : choiceNames,
      taxRate: (widget.item['taxRate'] as num?)?.toDouble(),
      weightDisplay:
          _isWeight ? _formatWeightDisplay(_weight, widget.item['unit'] as String?) : null,
      instruction: _instructionController.text.trim().isEmpty
          ? null
          : _instructionController.text.trim(),
      extras: extrasList.isEmpty ? null : extrasList,
      isStockManaged: widget.item['trackInventory'] as bool? ?? false,
    );

    widget.onAdd(cart);
    Navigator.pop(context);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyHelper.currentSymbol;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item['name'] as String? ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 19, fontWeight: FontWeight.w700)),
                        if (widget.categoryName != null)
                          Text(widget.categoryName!,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.surfaceMedium,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  if (_isWeight) _buildWeightSection(cur),
                  if (widget.variants.isNotEmpty) _buildVariantSection(cur),
                  ...widget.choices.map(_buildChoiceGroup),
                  ...widget.extras.map((g) => _buildExtraGroup(g, cur)),
                  _sectionHeader('Special Instruction (optional)', Icons.edit_note_rounded),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instructionController,
                    maxLines: 2,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Less spicy, no onions...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.divider)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.divider)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomBar(cur),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(String cur) {
    final total = _unitPrice * (_isWeight ? 1 : _quantity);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text('$cur${DecimalSettings.formatAmount(total)}',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primary)),
            const SizedBox(width: 12),
            // Qty stepper (hidden for weight items — qty is always 1).
            if (!_isWeight)
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (_quantity > 1) {
                          setState(() {
                            _quantity--;
                            _qtyController.text = '$_quantity';
                          });
                        }
                      },
                      child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Icon(Icons.remove, size: 18)),
                    ),
                    SizedBox(
                      width: 40,
                      child: TextField(
                        controller: _qtyController,
                        focusNode: _qtyFocus,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8)),
                        onChanged: (v) {
                          final n = int.tryParse(v.trim());
                          if (n != null && n >= 1) setState(() => _quantity = n);
                        },
                        onTapOutside: (_) {
                          final n = int.tryParse(_qtyController.text.trim());
                          setState(() => _quantity = (n == null || n < 1) ? 1 : n);
                          _qtyController.text = '$_quantity';
                          _qtyFocus.unfocus();
                        },
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        _quantity++;
                        _qtyController.text = '$_quantity';
                      }),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Icon(Icons.add, size: 18, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            if (!_isWeight) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Add to Cart',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSection(String cur) {
    final unit = widget.item['unit'] as String? ?? 'kg';
    final perUnit = (widget.item['price'] as num?)?.toDouble() ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Weight ($unit)', Icons.scale_rounded),
        const SizedBox(height: 10),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter weight in $unit',
            suffixText: unit,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          onChanged: (v) => setState(() => _weight = double.tryParse(v.trim()) ?? 0),
        ),
        const SizedBox(height: 6),
        Text('Rate: $cur${DecimalSettings.formatAmount(perUnit)} / $unit',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildVariantSection(String cur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Select Size', Icons.straighten_rounded),
        const SizedBox(height: 10),
        ...widget.variants.map((v) {
          final selected = _selectedVariant?['id'] == v['id'];
          final oos = _variantOutOfStock(v);
          final price = (v['price'] as num?)?.toDouble() ?? 0.0;
          return _optionTile(
            selected: selected,
            radio: true,
            disabled: oos,
            title: v['name'] as String? ?? '',
            subtitle: oos ? 'Out of Stock' : null,
            trailing: '$cur${DecimalSettings.formatAmount(price)}',
            onTap: oos ? null : () => _onVariantSelected(v),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildChoiceGroup(Map<String, dynamic> group) {
    final id = group['id'] as String;
    final multi = group['allowMultipleSelection'] as bool? ?? false;
    final opts = List<Map<String, dynamic>>.from(group['choiceOption'] as List? ?? []);
    final selected = _selectedChoiceOptions[id] ??= {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(group['name'] as String? ?? 'Choice', Icons.checklist_rounded),
        const SizedBox(height: 10),
        ...opts.map((o) {
          final name = o['name'] as String? ?? '';
          final isSel = selected.contains(name);
          return _optionTile(
            selected: isSel,
            radio: !multi,
            title: name,
            onTap: () => setState(() {
              if (multi) {
                isSel ? selected.remove(name) : selected.add(name);
              } else {
                selected.clear();
                if (!isSel) selected.add(name);
              }
            }),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildExtraGroup(Map<String, dynamic> group, String cur) {
    final c = _constraints(group);
    final id = group['Id'] as String? ?? '';
    final visible = _visibleToppings(group);
    if (visible.isEmpty) return const SizedBox.shrink();
    final count = _groupCount(group);
    final atMax = c.max > 0 && count >= c.max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          group['Ename'] as String? ?? 'Extras',
          Icons.add_circle_outline,
          badge: (c.min > 0 || c.max > 0)
              ? '${c.min > 0 ? 'Min ${c.min}' : ''}${c.min > 0 && c.max > 0 ? ' · ' : ''}${c.max > 0 ? 'Max ${c.max}' : ''}'
              : null,
        ),
        const SizedBox(height: 10),
        if (atMax)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Maximum selection reached',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500)),
          ),
        ...visible.map((t) {
          final name = t['name'] as String? ?? '';
          final qty = _extraQuantities[_extraKey(id, name)] ?? 0;
          final price = _toppingPrice(Map<String, dynamic>.from(t));
          final canInc = c.max == 0 || count < c.max;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: qty > 0 ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: qty > 0 ? AppColors.primary : Colors.grey.shade300,
                  width: qty > 0 ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: 13.5, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('$cur${DecimalSettings.formatAmount(price)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                _stepBtn(Icons.remove, enabled: qty > 0, onTap: () {
                  setState(() => _extraQuantities[_extraKey(id, name)] = qty - 1);
                }),
                Container(
                    width: 36,
                    alignment: Alignment.center,
                    child: Text('$qty',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600))),
                _stepBtn(Icons.add, enabled: canInc, onTap: () {
                  setState(() => _extraQuantities[_extraKey(id, name)] = qty + 1);
                }, primary: true),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _stepBtn(IconData icon,
      {required bool enabled, required VoidCallback onTap, bool primary = false}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: !enabled
              ? AppColors.surfaceMedium
              : (primary ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: !enabled
                ? AppColors.textSecondary
                : (primary ? Colors.white : AppColors.primary)),
      ),
    );
  }

  Widget _optionTile({
    required bool selected,
    required bool radio,
    required String title,
    String? subtitle,
    String? trailing,
    bool disabled = false,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.primary : Colors.grey.shade300,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: radio ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: radio ? null : BorderRadius.circular(4),
                  border: Border.all(
                      color: selected ? AppColors.primary : Colors.grey.shade400, width: 2),
                  color: selected ? AppColors.primary : Colors.transparent,
                ),
                child: selected
                    ? Icon(radio ? Icons.circle : Icons.check,
                        size: radio ? 10 : 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 13.5, fontWeight: FontWeight.w500)),
                    if (subtitle != null)
                      Text(subtitle,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.danger)),
                  ],
                ),
              ),
              if (trailing != null)
                Text(trailing,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, {String? badge}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          if (badge != null)
            Text(badge,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.primary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  void _showRequiredDialog(List<String> unmet) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.warning_rounded, color: Colors.orange, size: 32),
              ),
              const SizedBox(height: 14),
              Text('Selection Required',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...unmet.map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.circle, size: 6, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(u,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w500))),
                    ]),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('OK',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
