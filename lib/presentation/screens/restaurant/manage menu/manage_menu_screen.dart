import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/all_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/categories_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/choice_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/extra_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/items_tab.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/variant_tab.dart';
import 'package:unipos/util/color.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import '../import/bulk_import_test_screen_v3.dart';

class Managemenu extends StatefulWidget {
  const Managemenu({super.key});

  @override
  State<Managemenu> createState() => _ManagemenuState();
}

class _ManagemenuState extends State<Managemenu>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 6, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
  }

  Widget _buildTabButton(int index, String label, int count, bool isTablet) {
    final isSelected = tabController.index == index;
    return GestureDetector(
      onTap: () {
        tabController.animateTo(index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 20,
          vertical: isTablet ? 14 : 12,
        ),
        margin: EdgeInsets.only(right: isTablet ? 12 : 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15 : 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            SizedBox(width: isTablet ? 8 : 6),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 10 : 8,
                vertical: isTablet ? 3 : 2,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 13 : 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1200;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Menu Management',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          // Import Button
          Container(
            margin: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: isTablet ? 12 : 8,
            ),
            child: ElevatedButton.icon(
              icon: Icon(Icons.upload_file, size: isTablet ? 20 : 18),
              label: Text(
                'Import',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 8,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BulkImportTestScreenV3(),
                  ),
                );
              },
            ),
          ),

          // Admin Badge
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: isTablet ? 22 : 20,
                    color: AppColors.primary,
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      drawer: DrawerManage(islogout: true, isDelete: false, issync: false),
      body: Column(
        children: [
          // Modern Tab Bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
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
            child: Observer(
              builder: (_) {
                final totalCount = categoryStore.categoryCount +
                    itemStore.itemCount +
                    variantStore.totalVariants +
                    choiceStore.totalChoices +
                    extraStore.totalExtras;

                // For desktop/large tablets, show tabs in a centered row
                if (isDesktop) {
                  return Center(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildTabButton(0, 'All', totalCount, isTablet),
                        _buildTabButton(1, 'Items', itemStore.itemCount, isTablet),
                        _buildTabButton(2, 'Categories', categoryStore.categoryCount, isTablet),
                        _buildTabButton(3, 'Variants', variantStore.totalVariants, isTablet),
                        _buildTabButton(4, 'Choices', choiceStore.totalChoices, isTablet),
                        _buildTabButton(5, 'Extras', extraStore.totalExtras, isTablet),
                      ],
                    ),
                  );
                }

                // For mobile and tablet, show horizontal scroll
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton(0, 'All', totalCount, isTablet),
                      _buildTabButton(1, 'Items', itemStore.itemCount, isTablet),
                      _buildTabButton(2, 'Categories', categoryStore.categoryCount, isTablet),
                      _buildTabButton(3, 'Variants', variantStore.totalVariants, isTablet),
                      _buildTabButton(4, 'Choices', choiceStore.totalChoices, isTablet),
                      _buildTabButton(5, 'Extras', extraStore.totalExtras, isTablet),
                    ],
                  ),
                );
              },
            ),
          ),

          // Tab Content
          Expanded(
            child: isDesktop
                ? Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 1400),
                      child: TabBarView(
                        controller: tabController,
                        children: [
                          AllTab(),
                          ItemsTab(),
                          CategoryTab(),
                          VariantTab(),
                          ChoiceTab(),
                          ExtraTab(),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: tabController,
                    children: [
                      AllTab(),
                      ItemsTab(),
                      CategoryTab(),
                      VariantTab(),
                      ChoiceTab(),
                      ExtraTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
