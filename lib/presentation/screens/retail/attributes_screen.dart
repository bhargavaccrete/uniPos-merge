import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../core/di/service_locator.dart';
import '../../../domain/store/retail/attribute_store.dart';

/// Global product attributes (WooCommerce-style) — the dictionary of attribute
/// names (Color, Size, Material) and their values (Red, S/M/L, Cotton).
///
/// One shared list, read by two very different consumers: **Variable** products
/// use it to generate variants, and Settings → Simple Product Fields picks from
/// it to decide which text boxes a **Simple** product shows.
class AttributesScreen extends StatefulWidget {
  const AttributesScreen({super.key});

  @override
  State<AttributesScreen> createState() => _AttributesScreenState();
}

class _AttributesScreenState extends State<AttributesScreen> {
  final AttributeStore _attributeStore = attributeStore;

  @override
  void initState() {
    super.initState();
    _attributeStore.loadAttributes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Product Attributes',
        titleFontSize: 18,
        actions: [
          Observer(
            builder: (_) => _attributeStore.attributes.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Attribute',
                    onPressed: () => showAddAttributeDialog(context),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxContentWidth(context),
          child: Observer(
            builder: (_) {
              if (_attributeStore.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_attributeStore.attributes.isEmpty) {
                return AppEmptyState(
                  icon: Icons.category_outlined,
                  title: 'No attributes yet',
                  message:
                      'Create attributes like Color, Size or Material to '
                      'build variable products and describe simple ones.',
                  action: appEmptyStateAction(
                    label: 'Add First Attribute',
                    onPressed: () => showAddAttributeDialog(context),
                  ),
                );
              }

              return ListView(
                padding: AppResponsive.screenPadding(context),
                children: [
                  _buildExplainer(),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  ..._attributeStore.attributes.map(
                    (attribute) => _AttributeCard(
                      attribute: attribute,
                      values: _attributeStore.getValues(attribute.attributeId),
                      onEdit: () => _showEditAttributeDialog(attribute),
                      onDelete: () => _confirmDeleteAttribute(attribute),
                      onAddValue: () => _showAddValueDialog(attribute),
                      onEditValue: (value) =>
                          _showEditValueDialog(attribute, value),
                      onDeleteValue: _confirmDeleteValue,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExplainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Attributes are shared across every product. Variable products '
              'use them to generate variants; simple products show the ones '
              'picked in Settings → Simple Product Fields.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Attribute dialogs ──────────────────────────────────────────────────────

  Future<void> _showEditAttributeDialog(AttributeModel attribute) async {
    final name = await _promptAttributeName(
      context: context,
      title: 'Edit Attribute',
      confirmLabel: 'Update',
      initialValue: attribute.name,
    );
    if (name == null || name.isEmpty) return;

    final success = await _attributeStore.updateAttribute(
      attribute.attributeId,
      name: name,
    );
    if (!mounted) return;
    if (success) {
      await _attributeStore.loadAttributes();
      NotificationService.instance.showSuccess('Attribute "$name" updated');
    } else {
      NotificationService.instance.showError(
        _attributeStore.errorMessage ?? 'Failed to update',
      );
    }
  }

  Future<void> _confirmDeleteAttribute(AttributeModel attribute) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Attribute?',
      message:
          'Delete "${attribute.name}" and all of its values? '
          'Products already using it will keep what they saved.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final success = await _attributeStore.deleteAttribute(
      attribute.attributeId,
    );
    if (!mounted) return;
    if (success) {
      await _attributeStore.loadAttributes();
      NotificationService.instance.showSuccess(
        'Attribute "${attribute.name}" deleted',
      );
    } else {
      NotificationService.instance.showError(
        _attributeStore.errorMessage ?? 'Cannot delete',
      );
    }
  }

  // ── Value dialogs ──────────────────────────────────────────────────────────

  Future<void> _showAddValueDialog(AttributeModel attribute) async {
    final input = await _promptForValue(
      attribute: attribute,
      title: 'Add ${attribute.name} Value',
      confirmLabel: 'Add',
      helper: 'Tip: add several at once, separated by commas.',
    );
    if (input == null || input.value.isEmpty) return;

    // Comma-separated input is a bulk add; a single value can also carry a
    // colour swatch, which the bulk path has no place to put.
    final values = input.value
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (values.isEmpty) return;

    final success = values.length > 1
        ? await _attributeStore.addMultipleValues(attribute.attributeId, values)
        : await _attributeStore.addValue(
            attribute.attributeId,
            values.first,
            colorCode: input.colorCode,
          );

    if (!mounted) return;
    if (success) {
      await _attributeStore.loadAttributes();
      NotificationService.instance.showSuccess(
        'Added ${values.length} value(s)',
      );
    } else {
      NotificationService.instance.showError(
        _attributeStore.errorMessage ?? 'Failed to add',
      );
    }
  }

  Future<void> _showEditValueDialog(
    AttributeModel attribute,
    AttributeValueModel value,
  ) async {
    final input = await _promptForValue(
      attribute: attribute,
      title: 'Edit ${attribute.name} Value',
      confirmLabel: 'Update',
      initialValue: value.value,
      initialColorCode: value.colorCode,
    );
    if (input == null || input.value.isEmpty) return;

    final success = await _attributeStore.updateValue(
      value.valueId,
      value: input.value,
      colorCode: input.colorCode,
    );
    if (!mounted) return;
    if (success) {
      await _attributeStore.loadAttributes();
      NotificationService.instance.showSuccess(
        'Value "${input.value}" updated',
      );
    } else {
      NotificationService.instance.showError(
        _attributeStore.errorMessage ?? 'Failed to update',
      );
    }
  }

  /// Shared value prompt. The colour-code field only appears for colour-ish
  /// attributes, matching how [_ValueChip] decides to draw a swatch.
  Future<_ValueInput?> _promptForValue({
    required AttributeModel attribute,
    required String title,
    required String confirmLabel,
    String? helper,
    String? initialValue,
    String? initialColorCode,
  }) {
    final valueController = TextEditingController(text: initialValue);
    final colorController = TextEditingController(text: initialColorCode ?? '');
    final isColor = _isColorAttribute(attribute.name);

    _ValueInput read() => _ValueInput(
      value: valueController.text.trim(),
      colorCode: colorController.text.trim().isEmpty
          ? null
          : colorController.text.trim(),
    );

    return showDialog<_ValueInput>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [valueController, colorController],
        child: AppDialogShell(
          title: title,
          accent: AppColors.primary,
          icon: Icons.style_outlined,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: valueController,
                label: 'Value',
                hint: _getValueHint(attribute.name),
                required: true,
                autofocus: true,
                textInputAction: isColor
                    ? TextInputAction.next
                    : TextInputAction.done,
                onFieldSubmitted: isColor
                    ? null
                    : (_) => Navigator.pop(dialogContext, read()),
              ),
              if (isColor) ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: colorController,
                  label: 'Color Code (optional)',
                  hint: '#FF0000',
                  icon: Icons.palette_outlined,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => Navigator.pop(dialogContext, read()),
                ),
              ],
              if (helper != null) ...[
                const SizedBox(height: 10),
                Text(
                  helper,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            appDialogCancelButton(dialogContext),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: confirmLabel,
              onPressed: () => Navigator.pop(dialogContext, read()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteValue(AttributeValueModel value) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Value?',
      message: 'Delete "${value.value}"?',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final success = await _attributeStore.deleteValue(value.valueId);
    if (!mounted) return;
    if (success) {
      await _attributeStore.loadAttributes();
      NotificationService.instance.showSuccess(
        'Value "${value.value}" deleted',
      );
    } else {
      NotificationService.instance.showError(
        _attributeStore.errorMessage ?? 'Cannot delete',
      );
    }
  }

  String _getValueHint(String attributeName) {
    final name = attributeName.toLowerCase();
    if (_isColorAttribute(attributeName)) return 'e.g. Red, Blue, Green';
    if (name.contains('size')) return 'e.g. S, M, L, XL';
    if (name.contains('material')) return 'e.g. Cotton, Polyester, Silk';
    if (name.contains('weight')) return 'e.g. 100g, 250g, 500g';
    return 'e.g. Value 1, Value 2';
  }
}

/// True for attributes that should offer a colour swatch.
bool _isColorAttribute(String name) {
  final lower = name.toLowerCase();
  return lower.contains('color') || lower.contains('colour');
}

/// What a value dialog returns — the trimmed value plus an optional colour.
class _ValueInput {
  final String value;
  final String? colorCode;

  const _ValueInput({required this.value, this.colorCode});
}

class _AttributeCard extends StatelessWidget {
  final AttributeModel attribute;
  final List<AttributeValueModel> values;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddValue;
  final ValueChanged<AttributeValueModel> onEditValue;
  final ValueChanged<AttributeValueModel> onDeleteValue;

  const _AttributeCard({
    required this.attribute,
    required this.values,
    required this.onEdit,
    required this.onDelete,
    required this.onAddValue,
    required this.onEditValue,
    required this.onDeleteValue,
  });

  @override
  Widget build(BuildContext context) {
    final isColor = _isColorAttribute(attribute.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        // Same soft lift the POS and report cards use.
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
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
                    Text(
                      attribute.name,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      values.isEmpty
                          ? 'No values yet'
                          : '${values.length} value${values.length == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Rename/Delete act on the ATTRIBUTE. The value chips below carry
              // their own long-press menu — that stays, chips are too dense for
              // per-chip buttons.
              RowActionButton(
                icon: Icons.edit_outlined,
                color: AppColors.primary,
                tooltip: 'Rename Attribute',
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              RowActionButton(
                icon: Icons.delete_outline_rounded,
                color: AppColors.danger,
                tooltip: 'Delete Attribute',
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: AppColors.divider),
          SizedBox(height: AppResponsive.smallSpacing(context)),

          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: values.isEmpty
                ? Text(
                    'Add values like ${_placeholderFor(attribute.name)} so this '
                    'attribute can be used.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: values
                        .map(
                          (value) => _ValueChip(
                            value: value,
                            isColor: isColor,
                            onEdit: () => onEditValue(value),
                            onDelete: () => onDeleteValue(value),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: onAddValue,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Add Value',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 11),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _placeholderFor(String attributeName) {
    final name = attributeName.toLowerCase();
    if (_isColorAttribute(attributeName)) return 'Red or Blue';
    if (name.contains('size')) return 'S, M or L';
    if (name.contains('material')) return 'Cotton or Silk';
    return 'the options you sell';
  }
}

/// A single attribute value. Tap edits it; long-press opens edit/delete —
/// keeping a delete affordance off every chip.
class _ValueChip extends StatelessWidget {
  final AttributeValueModel value;
  final bool isColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ValueChip({
    required this.value,
    required this.isColor,
    required this.onEdit,
    required this.onDelete,
  });

  Color? get _swatch {
    if (!isColor || value.colorCode == null) return null;
    try {
      final hex = value.colorCode!.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<void> _showMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final selected = await showMenu<String>(
      context: context,
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy + box.size.height,
        overlay.size.width - topLeft.dx - box.size.width,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 10),
              Text(
                'Edit',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.danger,
              ),
              const SizedBox(width: 10),
              Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected == 'edit') onEdit();
    if (selected == 'delete') onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final swatch = _swatch;

    return Tooltip(
      message: 'Tap to edit · Long-press for more',
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onEdit,
          onLongPress: () => _showMenu(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (swatch != null) ...[
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  value.value,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared entry points ──────────────────────────────────────────────────────
// Top-level so ProductManagementScreen's contextual "+" can open the same
// dialog the standalone screen uses, without reaching into its State.

/// Creates a new global attribute. Safe to call from any context.
Future<void> showAddAttributeDialog(BuildContext context) async {
  final name = await _promptAttributeName(
    context: context,
    title: 'Add Attribute',
    subtitle: 'Reusable across all products',
    confirmLabel: 'Create',
    hint: 'e.g. Color, Size, Material',
  );
  if (name == null || name.isEmpty) return;

  final success = await attributeStore.addAttribute(name);
  if (!context.mounted) return;
  if (success) {
    await attributeStore.loadAttributes();
    NotificationService.instance.showSuccess('Attribute "$name" created');
  } else {
    NotificationService.instance.showError(
      attributeStore.errorMessage ?? 'Failed to create attribute',
    );
  }
}

/// Shared name prompt for add/edit. Returns the trimmed name, or null when
/// the user cancels. The text is captured before the pop, so nothing reads a
/// controller that [DialogDisposeScope] has already torn down.
Future<String?> _promptAttributeName({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? subtitle,
  String? hint,
  String? initialValue,
}) {
  final controller = TextEditingController(text: initialValue);

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => DialogDisposeScope(
      disposables: [controller],
      child: AppDialogShell(
        title: title,
        subtitle: subtitle,
        accent: AppColors.primary,
        icon: Icons.label_outline_rounded,
        body: AppTextField(
          controller: controller,
          label: 'Attribute Name',
          hint: hint,
          icon: Icons.label_outline_rounded,
          required: true,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          appDialogCancelButton(dialogContext),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: confirmLabel,
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
          ),
        ],
      ),
    ),
  );
}
