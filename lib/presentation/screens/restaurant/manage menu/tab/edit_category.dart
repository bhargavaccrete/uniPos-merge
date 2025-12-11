import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_db.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/audit_trail_helper.dart';

class EditCategory extends StatefulWidget {
  final Category category;
  const EditCategory({super.key, required this.category,});

  @override
  State<EditCategory> createState() => _EditCategoryState();
}

class _EditCategoryState extends State<EditCategory> {

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController nameController = TextEditingController();
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
              padding: EdgeInsets.all(10),
              width: double.infinity,
              // color: Colors.red,
              height:MediaQuery.of(context).size.height * 0.3 ,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      alignment: Alignment.center,

                      width: MediaQuery.of(context).size.width * 0.4,
                      height:MediaQuery.of(context).size.height * 0.2 ,

                      decoration: BoxDecoration(
                        // color: Colors.green,
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
                    width: MediaQuery.of(context).size.width * 0.4,
                    height:MediaQuery.of(context).size.height * 0.2 ,

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
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
    Navigator.pop(context);
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    nameController = TextEditingController(text: widget.category.name);
    // _selectedImage = widget.category.imagePath.;
    // saveChanges();
  }

  void saveChanges()async{
    final updateCategory = widget.category.copyWith(
        name: nameController.text,
        imagePath: _selectedImage != null ? _selectedImage!.path: null
    );

    // 🔍 AUDIT TRAIL: Track this category edit
    AuditTrailHelper.trackEdit(updateCategory, editedBy: 'Admin'); // TODO: Replace 'Admin' with actual logged-in user

    await HiveBoxes.updateCategory(updateCategory);
    Navigator.pop(context, true);

  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primarycolor,
        title: Text('Edit Category',style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 20),),
        automaticallyImplyLeading: false,
        leading: InkWell(
            onTap: (){
              Navigator.pop(context);
            },
            child: Icon(Icons.arrow_back_ios_new,color: Colors.white,)),
      ),

      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: Column(
            children: [
              Container(

                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2)),
                    labelStyle: GoogleFonts.poppins(
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(),
                    labelText: "Category Name (English)",
                  ),
                ),
              ),

              SizedBox(height: 20,),
              InkWell(
                  onTap: _showImagePicker,
                  child: Column(
                    children: [
                      Container(
                        // color:Colors.red,
                          height:height * 0.2,
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
                                      color:
                                      Colors.grey,
                                      size: 50)),
                              SizedBox(
                                height: 5,
                              ),
                              Text(
                                'Upload Image',
                                textScaler: TextScaler.linear(1),

                                style:

                                GoogleFonts.poppins(
                                    fontSize:16,

                                    fontWeight:
                                    FontWeight
                                        .w500),
                              ),
                              Text('600X400',textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(
                                    fontSize: 12

                                ),)
                            ],
                          )),
                      Text(
                          'Upload Image (png , .jpg, .jpeg) upto 3mb',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 12))
                    ],
                  )),

              SizedBox(height: 20,),

              CommonButton(
                  onTap:(){
                    saveChanges();
                  },
                  bordercircular: 5,
                  width:width * 0.9,
                  height: height * 0.06,
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                              BorderRadius.circular(10)),
                          child: Icon(Icons.add)),
                      SizedBox(
                        width: 5,
                      ),
                      Text(
                        'Update Category',
                        style: GoogleFonts.poppins(
                            fontSize: 12,

                            color: Colors.white),
                      )
                    ],
                  )),

            ],
          ),
        ),
      ),
    );
  }
}
