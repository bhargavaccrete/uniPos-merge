import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/bottomsheet.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/images.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../../widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/common/currency_helper.dart';

class AllTab extends StatefulWidget {
  const AllTab({super.key});

  @override
  State<AllTab> createState() => _AllTabState();
}

class _AllTabState extends State<AllTab> {
  String query = '';
  final TextEditingController searchController = TextEditingController();
  final Map<String, GlobalKey> _categoryKeys = {};

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
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Modern Search Bar
          Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: searchController,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      hintText: 'Search categories, items, variants...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 22),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey, size: 20),
                              onPressed: () {
                                searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),

              // Content Area
              Expanded(
                child: Observer(
                  builder: (_) {
                    final allCategories = categoryStore.categories.toList();
                    final allItems = itemStore.items.toList();
                    final allVariants = variantStore.variants.toList();

                    final filtercat = query.isEmpty
                        ? allCategories
                        : allCategories.where((cat) {
                            final name = cat.name.toLowerCase();
                            final queryLower = query.toLowerCase();
                            return name.contains(queryLower);
                          }).toList();

                    final Map<String, List<Items>> categoryItemsMap = {};
                    for (var category in allCategories) {
                      categoryItemsMap[category.id] = allItems
                          .where((item) => item.categoryOfItem == category.id)
                          .toList();
                    }

                    if (allCategories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(AppImages.notfoundanimation, height: height * 0.25),
                            SizedBox(height: 16),
                            Text(
                              'No Categories Found!',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start by adding categories to organize your menu',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: filtercat.length,
                      itemBuilder: (context, index) {
                        final cat = filtercat[index];
                        final items = categoryItemsMap[cat.id] ?? [];

                        // Create or get key for this category
                        if (!_categoryKeys.containsKey(cat.id)) {
                          _categoryKeys[cat.id] = GlobalKey();
                        }

                        return Card(
                          key: _categoryKeys[cat.id],
                          margin: EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              childrenPadding: EdgeInsets.only(bottom: 12),
                              leading: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.category,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                cat.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                '${items.length} items',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              children: items.isEmpty
                                  ? [
                                      Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              "No items in this category",
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]
                                  : items.map((item) {
                                      return Container(
                                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: item.isEnabled
                                                ? Colors.grey.shade200
                                                : Colors.red.shade100,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.03),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            // Item Header
                                            Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  // Item Icon
                                                  Container(
                                                    padding: EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: item.isEnabled
                                                          ? Colors.green.withOpacity(0.1)
                                                          : Colors.red.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Icon(
                                                      Icons.restaurant_menu,
                                                      color: item.isEnabled ? Colors.green : Colors.red,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  SizedBox(width: 12),

                                                  // Item Info
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          item.name,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding: EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.primary.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                "${CurrencyHelper.currentSymbol}${item.price != null ? DecimalSettings.formatAmount(item.price!) : "N/A"}",
                                                                style: GoogleFonts.poppins(
                                                                  fontSize: 13,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: AppColors.primary,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Status Toggle
                                                  Transform.scale(
                                                    scale: 0.9,
                                                    child: Switch(
                                                      activeColor: Colors.white,
                                                      activeTrackColor: Colors.green,
                                                      inactiveThumbColor: Colors.white70,
                                                      inactiveTrackColor: Colors.red.shade300,
                                                      value: item.isEnabled,
                                                      onChanged: (bool value) async {
                                                        await itemStore.toggleItemStatus(item.id);
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Variants Section
                                            if (item.variant != null && item.variant!.isNotEmpty)
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius: BorderRadius.only(
                                                    bottomLeft: Radius.circular(12),
                                                    bottomRight: Radius.circular(12),
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.tune,
                                                          size: 14,
                                                          color: AppColors.primary,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          "Variants (${item.variant!.length})",
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 8),
                                                    ...item.variant!.map((variant) {
                                                      final variantData = allVariants.firstWhere(
                                                        (v) => v.id == variant.variantId,
                                                        orElse: () => VariantModel(
                                                            id: variant.variantId, name: 'Unknown'),
                                                      );
                                                      return Container(
                                                        margin: EdgeInsets.only(bottom: 6),
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: Colors.grey.shade200,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Container(
                                                                  width: 6,
                                                                  height: 6,
                                                                  decoration: BoxDecoration(
                                                                    color: AppColors.primary,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                ),
                                                                SizedBox(width: 8),
                                                                Text(
                                                                  variantData.name,
                                                                  style: GoogleFonts.poppins(
                                                                    fontSize: 12,
                                                                    color: Colors.grey.shade700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            Text(
                                                              "${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(variant.price)}",
                                                              style: GoogleFonts.poppins(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.black87,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

          // Bottom Sheet Menu
          BottomsheetMenu(
            onItemAdded: () {
              // Show success feedback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Item added successfully!',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}