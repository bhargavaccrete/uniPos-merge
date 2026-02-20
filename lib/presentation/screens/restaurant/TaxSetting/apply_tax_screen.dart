import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/common/currency_helper.dart';
import '../../../../util/restaurant/staticswitch.dart';
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

  @override
  void initState() {
    super.initState();
    itemStore.loadItems();
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

  void _onSelectedAllChecked(bool? isChecked, List<Items> allItems){
    setState(() {
      if(isChecked ==true){
        _selectedItemIds.addAll(allItems.map((item)=> item.id));
      }else{
        _selectedItemIds.clear();
      }
    });
  }


  Future<void> _applyTaxToSelected() async {
    if (_selectedItemIds.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final double rate = widget.taxToApply.taxperecentage! / 100.0;

      debugPrint("🔵 Applying tax: ${widget.taxToApply.taxname} at rate: $rate (${widget.taxToApply.taxperecentage}%)");
      debugPrint("🔵 Selected items: ${_selectedItemIds.length}");

      for (String id in _selectedItemIds) {
        try {
          final item = itemStore.items.firstWhere((item) => item.id == id);
          debugPrint("🔵 Applying tax to: ${item.name}, current taxRate: ${item.taxRate}");
          item.applyTax(rate);
          await itemStore.updateItem(item);
          debugPrint("🔵 After apply - ${item.name}, new taxRate: ${item.taxRate}");
        } catch (e) {
          debugPrint("❌ Item not found with id: $id");
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
          debugPrint("❌ Item not found with id: $id");
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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          "Apply ${widget.taxToApply.taxname}",
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Observer(
            builder: (context) {
              final items = itemStore.items;
              final isAllSelected = items.isNotEmpty && _selectedItemIds.length == items.length;

              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Text(
                      isAllSelected ? "Deselect All" : "Select All",
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 14 : 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Checkbox(
                      value: isAllSelected,
                      onChanged: (value) => _onSelectedAllChecked(value, items),
                      activeColor: AppColors.primary,
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

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(isTablet ? 16 : 12),
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
                            vertical: isTablet ? 14 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(Icons.check_circle_rounded, size: isTablet ? 20 : 18),
                        label: Text(
                          "Apply ${widget.taxToApply.taxperecentage}% Tax",
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_selectedItemIds.isEmpty || _isLoading) ? null : _removeTaxFromSelected,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 14 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(Icons.remove_circle_rounded, size: isTablet ? 20 : 18),
                        label: Text(
                          "Remove Tax",
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedItemIds.contains(item.id);

                    return Container(
                      margin: EdgeInsets.only(bottom: isTablet ? 10 : 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
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
                          horizontal: isTablet ? 16 : 12,
                          vertical: isTablet ? 10 : 8,
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isTablet ? 17 : 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              item.price == null
                                  ? '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(0)}'
                                  : AppSettings.isTaxInclusive
                                      ? item.taxRate != null
                                          ? DecimalSettings.formatAmount(item.basePrice)
                                          : DecimalSettings.formatAmount(item.price!)
                                      : DecimalSettings.formatAmount(item.price!),
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 16 : 15,
                                fontWeight: FontWeight.bold,
                                color: item.taxRate != null ? Colors.green : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        subtitle: item.taxRate != null
                            ? Padding(
                          padding: EdgeInsets.only(top: isTablet ? 10 : 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Tax Applied: ${item.taxRate! > 1 ? DecimalSettings.formatAmount(item.taxRate!) : DecimalSettings.formatAmount(item.taxRate! * 100)}%",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 13 : 12,
                                    color: Colors.blue,
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
                                      fontSize: isTablet ? 13 : 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    "Net Amount:",
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 13 : 12,
                                      color: Colors.grey.shade600,
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
                                      fontSize: isTablet ? 14 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
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
                                      fontSize: isTablet ? 15 : 14,
                                      color: Colors.black87,
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
                              fontSize: isTablet ? 13 : 12,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

// double totalgst(double itemprice , double gstrate){
//   return itemprice * gstrate / 100 ;
// }

}