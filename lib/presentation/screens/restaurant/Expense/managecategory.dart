import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_expensecategory.dart';
import 'package:unipos/data/models/restaurant/db/expensemodel_315.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/color.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';

class ManageCategory extends StatefulWidget {
  const ManageCategory({super.key});

  @override
  State<ManageCategory> createState() => _ManageCategoryState();
}



TextEditingController categoryController = TextEditingController();



class _ManageCategoryState extends State<ManageCategory> {


  Future<void>AddECategory()async{
    if(categoryController.text.trim().isEmpty){
      Navigator.pop(context);
      NotificationService.instance.showError('Category Name Cannot Be Empty');
      return ;
    }
    final  category = ExpenseCategory(
        id: Uuid().v4(),
        name: categoryController.text.trim());

    await HiveExpenseCat.addECategory(category);
    _clear();
    Navigator.pop(context);
  }


  void _clear(){
    setState(() {
      categoryController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios)),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.person_2_outlined),
                Text('Admin')
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              Column(
                children: [
                  Text('Manage Category',style:GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),),
                  SizedBox(height: 10,),
                  CommonButton(
                      bordercircular: 0,
                      height: height * 0.05,
                      width: width * 0.6,
                      onTap: (){
                        showModalBottomSheet(context: context,
                            builder: (BuildContext context){
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 10,vertical: 20),
                                height:  height * 0.35,
                                width: double.infinity,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Add New Expense Category',                          textScaler: TextScaler.linear(1),
                                            style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w500),),
                                          InkWell(
                                              onTap: (){
                                                Navigator.pop(context);
                                              },
                                              child: Icon(Icons.cancel,color: Colors.grey,))
                                        ],
                                      ),

                                      SizedBox(height: 25,),

                                      Text('Category Name',                          textScaler: TextScaler.linear(1),
                                        style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w400),),

                                      SizedBox(height: 10,),
                                      Container(
                                        // width: width * 0.45,
                                        height: height * 0.07,
                                        child: CommonTextForm(
                                            borderc: 0,
                                            BorderColor: AppColors.primary,
                                            controller: categoryController,
                                            HintColor: Colors.grey,
                                            hintText: 'Enter Category Name',
                                            obsecureText: false),
                                      ),

                                      SizedBox(height: 15,),

                                      CommonButton(
                                          bordercircular: 0,
                                          height: height* 0.05,
                                          onTap: (){
                                            AddECategory();
                                          }, child: Text('Add',style:GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w600)))

                                    ],
                                  ),
                                ),
                              );
                            });
                      },
                      child: Row(children: [
                        Icon(Icons.add,color: Colors.white,),
                        Text('Add New Category',style: GoogleFonts.poppins(color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        )
                      ],)),
                ],
              ),

              Column(children: [

                ValueListenableBuilder(valueListenable: HiveExpenseCat.getECategory().listenable(),
                    builder: (context,ecatgory,_){

                      final  allcategory = ecatgory.values.toList();

                      return Container(
                        // color: Colors.red,
                        width: width,
                        height: height * 0.45,
                        child: ListView.builder(
                            itemCount: allcategory.length,
                            itemBuilder:(context,index){
                              final category = allcategory[index];
                              return Container(
                                padding: EdgeInsets.all(10),
                                margin: EdgeInsets.all(5),
                                decoration:BoxDecoration(
                                    border: Border.all(color: Colors.grey)
                                ),
                                // color: Colors.green,
                                height: height * 0.07,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(category.name),
                                    Row(
                                      children: [



                                        InkWell(
                                            onTap: (){
                                              delete(category.id);

                                            },
                                            child: Icon(Icons.delete)),

                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch(
                                              value: category.isEnabled,
                                              onChanged: (bool value)async{
                                                category.isEnabled = value;
                                                await category.save();
                                              }),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              );
                            }),
                      );

                    })

              ],)



            ],
          ),
        ),
      ),
    );
  }
  void delete(String id)async{
    await HiveExpenseCat.deleteECategory(id);
  }
}
