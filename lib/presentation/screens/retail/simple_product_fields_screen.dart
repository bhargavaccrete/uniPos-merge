import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/retail/simple_product_fields_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Configures which descriptor fields appear on a **Simple** product's variant
/// card — replacing the hardcoded Color / Size / Weight boxes.
///
/// Separate from Settings → Product Attributes, which drives **Variable**
/// products and variant generation. Both read the same global attribute list,
/// so nothing here is a second attribute system.
class SimpleProductFieldsScreen extends StatefulWidget {
  const SimpleProductFieldsScreen({super.key});

  @override
  State<SimpleProductFieldsScreen> createState() =>
      _SimpleProductFieldsScreenState();
}

class _SimpleProductFieldsScreenState extends State<SimpleProductFieldsScreen> {
  final SimpleProductFieldsService _service = SimpleProductFieldsService();

  List<AttributeModel> _fields = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // resolveFields seeds this store type's default attributes, then returns
    // either the saved selection or those defaults — one definition, shared
    // with every product form.
    final fields = await _service.resolveFields();

    if (!mounted) return;
    setState(() {
      _fields = fields;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await _service.setFieldIds(
      _fields.map((a) => a.attributeId).toList(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      NotificationService.instance.showSuccess('Simple product fields saved');
      Navigator.of(context).pop();
    } else {
      NotificationService.instance.showError('Could not save fields');
    }
  }

  Future<void> _resetToDefaults() async {
    // Name the actual defaults for THIS store type rather than a fixed list —
    // a cosmetics shop being offered "Size, Color and Weight" would be wrong.
    final defaults = _service.defaultFieldNames();
    final restoring = defaults.isEmpty
        ? 'Clear the fields shown on simple products?'
        : 'Restore ${_joinNames(defaults)} as the fields on simple products?';

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Reset Fields',
      message: '$restoring Your attributes themselves are not deleted.',
      confirmLabel: 'Reset',
      icon: Icons.restart_alt_rounded,
    );
    if (!confirmed) return;

    await _service.resetToDefaults();
    final fields = await _service.resolveDefaultFields();
    if (!mounted) return;
    setState(() => _fields = fields);
    NotificationService.instance.showSuccess('Fields reset');
  }

  /// 'Size, Color and Weight' — for the confirm message.
  static String _joinNames(List<String> names) {
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  void _removeField(AttributeModel attribute) {
    setState(
      () => _fields.removeWhere((a) => a.attributeId == attribute.attributeId),
    );
  }

  Future<void> _showAddFieldSheet() async {
    final existingIds = _fields.map((a) => a.attributeId).toSet();
    final available = attributeStore.attributes
        .where((a) => !existingIds.contains(a.attributeId))
        .toList();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Add Field',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showCreateFieldDialog();
                    },
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: AppResponsive.smallIconSize(context),
                    ),
                    label: Text(
                      'Create New',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            if (available.isEmpty)
              Padding(
                padding: AppResponsive.padding(context),
                child: Text(
                  'All existing attributes are already added.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (_, i) {
                    final attribute = available[i];
                    final values = attributeStore.getValues(
                      attribute.attributeId,
                    );
                    return ListTile(
                      leading: const Icon(
                        Icons.label_outline_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        attribute.name,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        values.isEmpty
                            ? 'No preset values'
                            : values.map((v) => v.value).take(4).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        setState(() => _fields.add(attribute));
                      },
                    );
                  },
                ),
              ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateFieldDialog() async {
    final controller = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Create Field',
        subtitle: 'Adds a new global attribute',
        accent: AppColors.primary,
        icon: Icons.new_label_outlined,
        body: AppTextField(
          controller: controller,
          label: 'Field name',
          hint: 'e.g. Flavour, Volume, Capacity',
          icon: Icons.label_outline_rounded,
          required: true,
          autofocus: true,
        ),
        actions: [
          appDialogCancelButton(dialogContext),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          appDialogPrimaryButton(
            label: 'Create',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    final name = controller.text.trim();
    controller.dispose();
    if (created != true || name.isEmpty) return;

    final ok = await attributeStore.addAttribute(name);
    if (!mounted) return;
    if (!ok) {
      NotificationService.instance.showError(
        attributeStore.errorMessage ?? 'Could not create field',
      );
      return;
    }

    final attribute = attributeStore.getAttributeByName(name);
    if (attribute == null) return;
    setState(() => _fields.add(attribute));
    NotificationService.instance.showSuccess(
      'Field created. Add its values in Settings → Product Attributes.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Simple Product Fields',
        titleFontSize: AppResponsive.subheadingFontSize(context),
        actions: [
          IconButton(
            icon: Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset to defaults',
            onPressed: _isLoading || _isSaving ? null : _resetToDefaults,
          ),
        ],
      ),
      body: SafeArea(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxCardWidth(context),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildExplainer(),
                    Expanded(child: _buildFieldList()),
                    _buildBottomBar(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildExplainer() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.primary,
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Text(
              'These fields appear on every simple product. Remove what you '
              'don\'t sell by and add your own — price, stock, barcode and SKU '
              'are always shown.',
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

  Widget _buildFieldList() {
    if (_fields.isEmpty) {
      return AppEmptyState(
        icon: Icons.label_off_outlined,
        title: 'No fields',
        message:
            'Simple products will show only price, stock, barcode and SKU.',
        action: OutlinedButton.icon(
          onPressed: _showAddFieldSheet,
          icon: const Icon(Icons.add),
          label: Text('Add Field'),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: [
        ..._fields.map(_buildFieldCard),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        OutlinedButton.icon(
          onPressed: _showAddFieldSheet,
          icon: Icon(Icons.add),
          label: Text(
            'Add Field',
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
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldCard(AttributeModel attribute) {
    final values = attributeStore.getValues(attribute.attributeId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
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
                const SizedBox(height: 3),
                Text(
                  values.isEmpty
                      ? 'Free text — no preset values'
                      : values.map((v) => v.value).take(5).join(' · '),
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
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              color: AppColors.danger,
              size: AppResponsive.iconSize(context),
            ),
            tooltip: 'Remove field',
            onPressed: () => _removeField(attribute),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Save Fields',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
