import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_cart.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:uuid/uuid.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../../util/restaurant/currency_helper.dart';
import '../../../../util/restaurant/decimal_settings.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/visual_keyboard.dart';
import '../Desktop/online_Order_desktop/online.dart';
import 'WeightItemDialog.dart';
import 'item_options_dialog.dart';

class MenuScreen extends StatefulWidget {
  final String? tableIdForNewOrder;
  final OrderModel? existingOrder;
  final bool isForAddingItem;

  const MenuScreen({super.key, this.existingOrder, this.isForAddingItem = false, this.tableIdForNewOrder});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {

  bool isCartShow = false;
  double totalPrice = 0.0;
  List<CartItem> cartItemsList = [];
  List<Items> itemsList = [];
  String? activeCategory;
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  // final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _codehereFocusNode = FocusNode();


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadCartItems();

    if (widget.tableIdForNewOrder != null) {
      _storeSelectedTable(widget.tableIdForNewOrder!);
    }

    _searchController.addListener((){
      setState(() {
        query = _searchController.text;
      });
    });

    // Listen for search field focus - show visual keyboard if enabled
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && AppSettings.visualKeyboard) {
        // Hide system keyboard
        FocusScope.of(context).requestFocus(FocusNode());
        // Show visual keyboard
        VisualKeyboardHelper.show(
          context: context,
          controller: _searchController,
          keyboardType: KeyboardType.text,
        );
      }
    });


    _codehereFocusNode.addListener(() {
      if (_codehereFocusNode.hasFocus && AppSettings.visualKeyboard) {
        // Hide system keyboard
        FocusScope.of(context).requestFocus(FocusNode());
        // Show visual keyboard
        VisualKeyboardHelper.show(
          context: context,
          controller: _codeController,
          keyboardType: KeyboardType.text,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _storeSelectedTable(String tableId) async {
    final appBox = Hive.box('app_state');
    await appBox.put('selected_table_for_new_order', tableId);
  }


// REPLACE your old _handleItemTap function with this new one
// In MenuScreen.dart

  Future<void> _handleItemTap(Items item) async {
    // --- START: LOGIC FOR WEIGHT ITEMS ---
    if (item.isSoldByWeight) {
      final CartItem? weightCartItem = await showWeightItemDialog(context, item);
      if (weightCartItem != null) {


        await _addItemToCart(weightCartItem);
      }
      return;
    }
    // --- END: LOGIC FOR WEIGHT ITEMS ---

    final bool hasVariants = item.variant != null && item.variant!.isNotEmpty;

    // --- 1. Find the category name for the tapped item ---
    String? categoryName;
    try {
      final categoryBox = Hive.box<Category>('categories');
      final category = categoryBox.values.firstWhere((cat) => cat.id == item.categoryOfItem);
      categoryName = category.name;
    } catch (e) {
      print("Could not find category for item: ${item.name}. Defaulting to 'Uncategorized'");
      categoryName = 'Uncategorized';
    }

    if (hasVariants) {
      // If variants exist, show the options dialog
      final result = await showModalBottomSheet<CartItem>(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.4,
            minChildSize: 0.3,
            maxChildSize: 0.5,
            builder: (_, controller) {
              return SingleChildScrollView(
                controller: controller,
                // --- 2. Pass the categoryName to the dialog ---
                child: ItemOptionsDialog(item: item, categoryName: categoryName),
              );
            },
          );
        },
      );

      // If the dialog returns a CartItem, add it
      if (result != null) {
        await _addItemToCart(result);
      }
    } else {
      // If no variants, create a simple CartItem and add it directly
      final simpleCartItem = CartItem(
        productId: item.id,
        isStockManaged: item.trackInventory,
        id: const Uuid().v4(),
        title: item.name,
        imagePath: item.imagePath ?? '',
        price: item.price ?? 0,
        quantity: 1,
        taxRate: item.taxRate,
        weightDisplay: null,
        // --- 3. Add the categoryName here for simple items ---
        categoryName: categoryName,
      );

      // --- ADD THIS PRINT STATEMENT ---
      print('--- ADD TO CART --- Product ID: "${simpleCartItem.productId}", Stock Managed: ${simpleCartItem.isStockManaged}');

      await _addItemToCart(simpleCartItem);
    }
  }

  /// This is the single, final function to add a prepared CartItem to the database.
  Future<void> _addItemToCart(CartItem cartItem) async {
    try {
      final result = await HiveCart.addToCart(cartItem);

      if (result['success'] == true) {
        await loadCartItems();

        setState(() {
          isCartShow = true;
        });

        if (mounted) {
          // TopSnack.show(context,
          //     content:  Text('${cartItem.title} added toO cart'),);


          // Show success notification
          NotificationService.instance.showSuccess(
            '${cartItem.title} added to cart',
          );

          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text('${cartItem.title} added to cart'),
          //     duration: const Duration(seconds: 2),
          //   ),
          // );
        }
      } else {
        // Show stock limitation error
        if (mounted) {

          NotificationService.instance.showError(
            result['message'] ?? 'Cannot add item to cart',
          );
        }
      }
    } catch (e) {
      print('Error adding to cart: $e');
      if (mounted) {
        NotificationService.instance.showError(
          'Error adding item to cart',
        );
      }
    }
  }

  Future<void> loadCartItems() async {
    try {
      final items = await HiveCart.getAllCartItems();
      setState(() {
        cartItemsList = items;
        totalPrice = items.fold(0.0, (sum, item) => sum + item.totalPrice);
        isCartShow = items.isNotEmpty;
      });
    } catch (e) {
      print('Error loading cart items: $e');
    }
  }



  String _formatStockDisplay(Items item) {
    if (!item.trackInventory) return '';

    final stock = item.stockQuantity;
    final unit = item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');
    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    if (stock <= 0) {
      if (allowOrderWhenOutOfStock) {
        return 'Order Available'; // Still orderable when out of stock
      } else {
        return 'Out of Stock'; // Not orderable when out of stock
      }
    }

    // For weight-based items, show appropriate decimal places
    if (item.isSoldByWeight) {
      if (unit.toUpperCase().contains('GM') || unit.toUpperCase().contains('GRAM')) {
        return '${stock.toStringAsFixed(stock == stock.toInt() ? 0 : 1)}${unit}';
      } else if (unit.toUpperCase().contains('KG')) {
        if (stock >= 1000) {
          double kg = stock / 1000;
          return '${kg.toStringAsFixed(kg == kg.toInt() ? 0 : 1)}KG';
        } else {
          return '${stock.toStringAsFixed(0)}GM';
        }
      }
      return '${stock.toStringAsFixed(2)}${unit}';
    } else {
      // For unit-based items, always show whole numbers
      return '${stock.toStringAsFixed(0)} ${unit}';
    }
  }

  Color _getStockColor(Items item, bool isBackground) {
    if (!item.trackInventory) return Colors.grey;

    final stock = item.stockQuantity;
    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    if (stock <= 0) {
      if (allowOrderWhenOutOfStock) {
        // Orange for out of stock but orderable
        return isBackground ? Colors.orange[50]! : Colors.orange[700]!;
      } else {
        // Red for out of stock and not orderable
        return isBackground ? Colors.red[50]! : Colors.red[700]!;
      }
    } else {
      // Green for in stock
      return isBackground ? Colors.green[50]! : Colors.green[700]!;
    }
  }

  Color _getStockBorderColor(Items item) {
    if (!item.trackInventory) return Colors.grey[300]!;

    final stock = item.stockQuantity;
    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    if (stock <= 0) {
      if (allowOrderWhenOutOfStock) {
        return Colors.orange[300]!; // Orange border for orderable out of stock
      } else {
        return Colors.red[300]!; // Red border for non-orderable out of stock
      }
    } else {
      return Colors.green[300]!; // Green border for in stock
    }
  }

  IconData _getStockIcon(Items item) {
    if (!item.trackInventory) return Icons.inventory;

    final stock = item.stockQuantity;
    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    if (stock <= 0) {
      if (allowOrderWhenOutOfStock) {
        return Icons.shopping_cart; // Shopping cart for orderable out of stock
      } else {
        return Icons.block; // Block icon for non-orderable out of stock
      }
    } else {
      return Icons.inventory; // Inventory icon for in stock
    }
  }

  @override
  Widget build(BuildContext context) {

    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding:  EdgeInsets.only(top: 10),
          child: Container(
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSettings.useGridViewCategory
                              ? SizedBox()
                              : Container(
                            width: width * 0.3,
                            height: height,
                            color: Colors.blue.shade50,
                            // color: Colors.blue,
                            child: Column(
                              children: [
                                Container(
                                  alignment: Alignment.center,
                                  width: width * 0.3,
                                  height: height * 0.04,
                                  decoration: BoxDecoration(color: primarycolor, borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                    'Categories',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                SizedBox(
                                  height: 20,
                                ),





                                /*------------------------------------Categories-------------------------------------*/

                                ValueListenableBuilder(valueListenable:Hive.box<Category>('categories').listenable(),
                                    builder: (context , categorys , _)
                                    {
                                      final  allcat = categorys.values.toList();


                                      if(allcat.isEmpty){
                                        return Container(
                                          padding: EdgeInsets.all(5),
                                          child: Text(
                                            'No Category Found',
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }
                                      return Container(
                                        // color: Colors.red,
                                        height: height * 0.5,
                                        width: 100,
                                        child: Column(
                                          children: [
                                            if (AppSettings.allItemsCategory)
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    activeCategory = null;
                                                    // loadhive();
                                                  });
                                                },
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  width: width * 0.25,
                                                  height: height * 0.03,
                                                  decoration: BoxDecoration(
                                                      color: Colors.teal[100],
                                                      borderRadius: BorderRadius.circular(2),
                                                      border: Border.all(
                                                        color: primarycolor,
                                                      )),
                                                  child: Text(
                                                    'All Items',
                                                    textScaler: TextScaler.linear(1),
                                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              ),
                                            Expanded(
                                              // flex: 1,
                                              child: ListView.builder(
                                                  itemCount: allcat.length,
                                                  itemBuilder: (context, index) {
                                                    var category = allcat[index];
                                                    final isSelected = category.name == activeCategory;
                                                    return Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: InkWell(
                                                        // onTap: (){
                                                        //   setState(() {
                                                        //     activeCategory = isSelected ? null : category.name;
                                                        //   });
                                                        //   loadhive();
                                                        // },

                                                        onTap: () {
                                                          setState(() {
                                                            if (isSelected) {
                                                              activeCategory = null;
                                                            } else {
                                                              activeCategory = isSelected? null : category.id;
                                                            }
                                                          }
                                                          );

                                                          // loadhive();
                                                        },
                                                        child: Container(
                                                          alignment: Alignment.center,
                                                          width: width * 0.25,
                                                          height: height * 0.04,
                                                          decoration: BoxDecoration(
                                                              color: primarycolor,
                                                              borderRadius: BorderRadius.circular(2),
                                                              border: Border.all(
                                                                color: primarycolor,
                                                              )),
                                                          child: Text(
                                                            category.name,
                                                            overflow: TextOverflow.ellipsis,
                                                            textScaler: TextScaler.linear(1),
                                                            style: GoogleFonts.poppins(
                                                                fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                              ],
                            ),
                          ),

                     /* -------------------------Online Order Column-----------------------*/
                          Expanded(
                            child: Column(
                              children: [

               /*------------------------Online Order  Button----------------------*/
                              /*
                                Container(
                                  // color: Colors.red,
                                  child: CommonButton(
                                      borderwidth: 1,
                                      bgcolor: screenBGColor,
                                      bordercolor: Colors.black,
                                      bordercircular: 12,
                                      width: width * 0.65,
                                      height: height * 0.045,
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => OnlineDesktop()));
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.shopping_cart_outlined),
                                          Text(
                                            'Online Order',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      )),
                                ),

                                SizedBox(height: 15),*/

                                // Search text field
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Container(
                                            // width: width * 0.32,
                                            height: height * 0.04,
                                            // color: Colors.red,
                                            child: TextField(
                                              textAlign: TextAlign.center,
                                              controller: _codeController,
                                              focusNode: _codehereFocusNode,
                                              readOnly: AppSettings.visualKeyboard,
                                              onTap: AppSettings.visualKeyboard? (){
                                                VisualKeyboardHelper.show(
                                                  context: context,
                                                  controller: _codeController,
                                                  keyboardType: KeyboardType.text,
                                                );
                                              } : null,
                                              decoration: InputDecoration(
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                  hintText: 'Code Here',
                                                  suffixIcon: AppSettings.visualKeyboard
                                                      ? Icon(Icons.keyboard, size: 18, color: primarycolor)
                                                      : null,
                                                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                                                  border: OutlineInputBorder()),
                                            )),
                                      ),
                                      SizedBox(
                                        width: 2,
                                      ),
                                      Expanded(
                                        child: Container(
                                            // width: width * 0.32,
                                            height: height * 0.04,

                                            // color: Colors.red,
                                            child: TextField(
                                              textAlign: TextAlign.center,
                                              controller: _searchController,
                                              focusNode: _searchFocusNode,
                                              readOnly: AppSettings.visualKeyboard, // Prevent system keyboard when visual keyboard is enabled
                                              onTap: AppSettings.visualKeyboard ? () {
                                                // Show visual keyboard on tap
                                                VisualKeyboardHelper.show(
                                                  context: context,
                                                  controller: _searchController,
                                                  keyboardType: KeyboardType.text,
                                                );
                                              } : null,
                                              decoration: InputDecoration(
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                  hintText: 'Search Items',
                                                  suffixIcon: AppSettings.visualKeyboard
                                                      ? Icon(Icons.keyboard, size: 18, color: primarycolor)
                                                      : null,
                                                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                                                  border: OutlineInputBorder()),
                                            )),
                                      ),
                                    ],
                                  ),
                                ),


                           /* -----------category if gridview---------------*/
                                if (AppSettings.useGridViewCategory)
                                  Container(
                                      width: width * 0.9,
                                      height: height * 0.06,
                                      color: Colors.blue.shade50,
                                      // color: Colors.blue,
                                      child:

                                      ValueListenableBuilder(valueListenable: Hive.box<Category>('categories').listenable(),
                                          builder: (context , categorys , _){





                                            final allCat = categorys.values.toList();



                                            print('Active Category: $activeCategory');
                                            print('Filtered Items Count: ${itemsList.length}');
                                            if(allCat.isEmpty){
                                              return Container(
                                                padding: EdgeInsets.all(5),
                                                child: Text(
                                                  'No Category Found',
                                                  textAlign: TextAlign.center,
                                                ),
                                              );

                                            }
                                            return ListView.builder(
                                                physics: BouncingScrollPhysics(),
                                                scrollDirection: Axis.horizontal,
                                                itemCount: allCat.length,
                                                itemBuilder: (context, index) {
                                                  var category = allCat[index];
                                                  final isSelected = category.name == activeCategory;
                                                  return Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: InkWell(
                                                      // onTap: (){
                                                      //   setState(() {
                                                      //     activeCategory = isSelected ? null : category.name;
                                                      //   });
                                                      //   loadhive();
                                                      // },

                                                      onTap: () {
                                                        setState(() {
                                                          activeCategory = isSelected ? null : category.id; // Uses id
                                                        });
                                                        // loadhive(); // reload based on updated activeCategory
                                                        print('Active Category: $activeCategory');
                                                        print('Filtered Items Count: ${itemsList.length}');
                                                      },

                                                      child: Container(
                                                        alignment: Alignment.center,
                                                        width: width * 0.25,
                                                        height: height * 0.04,
                                                        decoration: BoxDecoration(
                                                            color: Colors.teal[100],
                                                            borderRadius: BorderRadius.circular(2),
                                                            border: Border.all(
                                                              color: primarycolor,
                                                            )),
                                                        child: Text(
                                                          category.name,
                                                          textScaler: TextScaler.linear(1),
                                                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                });

                                          })
                                  ),


                                /*----------item card -------------*/
                                //change the aspect ration for card height
                                Container(
                                  // color: Colors.red,
                                  width: width,
                                  height: height,
                                  child:
                                  ValueListenableBuilder(
                                      valueListenable: AppSettings.settingsNotifier,
                                      builder: (context, value, _){
                                        double aspectRatio =
                                        AppSettings.useGridViewCategory ?
                                        // Grid view category - shorter cards
                                        (AppSettings.fixItemCard ?
                                        (AppSettings.showItemImage ? 1.4 : 2.5)
                                            :
                                        (AppSettings.showItemImage ? 1.0 : 2.0))
                                            :
                                        // Side category - normal cards
                                        (AppSettings.fixItemCard ?
                                        (AppSettings.showItemImage ? 1.2 : 2.2)
                                            :
                                        (AppSettings.showItemImage ? 0.65 : 1.5));

                                        return ValueListenableBuilder(valueListenable: Hive.box<Items>('itemBoxs').listenable(),
                                            builder:(context, item, _){
                                              final items = item.values.toList();

                                              final visibleItems = items.where((item)=> item.isEnabled).toList();


                                              final filteredItems = (activeCategory != null && activeCategory!.isNotEmpty)
                                                  ? visibleItems.where((item)=> item.categoryOfItem == activeCategory).toList()
                                                  : visibleItems;


                                              final filterdsearch = query.isEmpty
                                                  ? filteredItems
                                                  : filteredItems.where((item){
                                                final name = item.name.toLowerCase();
                                                final querylower = query.toLowerCase();
                                                return name.contains(querylower);
                                              }).toList();


                                              print('Active Category: $activeCategory');
                                              print('Filtered Items Count: ${itemsList.length}');


                                              if(filteredItems.isEmpty){
                                                return Container(
                                                  // alignment: Alignment.center,
                                                  width: width * 0.5,
                                                  height: height * 0.01,
                                                  padding: EdgeInsets.all(20),
                                                  // color: Colors.red,
                                                  child: Center(child: Text('No Items')
                                                  ),);
                                              }
                                              return    GridView.builder(
                                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 2,
                                                    // Two items per row
                                                    crossAxisSpacing: 20,
                                                    // Space between columns
                                                    mainAxisSpacing: 10,
                                                    // Space between rows
                                                    childAspectRatio: aspectRatio, // Adjust item size
                                                  ),
                                                  itemCount: filterdsearch.length,
                                                  itemBuilder: (context, index) {
                                                    final item = filterdsearch[index];
                                                    // final categoryOfItem = items[index].categoryOfItem;
                                                    return Card(
                                                      child:
                                                      // ontap item
                                                      InkWell(
                                                        // onTap: () => addToCart(item),
                                                        onTap: () => _handleItemTap(item),
                                                        child: Container(
                                                          // color: Colors.red,
                                                          width: width * 0.3,
                                                          height: AppSettings.showItemImage ? height * 0.1 : height * 0.1,
                                                          child: Column(
                                                            children: [


                                                              AppSettings.showItemImage
                                                                  ? (item.imagePath != null && item.imagePath!.isNotEmpty
                                                                  ? (File(item.imagePath!).existsSync()
                                                                  ? Image.file(
                                                                File(item.imagePath!),
                                                                fit: BoxFit.cover,
                                                                width: 80,
                                                                height: 80,
                                                              )
                                                                  : Icon(Icons.broken_image, size: 80, color: Colors.grey))
                                                                  : Icon(Icons.image, size: 80, color: Colors.grey))
                                                                  : SizedBox(),



                                                              /*AppSettings.showItemImage
                                                          ? (item.imagePath != null && item.imagePath!.isNotEmpty

                                                          ?Image.memory(
                                                        base64Decode(item.imagePath!),
                                                        fit: BoxFit.fill,
                                                        width: 80,
                                                        height: 80,
                                                      )

                                                          : (Icon(
                                                        Icons.image,
                                                        size: 80,
                                                      )))
                                                          : SizedBox(),*/
                                                              SizedBox(height: 5,),
                                                              Center(
                                                                child: Text(
                                                                  item.name,
                                                                  textAlign: TextAlign.center,
                                                                  style: GoogleFonts.poppins(fontSize: 12,color: Colors.indigo.shade900, fontWeight: FontWeight.w600),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                height: 5,
                                                              ),
                                                              AppSettings.showItemPrice
                                                                  ? Text(
                                                                  item.price != null
                                                                      ? "Price: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price!)}"
                                                                      : (item.variant != null && item.variant!.isNotEmpty)
                                                                      ? "Price: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.variant!.first.price)}+"
                                                                      : "Price: N/A",
                                                                  textAlign: TextAlign.center,
                                                                  style: GoogleFonts.poppins(color: Colors.indigo.shade900, fontWeight: FontWeight.w600))
                                                                  : SizedBox(),

                                                              // Stock quantity display
                                                              if (item.trackInventory) ...[
                                                                SizedBox(height: 3),
                                                                Container(
                                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: _getStockColor(item, true),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    border: Border.all(
                                                                      color: _getStockBorderColor(item),
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Icon(
                                                                        _getStockIcon(item),
                                                                        size: 12,
                                                                        color: _getStockColor(item, false),
                                                                      ),
                                                                      SizedBox(width: 3),
                                                                      Text(
                                                                        _formatStockDisplay(item),
                                                                        style: GoogleFonts.poppins(
                                                                          fontSize: 9,
                                                                          color: _getStockColor(item, false),
                                                                          fontWeight: FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  });
                                            });

                                      }
                                  ),
                                )





                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isCartShow)
                      // isCartShow?
                        Positioned(
                            top: height * 0.65,
                            width: width * 0.8,
                            left: width * 0.1,
                            // right: 20,
                            child: Container(
                                width: width,
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primarycolor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total price: $totalPrice',
                                      textScaler: TextScaler.linear(1),
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    CommonButton(
                                        bordercircular: 25,
                                        bgcolor: Colors.white,
                                        width: width * 0.3,
                                        height: height * 0.05,
                                        onTap: () async {
                                          if (widget.isForAddingItem == true) {
                                            // For an existing order, we just go back. No other logic is needed.
                                            Navigator.pop(context);
                                          } else {
                                            // For a new order, we navigate to the cart and then refresh when we return.
                                            final appBox = Hive.box('app_state');
                                            await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) => CartScreen(selectedTableNo: widget.tableIdForNewOrder,)));
                                            appBox.delete('selected_table_for_new_order');
                                            await loadCartItems();
                                          }
                                        },
                                        //     () async {
                                        //   final appBox = Hive.box('app_state');
                                        //   // final selectedTable = appBox.get('selected_table_for_new_order');
                                        //
                                        //
                                        //   widget.isForAddingItem ==true?
                                        //       Navigator.pop(context):
                                        //   await Navigator.push(
                                        //       context,
                                        //       MaterialPageRoute(
                                        //           builder: (context) => CartScreen(
                                        //
                                        //             // isActiveCart: true,
                                        //               // cartItems: cartItems,
                                        //               // selectedTableNo: selectedTable,
                                        //               )));
                                        //   appBox.delete('selected_table_for_new_order');
                                        //   // await loadCartItems();
                                        //
                                        //   await loadCartItems();
                                        // },
                                        child: Container(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'View Cart',
                                                style: GoogleFonts.poppins(fontSize: 14),
                                                textScaler: TextScaler.linear(1),
                                              ),
                                              Icon(
                                                Icons.arrow_forward_ios,
                                                size: 20,
                                              )
                                            ],
                                          ),
                                        ))
                                  ],
                                )))
                      // : SizedBox()
                    ],
                  ),
                ]
            ),
          ),
        ),
      ),

    );
  }
}
