import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/restaurant/staticswitch.dart';

class ApplyTaxScreen extends StatefulWidget {
  final Tax taxToApply;
  const ApplyTaxScreen({super.key,
    required this.taxToApply,
  });

  @override
  State<ApplyTaxScreen> createState() => _ApplyTaxScreenState();
}

class _ApplyTaxScreenState extends State<ApplyTaxScreen> {


  final Box<Items> itemBox = Hive.box<Items>('itemBoxs');
  final Set<String> _selectedItemIds = {};


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


  void _applyTaxToSelected() {
    if (_selectedItemIds.isEmpty) return;

    final double rate = widget.taxToApply.taxperecentage! / 100.0;

    debugPrint("🔵 Applying tax: ${widget.taxToApply.taxname} at rate: $rate (${widget.taxToApply.taxperecentage}%)");
    debugPrint("🔵 Selected items: ${_selectedItemIds.length}");

    for (String id in _selectedItemIds) {
      // Get item directly from box using the id as key
      final item = itemBox.get(id);
      if (item != null) {
        debugPrint("🔵 Applying tax to: ${item.name}, current taxRate: ${item.taxRate}");
        item.applyTax(rate);
        debugPrint("🔵 After apply - ${item.name}, new taxRate: ${item.taxRate}");
      } else {
        debugPrint("❌ Item not found with key: $id");
        debugPrint("❌ Available keys in box: ${itemBox.keys.take(5).toList()}");
      }
    }

    setState(() => _selectedItemIds.clear());

    NotificationService.instance.showInfo(
      '${widget.taxToApply.taxname} (${widget.taxToApply.taxperecentage}%) applied to selected items.',
    );


    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('${widget.taxToApply.taxname} (${widget.taxToApply.taxperecentage}%) applied to selected items.'),
    //     backgroundColor: Colors.green,
    //   ),
    // );
  }

// ✅ OPTIMIZED: This method is also now more performant
  void _removeTaxFromSelected() {
    if (_selectedItemIds.isEmpty) return;

    for (String id in _selectedItemIds) {
      final item = itemBox.get(id); // Get item directly from box
      item?.removeTax();
    }

    setState(() => _selectedItemIds.clear());


    NotificationService.instance.showInfo(
      'Tax removed from selected items.',
    );

    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(
    //     content: Text('Tax removed from selected items.'),
    //     backgroundColor: Colors.red,
    //   ),
    // );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Apply ${widget.taxToApply.taxname}"),
        actions: [
          ValueListenableBuilder(
            valueListenable: itemBox.listenable(),
            builder: (context, Box<Items> box, _) {
              final items = box.values.toList();
              final isAllSelected = items.isNotEmpty && _selectedItemIds.length == items.length;

              return Row(
                children: [
                  Text(isAllSelected ? "Deselect All" : "Select All"),
                  Checkbox(
                    value: isAllSelected,
                    onChanged: (value) => _onSelectedAllChecked(value, items),
                    activeColor: Colors.white,
                    checkColor: Theme.of(context).primaryColor,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: itemBox.listenable(),
        builder: (context, Box<Items> box, _) {
          final items = box.values.toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedItemIds.isEmpty ? null : _applyTaxToSelected,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: Text("Apply ${widget.taxToApply.taxperecentage}% Tax", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedItemIds.isEmpty ? null : _removeTaxFromSelected,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("Remove Tax", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedItemIds.contains(item.id);

                    // ✅ UI UPDATED TO MATCH YOUR IMAGE
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (bool? value) => _onItemChecked(value, item),
                        activeColor: Colors.blue,
                        controlAffinity: ListTileControlAffinity.leading,

                        // --- Title Row ---
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),


                            Text(
                              // Show appropriate price based on tax setting
                              AppSettings.isTaxInclusive
                                  ? item.taxRate != null
                                  ? item.basePrice.toStringAsFixed(2)  // Show base price if tax applied
                                  : item.price!.toStringAsFixed(2)     // Show original price if no tax
                                  : item.price!.toStringAsFixed(2),        // Show base price for exclusive
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: item.taxRate != null ? Colors.green : Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        // --- Subtitle with Tax Breakdown ---
                        subtitle: item.taxRate != null
                            ? Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show tax percentage applied
                              Text(
                                "Tax Applied: ${(item.taxRate! * 100).toStringAsFixed(2)}%",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Tax Amount:"),
                                  const Text("Net Amount on Item:"),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppSettings.isTaxInclusive
                                        ? "₹${item.taxAmount.toStringAsFixed(2)}"  // Show calculated tax from inclusive price
                                        : "₹${(item.price! * item.taxRate!).toStringAsFixed(2)}", // Show tax on base price
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    AppSettings.isTaxInclusive
                                        ? "₹${item.price!.toStringAsFixed(2)}"     // Show inclusive price as net amount
                                        : "₹${(item.price! * (1 + item.taxRate!)).toStringAsFixed(2)}", // Show base + tax as net amount
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                            : const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "No tax applied",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ), // Show "No tax applied" if no tax
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