// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:BillBerry/componets/Button.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:BillBerry/database/hive_db.dart';
// import 'package:BillBerry/model/db/categorymodel_0.dart';
// import 'package:BillBerry/screens/respinsive.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:uuid/uuid.dart';
//
// import '../model/db/itemmodel_2.dart';
// import '../utils/responsive_helper.dart';
//
//
//
//
// class BottomsheetMenu extends StatefulWidget {
//   // final Function(Map<String, String>)? onAdditem;
//
//   const BottomsheetMenu({super.key});
//
//
//   const BottomsheetMenu({super.key, this.onAdditem});
//
//
//
//   @override
//   State<BottomsheetMenu> createState() => _BottomsheetMenuState();
// }
//
// class _BottomsheetMenuState extends State<BottomsheetMenu> {
//
//
//   List<Items>? itemsList = [];
//
//   /// load hive data of item
//   Future <void> loadHive() async {
//     final box = await itemsBoxes.getItemBox();
//     setState(() {
//       itemsList = box.values.toList();
//     });
//   }
//
//   ///   add items
//   Future <void> _addItem() async {
//     final newitem = Items(
//       id: const Uuid().v4(),
//       name: itemNameController.text.trim(),
//       price: priceController.text.trim(),
//       description: descriptionController.text.trim(),
//     );
//     await itemsBoxes.addItem(newitem);
//     await loadHive();
//     Navigator.pop(context);
//   }
//
//
//   ///delete items
//   void _deleteItem(dynamic id) async {
//     await itemsBoxes.deleteItem(id);
//     loadHive();
//   }
//
//   ///for add item screeen
//   final TextEditingController weightController = TextEditingController();
//   final TextEditingController itemNameController = TextEditingController();
//   final TextEditingController choiceController = TextEditingController();
//   final TextEditingController kgController = TextEditingController();
//   final TextEditingController priceController = TextEditingController();
//   final TextEditingController vegNonvegController = TextEditingController();
//   final TextEditingController descriptionController = TextEditingController();
//   final TextEditingController inventoryController = TextEditingController();
//   bool ismanage = false;
//
//   File? _seclectedImage;
//   final ImagePicker _picker = ImagePicker();
//
//
//   List<Map<String, dynamic>> categoryList = [];
//   List<Category> categorieshive = [];
//
//   Future<void> loadCategories() async {
//     final prefs = await SharedPreferences.getInstance();
//     final data = prefs.getString('categories');
//     if (data != null) {
//       setState(() {
//         categoryList = List<Map<String, dynamic>>.from(jsonDecode(data));
//       });
//     }
//   }
//
//   String? selectedCategory;
//
//   void _showImagePicker() {
//     showModalBottomSheet(
//         context: context,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         builder: (context) {
//           return Padding(
//               padding: EdgeInsets.all(20),
//               child: Container(
//                 // color: Colors.red,
//                 width: double.infinity,
//                 height: ResponsiveHelper.responsiveHeight(context, 0.25),
//
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     InkWell(
//                       onTap: () => _pickIMage(ImageSource.gallery),
//                       child: Container(
//                         alignment: Alignment.center,
//                         width: ResponsiveHelper.responsiveWidth(context, 0.35),
//                         height: ResponsiveHelper.responsiveHeight(context, 0.2),
//                         decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(4)),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.photo_library,
//                               size: 50,
//                               color: primarycolor,
//                             ),
//                             Text('From Gallery'),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Container(
//                       width: ResponsiveHelper.responsiveWidth(context, 0.35),
//                       height: ResponsiveHelper.responsiveHeight(context, 0.2),
//                       decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(4)),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.search,
//                             size: 50,
//                             color: primarycolor,
//                           ),
//                           Text('From Search'),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ));
//         });
//   }
//
//   // function For Image Pick
//   Future<void> _pickIMage(ImageSource source) async {
//     final pickedFile = await _picker.pickImage(source: source);
//     if (pickedFile != null) {
//       setState(() {
//         _seclectedImage = File(pickedFile.path);
//       });
//     }
//     Navigator.pop(context);
//   }
//
//   // clear image after refresh
//
//   void _clearImage() {
//     setState(() {
//       _seclectedImage = null;
//       itemNameController.clear();
//
//       Navigator.pop(context);
//     });
//   }
//
//
//   // void _submitItem() {
//   //   final item = {
//   //     "itemname": itemsNameController.text.trim(),
//   //     "price": priceController.text.trim(),
//   //     "description": descriptionController.text.trim(),
//   //     "kg": weightController.text.trim(),
//   //   };
//   //
//   //   // widget.onAdditem!(item);
//   //   Navigator.pop(context); // Close bottom sheet
//   // }
//   @override
//   Widget build(BuildContext context) {
//     return CommonButton(
//         bordercircular: 25,
//         width: ResponsiveHelper.responsiveWidth(context, 0.5),
//         height: ResponsiveHelper.responsiveHeight(context, 0.06),
//         onTap: () {
//           showModalBottomSheet(
//             context: context,
//             isScrollControlled: true,
//             // Allows full-screen height
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//             ),
//             builder: (BuildContext context) {
//               String _SelectedOption = "Each";
//               String dropdownvalue = 'Veg';
//               String dropDownvaluekg = 'KILOGRAM(KG)';
//               var itemskg = ['KILOGRAM(KG)', 'GRAM(GM)'];
//               var items = ['Veg', 'Non-Veg'];
//               return StatefulBuilder(builder: (context, setState) {
//                 return Container(
//                     child: SingleChildScrollView(
//                       // padding: EdgeInsets.only(
//                       //   bottom: MediaQuery.of(context).viewInsets.bottom + 20,
//                       // ),
//                         child: AnimatedContainer(
//                           height:
//                           // height * 0.95,
//                           _SelectedOption == "Weight"
//                               ? ResponsiveHelper.responsiveHeight(context, 0.94)
//                               : ResponsiveHelper.responsiveHeight(
//                               context, 0.91),
//                           decoration: BoxDecoration(
//                             // color: Colors.red,
//                               borderRadius: BorderRadius.only(
//                                   topLeft: Radius.circular(50),
//                                   topRight: Radius.circular(50))),
//                           padding: EdgeInsets.fromLTRB(15, 15, 15, 40),
//                           duration: Duration(microseconds: 1),
//                           child: Column(
//                             // mainAxisSize: MainAxisSize.min,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                           Center(
//                           child: Text(
//                           "Add Item",
//                             textScaler: TextScaler.linear(1),
//                             style: TextStyle(
//                                 fontSize: ResponsiveHelper.responsiveTextSize(
//                                     context, 16),
//                                 fontWeight: FontWeight.bold),
//                           ),
//                         ),
//                         SizedBox(
//                           height: ResponsiveHelper.responsiveHeight(
//                               context, 0.01),
//                         ),
//
//                         // ITem Name
//                         Container(
//                           // color: Colors.red,
//                           height: ResponsiveHelper.responsiveHeight(
//                               context, 0.06),
//                           child: TextField(
//                             controller: itemNameController,
//                             decoration: InputDecoration(
//                               focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(2)),
//                               labelStyle: GoogleFonts.poppins(
//                                 color: Colors.grey,
//                               ),
//                               border: OutlineInputBorder(),
//                               labelText: "Item Name (English)",
//                             ),
//                           ),
//                         ),
//
//                         //   sold by
//                         Row(
//                           children: [
//                             Text("Sold by:"),
//                             Row(
//                               children: [
//                                 Radio(
//                                   value: "Each",
//                                   groupValue: _SelectedOption,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       _SelectedOption = value!;
//                                     });
//
//                                     Future.microtask(() {
//                                       setState(() {});
//                                     });
//                                   },
//                                   activeColor: primarycolor,
//                                 ),
//                                 Text("Each"),
//                               ],
//                             ),
//                             Row(
//                               children: [
//                                 Radio(
//                                   value: "Weight",
//                                   groupValue: _SelectedOption,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       _SelectedOption = value!;
//                                     });
//                                     WidgetsBinding.instance
//                                         .addPostFrameCallback((_) {
//                                       setState(() {});
//                                     });
//                                   },
//                                   activeColor: primarycolor,
//                                 ),
//                                 Text("Weight"),
//                               ],
//                             ),
//                           ],
//                         ),
//
//                         if (_SelectedOption == "Weight")
//                     // SizedBox(width: ResponsiveHelper.responsiveWidth(context, 0.01),),
//                     Container(
//                     height: ResponsiveHelper.responsiveHeight(
//                     context, 0.06),
//
//                 child: TextField(
//                 controller: itemNameController,
//                 decoration: InputDecoration(
//                 focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(2)),
//                 labelStyle: GoogleFonts.poppins(
//                 color: Colors.grey,
//                 ),
//                 border: OutlineInputBorder(),
//                 labelText: "Item Name (English)",
//                 alignment: Alignment.center,
//                 width: double.infinity,
//                 // padding: EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                 // color: Colors.red,
//
//                 border: Border.all(
//                 width: 0.5, color: Colors.grey)),
//                 child: Padding(
//                 padding: const EdgeInsets.symmetric(
//                 horizontal: 5,
//
//                 ),
//                 child: DropdownButtonHideUnderline(
//                 child: DropdownButton(
//                 // underline:  null,
//                 borderRadius: BorderRadius.circular(2),
//                 isExpanded: true,
//                 icon: Icon(
//                 Icons.keyboard_arrow_down_rounded),
//                 value: dropDownvaluekg,
//                 items: itemskg.map((String items) {
//                 return DropdownMenuItem(
//                 value: items,
//                 child: Text(
//                 items,
//                 textScaler: TextScaler.linear(1),
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context, 14),
//                 ),
//                 ),
//                 );
//                 }).toList(),
//                 onChanged: (String? newValue) {
//                 setState(() {
//                 dropDownvaluekg = newValue!;
//                 });
//                 }),
//                 ),
//                 ),
//                 ),
//                 SizedBox(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.01),
//                 ),
//
//                 // price
//                 Container(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.06),
//                 child: TextField(
//                 controller: priceController,
//                 decoration: InputDecoration(
//                 focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(2)),
//                 border: OutlineInputBorder(),
//                 labelText: "Price",
//                 labelStyle: GoogleFonts.poppins(
//                 color: Colors.grey,
//                 ),
//                 ),
//                 keyboardType: TextInputType.number,
//                 ),
//                 ),
//                 SizedBox(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.01),
//                 ),
//
//                 // select category
//                 Container(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.06),
//                 // padding: EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                 // color: Colors.red,
//
//                 border: Border.all(
//                 width: 0.5, color: Colors.black38)),
//                 child: CommonButton(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.05),
//                 bgcolor: Colors.transparent,
//                 bordercolor: Colors.black12,
//                 bordercircular: 0,
//                 onTap: () async {
//                 // Reload the latest category list before showing the bottom sheet
//                 await loadHive();
//                 showModalBottomSheet(
//                 context: context,
//                 builder: (BuildContext context) {
//                 return FutureBuilder(
//                 future: loadHive(),
//                 builder: (context, snapshot) {
//                 return Container(
//                 padding: EdgeInsets.all(20),
//                 height: categorieshive.isEmpty
//                 ? 300
//                     : 500,
//                 child: Column(
//                 children: [
//                 Row(
//                 mainAxisAlignment:
//                 MainAxisAlignment
//                     .spaceBetween,
//                 children: [
//                 Text(
//                 'Select a Category',
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context,
//                 16),
//                 fontWeight:
//                 FontWeight
//                     .w600),
//                 ),
//                 IconButton(
//                 color: Colors.blue,
//                 onPressed: () {
//                 Navigator.pop(
//                 context);
//                 },
//                 icon: Icon(
//                 Icons.cancel,
//                 color:
//                 Colors.grey,
//                 ))
//                 ],
//                 ),
//                 Divider(),
//                 Expanded(
//                 child: categorieshive
//                     .isEmpty
//                 ? Container(
//                 padding:
//                 EdgeInsets
//                     .all(
//                 30),
//                 width: double
//                     .infinity,
//                 height: ResponsiveHelper
//                     .responsiveHeight(
//                 context,
//                 0.2),
//                 // color: Colors.green,
//                 child: Column(
//                 mainAxisAlignment:
//                 MainAxisAlignment
//                     .spaceBetween,
//                 children: [
//                 Text(
//                 'No Category added yet!! Please \nadd  category for your items',
//                 textScaler:
//                 TextScaler.linear(1),
//                 style: GoogleFonts
//                     .poppins(
//                 fontSize: ResponsiveHelper.responsiveTextSize(
//                 context,
//                 12),
//                 ),
//                 textAlign:
//                 TextAlign.center,
//                 ),
//                 CommonButton(
//                 width: double
//                     .infinity,
//                 height: ResponsiveHelper.responsiveHeight(context,
//                 0.08),
//                 onTap:
//                 () {},
//                 child:
//                 Padding(
//                 padding:
//                 const EdgeInsets.all(8.0),
//                 child:
//                 Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                 Container(
//                 decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: Colors.white),
//                 child: Icon(
//                 Icons.add,
//                 ),
//                 ),
//                 SizedBox(
//                 width: ResponsiveHelper.responsiveWidth(context, 0.03),
//                 ),
//                 Text(
//                 'Add New Category',
//                 style: GoogleFonts.poppins(color: Colors.white),
//                 )
//                 ],
//                 ),
//                 ))
//                 ],
//                 ),
//                 )
//
//                 // :ListView.builder(
//                 // itemCount: categoryList.length,
//                 // itemBuilder: (context,index){
//                 //   return ListTile(
//                 //     title: Text(categoryList[index]['title']),
//                 //      onTap: (){
//                 //       setState((){
//                 //         selectedCategory = categoryList[index]['title'];
//                 //       });
//                 //       Navigator.pop(context);
//                 //      },
//                 //   );
//                 // })
//                     : ListView
//                     .builder(
//                 itemCount:
//                 categorieshive
//                     .length,
//                 itemBuilder:
//                 (context,
//                 index) {
//                 var category = categorieshive[index];
//
//                 return InkWell(
//                 onTap:
//                 () {
//                 setState(() {
//                 selectedCategory = category.name;
//                 });
//                 Navigator.pop(context);
//                 },
//                 child:
//                 Container(
//                 child:
//                 Column(
//                 children: [
//                 Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                 Row(
//                 children: [
//                 Checkbox(value: true, onChanged: (value) {}),
//                 Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                 Text(
//                 category.name,
//                 style: GoogleFonts.poppins(
//                 fontWeight: FontWeight.w600,
//                 fontSize: ResponsiveHelper.responsiveTextSize(context, 18),
//                 ),
//                 ),
//                 Text(
//                 '0 Product Listed',
//                 style: GoogleFonts.poppins(fontSize: ResponsiveHelper.responsiveTextSize(context, 14), color: Colors.grey),
//                 )
//                 ],
//                 ),
//                 ],
//                 ),
//                 Row(
//                 children: [
//                 Container(
//                 width: ResponsiveHelper.responsiveWidth(context, 0.1),
//                 height: ResponsiveHelper.responsiveHeight(context, 0.04),
//                 decoration: BoxDecoration(color: primarycolor, borderRadius: BorderRadius.circular(5)),
//                 child: Icon(
//                 Icons.edit,
//                 color: Colors.white,
//                 ),
//                 ),
//                 SizedBox(
//                 width: 5,
//                 ),
//                 Container(
//                 width: ResponsiveHelper.responsiveWidth(context, 0.1),
//                 height: ResponsiveHelper.responsiveHeight(context, 0.04),
//                 decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
//                 child: Icon(
//                 Icons.delete,
//                 color: Colors.white,
//                 ),
//                 ),
//                 ],
//                 )
//                 ],
//                 ),
//                 Divider()
//                 ],
//                 ),
//                 ),
//                 );
//                 }))
//                 ],
//                 ),
//                 );
//                 });
//                 });
//                 },
//                 child: Padding(
//                 padding: const EdgeInsets.symmetric(
//                 horizontal: 5),
//                 child: Row(
//                 mainAxisAlignment:
//                 MainAxisAlignment.spaceBetween,
//                 children: [
//                 Text(
//                 selectedCategory ?? 'Select Category',
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context, 16),
//                 ),
//                 ),
//                 Icon(Icons.arrow_forward_ios)
//                 ],
//                 ),
//                 ))),
//                 SizedBox(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.01),
//                 ),
//
//                 // veg
//                 InkWell(
//                 onTap: () {
//                 showModalBottomSheet(
//                 context: context,
//                 builder: (context) {
//
//                 return StatefulBuilder(
//                 builder: (context, setModalState) {
//                 return Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                 Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                 Text(
//                 'Select Category',
//                 style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 ),
//                 ),
//                 GestureDetector(
//                 onTap: () => Navigator.pop(context),
//                 child: Icon(Icons.close),
//                 ),
//                 ],
//                 ),
//                 ),
//                 Divider(thickness: 1),
//                 Container(
//                 margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 decoration: BoxDecoration(
//                 border: Border.all(color: Colors.black, width: 1),
//                 borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: ListTile(
//                 leading: Icon(Icons.circle, color: Colors.green),
//                 title: Text('Veg'),
//                 onTap: () {
//                 setState(() {
//                 selectedIMGCategory = 'Veg';
//                 });
//                 Navigator.pop(context);
//                 },
//                 ),
//                 ),
//                 Container(
//                 margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 decoration: BoxDecoration(
//                 border: Border.all(color: Colors.black, width: 1),
//                 borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: ListTile(
//                 leading: Icon(Icons.circle, color: Colors.red),
//                 title: Text('Non-Veg'),
//                 onTap: () {
//                 setState(() {
//                 selectedIMGCategory = 'Non-Veg';
//                 });
//                 Navigator.pop(context);
//                 },
//                 ),
//                 ),
//                 ],
//                 );
//                 },
//                 );
//                 },
//                 );
//                 },
//                 child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 12, vertical:10 ),
//                 decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey),
//                 borderRadius: BorderRadius.circular(3),
//                 ),
//                 child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                 Row(
//                 children: [
//                 if (selectedIMGCategory == 'Veg') ...[
//                 Icon(Icons.circle, color: Colors.green, size: 16),
//                 SizedBox(width: 6),
//                 Text('Veg', style: TextStyle(color: Colors.black)),
//                 ] else if (selectedIMGCategory == 'Non-Veg') ...[
//                 Icon(Icons.circle, color: Colors.red, size: 16),
//                 SizedBox(width: 6),
//                 Text('Non-Veg', style: TextStyle(color: Colors.black)),
//                 ] else ...[
//                 Text('Select Veg / Non-Veg', style: TextStyle(color: Colors.grey)),
//                 ],
//                 ],
//                 ),
//                 Icon(Icons.keyboard_arrow_down_rounded),
//                 ],
//                 ),
//                 ),
//                 ),
//                 SizedBox(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.01),
//                 ),
//                 /// Description
//                 Container(
//                 height: 50,
//                 child: TextField(
//                 controller: descriptionController,
//                 decoration: InputDecoration(
//                 focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(2)),
//                 border: OutlineInputBorder(),
//                 labelStyle: GoogleFonts.poppins(
//                 color: Colors.grey,
//                 ),
//                 labelText: "Description (Optional)"),
//                 ),
//                 ),
//                 SizedBox(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.01),
//                 ),
//                 // Manage inventory
//                 Container(
//                 padding: EdgeInsets.symmetric(
//                 horizontal: 10, vertical: 5),
//                 decoration: BoxDecoration(border: Border.all()),
//                 child: Row(
//                 mainAxisAlignment:
//                 MainAxisAlignment.spaceBetween,
//                 children: [
//                 Text(
//                 "Manage Inventory",
//                 style: GoogleFonts.poppins(
//                 fontWeight: FontWeight.w600,
//                 ),
//                 ),
//                 Row(
//                 children: [
//                 Filterbutton(
//                 title: 'YES',
//                 selectedFilter: selectedFilter,
//                 onpressed: () {
//                 setState(() {
//                 selectedFilter = "YES";
//                 });
//                 },
//                 ),
//                 SizedBox(width: 10,),
//                 Filterbutton(
//                 title: 'NO',
//                 selectedFilter: selectedFilter,
//                 onpressed: () {
//                 setState(() {
//                 selectedFilter = "NO";
//                 });
//                 },
//                 ),
//                 ],
//                 ),
//                 ],
//                 ),
//                 ),
//                 SizedBox(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.02),
//                 ),
//                 /// manage inventory was finished here
//                 // Image
//                 GestureDetector(
//                 onTap: _showImagePicker,
//                 child: Column(
//                 children: [
//                 Container(
//                 height:
//                 ResponsiveHelper.responsiveHeight(
//                 context, 0.14),
//                 decoration: BoxDecoration(
//                 // color: Colors.green,
//
//                 border:
//                 Border.all(color: Colors.grey),
//                 borderRadius:
//                 BorderRadius.circular(10),
//                 ),
//                 child: _seclectedImage != null
//                 ? Image.file(
//                 _seclectedImage!,
//                 fit: BoxFit.cover,
//                 height: 40,
//                 width: 150,
//                 )
//                     : Column(
//                 mainAxisAlignment:
//                 MainAxisAlignment.center,
//                 children: [
//                 Center(
//                 child: Icon(Icons.image,
//                 color: Colors.grey,
//                 size: 40)),
//                 Text(
//                 textScaler:
//                 TextScaler.linear(1),
//                 'Upload Image',
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context, 14),
//                 fontWeight:
//                 FontWeight.w500),
//                 ),
//                 Text(
//                 '600X400',
//                 textScaler:
//                 TextScaler.linear(1),
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context, 14),
//                 ),
//                 )
//                 ],
//                 )),
//                 Text(
//                 'Upload Image (png , .jpg, .jpeg) upto 3mb',
//                 textScaler: TextScaler.linear(1),
//                 style: GoogleFonts.poppins(
//                 color: Colors.grey,
//                 fontSize:
//                 ResponsiveHelper.responsiveTextSize(
//                 context, 10),
//                 ),
//                 )
//                 ],
//                 )),
//                 SizedBox(
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.02),
//                 ),
//                 _SelectedOption == "Weight"
//                 ? CommonButton (
//                 onTap: () {
//                 _clearImage();
//                 loadHive();
//                 },
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.05),
//                 width: ResponsiveHelper.responsiveWidth(
//                 context, 0.9),
//                 child: Row(
//                 mainAxisAlignment:
//                 MainAxisAlignment.center,
//                 children: [
//                 Container(
//                 decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius:
//                 BorderRadius.circular(10)),
//                 child: Icon(Icons.add)),
//                 SizedBox(width: 5),
//                 Text(
//                 'Quick Add',
//                 textScaler: TextScaler.linear(1),
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context, 12),
//                 color: Colors.white),
//                 )
//                 ],
//                 ),
//                 )
//                     : Row(
//                 mainAxisAlignment:
//                 MainAxisAlignment.spaceBetween,
//                 children: [
//                 Expanded(
//                 child: CommonButton(
//                 onTap: () {},
//                 bgcolor: Colors.white,
//                 bordercolor: Colors.deepOrange,
//                 height:
//                 ResponsiveHelper.responsiveHeight(
//                 context, 0.06),
//                 width:
//                 ResponsiveHelper.responsiveWidth(
//                 context, 0.35),
//                 child: Row(
//                  return Container(
//                 // color: Colors.red,
//                 padding: EdgeInsets.symmetric(
//                 horizontal: 20, vertical: 20),
//                 width: ResponsiveHelper.maxContentWidth(
//                 context),
//                 height: ResponsiveHelper.responsiveHeight(
//                 context, 0.4),
//                 child: Column(
//                 crossAxisAlignment:
//                 CrossAxisAlignment.center,
//                 children: [
//                 Row(
//                   mainAxisAlignment:
//                 MainAxisAlignment.spaceBetween,
//                 children: [
//                 Text(
//                 'Select Veg/ Non-Veg/Others',
//                 textScaler:
//                 TextScaler.linear(1),
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context, 16),
//                 ),
//                 ),
//                 IconButton(
//                 onPressed: () {
//                 Navigator.pop(context);
//                 },
//                 icon: Icon(Icons.cancel))
//                 ],
//                 ),
//                 SizedBox(
//                 height: ResponsiveHelper
//                     .responsiveHeight(
//                 context, 0.02),
//                 ),
//                 Container(
//                 padding: EdgeInsets.all(15),
//                 decoration: BoxDecoration(
//                 border: Border.all()),
//                 width: ResponsiveHelper
//                     .responsiveWidth(context, 0.8),
//                 height: ResponsiveHelper
//                     .responsiveHeight(
//                 context, 0.09),
//                 child: Row(
//                 children: [
//                 Icon(
//                 Icons.circle,
//                 color: Colors.green,
//                 ),
//                 SizedBox(
//                 width: ResponsiveHelper
//                     .responsiveWidth(
//                 context, 0.03),
//                 ),
//                 Text(
//                 'Veg',
//                 textScaler:
//                 TextScaler.linear(1),
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context, 16),
//                 ),
//                 )
//                 ],
//                 ),
//                 ),
//                 SizedBox(
//                 height: ResponsiveHelper
//                     .responsiveHeight(
//                 context, 0.02),
//                 ),
//                 Container(
//                 padding: EdgeInsets.all(15),
//                 decoration: BoxDecoration(
//                 border: Border.all()),
//                 width: ResponsiveHelper
//                     .responsiveWidth(context, 0.8),
//                 height: ResponsiveHelper
//                     .responsiveHeight(
//                 context, 0.09),
//                 child: Row(
//                 children: [
//                 Icon(
//                 Icons.circle,
//                 color: Colors.red,
//                 ),
//                 SizedBox(
//                 width: ResponsiveHelper
//                     .responsiveWidth(
//                 context, 0.03),
//                 ),
//                 Text(
//                 'Non-Veg',
//                 textScaler:
//                 TextScaler.linear(1),
//                 style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper
//                     .responsiveTextSize(
//                 context, 16),
//                 ),
//                 )
//                 ],
//                 ),
//                 ),
//                 ]
//                 ,
//                 )
//                 ,
//                 );
//               });
//             },
//             child: Container(
//                 padding: EdgeInsets.symmetric(
//                     horizontal: 10, vertical: 5),
//                 // alignment: Alignment.sta,
//                 width: double.infinity,
//                 height: ResponsiveHelper.responsiveHeight(
//                     context, 0.06),
//                 // padding: EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   // color: Colors.red,
//
//                     border: Border.all(
//                         width: 1, color: Colors.black38)),
//                 child: Row(
//                   mainAxisAlignment:
//                   MainAxisAlignment.spaceBetween,
//                   children: [
//                     Row(
//                       mainAxisAlignment:
//                       MainAxisAlignment.start,
//                       children: [
//                         Container(
//                             decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 shape: BoxShape.rectangle,
//                                 border: Border.all(
//                                     color: Colors.green)),
//                             child: Icon(
//                               Icons.circle,
//                               size: 20,
//                               color: Colors.green,
//                             )),
//                         SizedBox(
//                           width: 10,
//                         ),
//                         Text(
//                           'Veg',
//                           style: GoogleFonts.poppins(
//                             fontSize: ResponsiveHelper
//                                 .responsiveTextSize(
//                                 context, 16),
//                           ),
//                         ),
//                       ],
//                     ),
//                     Icon(Icons.keyboard_arrow_down_sharp)
//                   ],
//                 )),
//           )
//           ,
// / veg nonveg was finished
//           SizedBox(
//           height: ResponsiveHelper.responsiveHeight(
//           context, 0.01),
//           ),
//
//           // Description
//           Container(
//           height: 50,
//           child: TextField(
//           decoration: InputDecoration(
//           focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(2)),
//           border: OutlineInputBorder(),
//           labelStyle: GoogleFonts.poppins(
//           color: Colors.grey,
//           ),
//           labelText: "Description (Optional)"),
//           ),
//           ),
//           SizedBox(
//           height: ResponsiveHelper.responsiveHeight(
//           context, 0.01),
//           ),
//
//           // Manage inventory
//           Container(
//           padding: EdgeInsets.symmetric(
//           horizontal: 10, vertical: 5),
//           decoration: BoxDecoration(border: Border.all()),
//           child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//           Text(
//           "Manage Inventory",
//           style: GoogleFonts.poppins(
//           fontWeight: FontWeight.w600,
//           ),
//           ),
//           Row(
//           children: [
//           CommonButton(
//           onTap: () {},
//           width: 60,
//           height: 30,
//           bgcolor: Colors.white,
//           bordercolor: primarycolor,
//           bordercircular: 2,
//           child: Text(
//           "Yes",
//           textAlign: TextAlign.center,
//           )),
//           SizedBox(width: 10),
//           CommonButton(
//           onTap: () {},
//           width: 60,
//           height: 30,
//           // bgcolor: Colors.white,
//           bordercolor: primarycolor,
//           bordercircular: 2,
//           child: Text(
//           "No",
//           textAlign: TextAlign.center,
//           style: TextStyle(color: Colors.white),
//           )),
//           ],
//           ),
//           ],
//           ),
//           ),
//           SizedBox(
//           height: ResponsiveHelper.responsiveHeight(
//           context, 0.02),
//           ),
//
//
//           // Image
//           GestureDetector(
//           onTap: _showImagePicker,
//           child: Column(
//           children: [
//           Container(
//           height: ResponsiveHelper.responsiveHeight(
//           context, 0.14),
//           decoration: BoxDecoration(
//           // color: Colors.green,
//
//           border: Border.all(color: Colors.grey),
//           borderRadius: BorderRadius.circular(10),
//           ),
//           child: _seclectedImage != null
//           ? Image.file(
//           _seclectedImage!,
//           fit: BoxFit.cover,
//           height: 40,
//           width: 150,
//           )
//               : Column(
//           mainAxisAlignment:
//           MainAxisAlignment.center,
//           children: [
//           Center(
//           child: Icon(Icons.image,
//           color: Colors.grey,
//           size: 40)),
//           Text(
//           textScaler:
//           TextScaler.linear(1),
//           'Upload Image',
//           style: GoogleFonts.poppins(
//           fontSize: ResponsiveHelper
//               .responsiveTextSize(
//           context, 14),
//           fontWeight:
//           FontWeight.w500),
//           ),
//           Text(
//           '600X400',
//           textScaler:
//           TextScaler.linear(1),
//           style: GoogleFonts.poppins(
//           fontSize: ResponsiveHelper
//               .responsiveTextSize(
//           context, 14),
//           ),
//           )
//           ],
//           )),
//           Text(
//           'Upload Image (png , .jpg, .jpeg) upto 3mb',
//           textScaler: TextScaler.linear(1),
//           style: GoogleFonts.poppins(
//           color: Colors.grey,
//           fontSize:
//           ResponsiveHelper.responsiveTextSize(
//           context, 10),
//           ),
//           )
//           ],
//           )),
//           SizedBox(
//           height: ResponsiveHelper.responsiveHeight(
//           context, 0.02),
//           ),
//           _SelectedOption == "Weight"
//           ? CommonButton(
//           onTap: () {
//           _clearImage();
//           },
//           height: ResponsiveHelper.responsiveHeight(
//           context, 0.05),
//           width: ResponsiveHelper.responsiveWidth(
//           context, 0.9),
//           child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//           Container(
//           decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius:
//           BorderRadius.circular(10)),
//           child: Icon(Icons.add)),
//           SizedBox(width: 5),
//           Text(
//           'Quick Add',
//           textScaler: TextScaler.linear(1),
//           style: GoogleFonts.poppins(
//           fontSize: ResponsiveHelper
//               .responsiveTextSize(
//           context, 12),
//           color: Colors.white),
//           )
//           ],
//           ),
//           )
//               : Row(
//           mainAxisAlignment:
//           MainAxisAlignment.spaceBetween,
//           children: [
//           Expanded(
//           child: CommonButton(
//           onTap: () {},
//           bgcolor: Colors.white,
//           bordercolor: Colors.deepOrange,
//           height:
//           ResponsiveHelper.responsiveHeight(
//           context, 0.06),
//           width: ResponsiveHelper.responsiveWidth(
//           context, 0.35),
//           child: Row(
//           mainAxisAlignment:
//           MainAxisAlignment.center,
//           children: [
//           Container(
//           decoration: BoxDecoration(
//           color: Colors.deepOrange,
//           borderRadius:
//           BorderRadius.circular(
//           10)),
//           child: Icon(Icons.add,
//           color: Colors.white)),
//           SizedBox(width: 10),
//           Text(
//           'Add More Info',
//           textScaler: TextScaler.linear(1),
//           style: GoogleFonts.poppins(
//           fontSize: ResponsiveHelper
//               .responsiveTextSize(
//           context, 12),
//           ),
//           )
//           ],
//           ),
//           ),
//           ),
//           SizedBox(
//           width: ResponsiveHelper.responsiveWidth(
//           context, 0.01),
//           ),
//           Expanded(
//           child: CommonButton(
//
//           onTap: (){
//           _addItem(); /// call the funciton fo t
//           },
//           height:
//
//
//           onTap: () {
//           _submitItem();
//           Navigator.pop(context);
//           _clearImage();
//           },
//           height:
//           >>>>>>> ce9bf255092d36e8c995f55498bb014acdf99ba2
//           ResponsiveHelper.responsiveHeight(
//           context, 0.06),
//           width: ResponsiveHelper.responsiveWidth(
//           context, 0.35),
//           child: Row(
//           mainAxisAlignment:
//           MainAxisAlignment.center,
//           children: [
//           Container(
//           decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius:
//           BorderRadius.circular(10)),
//           child: Icon(Icons.add)),
//           SizedBox(width: 5),
//           Text("Add items")
//
//           ],
//           ),
//           ),
//           ),
//           ],
//           )
//           ],
//           ),
//           ),
//           ),
//           );
//         });
//   }
//
//   ,
//
//   );
// },child: Row
// (
// mainAxisAlignment: MainAxisAlignment.center,
// children: [
// Container(
// child: Icon(Icons.add),
// decoration: BoxDecoration(
// color: Colors.white, borderRadius: BorderRadius.circular(15)),
// ),
// SizedBox(
// width: 5,
// ),
// Text(
// 'Add items',
// style: GoogleFonts.poppins(
// color: Colors.white,
// fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
// ),
// )
// ]
// ,
// )
// );
// }
// }
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
