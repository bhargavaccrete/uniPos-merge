import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/tab/all_tab.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/tab/categories_tab.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/tab/choice_tab.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/tab/extra_tab.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/tab/items_tab.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/tab/variant_tab.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import '../import/bulk_import_screen.dart';

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
    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        // After swipe settles — scroll to selected tab
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
    final targetScroll =
        _tabScrollController.offset +
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
      onTap: () => tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.largeSpacing(context),
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          count > 0 ? '$label · $count' : label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final isDesktop = AppResponsive.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: buildPrimaryAppBar(
        title: 'Menu Management',
        titleFontSize: AppResponsive.headingFontSize(context),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            tooltip: 'Import',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RestaurantBulkImportScreen(),
                ),
              );
            },
          ),
          SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Modern Tab Bar
          Container(
            width: double.infinity,
            padding: AppResponsive.padding(context),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Observer(
              builder: (_) {
                final totalCount =
                    categoryStore.categoryCount +
                    itemStore.itemCount +
                    variantStore.totalVariants +
                    choiceStore.totalChoices +
                    extraStore.totalExtras;

                // AnimatedBuilder scopes tab-highlight rebuilds to this subtree only
                return AnimatedBuilder(
                  animation: tabController.animation!,
                  builder: (_, __) {
                    // For desktop only, show tabs in a centered wrap (no scroll)
                    if (isDesktop) {
                      return Center(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildTabButton(0, 'All', totalCount, isTablet),
                            _buildTabButton(
                              1,
                              'Items',
                              itemStore.itemCount,
                              isTablet,
                            ),
                            _buildTabButton(
                              2,
                              'Categories',
                              categoryStore.categoryCount,
                              isTablet,
                            ),
                            _buildTabButton(
                              3,
                              'Variants',
                              variantStore.totalVariants,
                              isTablet,
                            ),
                            _buildTabButton(
                              4,
                              'Choices',
                              choiceStore.totalChoices,
                              isTablet,
                            ),
                            _buildTabButton(
                              5,
                              'Extras',
                              extraStore.totalExtras,
                              isTablet,
                            ),
                          ],
                        ),
                      );
                    }

                    // Mobile + tablet: horizontal scroll
                    return SingleChildScrollView(
                      controller: _tabScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton(0, 'All', totalCount, isTablet),
                          _buildTabButton(
                            1,
                            'Items',
                            itemStore.itemCount,
                            isTablet,
                          ),
                          _buildTabButton(
                            2,
                            'Categories',
                            categoryStore.categoryCount,
                            isTablet,
                          ),
                          _buildTabButton(
                            3,
                            'Variants',
                            variantStore.totalVariants,
                            isTablet,
                          ),
                          _buildTabButton(
                            4,
                            'Choices',
                            choiceStore.totalChoices,
                            isTablet,
                          ),
                          _buildTabButton(
                            5,
                            'Extras',
                            extraStore.totalExtras,
                            isTablet,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Tab Content — the page shell. Applied at every breakpoint, not
          // just desktop: the old `isDesktop ?` branch left tablet full-bleed,
          // so this screen's gutters disagreed with its own desktop layout.
          // maxContentWidth is infinity on mobile, so the cap is a no-op there
          // and the separate uncapped branch is no longer needed.
          Expanded(
            child: AppResponsive.constrainedContent(
              context: context,
              maxWidth: AppResponsive.maxContentWidth(context),
              alignment: Alignment.topCenter,
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
          ),
        ],
      ),
    );
  }
}
