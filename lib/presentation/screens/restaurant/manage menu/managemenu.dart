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

import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/constants/restaurant/color.dart';


import '../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../data/models/restaurant/db/choiceoptionmodel_307.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
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
    // TODO: implement initState
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
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Items>('itemBoxs').listenable(),
              builder: (context, Box<Items> itemBox, _) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box<Category>('categories').listenable(),
                  builder: (context, Box<Category> categoryBox, _) {
                    return ValueListenableBuilder(
                      valueListenable: Hive.box<VariantModel>('variante').listenable(),
                      builder: (context, Box<VariantModel> variantBox, _) {
                        return ValueListenableBuilder(
                          valueListenable: Hive.box<ChoicesModel>('choice').listenable(),
                          builder: (context, Box<ChoicesModel> choiceBox, _) {
                            return ValueListenableBuilder(
                              valueListenable: Hive.box<Extramodel>('extra').listenable(),
                              builder: (context, Box<Extramodel> extraBox, _) {
                                // Get counts
                                final itemCount = itemBox.length;
                                final categoryCount = categoryBox.length;
                                final variantCount = variantBox.length;
                                final choiceCount = choiceBox.length;
                                final extraCount = extraBox.length;
                                final totalCount = itemCount + categoryCount + variantCount + choiceCount + extraCount;

                                return TabBar(
                                  labelPadding: EdgeInsets.symmetric(horizontal: 50),
                                  isScrollable: true,
                                  controller: tabController,
                                  labelColor: Colors.black,
                                  unselectedLabelColor: Colors.grey,
                                  dividerColor: Colors.transparent,
                                  indicatorColor: primarycolor,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  indicator: UnderlineTabIndicator(
                                      borderSide: BorderSide(width: 3.0, color: primarycolor),
                                      insets: EdgeInsets.symmetric(horizontal: 20)
                                  ),
                                  tabs: [
                                    Tab(
                                      text: 'All ($totalCount)',
                                    ),
                                    Tab(
                                      text: "Items ($itemCount)",
                                    ),
                                    Tab(
                                      text: 'Categories ($categoryCount)',
                                    ),
                                    Tab(
                                      text: 'Variant ($variantCount)',
                                    ),
                                    Tab(
                                      text: 'Choice ($choiceCount)',
                                    ),
                                    Tab(
                                      text: 'Extra ($extraCount)',
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),

        // bottom: PreferredSize(
        //   preferredSize: Size.fromHeight(48),
        //   child: Container(
        //     width: double.infinity,
        //     child: TabBar(
        //       isScrollable: true,
        //       // indicatorSize: TabBarIndicatorSize.values(),
        //       controller: tabController,
        //       labelColor: Colors.white,
        //       unselectedLabelColor: Colors.grey,
        //       dividerColor: Colors.transparent,
        //
        //       indicatorColor: Primarysecond,
        //       indicatorSize: TabBarIndicatorSize.tab,
        //       indicator: BoxDecoration(
        //           color: primarycolor, borderRadius: BorderRadius.circular(2)),
        //
        //         tabs: const [
        //
        //               Tab(
        //                 text: 'All',
        //               ),
        //               Tab(
        //                 text: "items",
        //               ),
        //               Tab(
        //                 text: 'Categories',
        //               ),
        //               Tab(
        //                 text: 'Variant',
        //               ),
        //               Tab(
        //                 text: 'Choice',
        //               ),
        //               Tab(
        //                 text: 'Extra',
        //               ),
        //             ],
        //     ),
        //   ),
        // ),
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
