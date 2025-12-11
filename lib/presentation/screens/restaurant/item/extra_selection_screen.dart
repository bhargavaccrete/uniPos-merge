import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';


class ExtraSelectionScreen extends StatefulWidget {
  final List<String> selectedExtraIds;

  const ExtraSelectionScreen({
    super.key,
    required this.selectedExtraIds,
  });

  @override
  State<ExtraSelectionScreen> createState() => _ExtraSelectionScreenState();
}

class _ExtraSelectionScreenState extends State<ExtraSelectionScreen> {
  List<Extramodel> availableExtras = [];
  Set<String> selectedExtraIds = {};

  @override
  void initState() {
    super.initState();
    _loadExtras();
    _initializeSelections();
  }

  void _loadExtras() {
    final extraBox = Hive.box<Extramodel>('extra');
    setState(() {
      availableExtras = extraBox.values.toList();
    });
  }

  void _initializeSelections() {
    selectedExtraIds = Set<String>.from(widget.selectedExtraIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Extras',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: primarycolor),
            onPressed: () => _showAddExtraDialog(),
            tooltip: 'Add New Extra',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: availableExtras.isEmpty
                ? _buildEmptyState()
                : _buildExtraList(),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 20),
            Text(
              'No Extras Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Create your first extra category to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            CommonButton(
              onTap: () => _showAddExtraDialog(),
              bgcolor: primarycolor,
              bordercircular: 10,
              height: 50,
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Add Extra',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraList() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select extra categories for this item:',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),

          ...availableExtras.map<Widget>((extra) {
            final isSelected = selectedExtraIds.contains(extra.Id);
            final toppingCount = extra.topping?.length ?? 0;

            return Container(
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? primarycolor : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? primarycolor.withValues(alpha: 0.05) : Colors.white,
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      selectedExtraIds.add(extra.Id);
                    } else {
                      selectedExtraIds.remove(extra.Id);
                    }
                  });
                },
                activeColor: primarycolor,
                title: Text(
                  extra.Ename,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.grey[700],
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5),
                    Text(
                      '$toppingCount topping${toppingCount != 1 ? 's' : ''} available',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (extra.topping != null && extra.topping!.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: extra.topping!.take(3).map((topping) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: topping.isveg ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: topping.isveg ? Colors.green : Colors.red,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  topping.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()
                          ..add(
                            extra.topping!.length > 3
                                ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+${extra.topping!.length - 3}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                                : Container(),
                          ),
                      ),
                    ],
                    SizedBox(height: 5),
                  ],
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CommonButton(
              onTap: () => Navigator.pop(context),
              bgcolor: Colors.white,
              bordercolor: primarycolor,
              bordercircular: 10,
              height: ResponsiveHelper.responsiveHeight(context, 0.06),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: primarycolor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: CommonButton(
              onTap: () {
                Navigator.pop(context, selectedExtraIds.toList());
              },
              bordercircular: 10,
              height: ResponsiveHelper.responsiveHeight(context, 0.06),
              child: Text(
                'Save',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExtraDialog() {
    final extraNameController = TextEditingController();
    final List<Map<String, dynamic>> toppingData = [
      {
        'nameController': TextEditingController(),
        'priceController': TextEditingController(),
        'isVeg': true,
      }
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add New Extra',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter extra category name and toppings',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 15),
                    CommonTextForm(
                      controller: extraNameController,
                      labelText: 'Category Name (e.g., Add-ons)',
                      obsecureText: false,
                      borderc: 8,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Toppings:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    ...List.generate(toppingData.length, (index) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 15),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Topping ${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                if (toppingData.length > 1)
                                  IconButton(
                                    icon: Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setDialogState(() {
                                        toppingData[index]['nameController'].dispose();
                                        toppingData[index]['priceController'].dispose();
                                        toppingData.removeAt(index);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            SizedBox(height: 8),
                            CommonTextForm(
                              controller: toppingData[index]['nameController'],
                              labelText: 'Topping Name',
                              obsecureText: false,
                              borderc: 8,
                            ),
                            SizedBox(height: 10),
                            CommonTextForm(
                              controller: toppingData[index]['priceController'],
                              labelText: 'Price',
                              obsecureText: false,
                              borderc: 8,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Type:',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        groupValue: toppingData[index]['isVeg'],
                                        onChanged: (value) {
                                          setDialogState(() {
                                            toppingData[index]['isVeg'] = value!;
                                          });
                                        },
                                        activeColor: Colors.green,
                                      ),
                                      Icon(Icons.circle, color: Colors.green, size: 12),
                                      SizedBox(width: 4),
                                      Text('Veg', style: GoogleFonts.poppins(fontSize: 12)),
                                      SizedBox(width: 15),
                                      Radio<bool>(
                                        value: false,
                                        groupValue: toppingData[index]['isVeg'],
                                        onChanged: (value) {
                                          setDialogState(() {
                                            toppingData[index]['isVeg'] = value!;
                                          });
                                        },
                                        activeColor: Colors.red,
                                      ),
                                      Icon(Icons.circle, color: Colors.red, size: 12),
                                      SizedBox(width: 4),
                                      Text('Non-Veg', style: GoogleFonts.poppins(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          toppingData.add({
                            'nameController': TextEditingController(),
                            'priceController': TextEditingController(),
                            'isVeg': true,
                          });
                        });
                      },
                      icon: Icon(Icons.add_circle_outline, color: primarycolor),
                      label: Text(
                        'Add Topping',
                        style: GoogleFonts.poppins(color: primarycolor),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (var data in toppingData) {
                      data['nameController'].dispose();
                      data['priceController'].dispose();
                    }
                    extraNameController.dispose();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (extraNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter an extra category name'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Collect all valid toppings
                    final toppings = <Topping>[];
                    for (var data in toppingData) {
                      final name = data['nameController'].text.trim();
                      final priceText = data['priceController'].text.trim();

                      if (name.isNotEmpty && priceText.isNotEmpty) {
                        final price = double.tryParse(priceText);
                        if (price != null && price >= 0) {
                          toppings.add(Topping(
                            name: name,
                            isveg: data['isVeg'],
                            price: price,
                          ));
                        }
                      }
                    }

                    if (toppings.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please add at least one valid topping'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final newExtra = Extramodel(
                      Id: Uuid().v4(),
                      Ename: extraNameController.text.trim(),
                      isEnabled: true,
                      topping: toppings,
                    );

                    final extraBox = Hive.box<Extramodel>('extra');
                    await extraBox.put(newExtra.Id, newExtra);

                    _loadExtras();

                    for (var data in toppingData) {
                      data['nameController'].dispose();
                      data['priceController'].dispose();
                    }
                    extraNameController.dispose();
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Extra "${newExtra.Ename}" added with ${toppings.length} toppings'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primarycolor,
                  ),
                  child: Text(
                    'Add',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}