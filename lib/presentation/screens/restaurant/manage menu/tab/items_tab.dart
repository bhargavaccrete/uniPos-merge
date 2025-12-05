import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/edit_item.dart' show EdititemScreen;
import 'package:unipos/presentation/widget/componets/restaurant/componets/bottomsheet.dart';
import 'package:unipos/util/restaurant/audit_trail_helper.dart';
import 'package:unipos/util/restaurant/currency_helper.dart';
import 'package:unipos/util/restaurant/images.dart';

class ItemsTab extends StatefulWidget {
  final String? selectedCategory;

  const ItemsTab({
    super.key,
    this.selectedCategory,
  });

  @override
  State<ItemsTab> createState() => _AllTabState();
}

List<String> options = ['Each', 'Weight'];

class _AllTabState extends State<ItemsTab> {
  String currencySymbol = '\$'; // Default currency symbol

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
  }

  // Load currency symbol from preferences
  Future<void> _loadCurrencySymbol() async {
    final symbol = await CurrencyHelper.getCurrencySymbol();
    setState(() {
      currencySymbol = symbol;
    });
  }

  void _deleteItem(String id) async {
    await itemStore.deleteItem(id);
  }

  void editItems(Items itemToEdit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EdititemScreen(items: itemToEdit)),
    );
  }

  TextEditingController SearchController = TextEditingController();
  TextEditingController itemsNameController = TextEditingController();
  TextEditingController ipriceController = TextEditingController();
  String groupValue = 'Each';

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: Column(
        children: [
          Observer(
            builder: (_) {
              final allItem = itemStore.items.toList();

              if (allItem.isEmpty) {
                return Container(
                  height: height * 0.70,
                  width: width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(notfoundanimation, height: height * 0.3),
                      Text(
                        'No such items Found!',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400),
                      )
                    ],
                  ),
                );
              }
              return Container(
                height: height * 0.7,
                child: ListView.builder(
                    itemCount: allItem.length,
                    itemBuilder: (context, index) {
                      final item = allItem[index];
                      final categoryId = item.categoryOfItem;
                      final category = categoryId != null ? categoryStore.getCategoryById(categoryId) : null;
                      final categoryName = category?.name ?? 'Unknown';

                      return Card(
                        child: ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.name,
                                    textScaler: TextScaler.linear(1),
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Icon(
                                    Icons.circle,
                                    color: item.isVeg == 'Veg' ? Colors.green : Colors.red,
                                    size: 10,
                                  )
                                ],
                              ),
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: primarycolor,
                                  inactiveThumbColor: Colors.white70,
                                  inactiveTrackColor: Colors.grey.shade400,
                                  value: item.isEnabled,
                                  onChanged: (bool value) async {
                                    item.isEnabled = value;
                                    await item.save();
                                  },
                                ),
                              )
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryName,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              // 🔍 AUDIT TRAIL: Display edit history
                              if (item.createdTime != null || AuditTrailHelper.hasBeenEdited(item))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Show creation time
                                      if (item.createdTime != null)
                                        Text(
                                          'Created: ${item.createdTime!.day}/${item.createdTime!.month}/${item.createdTime!.year} ${item.createdTime!.hour}:${item.createdTime!.minute.toString().padLeft(2, '0')}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                      // Show edit history if item has been edited
                                      if (AuditTrailHelper.hasBeenEdited(item))
                                        Text(
                                          'Edited ${item.editCount} time(s) • Last: ${item.lastEditedTime!.day}/${item.lastEditedTime!.month}/${item.lastEditedTime!.year} ${item.lastEditedTime!.hour}:${item.lastEditedTime!.minute.toString().padLeft(2, '0')}${item.editedBy != null ? ' by ${item.editedBy}' : ''}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.orange[700],
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // 💰 CURRENCY: Display price with selected currency symbol
                                  Text(
                                      CurrencyHelper.formatAmountWithSymbol(item.price ?? 0, currencySymbol),
                                      style: GoogleFonts.poppins(fontSize: 16, color: primarycolor, fontWeight: FontWeight.bold)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Icon(Icons.qr_code),
                                      SizedBox(
                                        width: 3,
                                      ),
                                      Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          height: 30,
                                          width: 30,
                                          child: InkWell(
                                              onTap: () async {
                                                editItems(item);
                                              },
                                              child: Icon(Icons.mode_edit_outlined))),
                                      SizedBox(
                                        width: 3,
                                      ),
                                      InkWell(
                                        onTap: () {
                                          _deleteItem(item.id);
                                        },
                                        child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            height: 30,
                                            width: 30,
                                            child: Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                            )),
                                      ),
                                      SizedBox(
                                        width: 3,
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
              );
            },
          ),
          BottomsheetMenu(
            onCategorySelected: (category) {
              setState(() {
                // activeCategory = category; // Filter Items by this category
              });
            },
          )
        ],
      ),
    );
  }
}