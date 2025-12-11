import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/drawer.dart';
import '../Desktop/online_Order_desktop/online.dart';
import '../tabbar/menu.dart';
import '../tabbar/order.dart';
import '../tabbar/table.dart';

class Startorder extends StatefulWidget {
  final OrderModel? existingOrder;
  final bool? isForAddingItem;
  final String? newOrderForTableId;

  const Startorder({super.key,
    this.isForAddingItem,
    this.existingOrder, this.newOrderForTableId});

  @override
  State<Startorder> createState() => _StartorderState();
}

class _StartorderState extends State<Startorder>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  // --- STATE FOR MANAGING THE CURRENT ORDER ---
  List<CartItem> _currentCartItems = [];
  String? _tableIdForCurrentSession;
  double get _totalPrice => _currentCartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
    // Initialize state based on what was passed to the widget
    if (widget.existingOrder != null) {
      _currentCartItems = List.from(widget.existingOrder!.items);
      _tableIdForCurrentSession = widget.existingOrder!.tableNo;
    } else if (widget.newOrderForTableId != null) {
      _tableIdForCurrentSession = widget.newOrderForTableId;
      tabController.index = 0; // Default to menu for a new order
    }

    tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }







  @override
  /// Builds the detailed view for an existing order (matches your screenshot).
  // Widget _buildExistingOrderView() {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('Order Details'),
  //       leading: IconButton(
  //         icon: const Icon(Icons.arrow_back),
  //         onPressed: () => Navigator.of(context).pop(),
  //       ),
  //       actions: [
  //         TextButton.icon(
  //           icon: const Icon(Icons.clear, color: Colors.white),
  //           label: const Text('Clear Cart', style: TextStyle(color: Colors.white)),
  //           style: TextButton.styleFrom(backgroundColor: primarycolor),
  //           onPressed: () {
  //             // You can add a confirmation dialog here
  //             setState(() {
  //               _currentCartItems.clear();
  //             });
  //           },
  //         )
  //       ],
  //     ),
  //     body: Column(
  //       children: [
  //         // Header buttons
  //         Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //             children: [
  //               ElevatedButton.icon(onPressed: (){}, icon: Icon(Icons.delivery_dining), label: Text('Take Away')),
  //               ElevatedButton.icon(onPressed: (){}, icon: Icon(Icons.dinner_dining), label: Text('Dine In'), style: ElevatedButton.styleFrom(backgroundColor: primarycolor)),
  //               ElevatedButton.icon(onPressed: (){}, icon: Icon(Icons.delivery_dining_outlined), label: Text('Delivery')),
  //             ],
  //           ),
  //         ),
  //         // Table Number and Headers
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           color: Colors.grey.shade200,
  //           child: Column(
  //             children: [
  //               if (_tableIdForCurrentSession != null) ...[
  //                 Container(
  //                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  //                   decoration: BoxDecoration(
  //                       border: Border.all(color: primarycolor),
  //                       borderRadius: BorderRadius.circular(20)
  //                   ),
  //                   child: Text('Table No: $_tableIdForCurrentSession', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
  //                 ),
  //                 const SizedBox(height: 10),
  //               ],
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Expanded(flex: 3, child: Text('Items', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
  //                   Expanded(flex: 2, child: Center(child: Text('QTY', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
  //                   Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('Amount', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //         // Items List
  //         Expanded(
  //           child: _currentCartItems.isEmpty
  //               ? const Center(child: Text('No items in this order.'))
  //               : ListView.separated(
  //             padding: const EdgeInsets.all(16),
  //             itemCount: _currentCartItems.length,
  //             separatorBuilder: (context, index) => const Divider(),
  //             itemBuilder: (context, index) {
  //               final item = _currentCartItems[index];
  //               return Row(
  //                 children: [
  //                   Expanded(
  //                     flex: 3,
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text('KOT - #${widget.existingOrder?.kotNumber ?? 'N/A'}', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
  //                         Text(item.title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
  //                       ],
  //                     ),
  //                   ),
  //                   Expanded(
  //                     flex: 2,
  //                     child: Row(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       children: [
  //                         IconButton(icon: Icon(Icons.remove_circle_outline, color: primarycolor), onPressed: () => _decreaseQuantity(item)),
  //                         Text(item.quantity.toString(), style: GoogleFonts.poppins(fontSize: 16)),
  //                         IconButton(icon: Icon(Icons.add_circle_outline, color: primarycolor), onPressed: () => _increaseQuantity(item)),
  //                       ],
  //                     ),
  //                   ),
  //                   Expanded(
  //                     flex: 2,
  //                     child: Align(
  //                       alignment: Alignment.centerRight,
  //                       child: Text('Rs. ${item.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
  //                     ),
  //                   ),
  //                 ],
  //               );
  //             },
  //           ),
  //         ),
  //         // Bottom Action Bar
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2)],
  //           ),
  //           child: Column(
  //             children: [
  //               CommonButton(
  //                 onTap: _addItem,
  //                 child: const Text('Add Itemm'),
  //               ),
  //               const SizedBox(height: 10),
  //               Row(
  //                 children: [
  //                   Expanded(child: CommonButton(onTap: () {}, child: Text('Settle (Rs. ${_totalPrice.toStringAsFixed(2)})'))),
  //                   const SizedBox(width: 10),
  //                   Expanded(child: CommonButton(onTap: _updateAndSaveChanges, child: const Text('Place Order'))),
  //                 ],
  //               ),
  //               const SizedBox(height: 10),
  //               CommonButton(onTap: () {}, child: const Text('Print Bill')),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// Builds the default TabBar view for starting new orders.
  Widget build(BuildContext context) {
    print(widget.newOrderForTableId ?? 'no table id ');
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return LayoutBuilder(
      builder: (context , constraints){
        if(constraints.maxWidth <700){
          return Scaffold(
            appBar: AppBar(
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    icon: Icon(Icons.menu, size: 28),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    padding: EdgeInsets.zero,        // remove unwanted padding
                    constraints: BoxConstraints(),   // remove default constraints
                    alignment: Alignment.center,     // force icon to stay centered
                  );
                },
              ),

              title: Text(
                'orange',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person),
                          Text(
                            'Admin',
                            style: GoogleFonts.poppins(fontSize: 12),
                            textScaler: TextScaler.linear(1),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(50),
                child: Container(
                  width: double.infinity,
                  child: TabBar(
                    isScrollable: false,
                    // indicatorSize: TabBarIndicatorSize.values(),
                    controller: tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    dividerColor: Colors.transparent,

                    indicatorColor: Primarysecond,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                        color: primarycolor, borderRadius: BorderRadius.circular(2)),

                    tabs: const [
                      Tab(
                        text: 'Menu',
                      ),
                      Tab(
                        text: 'Order',
                      ),
                      Tab(
                        text: 'Tables',
                      )
                    ],
                  ),
                ),
              ),
            ),
            drawer: Drawerr(),
            body: TabBarView(
              controller: tabController,
              children: [ MenuScreen(tableIdForNewOrder:_tableIdForCurrentSession,isForAddingItem: widget.isForAddingItem ?? false,), Order(), const TableScreen()],
            ),
          );
        }      else{
          return  Scaffold(
            appBar:AppBar(
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black.withValues(alpha: 1),
              elevation: 5,
              title: Text('Orange',style: GoogleFonts.poppins(fontWeight: FontWeight.w600),),
              actions: [
                Card(
                  color: Colors.white,
                  elevation: 25,
                  shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white,
                        width: 2.0,
                      )),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Text('15'),
                        SizedBox(width: 5,),
                        Image.asset('assets/icons/restaurant.png')
                        // Container(
                        //   padding: EdgeInsets.all(10),
                        //   decoration: BoxDecoration(
                        //     color: Colors.white,
                        //     shape: BoxShape.circle
                        //   ),
                        //   child: ,),
                      ],
                    ),
                  ),
                ),
                SizedBox(width:25),
                InkWell(
                  onTap: (){
                    Navigator.push(context, MaterialPageRoute(builder: (context)=> OnlineDesktop()));
                  },
                  child: Card(
                    color: Colors.white,
                    elevation: 25,
                    shape: StadiumBorder(
                        side: BorderSide(
                          color: Colors.white,
                          width: 2.0,
                        )),
                    // color: Colors.white,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        // color: Colors.white,
                        shape: BoxShape.circle,

                      ),
                      child: Image.asset('assets/icons/dinner.png'),),
                  ),
                ),
                SizedBox(width:10),

                Card(
                  color: Colors.white,
                  elevation: 25,
                  shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white,
                        width: 2.0,
                      )),
                  // color: Colors.white,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      shape: BoxShape.circle,

                    ),
                    child: Image.asset('assets/icons/volume.png'),),
                ),
                SizedBox(width:10),

                Card(
                  color: Colors.white,
                  elevation: 25,
                  shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white,
                        width: 2.0,
                      )),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle
                    ),
                    child: Image.asset('assets/icons/home.png'),),
                ),
                SizedBox(width:10),
                Card(
                  color: Colors.white,
                  elevation: 25,
                  shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white,
                        width: 2.0,
                      )),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle
                    ),
                    child: Image.asset('assets/icons/printer3.png'),),
                ),
                SizedBox(width:10),
                Card(
                  color: Colors.white,
                  elevation: 25,
                  shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white,
                        width: 2.0,
                      )),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle
                    ),
                    child: Image.asset('assets/icons/internet.png'),),
                ),
                SizedBox(width:10),
                Card(
                    color: Colors.white,
                    elevation: 25,
                    shape: StadiumBorder(
                        side: BorderSide(
                          color: Colors.white,
                          width: 2.0,
                        )),
                    child:Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('V 5.8'),
                    )
                ),
                SizedBox(width:10),
                Card(
                    color: Colors.white,
                    elevation: 25,
                    shape: StadiumBorder(
                        side: BorderSide(
                          color: Colors.white,
                          width: 2.0,
                        )),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Image.asset('assets/icons/user.png'),
                          SizedBox(width:5),

                          Text('Admin'),
                          SizedBox(width:5),

                          Image.asset('assets/icons/arrows.png',height: 20,)
                        ],
                      ),
                    )
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      // color: Colors.red,
                      width: width,
                      height: height * 0.6,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                              padding: EdgeInsets.only(left: 50),
                              width: width * 0.3,
                              // alignment: Alignment.center,
                              //   color: Colors.red,
                              child: Center(child: Image.asset('assets/images/menu.jpg',))),
                          SizedBox(height: 15),
                          Text('If Menu Is Already Added , Sync The Menu'),
                          SizedBox(height: 10,),
                          CommonButton(
                              height: height * 0.06,
                              width: width * 0.3,
                              onTap: (){},
                              child: Text("Sync Menu",style: GoogleFonts.poppins(fontWeight: FontWeight.w700),))
                        ],
                      ) ,
                    )
                  ],
                ),
              ),
            ),
            drawer:Drawerr() ,
          );
        }
      },

    );
  }
}
