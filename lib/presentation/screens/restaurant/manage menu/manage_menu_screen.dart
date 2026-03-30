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
  final ScrollController _tabScrollController = ScrollController();
  final List<GlobalKey> _tabKeys = List.generate(6, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 6, vsync: this);
    // Use animation listener for real-time tab highlight during swipe
    tabController.animation!.addListener(() {
      final newIndex = tabController.animation!.value.round();
      if (newIndex != tabController.index && !tabController.indexIsChanging) {
        // During swipe — update highlight immediately
        setState(() {});
      }
    });
    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        // After swipe settles — final update + scroll
        setState(() {});
        _scrollToSelectedTab(tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    tabController.dispose();
    super.dispose();
  }

  /// Scrolls the tab bar so the selected tab is visible and centered
  void _scrollToSelectedTab(int index) {
    final keyContext = _tabKeys[index].currentContext;
    if (keyContext == null || !_tabScrollController.hasClients) return;

    final renderBox = keyContext.findRenderObject() as RenderBox;
    final tabOffset = renderBox.localToGlobal(Offset.zero).dx;
    final tabWidth = renderBox.size.width;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate scroll offset to center the selected tab
    final targetScroll = _tabScrollController.offset +
        tabOffset -
        (screenWidth / 2) +
        (tabWidth / 2);

    _tabScrollController.animateTo(
      targetScroll.clamp(0.0, _tabScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildTabButton(int index, String label, int count, bool isTablet) {
    final isSelected = tabController.animation!.value.round() == index;
    return GestureDetector(
      key: _tabKeys[index],
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
          boxShadow: [],
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
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
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
          IconButton(
            icon: Icon(Icons.upload_file, color: Colors.black87),
            tooltip: 'Import',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkImportTestScreenV3()));
            },
          ),
          SizedBox(width: 4),
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
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                  controller: _tabScrollController,
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
