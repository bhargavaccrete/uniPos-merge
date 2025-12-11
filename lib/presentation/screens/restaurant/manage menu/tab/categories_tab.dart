import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_db.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/screens/restaurant/manage%20menu/tab/edit_category.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/images.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'package:uuid/uuid.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../widget/componets/restaurant/componets/custom_category.dart';

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  final TextEditingController _searchController = TextEditingController();
  final  TextEditingController _categoryController = TextEditingController();


  // List<Map<String, dynamic>> CategoyList = [];
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool isActive = true;




  Map<String , List<Items>> categoryItemsMap = {};

  Map<String , bool>  toggleState = {};

  Future<void> loadCategoriesAndItems ()async {
    final categoryBox = await Hive.openBox<Category>('categories');
    final itemBox = await itemsBoxes.getItemBox();

    final allCategories = categoryBox.values.toList();
    final allItems = itemBox.values.toList();


    //group items by categoryid
    final Map<String, List<Items>> tempMap = {};
    for(var category in allCategories){
      tempMap[category.id] = allItems
          .where((item)=> item.categoryOfItem == category.id)
          .toList();
    }
    setState(() {
      categorieshive = allCategories;
      categoryItemsMap = tempMap;
    });
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // _loadCategories();
    loadHive();
    loadCategoriesAndItems();
  }

  // function to open bottom sheet
  void _showImagePicker() {
    showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.all(20.0),
            child: Container(
              padding: ResponsiveHelper.responsivePadding(context),
              width: double.infinity,
              // color: Colors.red,
              height: ResponsiveHelper.responsiveHeight(context, 0.25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      alignment: Alignment.center,
                      width: ResponsiveHelper.responsiveWidth(context, 0.35),
                      height: ResponsiveHelper.responsiveHeight(context, 0.2),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 50,
                            color: primarycolor,
                          ),
                          Text('From Gallery'),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: ResponsiveHelper.responsiveWidth(context, 0.35),
                    height: ResponsiveHelper.responsiveHeight(context, 0.2),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 50,
                          color: primarycolor,
                        ),
                        Text('From Search'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  // function for image pick
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
    Navigator.pop(context);
  }

  // clear image after refresh
  void _clearImage() {

    setState(() {
      _selectedImage = null;
      _categoryController.clear();
      // Navigator.pop(context);
    });
  }

  // hive add category
  Future<void> _addcategoryHive() async {
    if (_categoryController.text.trim().isEmpty) {
      Navigator.pop(context);
      // ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Category name cannot be Empty')));

      NotificationService.instance.showError(
        'Category name cannot be Empty',
      );
      return;


    }
    final newcategory = Category(
        imagePath: _selectedImage != null ? _selectedImage!.path : null,
        id: const Uuid().v4(),
        name: _categoryController.text.trim());

    await HiveBoxes.addCategory(newcategory);
    await loadHive();
    _clearImage();
    Navigator.pop(context);

// _clearImage();
  }

  List<Category> categorieshive = [];

  /// to load hive data
  Future<void> loadHive() async {
    final box = await HiveBoxes.getCategory();
    setState(() {
      categorieshive = box.values.toList();
    });
  }

  /// delete category
  void _deleteCategoryhive(dynamic id) async {
    await HiveBoxes.deleteCategory(id);
    await loadHive();
  }

  // void _addcategory (){
//     if(CategoryController.text.isNotEmpty){
//       setState(() {
//         CategoyList.add(
//             {"title": CategoryController.text,
//               "imagePath": _selectedImage !=null ?_selectedImage!.path : null  //store only if selected
//             });
//         _saveCategories();
//       });
//       _clearImage();
//       Navigator.pop(context);
//     }

  @override
  Widget build(BuildContext context) {
    // final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            // crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // search Category
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 5),
                    child: TextFormField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search Category",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: ResponsiveHelper.responsiveTextSize(
                              context, 16),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Icon(Icons.search, color: Colors.teal),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.02),
                  )
                ],
              ),
              // Spacer(),

              Column(
                children: [
                  categorieshive.isEmpty
                      ? Container(
                    height:
                    ResponsiveHelper.responsiveHeight(context, 0.6),
                    width: width,
                    // color: Colors.green,
                    // color: Colors.red,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          notfoundanimation,
                          height: ResponsiveHelper.responsiveHeight(
                              context, 0.3),
                        ),
                        Text(
                          'No Category Found',
                          style: GoogleFonts.poppins(
                              fontSize:
                              ResponsiveHelper.responsiveTextSize(
                                  context, 20),
                              fontWeight: FontWeight.w500),
                        )
                      ],
                    ),
                  )
                      : Container(
                    // color: Colors.purple,
                    height:
                    ResponsiveHelper.responsiveHeight(context, 0.6),

                    width: ResponsiveHelper.maxContentWidth(context),

                    child: ListView.builder(
                        itemCount: categorieshive.length,
                        itemBuilder: (context, index) {
                          var category = categorieshive[index];

                          // final cat = categoriesitem[index];
                          final items = categoryItemsMap[category.id] ?? [];

                          toggleState.putIfAbsent(category.id ,()=>  true);
                          return Card(
                            // margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            shape: RoundedRectangleBorder(),
                            child: Container(
                              // color: Colors.redAccent,
                                width: double.infinity,
                                height: ResponsiveHelper.responsiveHeight(
                                    context, 0.14),
                                child: CustomCategory(
                                    imagePath: category.imagePath,
                                    // _selectedImage != null
                                    //     ?Image.file(_selectedImage!, height:50,width: 50,)
                                    // : Icon(Icons.image,size: 50,color: Colors.grey,),
                                    // itemCount: items.length.toString(),
                                    itemCount:items.length.toString() ?? '0',
                                    title: category.name,
                                    isActive: toggleState[category.id]?? false,
                                    // 🔍 AUDIT TRAIL: Pass audit trail data to widget
                                    createdTime: category.createdTime,
                                    lastEditedTime: category.lastEditedTime,
                                    editedBy: category.editedBy,
                                    editCount: category.editCount,
                                    onDelet: () {
                                      showDialog(context: context,
                                          builder:(_)=> AlertDialog(
                                            title: Text('Delete Category'),
                                            content: Text("Are you sure want to delete this category and all its items?"),
                                            actions: [
                                              TextButton(onPressed: (){},
                                                child: Text("Cancel"),),
                                              TextButton(onPressed: (){
                                                _deleteCategoryhive(category.id);
                                                Navigator.pop(context);

                                              }, child: Text('Delete',style:TextStyle(color: Colors.red)))

                                            ],
                                          ));



                                      // _deleteCategoryhive(category.id);
                                      // HiveBoxes.deleteCategory(category.id);
                                    },
                                    // onEdit: (){
                                    //   Navigator.push(context, MaterialPageRoute(builder: (context)=> EditCategory(category: Category.fromMap(CategoyList[index]),
                                    //   )));
                                    //
                                    //   // setState(() {
                                    //   //   CategoryController.text = category.name;
                                    //   //   _selectedImage = category.imagePath != null ? File(category.imagePath!):null;
                                    //   // });
                                    // },
                                    onEdit: () async {
                                      List<Category> categoryList =
                                      await HiveBoxes
                                          .getAllCategories();

                                      if (categoryList.isNotEmpty) {
                                        final result =
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditCategory(
                                                  category:
                                                  categoryList[index],
                                                ),
                                          ),
                                        );

                                        if (result == true) {
                                          // Refresh the list
                                          setState(() {
                                            loadHive();
                                            // Optionally re-fetch the data
                                          });
                                        }
                                      } else {

                                        NotificationService.instance.showInfo(
                                          'No category available to edit',
                                        );

                                        // ScaffoldMessenger.of(context)
                                        //     .showSnackBar(
                                        //   SnackBar(
                                        //       content: Text(
                                        //           "No category available to edit")),
                                        // );
                                      }
                                    },
                                    onToggle: ( value) {
                                      setState(() {
                                        toggleState[category.id] = value;
                                      });
                                    })),
                          );
                        }),
                  )
                ],
              ),
              // Button  Add Category
              CommonButton(

                  width: ResponsiveHelper.responsiveWidth(context, 0.5),
                  height: ResponsiveHelper.responsiveHeight(context, 0.06),
                  onTap: () {
                    showModalBottomSheet(
                        isScrollControlled: true,
                        context: context,
                        builder: (BuildContext context) {
                          return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: Container(
                                width: double.infinity,
                                height: ResponsiveHelper.responsiveHeight(
                                    context, 0.6),
                                padding: ResponsiveHelper.responsivePadding(
                                  context,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Add Category',
                                      style: GoogleFonts.poppins(
                                          fontSize: ResponsiveHelper
                                              .responsiveTextSize(context, 20),
                                          fontWeight: FontWeight.w400),
                                    ),
                                    Divider(),
                                    Container(
                                      height: ResponsiveHelper.responsiveHeight(
                                          context, 0.08),
                                      child: TextField(
                                        controller: _categoryController,
                                        decoration: InputDecoration(
                                          focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(2)),
                                          labelStyle: GoogleFonts.poppins(
                                            color: Colors.grey,
                                          ),
                                          border: OutlineInputBorder(),
                                          labelText: "Category Name (English)",
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    InkWell(
                                        onTap: _showImagePicker,
                                        child: Column(
                                          children: [

                                            Container(
                                              // color:Colors.red,
                                                height: ResponsiveHelper
                                                    .responsiveHeight(
                                                    context, 0.16),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Colors.grey),
                                                  borderRadius:
                                                  BorderRadius.circular(10),
                                                ),
                                                child: _selectedImage != null
                                                    ? Image.file(
                                                  _selectedImage!,
                                                  fit: BoxFit.cover,
                                                  height: 50,
                                                  width: 150,
                                                )
                                                    : Column(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .center,
                                                  children: [
                                                    Center(
                                                        child: Icon(
                                                            Icons.image,
                                                            color: Colors
                                                                .grey,
                                                            size: 50)),
                                                    SizedBox(
                                                      height: 5,
                                                    ),
                                                    Text(
                                                      'Upload Image',
                                                      textScaler:
                                                      TextScaler
                                                          .linear(1),
                                                      style: GoogleFonts.poppins(
                                                          fontSize: ResponsiveHelper
                                                              .responsiveTextSize(
                                                              context,
                                                              16),
                                                          fontWeight:
                                                          FontWeight
                                                              .w500),
                                                    ),
                                                    Text(
                                                      '600X400',
                                                      textScaler:
                                                      TextScaler
                                                          .linear(1),
                                                      style: GoogleFonts
                                                          .poppins(
                                                        fontSize: ResponsiveHelper
                                                            .responsiveTextSize(
                                                            context,
                                                            12),
                                                      ),
                                                    )
                                                  ],
                                                )),
                                            Text(
                                              'Upload Image (png , .jpg, .jpeg) upto 3mb',
                                              textScaler: TextScaler.linear(1),
                                              style: GoogleFonts.poppins(
                                                fontSize: ResponsiveHelper
                                                    .responsiveTextSize(
                                                    context, 14),
                                              ),
                                            )
                                          ],
                                        )),
                                    SizedBox(
                                      height: ResponsiveHelper.responsiveHeight(
                                          context, 0.02),
                                    ),
                                    CommonButton(
                                        onTap: () {
                                          _addcategoryHive();
                                        },
                                        // bgcolor: Colors.white,
                                        // bordercolor: Colors.deepOrange,
                                        width: ResponsiveHelper.responsiveWidth(
                                            context, 0.9),
                                        height:
                                        ResponsiveHelper.responsiveHeight(
                                            context, 0.07),
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Container(
                                                decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        10)),
                                                child: Icon(Icons.add)),
                                            SizedBox(
                                              width: 5,
                                            ),
                                            Text(
                                              'Add Category',
                                              style: GoogleFonts.poppins(
                                                  fontSize: ResponsiveHelper
                                                      .responsiveTextSize(
                                                      context, 16),
                                                  color: Colors.white),
                                            )
                                          ],
                                        )),
                                  ],
                                ),
                              ));
                        });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        child: Icon(Icons.add),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Text(
                        'Add Category',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize:
                          ResponsiveHelper.responsiveTextSize(context, 16),
                        ),
                      )
                    ],
                  ))
            ],
          ),
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:lottie/lottie.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../../componets/Button.dart';
// import '../../../componets/custom_category.dart';
// import 'package:BillBerry/utils/responsive_helper.dart';
//
// class CategoryTab extends StatefulWidget {
//   const CategoryTab({super.key});
//
//   @override
//   State<CategoryTab> createState() => _CategoryTabState();
// }
//
// class _CategoryTabState extends State<CategoryTab> {
//   TextEditingController SearchController = TextEditingController();
//   TextEditingController CategoryController = TextEditingController();
//   List<Map<String,dynamic>> CategoyList = [];
//   File? _selectedImage;
//   final ImagePicker _picker = ImagePicker();
//   bool isActive = true;
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     _loadCategories();
//   }
//
//  //  Save categories to SharedPRefrences
//  Future<void> _saveCategories() async {
//    final prefs =await SharedPreferences.getInstance();
//    prefs.setString('categories', jsonEncode(CategoyList));
//  }
//
//   // Load Categories From SharedPrefrence
//   Future<void> _loadCategories() async{
//    final prefs = await SharedPreferences.getInstance();
//    final data = prefs.getString('categories');
//    if(data != null){
//      setState(() {
//        CategoyList = List<Map<String,dynamic>>.from(jsonDecode(data));
//      });
//    }
//   }
//
//   // function to open bottom sheet
//   void _showImagePicker() {
//     showModalBottomSheet(
//         context: context,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         builder: (context) {
//           return Padding(
//             padding: EdgeInsets.all(20.0),
//             child: Container(
//               padding: ResponsiveHelper.responsivePadding(context),
//               width: double.infinity,
//               // color: Colors.red,
//               height: ResponsiveHelper.responsiveHeight(context, 0.25),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   InkWell(
//                     onTap: () => _pickImage(ImageSource.gallery),
//                     child: Container(
//                       alignment: Alignment.center,
//                     width: ResponsiveHelper.responsiveWidth(context, 0.35) ,
//                       height: ResponsiveHelper.responsiveHeight(context, 0.2),
//                       decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(4)),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.photo_library,
//                             size: 50,
//                             color: primarycolor,
//                           ),
//                           Text('From Gallery'),
//                         ],
//                       ),
//                     ),
//                   ),
//                   Container(
//                     width: ResponsiveHelper.responsiveWidth(context, 0.35) ,
//                     height: ResponsiveHelper.responsiveHeight(context, 0.2),
//                     decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(4)),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.search,
//                           size: 50,
//                           color: primarycolor,
//                         ),
//                         Text('From Search'),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         });
//   }
//
//   // function for image pick
//   Future<void> _pickImage(ImageSource source) async {
//     final pickedFile = await _picker.pickImage(source: source);
//     if (pickedFile != null) {
//       setState(() {
//         _selectedImage = File(pickedFile.path);
//       });
//     }
//     Navigator.pop(context);
//   }
//
//   // clear image after refresh
//   void _clearImage() {
//     setState(() {
//       _selectedImage = null;
//       CategoryController.clear();
//       // Navigator.pop(context);
//     });
//   }
//   /// Add category to the list and save
//   void _addcategory (){
//     if(CategoryController.text.isNotEmpty){
//       setState(() {
//         CategoyList.add(
//             {"title": CategoryController.text,
//               "imagePath": _selectedImage !=null ?_selectedImage!.path : null  //store only if selected
//             });
//         _saveCategories();
//       });
//       _clearImage();
//       Navigator.pop(context);
//     }
//   }
//
//   // Delete category and Update SharedPreferences
//
//   void _deleteCategory(int index)async{
//     setState(() {
//       CategoyList.removeAt(index);
//       _saveCategories();
//     });
//     // save updated list
//     final prefs = await SharedPreferences.getInstance();
//     prefs.setString('categories', jsonEncode(CategoyList));
//   }
//
//   //
//
//   @override
//   Widget build(BuildContext context) {
//     final height = MediaQuery.of(context).size.height * 1;
//     final width = MediaQuery.of(context).size.width * 1;
//
//     return Scaffold(
//       body: SingleChildScrollView(
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             // crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               // search Category
//               Container(
//                 // height: height * 0.7,
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 5, vertical: 5),
//                       child: TextFormField(
//                         controller: SearchController,
//                         decoration: InputDecoration(
//                           hintText: "Search Category",
//                           hintStyle: GoogleFonts.poppins(
//                               color: Colors.grey,
//                             fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
//                           ),
//                           filled: true,
//                           fillColor: Colors.white,
//                           contentPadding: EdgeInsets.symmetric(
//                               vertical: 12, horizontal: 16),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide.none,
//                           ),
//                           suffixIcon: Padding(
//                             padding: const EdgeInsets.all(12.0),
//                             child: Icon(Icons.search, color: Colors.teal),
//                           ),
//                         ),
//                       ),
//
//
//
//                     ),
//
//                    SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.02),)
//
//                   ],
//                 ),
//               ),
//               // Spacer(),
//
//               Column(
//                 children: [
//                 CategoyList.isEmpty?
//                   Container(
//                     height: ResponsiveHelper.responsiveHeight(context, 0.6),
//                     width: width,
//                     // color: Colors.green,
//                     // color: Colors.red,
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Lottie.asset('assets/animation/notfoundanimation.json', height: ResponsiveHelper.responsiveHeight(context, 0.3),
//                         ),
//
//                         Text('No Category Found',style: GoogleFonts.poppins(
//                             fontSize: ResponsiveHelper.responsiveTextSize(context, 20),
//                             fontWeight: FontWeight.w500),)
//                       ],
//                     ),
//                   )
//
//                     : Container(
//                       // color: Colors.purple,
//                       height: ResponsiveHelper.responsiveHeight(context, 0.6),
//
//                       width: ResponsiveHelper.maxContentWidth(context),
//
//                       child: ListView.builder(
//                           itemCount: CategoyList.length,
//                           itemBuilder: (context, index){
//                             var category = CategoyList[index];
//                         return Card(
//                           // margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                           shape: RoundedRectangleBorder(),
//                           child: Container(
//                             // color: Colors.redAccent,
//                             width: double.infinity,
//                               height: ResponsiveHelper.responsiveHeight(context, 0.14),
//                               child:CustomCategory(
//                                 imagePath: category['imagePath'],
//                                 // _selectedImage != null
//                                 //     ?Image.file(_selectedImage!, height:50,width: 50,)
//                                 // : Icon(Icons.image,size: 50,color: Colors.grey,),
//                                 itemCount: 0.toString(),
//                               title: category['title'],
//                               isActive: isActive,
//                               onDelet:(){
//                                 _deleteCategory(index);
//                               },
//                               onEdit: (){},
//                               onToggle: (bool value){
//                               setState(() {
//                                 isActive = value;
//                               });
//                               }
//                             )
//                           ),
//                         );
//                       }),
//                     )
//
//                 ],
//               ),
//               // Button  Add Category
//               CommonButton(
//                   width: ResponsiveHelper.responsiveWidth(context, 0.5),
//                   height: ResponsiveHelper.responsiveHeight(context, 0.06),
//
//                   onTap: () {
//                     showModalBottomSheet(
//                         isScrollControlled: true,
//                         context: context,
//                         builder: (BuildContext context) {
//                           return Padding(
//                             padding: EdgeInsets.only(
//                               bottom: MediaQuery.of(context).viewInsets.bottom,
//                           ),
//
//                             child: Container(
//                             width: double.infinity,
//                             height: ResponsiveHelper.responsiveHeight(context, 0.6),
//
//                             padding: ResponsiveHelper.responsivePadding(context,),
//                             child: Column(
//                               children: [
//                                 Text(
//                                   'Add Category',
//                                   style: GoogleFonts.poppins(
//                                       fontSize: ResponsiveHelper.responsiveTextSize(context, 20),
//
//                                       fontWeight: FontWeight.w400),
//                                 ),
//                                 Divider(),
//                                 Container(
//                                   height: ResponsiveHelper.responsiveHeight(context, 0.08),
//                                   child: TextField(
//                                     controller: CategoryController,
//                                     decoration: InputDecoration(
//                                       focusedBorder: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(2)),
//                                       labelStyle: GoogleFonts.poppins(
//                                         color: Colors.grey,
//                                       ),
//                                       border: OutlineInputBorder(),
//                                       labelText: "Category Name (English)",
//                                     ),
//                                   ),
//                                 ),
//                                 SizedBox(height: 10),
//                                 InkWell(
//                                     onTap: _showImagePicker,
//                                     child: Column(
//                                       children: [
//                                         Container(
//                                             // color:Colors.red,
//                                             height: ResponsiveHelper.responsiveHeight(context, 0.16),
//                                             decoration: BoxDecoration(
//                                               border: Border.all(
//                                                   color: Colors.grey),
//                                               borderRadius:
//                                                   BorderRadius.circular(10),
//                                             ),
//                                             child: _selectedImage != null
//                                                 ? Image.file(
//                                                     _selectedImage!,
//                                                     fit: BoxFit.cover,
//                                                     height: 50,
//                                                     width: 150,
//                                                   )
//                                                 : Column(
//                                                     mainAxisAlignment:
//                                                         MainAxisAlignment
//                                                             .center,
//                                                     children: [
//                                                       Center(
//                                                           child: Icon(
//                                                               Icons.image,
//                                                               color:
//                                                                   Colors.grey,
//                                                               size: 50)),
//                                                       SizedBox(
//                                                         height: 5,
//                                                       ),
//                                                       Text(
//                                                         'Upload Image',
//                                                         textScaler: TextScaler.linear(1),
//
//                                                         style:
//
//                                                             GoogleFonts.poppins(
//                                                                 fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
//
//                                                                 fontWeight:
//                                                                     FontWeight
//                                                                         .w500),
//                                                       ),
//                                                       Text('600X400',textScaler: TextScaler.linear(1),
//                                                         style: GoogleFonts.poppins(
//                                                           fontSize: ResponsiveHelper.responsiveTextSize(context, 12),
//
//                                                         ),)
//                                                     ],
//                                                   )),
//                                         Text(
//                                           'Upload Image (png , .jpg, .jpeg) upto 3mb',
//                                           textScaler: TextScaler.linear(1),
//                                           style: GoogleFonts.poppins(
//                                             fontSize: ResponsiveHelper.responsiveTextSize(context, 14),),
//                                         )
//                                       ],
//                                     )),
//                                 SizedBox(
//                                   height: ResponsiveHelper.responsiveHeight(context, 0.02),
//
//                                 ),
//                                 CommonButton(
//                                     onTap:(){
//                                       _addcategory();
//                                       // _clearImage();
//                                     },
//                                     // bgcolor: Colors.white,
//                                     // bordercolor: Colors.deepOrange,
//                                     width: ResponsiveHelper.responsiveWidth(context, 0.9),
//                                     height: ResponsiveHelper.responsiveHeight(context, 0.07),
//
//                                     child: Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.center,
//                                       children: [
//                                         Container(
//                                             decoration: BoxDecoration(
//                                                 color: Colors.white,
//                                                 borderRadius:
//                                                     BorderRadius.circular(10)),
//                                             child: Icon(Icons.add)),
//                                         SizedBox(
//                                           width: 5,
//                                         ),
//                                         Text(
//                                           'Add Category',
//                                           style: GoogleFonts.poppins(
//                                               fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
//
//                                               color: Colors.white),
//                                         )
//                                       ],
//                                     )),
//                               ],
//                             ),
//                           ));
//                         });
//                   },
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         child: Icon(Icons.add),
//                         decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(15)),
//                       ),
//                       SizedBox(
//                         width: 5,
//                       ),
//                       Text(
//                         'Add Category',
//                         style: GoogleFonts.poppins(
//                             color: Colors.white,
//                           fontSize: ResponsiveHelper.responsiveTextSize(context, 16),),
//                       )
//                     ],
//                   ))
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
