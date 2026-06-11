import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/common/currency_helper.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../widget/componets/common/primary_app_bar.dart';
import '../../../widget/componets/common/app_text_field.dart';
import 'package:unipos/util/common/decimal_settings.dart';

class ApplyTaxScreen extends StatefulWidget {
  final Tax taxToApply;
  const ApplyTaxScreen({super.key,
    required this.taxToApply,
  });

  @override
  State<ApplyTaxScreen> createState() => _ApplyTaxScreenState();
}

class _ApplyTaxScreenState extends State<ApplyTaxScreen> {
  final Set<String> _selectedItemIds = {};
  bool _isLoading = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _activeCategoryId; // null = All categories

  @override
  void initState() {
    super.initState();
    itemStore.loadItems();
    categoryStore.loadCategories();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Items currently visible after applying the category + search filters.
  /// This is the single source the checklist AND "Select All" both use, so
  /// selecting all only ever affects what the user can actually see.
  List<Items> _visibleItems(List<Items> allItems) {
    var result = allItems;

    // 1. Category filter (null = All)
    if (_activeCategoryId != null) {
      result = result.where((item) => item.categoryOfItem == _activeCategoryId).toList();
    }

    // 2. Search filter (case-insensitive name match)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((item) =>
          item.name.toLowerCase().contains(query) ||
          (item.itemCode != null && item.itemCode!.toLowerCase().contains(query))).toList();
    }

    return result;
  }

  Widget _categoryChip({required String label, required String? id}) {
    final selected = _activeCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _activeCategoryId = id),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceLight,
        labelStyle: GoogleFonts.poppins(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
        ),
      ),
    );
  }


  void _onItemChecked(bool? isChecked, Items item) {
    setState(() {
      if (isChecked == true) {
        _selectedItemIds.add(item.id);
      } else {
        _selectedItemIds.remove(item.id);
      }
    });
  }

  void _onSelectedAllChecked(bool? isChecked, List<Items> visibleItems){
    setState(() {
      final visibleIds = visibleItems.map((item) => item.id);
      if(isChecked ==true){
        _selectedItemIds.addAll(visibleIds);
      }else{
        // Only deselect what's currently visible — keep selections in other filters.
        _selectedItemIds.removeAll(visibleIds);
      }
    });
  }


  Future<void> _applyTaxToSelected() async {
    if (_selectedItemIds.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final double rate = widget.taxToApply.taxperecentage! / 100.0;

      for (String id in _selectedItemIds) {
        try {
          final item = itemStore.items.firstWhere((item) => item.id == id);
          item.applyTax(rate);
          await itemStore.updateItem(item);
        } catch (e) {
          // item not found, skip
        }
      }

      setState(() => _selectedItemIds.clear());

      NotificationService.instance.showSuccess(
        '${widget.taxToApply.taxname} (${widget.taxToApply.taxperecentage}%) applied to selected items.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeTaxFromSelected() async {
    if (_selectedItemIds.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      for (String id in _selectedItemIds) {
        try {
          final item = itemStore.items.firstWhere((item) => item.id == id);
          item.removeTax();
          await itemStore.updateItem(item);
        } catch (e) {
          // item not found, skip
        }
      }

      setState(() => _selectedItemIds.clear());

      NotificationService.instance.showSuccess(
        'Tax removed from selected items.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
  return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: "Apply ${widget.taxToApply.taxname}",
        titleFontSize: AppResponsive.headingFontSize(context),
        actions: [
          Observer(
            builder: (context) {
              final items = _visibleItems(itemStore.items);
              final isAllSelected = items.isNotEmpty && items.every((i) => _selectedItemIds.contains(i.id));

              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Text(
                      isAllSelected ? "Deselect All" : "Select All",
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Checkbox(
                      value: isAllSelected,
                      onChanged: (value) => _onSelectedAllChecked(value, items),
                      activeColor: Colors.white,
                      checkColor: AppColors.primary,
                      side: const BorderSide(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Observer(
        builder: (context) {
          if (itemStore.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final items = itemStore.items;

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: AppResponsive.getValue(context, mobile: 64.0, tablet: 80.0, desktop: 96.0), color: AppColors.divider),
                  SizedBox(height: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),
                  Text(
                    'No items available',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 18.0, desktop: 20.0),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add items to your menu first',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final visibleItems = _visibleItems(items);

          // Remove Tax is only meaningful when at least one selected item
          // actually has a tax applied — otherwise there's nothing to remove.
          final hasTaxedSelection = items.any(
            (i) => _selectedItemIds.contains(i.id) && i.taxRate != null,
          );

          return Column(
            children: [
              // Search bar + category filter chips
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: [
                    AppTextField(
                      controller: _searchController,
                      hint: 'Search items…',
                      icon: Icons.search_rounded,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _categoryChip(label: 'All', id: null),
                          ...categoryStore.categories
                              .map((c) => _categoryChip(label: c.name, id: c.id)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleItems.isEmpty
                    ? Center(
                        child: Text(
                          'No items match your search',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                  padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0)),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    final isSelected = _selectedItemIds.contains(item.id);

                    return Container(
                      margin: EdgeInsets.only(bottom: AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: AppResponsive.shadowBlurRadius(context),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (bool? value) => _onItemChecked(value, item),
                        activeColor: AppColors.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
                          vertical: AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0),
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              item.price == null
                                  ? '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(0)}'
                                  : AppSettings.isTaxInclusive
                                      ? item.taxRate != null
                                          ? '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.basePrice)}'
                                          : '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price!)}'
                                      : '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price!)}',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.getValue(context, mobile: 15.0, tablet: 16.0, desktop: 17.0),
                                fontWeight: FontWeight.bold,
                                color: item.taxRate != null ? AppColors.success : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        subtitle: item.taxRate != null
                            ? Padding(
                          padding: EdgeInsets.only(top: AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Tax Applied: ${item.taxRate! > 1 ? DecimalSettings.formatAmount(item.taxRate!) : DecimalSettings.formatAmount(item.taxRate! * 100)}%",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Tax Amount:",
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    "Net Amount:",
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.price == null
                                        ? '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(0)}'
                                        : AppSettings.isTaxInclusive
                                            ? '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.taxAmount)}'
                                            : '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price! * item.taxRate!)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  Text(
                                    item.price == null
                                        ? '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(0)}'
                                        : AppSettings.isTaxInclusive
                                            ? '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price!)}'
                                            : '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price! * (1 + item.taxRate!))}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                            : Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            "No tax applied",
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Action buttons pinned at the bottom
              _buildActionBar(hasTaxedSelection),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionBar(bool hasTaxedSelection) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
        AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
        AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
        AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_selectedItemIds.isEmpty || _isLoading) ? null : _applyTaxToSelected,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(Icons.check_circle_rounded, size: AppResponsive.getValue(context, mobile: 18.0, tablet: 20.0, desktop: 22.0)),
                label: Text(
                  "Apply ${widget.taxToApply.taxperecentage}% Tax",
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_selectedItemIds.isEmpty || _isLoading || !hasTaxedSelection) ? null : _removeTaxFromSelected,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(Icons.remove_circle_rounded, size: AppResponsive.getValue(context, mobile: 18.0, tablet: 20.0, desktop: 22.0)),
                label: Text(
                  "Remove Tax",
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// double totalgst(double itemprice , double gstrate){
//   return itemprice * gstrate / 100 ;
// }

}