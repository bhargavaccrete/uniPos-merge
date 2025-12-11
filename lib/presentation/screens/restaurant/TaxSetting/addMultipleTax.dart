import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:uuid/uuid.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/database/hive_tax.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import 'apply_tax_screen.dart';

class Addtax extends StatefulWidget {
  @override
  State<Addtax> createState() => _AddtaxState();
}

class _AddtaxState extends State<Addtax> {
  bool _ischecked1 = false;


  final TextEditingController _taxNameController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();





  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _taxNumberController.dispose();
    _taxNameController.dispose();
  }

  void _clearControllers(){
    _taxNumberController.clear();
    _taxNameController.clear();
  }

  Future<void> _addOrUpdateTax({Tax? existingTax})async{
    final taxName = _taxNameController.text.trim();
    final taxPercentage = double.tryParse(_taxNumberController.text.trim());

    if(taxName.isEmpty || taxPercentage == null){
      NotificationService.instance.showInfo(
        'Enter a valid Tax Name/Number',
      );
      return ;
    }

    if(existingTax != null){
      existingTax.taxname = taxName;
      existingTax.taxperecentage = taxPercentage;
      await TaxBox.updateTax(existingTax);
    }else {
      final newTax = Tax(
        id: Uuid().v4(),
        taxname: taxName,
        taxperecentage: taxPercentage,
      );
      await TaxBox.addTax(newTax);

      // Apply tax to all items if checkbox is checked
      if(_ischecked1) {
        await _applyTaxToAllItems(taxPercentage);
      }
    }
    _clearControllers();
    setState(() {
      _ischecked1 = false;
    });
    Navigator.pop(context);
  }


  void _delete(String id)async{
    await TaxBox.deleteTax(id);
    Navigator.pop(context);
  }

  Future<void> _applyTaxToAllItems(double taxPercentage) async {
    final itemBox = Hive.box<Items>('itemBoxs');
    final rate = taxPercentage / 100.0;

    for (final item in itemBox.values) {
      item.applyTax(rate);
    }

    NotificationService.instance.showInfo(
      'Tax applied to all items',
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;
    return Scaffold(
        appBar: AppBar(
          elevation: 1,
          actions: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [Icon(Icons.person), Text('Admin')],
              ),
            )
          ],
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              children: [

                Container(
                  // color: Colors.red,
                  width: width * 0.9,
                  height: height * 0.6,
                  child:
                  FutureBuilder<Box<Tax>>(
                      future: TaxBox.getTaxBox(),
                      builder: (context, snapshot){
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final allTax = snapshot.data!.values.toList();

                        if (allTax.isEmpty) {
                          return Column(
                            children: [
                              Container(
                                height: height * 0.1,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(color: Colors.grey)),
                                child: ListTile(
                                  leading: Icon(Icons.calculate, size: 50),
                                  title: Text(
                                    "Add Tax to your items",
                                    style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    "You have not configured any taxes yet.",
                                    style: TextStyle(
                                        color: Colors.blueGrey[200], fontSize: 15.0),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              Image.asset(
                                'assets/images/taximage.png',
                                height: height * 0.5,
                              ),
                              SizedBox(height: 25),
                            ],
                          );
                        }


                        return Container(
                          width: 200,
                          height: 100,
                          child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: allTax.length,
                              itemBuilder: (context,index){
                                final tax = allTax[index];
                                return Card(
                                  elevation: 5,
                                  child: Container(
                                    padding: EdgeInsets.all(10),
                                    width: width,
                                    height: height * 0.2,
                                    child: Column(
                                      children: [

                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Text('TaxName:',style: GoogleFonts.poppins(color: Colors.deepOrange,fontWeight: FontWeight.w500),),
                                                SizedBox(width: 5),
                                                Text(tax.taxname,style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.w500)),
                                              ],
                                            ),

                                            Row(
                                              children: [
                                                InkWell(
                                                  onTap: (){
                                                    _model(height, width,existingTax: tax);
                                                  },
                                                  child: Container(
                                                      padding: EdgeInsets.all(5),
                                                      decoration: BoxDecoration(color: Colors.grey.shade200),
                                                      child: Icon(Icons.edit,color: Colors.grey.shade500,)),
                                                ),
                                                SizedBox(width: 5,),
                                                InkWell(
                                                  onTap: ()=> _showDeleteConfirmation(context, height, width, tax.id),
                                                  child: Container(
                                                    padding: EdgeInsets.all(5),
                                                    decoration: BoxDecoration(color: Colors.red),
                                                    child:Icon(Icons.delete,color: Colors.white,),),
                                                )
                                              ],
                                            )
                                          ],
                                        ),
                                        RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.poppins(color: Colors.black, fontSize: 16),
                                            children: [
                                              TextSpan(text: 'Tax Rate: ', style: TextStyle(color: Colors.deepOrange)),
                                              TextSpan(text: '${tax.taxperecentage}%'),
                                            ],
                                          ),
                                        ),

                                        SizedBox(height: 20,),

                                        CommonButton(

                                            bordercircular: 5,
                                            width: width * 0.7,
                                            height:  height * 0.06,
                                            onTap: (){

                                              // TODO: Navigate to the item selection screen
                                              Navigator.push(context, MaterialPageRoute(builder: (_) => ApplyTaxScreen(taxToApply: tax,)));


                                            },
                                            child:Text('Apply Tax on items',style: GoogleFonts.poppins(color: Colors.white,fontSize: 14),))

                                      ],
                                    ),
                                  ),
                                );
                              }),
                        );

                      }),
                ),


// Spacer(),


                CommonButton(
                  bgcolor: primarycolor,
                  bordercircular: 10,
                  height: height * 0.06,
                  width: width * 0.8,
                  onTap: () {
                    _model(height,width);
                  },

                  child: Text(
                    "Add Tax ",
                    textScaler: TextScaler.linear(1.2),
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),


              ],
            ),
          ),
        ));
  }


  // ✅ 6. REFACTORED: Delete confirmation moved to its own method for clarity.
  void _showDeleteConfirmation(BuildContext context, double height, double width, String taxId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          height: height * 0.40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 60),
              SizedBox(height: 15),
              Text('Delete Tax', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('Are you sure you want to delete this tax?', textAlign: TextAlign.center),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CommonButton(
                        bordercolor: Colors.grey,
                        bgcolor: Colors.white,
                        bordercircular: 5,
                        onTap: () {
                          // ✅ 7. FIXED: Cancel button now closes the modal.
                          Navigator.pop(context);
                        },
                        child: Text('Cancel', style: TextStyle(color: Colors.black))),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: CommonButton(
                        bordercolor: Colors.red,
                        bgcolor: Colors.red,
                        bordercircular: 5,
                        onTap: () => _delete(taxId),
                        child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white))),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }


  Future<void> _model(double height, double width, {Tax? existingTax}) {
    bool isEdit = existingTax != null;

    if (isEdit) {
      _taxNameController.text = existingTax.taxname;
      _taxNumberController.text = existingTax.taxperecentage.toString();
      // Set checkboxes based on saved values
      // _ischecked1 = existingTax.isAppliedToAll;
      // _ischecked2 = existingTax.isInclusive;
    } else {
      // Clear fields when adding a new tax
      _clearControllers();
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for keyboard handling
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16, right: 16, top: 16
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isEdit ? 'Edit Tax' : 'Add Tax Name & Number',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close))
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: CommonTextForm(
                            obsecureText: false,
                            controller: _taxNameController,
                            labelText: 'Tax Name*',
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: CommonTextForm(
                            controller: _taxNumberController,
                            labelText: 'Tax %',
                            keyboardType: TextInputType.numberWithOptions(decimal: true), obsecureText: false, // Better keyboard
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Checkbox(
                            value: _ischecked1,
                            activeColor: primarycolor,
                            onChanged: (bool? value) {
                              setModalState(() => _ischecked1 = value ?? false);
                            }),
                        Text("Apply to all items")
                      ],
                    ),
                    SizedBox(height: 20),
                    CommonButton(
                        onTap: () => _addOrUpdateTax(existingTax: existingTax),
                        height: height * 0.06,
                        width: width * 0.9,
                        child: Center(
                            child: Text(
                              isEdit ? "Update" : "Submit",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ))),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

