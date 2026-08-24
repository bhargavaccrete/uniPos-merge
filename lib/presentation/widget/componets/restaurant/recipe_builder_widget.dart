import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';

/// Embeddable Recipe (Bill of Materials) builder — reused by the Add/Edit
/// Item screen (wired in a later step) for Semi-Finished and Recipe-Based
/// items. See docs/inventory_recipe_system_plan.md §8.2.
///
/// Emits a [RecipeModel] via [onChanged] every time the yield or an
/// ingredient row changes, or `null` once every ingredient row has been
/// removed (the caller reads `null` as "no recipe yet").
class RecipeBuilderWidget extends StatefulWidget {
  /// The item this recipe belongs to (`RecipeModel.itemId`).
  final String itemId;

  /// Every item in the system — filtered internally to Raw Material /
  /// Semi-Finished items for the ingredient picker.
  final List<Items> allItems;

  /// Existing recipe to edit, if any. Its id is reused on every emit so
  /// saving doesn't orphan the previous row.
  final RecipeModel? initialRecipe;

  final ValueChanged<RecipeModel?> onChanged;

  /// The parent item's selling price — when provided, a live margin %
  /// readout is shown next to the estimated cost.
  final double? sellingPrice;

  const RecipeBuilderWidget({
    super.key,
    required this.itemId,
    required this.allItems,
    this.initialRecipe,
    required this.onChanged,
    this.sellingPrice,
  });

  @override
  State<RecipeBuilderWidget> createState() => _RecipeBuilderWidgetState();
}

class _IngredientRow {
  String ingredientItemId;
  final TextEditingController qtyController;
  final TextEditingController unitController;
  final TextEditingController wastageController;
  final TextEditingController conversionController;
  bool showAdvanced;

  _IngredientRow({
    required this.ingredientItemId,
    required this.qtyController,
    required this.unitController,
    required this.wastageController,
    TextEditingController? conversionController,
    this.showAdvanced = false,
  }) : conversionController = conversionController ?? TextEditingController(text: '1');

  void dispose() {
    qtyController.dispose();
    unitController.dispose();
    wastageController.dispose();
    conversionController.dispose();
  }
}

class _RecipeBuilderWidgetState extends State<RecipeBuilderWidget> {
  late final String _recipeId;
  late final TextEditingController _yieldQtyController;
  late final TextEditingController _yieldUnitController;
  final List<_IngredientRow> _rows = [];
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _recipeId = widget.initialRecipe?.id ?? const Uuid().v4();
    _yieldQtyController = TextEditingController(
      text: _trimNum(widget.initialRecipe?.yieldQty ?? 1.0),
    );
    _yieldUnitController =
        TextEditingController(text: widget.initialRecipe?.yieldUnit ?? '');

    final existing = widget.initialRecipe?.ingredients ?? const [];
    for (final line in existing) {
      _rows.add(_IngredientRow(
        ingredientItemId: line.ingredientItemId,
        qtyController: TextEditingController(text: _trimNum(line.quantity)),
        unitController: TextEditingController(text: line.unit ?? ''),
        wastageController:
            TextEditingController(text: _trimNum(line.wastagePercent)),
        conversionController:
            TextEditingController(text: _trimNum(line.conversionFactor)),
        showAdvanced: line.wastagePercent != 0,
      ));
    }
  }

  @override
  void dispose() {
    _yieldQtyController.dispose();
    _yieldUnitController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  static String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  Map<String, Items> get _itemsById =>
      {for (final i in widget.allItems) i.id: i};

  Items? _ingredientFor(String id) => _itemsById[id];

  /// Whether this row's typed [_IngredientRow.unitController] text differs
  /// from the selected ingredient item's own stock unit — the trigger for
  /// showing the conversion-factor input. Matching (or a blank line unit)
  /// means no conversion is needed, so the input stays hidden.
  bool _needsConversion(_IngredientRow row) {
    final lineUnit = row.unitController.text.trim();
    if (lineUnit.isEmpty) return false;
    final itemUnit = _ingredientFor(row.ingredientItemId)?.unit?.trim() ?? '';
    if (itemUnit.isEmpty) return false;
    return lineUnit.toLowerCase() != itemUnit.toLowerCase();
  }

  double _conversionFactorFor(_IngredientRow row) {
    if (!_needsConversion(row)) return 1.0;
    return double.tryParse(row.conversionController.text.trim()) ?? 1.0;
  }

  double _lineEffectiveQty(_IngredientRow row) {
    final qty = double.tryParse(row.qtyController.text.trim()) ?? 0;
    final wastage = double.tryParse(row.wastageController.text.trim()) ?? 0;
    return qty * _conversionFactorFor(row) * (1 + wastage / 100);
  }

  double _lineCost(_IngredientRow row) {
    final ingredient = _ingredientFor(row.ingredientItemId);
    final cost = ingredient?.lastPurchaseCost ?? 0.0;
    return _lineEffectiveQty(row) * cost;
  }

  double get _totalCost =>
      _rows.fold(0.0, (sum, row) => sum + _lineCost(row));

  void _emit() {
    final ingredients = <RecipeIngredientModel>[];
    for (final row in _rows) {
      if (row.ingredientItemId.isEmpty) continue;
      final qty = double.tryParse(row.qtyController.text.trim()) ?? 0;
      if (qty <= 0) continue;
      ingredients.add(RecipeIngredientModel(
        ingredientItemId: row.ingredientItemId,
        quantity: qty,
        unit: row.unitController.text.trim().isEmpty
            ? null
            : row.unitController.text.trim(),
        wastagePercent: double.tryParse(row.wastageController.text.trim()) ?? 0,
        conversionFactor: _conversionFactorFor(row),
      ));
    }

    if (ingredients.isEmpty) {
      widget.onChanged(null);
      return;
    }

    final yieldQty = double.tryParse(_yieldQtyController.text.trim()) ?? 1.0;
    widget.onChanged(RecipeModel(
      id: _recipeId,
      itemId: widget.itemId,
      yieldQty: yieldQty <= 0 ? 1.0 : yieldQty,
      yieldUnit: _yieldUnitController.text.trim().isEmpty
          ? null
          : _yieldUnitController.text.trim(),
      ingredients: ingredients,
      prepInstructions: widget.initialRecipe?.prepInstructions,
      createdTime: widget.initialRecipe?.createdTime ?? DateTime.now(),
      lastEditedTime: DateTime.now(),
      editedBy: widget.initialRecipe?.editedBy,
      editCount: widget.initialRecipe?.editCount ?? 0,
    ));
  }

  void _onFieldChanged() => setState(_emit);

  Future<void> _addIngredient() async {
    final picked = await _showIngredientPicker();
    if (picked == null) return;
    setState(() {
      _rows.add(_IngredientRow(
        ingredientItemId: picked.id,
        qtyController: TextEditingController(text: '1'),
        unitController: TextEditingController(text: picked.unit ?? ''),
        wastageController: TextEditingController(text: '0'),
      ));
    });
    _emit();
  }

  Future<void> _replaceIngredient(_IngredientRow row) async {
    final picked = await _showIngredientPicker();
    if (picked == null) return;
    setState(() {
      row.ingredientItemId = picked.id;
      if (row.unitController.text.trim().isEmpty) {
        row.unitController.text = picked.unit ?? '';
      }
    });
    _emit();
  }

  void _removeRow(_IngredientRow row) {
    setState(() {
      _rows.remove(row);
      row.dispose();
    });
    _emit();
  }

  Future<Items?> _showIngredientPicker() {
    final candidates = widget.allItems
        .where((i) =>
            (i.isRawMaterial || i.isSemiFinished) && i.id != widget.itemId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return showModalBottomSheet<Items>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IngredientPickerSheet(candidates: candidates),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (_expanded) ...[
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildYieldRow(),
                  const SizedBox(height: 18),
                  _buildIngredientsHeader(),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rows.length,
                    itemBuilder: (context, index) =>
                        _buildIngredientRow(_rows[index]),
                  ),
                  if (_rows.isEmpty) _buildEmptyRowsHint(),
                  const SizedBox(height: 8),
                  _buildAddIngredientButton(),
                ],
              ),
            ),
            _buildCostFooter(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_long_rounded,
                  color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipe (Bill of Materials)',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _rows.isEmpty
                        ? 'No ingredients yet'
                        : '${_rows.length} ingredient${_rows.length == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYieldRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            controller: _yieldQtyController,
            label: 'This recipe makes',
            hint: '1',
            icon: Icons.numbers_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) => _onFieldChanged(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppTextField(
            controller: _yieldUnitController,
            label: 'Yield unit',
            hint: 'e.g. plate, kg',
            icon: Icons.straighten_rounded,
            onChanged: (_) => _onFieldChanged(),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsHeader() {
    return Text(
      'Ingredients',
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildEmptyRowsHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              color: AppColors.textSecondary.withValues(alpha: 0.6), size: 26),
          const SizedBox(height: 6),
          Text(
            'Add raw materials or semi-finished items that go into this recipe',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(_IngredientRow row) {
    final ingredient = _ingredientFor(row.ingredientItemId);
    final lineCost = _lineCost(row);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ingredient?.isSemiFinished == true
                    ? Icons.soup_kitchen_rounded
                    : Icons.grain_rounded,
                size: 18,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _replaceIngredient(row),
                  child: Text(
                    ingredient?.name ?? 'Select ingredient…',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ingredient == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _removeRow(row),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: row.qtyController,
                  label: 'Qty',
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (_) => _onFieldChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: row.unitController,
                  label: 'Unit',
                  hint: 'e.g. gm',
                  onChanged: (_) => _onFieldChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(lineCost)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'line cost',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: AppColors.accent.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_needsConversion(row)) _buildConversionFactorField(row, ingredient),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => row.showAdvanced = !row.showAdvanced),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    row.showAdvanced
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  Text(
                    'Advanced (wastage)',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (row.showAdvanced)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AppTextField(
                controller: row.wastageController,
                label: 'Wastage %',
                hint: '0',
                icon: Icons.warning_amber_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
        ],
      ),
    );
  }

  /// Shown only when this row's [_needsConversion] is true — i.e. the typed
  /// [_IngredientRow.unitController] text doesn't match the selected
  /// ingredient's own stock unit. Lets staff say how many stock units
  /// (kg, L, pcs…) one line unit (g, ml…) equals, so deduction always moves
  /// the ingredient item's stock in its own unit.
  Widget _buildConversionFactorField(_IngredientRow row, Items? ingredient) {
    final lineUnit = row.unitController.text.trim();
    final itemUnit = ingredient?.unit?.trim() ?? '';
    final factorText = row.conversionController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: row.conversionController,
            label: 'Conversion factor',
            hint: '1',
            icon: Icons.swap_horiz_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) => _onFieldChanged(),
          ),
          const SizedBox(height: 4),
          Text(
            '1 $lineUnit of ${ingredient?.name ?? 'this ingredient'} = '
            '${factorText.isEmpty ? '?' : factorText} $itemUnit '
            '(item\'s stock unit)',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddIngredientButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addIngredient,
        icon: Icon(Icons.add_circle_outline_rounded,
            color: AppColors.secondary, size: 18),
        label: Text(
          'Add Ingredient',
          style: GoogleFonts.poppins(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildCostFooter() {
    final sellingPrice = widget.sellingPrice;
    double? marginPercent;
    if (sellingPrice != null && sellingPrice > 0) {
      marginPercent = ((sellingPrice - _totalCost) / sellingPrice) * 100;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppColors.success.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.savings_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Recipe Cost',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalCost)}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          if (marginPercent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (marginPercent >= 0 ? AppColors.success : AppColors.danger)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Margin',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${marginPercent.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: marginPercent >= 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Search + select bottom sheet for ingredient picking — same interaction
/// shape as the Extras/Toppings pickers elsewhere in restaurant mode.
class _IngredientPickerSheet extends StatefulWidget {
  final List<Items> candidates;

  const _IngredientPickerSheet({required this.candidates});

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.candidates
        : widget.candidates
            .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Select Ingredient',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppTextField(
                controller: _searchController,
                hint: 'Search raw materials & semi-finished…',
                icon: Icons.search_rounded,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        widget.candidates.isEmpty
                            ? 'No Raw Material or Semi-Finished items yet'
                            : 'No matching items',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          leading: Icon(
                            item.isSemiFinished
                                ? Icons.soup_kitchen_rounded
                                : Icons.grain_rounded,
                            color: AppColors.secondary,
                          ),
                          title: Text(item.name,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            item.isSemiFinished ? 'Semi-Finished' : 'Raw Material',
                            style: GoogleFonts.poppins(
                                fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                          trailing: item.unit != null
                              ? Text(item.unit!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: AppColors.textSecondary))
                              : null,
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
