import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart'; // <-- Import hive_flutter
import 'package:lottie/lottie.dart';
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/bottomsheet.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/images.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';

import '../../../../../util/restaurant/images.dart';
import '../../../../widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/common/currency_helper.dart';

class AllTab extends StatefulWidget {
  const AllTab({super.key});

  @override
  State<AllTab> createState() => _AllTabState();
}

class _AllTabState extends State<AllTab> {
  // We no longer need initState, categories, categoryItemsMap, or loadCategoriesAndItems()!

  String query = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      setState(() {
        query = searchController.text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // Search Bar UI...
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: CommonTextForm(
                  borderc: 5,
                  labelText: 'Search Category',
                  LabelColor: Colors.grey,
                  gesture: Icon(Icons.search, color: Colors.grey),
                  BorderColor: Colors.grey,
                  obsecureText: false,
                  controller: searchController,
                ),
              ),

              // ✅ This builder automatically listens for any changes in your Hive boxes
              ValueListenableBuilder(
                // Listens to the 'categories' box
                valueListenable: Hive.box<Category>('categories').listenable(),
                builder: (context, Box<Category> categoryBox, _) {
                  final allCategories = categoryBox.values.toList();

                  return ValueListenableBuilder(
                    // Listens to the 'items' box
                    valueListenable: Hive.box<Items>('itemBoxs').listenable(),
                    builder: (context, Box<Items> itemBox, _) {
                      final allItems = itemBox.values.toList();

                      return ValueListenableBuilder(
                        // Listens to the 'variants' box
                        valueListenable: Hive.box<VariantModel>('variante').listenable(),
                        builder: (context, Box<VariantModel> variantBox, _) {
                          final filtercat = query.isEmpty
                              ? allCategories
                              : allCategories.where((cat) {
                                  final name = cat.name.toLowerCase();
                                  final queryLower = query.toLowerCase();
                                  return name.contains(queryLower);
                                }).toList();

                          // This logic now runs automatically whenever data changes
                          final Map<String, List<Items>> categoryItemsMap = {};
                          for (var category in allCategories) {
                            categoryItemsMap[category.id] = allItems.where((item) => item.categoryOfItem == category.id).toList();
                          }

                          // --- Build UI with the always-fresh data ---
                          if (allCategories.isEmpty) {
                            return Container(
                              height: height * 0.65,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Lottie.asset(AppImages.notfoundanimation, height: height * 0.3),
                                  Text('No Categories Found!', style: GoogleFonts.poppins(fontSize: 16)),
                                ],
                              ),
                            );
                          }

                          return Container(
                            // color: Colors.red,
                            height: height * 0.6, // Consider making this more flexible with Expanded
                            child: ListView.builder(
                              itemCount: filtercat.length,
                              itemBuilder: (context, index) {
                                final cat = filtercat[index];
                                final items = categoryItemsMap[cat.id] ?? [];

                                return ExpansionTile(
                                  title: Text(cat.name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                                  children: items.isEmpty
                                      ? [const Padding(padding: EdgeInsets.all(8.0), child: Text("No items in this category"))]
                                      : items.map((item) {
                                          return Container(
                                            padding: EdgeInsets.all(5),
                                            width: width * 0.9,

                                            margin: EdgeInsets.all(5),
                                            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                                            // color: Colors.red,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(item.name),
                                                    Row(
                                                      children: [
                                                        Text("${CurrencyHelper.currentSymbol}${item.price != null ? DecimalSettings.formatAmount(item.price!) : "N/A"}"),
                                                        Transform.scale(
                                                          scale: 0.8,
                                                          child: Switch(
                                                            // thumb when ON
                                                            activeColor: Colors.white,
                                                            // track when ON
                                                            activeTrackColor: AppColors.primary,
                                                            // thumb when OFF
                                                            inactiveThumbColor: Colors.white70,
                                                            // track when OFF
                                                            inactiveTrackColor: Colors.grey.shade400,
                                                            value: item.isEnabled,
                                                            onChanged: (bool value) async {
                                                              item.isEnabled = value;
                                                              await item.save();
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),

                                                Divider(),
                                                if (item.variant != null && item.variant!.isNotEmpty)
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Variations:",
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      ...item.variant!.map((variant) {
                                                        final variantData = variantBox.values.firstWhere(
                                                          (v) => v.id == variant.variantId,
                                                          orElse: () => VariantModel(id: variant.variantId, name: 'Unknown'),
                                                        );
                                                        return Padding(
                                                          padding: EdgeInsets.only(left: 8, bottom: 2),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Text(
                                                                "• ${variantData.name}",
                                                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
                                                              ),
                                                              Text(
                                                                "${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(variant.price)}",
                                                                style: GoogleFonts.poppins(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w500,
                                                                  color: AppColors.primary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              // BottomsheetMenu no longer needs a callback, as the UI is reactive
              BottomsheetMenu(),
            ],
          ),
        ),
      ),
    );
  }
}
