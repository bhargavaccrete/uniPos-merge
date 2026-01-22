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

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        // automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Import',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BulkImportTestScreenV3(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.person),
                Text(
                  'Admin',
                  style: GoogleFonts.poppins(),
                )
              ],
            ),
          )
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Container(
            width: double.infinity,
            child: Observer(
              builder: (_) {
                // Calculate total count from all stores
                final totalCount = categoryStore.categoryCount +
                                  itemStore.itemCount +
                                  variantStore.totalVariants +
                                  choiceStore.totalChoices +
                                  extraStore.totalExtras;

                return TabBar(
                  labelPadding: EdgeInsets.symmetric(horizontal: 50),
                  isScrollable: true,
                  controller: tabController,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  dividerColor: Colors.transparent,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(width: 3.0, color: AppColors.primary),
                    insets: EdgeInsets.symmetric(horizontal: 20)
                  ),
                  tabs: [
                    Tab(text: 'All ($totalCount)'),
                    Tab(text: "Items (${itemStore.itemCount})"),
                    Tab(text: 'Categories (${categoryStore.categoryCount})'),
                    Tab(text: 'Variant (${variantStore.totalVariants})'),
                    Tab(text: 'Choice (${choiceStore.totalChoices})'),
                    Tab(text: 'Extra (${extraStore.totalExtras})'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      drawer: DrawerManage(islogout:true,isDelete:true, issync: false,),
      body: TabBarView(controller: tabController, children: [
        AllTab(),
        ItemsTab(),
        CategoryTab(),
        VariantTab(),
        ChoiceTab(),
        ExtraTab(),
      ]),
    );
  }
}
