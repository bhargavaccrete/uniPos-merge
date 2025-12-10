import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart'; // <-- Import hive_flutter
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/all_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/categories_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/choice_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/extra_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/items_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/variant_tab.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/bottomsheet.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'package:uuid/uuid.dart';

import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../util/restaurant/images.dart';
import '../../../../widget/componets/restaurant/componets/Textform.dart';





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
  void initState(){
    super.initState();

    searchController.addListener((){
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
                  gesture: Icon(Icons.search,color: Colors.grey,),
                  BorderColor: Colors.grey,
                  obsecureText: false,
                controller: searchController,
                ),
              ),

              // ✅ This builder automatically listens for any changes in your Hive boxes
              ValueListenableBuilder(
                // Listens to the 'categories' box
                valueListenable: Hive.box<Category>('restaurant_categories').listenable(),
                builder: (context, categoryBox, _) {
                  return ValueListenableBuilder(
                    // Listens to the 'items' box
                    valueListenable: Hive.box<Items>('itemBoxs').listenable(),
                    builder: (context, itemBox, _) {
                      return ValueListenableBuilder(
                        // Listens to the 'variants' box
                        valueListenable: Hive.box<VariantModel>('variants').listenable(),
                        builder: (context, variantBox, _) {
                      final allCategories = categoryBox.values.toList();

                      final filtercat = query.isEmpty
                      ?allCategories
                          :allCategories.where((cat){
                            final name = cat.name.toLowerCase();
                            final queryLower = query.toLowerCase();
                            return name.contains(queryLower);
                      }).toList();


                      final allItems = itemBox.values.toList();

                      // This logic now runs automatically whenever data changes
                      final Map<String, List<Items>> categoryItemsMap = {};
                      for (var category in allCategories) {
                        categoryItemsMap[category.id] = allItems
                            .where((item) => item.categoryOfItem == category.id)
                            .toList();
                      }

                      // --- Build UI with the always-fresh data ---
                      if (allCategories.isEmpty) {
                        return Container(
                          height: height * 0.65,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Lottie.asset(notfoundanimation, height: height * 0.3),
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
                              title: Text(
                                cat.name,
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              children:
                              items.isEmpty
                                  ? [
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("No items in this category"),
                                )
                              ]
                                  :
                              items.map((item) {
                                return Container(
                                  padding: EdgeInsets.all(5),
                                  width: width * 0.9,

                                  margin: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black)
                                  ),
                                  // color: Colors.red,
                                  child: Column(
                                    crossAxisAlignment:CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(item.name),
                                          Row(
                                            children: [
                                              Text("₹${item.price ?? "N/A"}"),
                                              Transform.scale(
                                                  scale: 0.8,
                                                  child:Switch(

                                                    // thumb when ON
                                                      activeColor: Colors.white,
                                                      // track when ON
                                                      activeTrackColor: primarycolor,
                                                      // thumb when OFF
                                                      inactiveThumbColor: Colors.white70,
                                                      // track when OFF
                                                      inactiveTrackColor: Colors.grey.shade400,
                                                      value: item.isEnabled,
                                                      onChanged: (bool value)async{
                                                        item.isEnabled = value;
                                                        await item.save();

                                                      })),
                                            ],
                                          )
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
                                                color: Colors.grey[600]
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            ...item.variant!.map((variant) {
                                              final variantData = variantBox.values.firstWhere(
                                                (v) => v.id == variant.variantId,
                                                orElse: () => VariantModel(id: variant.variantId, name: 'Unknown')
                                              );
                                              return Padding(
                                                padding: EdgeInsets.only(left: 8, bottom: 2),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      "• ${variantData.name}",
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        color: Colors.grey[700]
                                                      ),
                                                    ),
                                                    Text(
                                                      "₹${variant.price}",
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                        color: primarycolor
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                    ],



                                  )
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
              BottomsheetMenu()
            ],
          ),
        ),
      ),
    );
  }



}


/*
import 'package:flutter/material.dart';
import 'package:BillBerry/componets/Textform.dart';
import 'package:BillBerry/componets/bottomsheet.dart';
import 'package:BillBerry/model/db/categorymodel_0.dart';
import 'package:BillBerry/model/db/itemmodel_2.dart';
import 'package:BillBerry/model/db/variantmodel_5.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';

import '../../../constant/color.dart';

class AllTab extends StatefulWidget {
  const AllTab({super.key});

  @override
  State<AllTab> createState() => _AllTabState();
}

class _AllTabState extends State<AllTab> {
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
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Header + Search ----
                Text(
                  "All Items",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: CommonTextForm(
                    borderc: 12,
                    labelText: 'Search Category',
                    LabelColor: Colors.grey.shade600,
                    gesture: const Icon(Icons.search, color: Colors.grey),
                    BorderColor: Colors.transparent,
                    obsecureText: false,
                    controller: searchController,
                  ),
                ),
                const SizedBox(height: 12),

                // ---- Reactive lists (unchanged functionality) ----
                ValueListenableBuilder(
                  valueListenable: Hive.box<Category>('restaurant_categories').listenable(),
                  builder: (context, categoryBox, _) {
                    return ValueListenableBuilder(
                      valueListenable: Hive.box<Items>('itemBoxs').listenable(),
                      builder: (context, itemBox, _) {
                        return ValueListenableBuilder(
                          valueListenable: Hive.box<VariantModel>('variants').listenable(),
                          builder: (context, variantBox, _) {
                            final allCategories = categoryBox.values.toList();

                            final filtercat = query.isEmpty
                                ? allCategories
                                : allCategories.where((cat) {
                              final name = cat.name.toLowerCase();
                              final queryLower = query.toLowerCase();
                              return name.contains(queryLower);
                            }).toList();

                            final allItems = itemBox.values.toList();

                            final Map<String, List<Items>> categoryItemsMap = {};
                            for (var category in allCategories) {
                              categoryItemsMap[category.id] = allItems
                                  .where((item) => item.categoryOfItem == category.id)
                                  .toList();
                            }

                            if (allCategories.isEmpty) {
                              return SizedBox(
                                height: height * 0.6,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Lottie.asset(
                                      'assets/animation/notfoundanimation.json',
                                      height: height * 0.28,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No Categories Found!',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add your first category to get started.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Container(
                              height: height * 0.62,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  expansionTileTheme: ExpansionTileThemeData(
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    collapsedShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                child: ListView.separated(
                                  itemCount: filtercat.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final cat = filtercat[index];
                                    final items = categoryItemsMap[cat.id] ?? [];
                                    final itemCount = items.length;

                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white,
                                            Colors.white,
                                            const Color(0xFFFDFDFE),
                                          ],
                                        ),
                                        border: Border.all(color: Colors.grey.shade200),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            offset: const Offset(0, 6),
                                            blurRadius: 14,
                                          ),
                                        ],
                                      ),
                                      child: ExpansionTile(
                                        leading: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: primarycolor.withOpacity(0.12),
                                          child: Text(
                                            cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
                                            style: GoogleFonts.poppins(
                                              color: primarycolor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                cat.name,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(color: Colors.grey.shade200),
                                              ),
                                              child: Text(
                                                '$itemCount items',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        children: items.isEmpty
                                            ? [
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.inbox_outlined, color: Colors.grey.shade500),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "No items in this category",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ]
                                            : items.map((item) {
                                          return _ItemCard(
                                            width: width,
                                            item: item,
                                            variantBox: variantBox,
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),
                Center(child: BottomsheetMenu()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final double width;
  final Items item;
  final Box<VariantModel> variantBox;

  const _ItemCard({
    required this.width,
    required this.item,
    required this.variantBox,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width * 0.9,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Name + Price + Toggle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primarycolor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primarycolor.withOpacity(0.18)),
                ),
                child: Text(
                  "₹${item.price ?? "N/A"}",
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: primarycolor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  activeColor: Colors.white,
                  activeTrackColor: primarycolor,
                  inactiveThumbColor: Colors.white70,
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

          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade200, height: 1),

          // Variants
          if (item.variant != null && item.variant!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Variations",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.variant!.map((variant) {
                final variantData = variantBox.values.firstWhere(
                      (v) => v.id == variant.variantId,
                  orElse: () => VariantModel(id: variant.variantId, name: 'Unknown'),
                );

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        variantData.name,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 18,
                        width: 1.2,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "₹${variant.price}",
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: primarycolor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
*/
