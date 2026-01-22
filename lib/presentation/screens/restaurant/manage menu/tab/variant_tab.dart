import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/images.dart';
import 'package:unipos/util/restaurant/images.dart';
import 'package:uuid/uuid.dart';


class VariantTab extends StatefulWidget {
  const VariantTab({super.key});

  @override
  State<VariantTab> createState() => _VariantTabState();
}

class _VariantTabState extends State<VariantTab> {
  TextEditingController VariantController = TextEditingController();

  // List<VariantModel> variantsList = [];

  VariantModel? editingVariante;

  void openBottomSheet({VariantModel? variante}) {
    if (variante != null) {
      print("Before set: ${VariantController.text}");
      VariantController.text = variante.name;
      editingVariante =variante;
      print("After set: ${VariantController.text}");
    } else {
      VariantController.clear();
      editingVariante = null;
    }
    showModalBottomSheet(
        context: context,
        builder: (context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: showMOdel()));
  }

  Future<void> _addOrEditVariante() async {
    final trimmedName = VariantController.text.trim();

    //   Do Not proceed if input is empty
    if (trimmedName.isEmpty) return;

    if (editingVariante != null) {
      final updateVariante = VariantModel(
          id: editingVariante!.id,
          name: trimmedName);
      await variantStore.updateVariant(updateVariante);
    } else {
      final newvariante = VariantModel(id: Uuid().v4(), name: trimmedName);
      await variantStore.addVariant(newvariante);
    }

    VariantController.clear();
    editingVariante = null;

    Navigator.pop(context);
  }

  Future<void> _delete(String id) async {
    await variantStore.deleteVariant(id);
    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Observer(
                  builder: (_) {
                    final allvariante = variantStore.variants.toList();

                    if (allvariante.isEmpty) {
                      return Container(
                        height: height * 0.7,
                        width: width,
                        // color: Colors.green,
                        // color: Colors.red,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // SizedBox(height: 50,),
                            Lottie.asset(AppImages.notfoundanimation, height: height * 0.3),

                            Text(
                              'No Variant Found',
                              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500),
                            )
                          ],
                        ),
                      );
                    }

                    return Container(
                      height: height * 0.7,
                      child: ListView.builder(
                          itemCount: allvariante.length,
                          itemBuilder: (context, index) {
                            final variante = allvariante[index];
                            return Card(
                              color: Colors.white,
                              child: ListTile(
                                title: Text(
                                  variante.name,
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                                // trailing:
                                trailing: Container(
                                  width: 60,
                                  child: Row(
                                    children: [
                                      InkWell(
                                          onTap: () => openBottomSheet(variante: variante),
                                          child: Container(
                                              padding: EdgeInsets.all(1),
                                              decoration: BoxDecoration(
                                                color: Colors.grey,
                                                borderRadius: BorderRadius.circular(5),
                                                // shape:BoxShape.circle,
                                              ),
                                              child: Icon(Icons.edit))),
                                      SizedBox(
                                        width: 5,
                                      ),
                                      InkWell(
                                          onTap: () {
                                            showModalBottomSheet(
                                                context: context,
                                                builder: (context) {
                                                  return Container(
                                                    height: height * 0.4,
                                                    width: double.infinity,
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          size: 100,
                                                          color: AppColors.primary,
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        Text(
                                                          'Delete Variant',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 5,
                                                        ),
                                                        Text(
                                                          'Are you sure you want to Delete this Variante',
                                                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        Container(
                                                          padding: EdgeInsets.all(10),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: CommonButton(
                                                                    bordercircular: 5,
                                                                    height: 40,
                                                                    width: 30,
                                                                    bordercolor: Colors.grey,
                                                                    bgcolor: Colors.white,
                                                                    onTap: () {
                                                                      Navigator.pop(context);
                                                                    },
                                                                    child: Text('Cancel')),
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: CommonButton(
                                                                    bordercircular: 5,
                                                                    height: 40,
                                                                    width: 30,
                                                                    bordercolor: Colors.red,
                                                                    bgcolor: Colors.red,
                                                                    onTap: () {
                                                                      _delete(variante.id);
                                                                    },
                                                                    child: Text(
                                                                      'Delete',
                                                                      style: GoogleFonts.poppins(color: Colors.white),
                                                                    )),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  );
                                                });
                                            // setState(() {
                                            //   variants.removeAt(index);
                                            // });
                                          },
                                          child: Container(
                                              padding: EdgeInsets.all(1),
                                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
                                              child: Icon(Icons.delete, color: Colors.white)))
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                    );
                  }),

              /* variantsList.isEmpty
                  ? Container(
                      height: height * 0.7,
                      width: width,
                      // color: Colors.green,
                      // color: Colors.red,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // SizedBox(height: 50,),
                          Lottie.asset(
                              'assets/animation/notfoundanimation.json',
                              height: height * 0.3),

                          Text(
                            'No Variant Found',
                            style: GoogleFonts.poppins(
                                fontSize: 20, fontWeight: FontWeight.w500),
                          )
                        ],
                      ),
                    )
                  : Container(
                      height: height * 0.7,
                      child:
                      ListView.builder(
                          itemCount: variantsList.length,
                          itemBuilder: (context, index) {
                            return Card(

                              color: Colors.white,
                              child: ListTile(

                                title: Text(
                                  variantsList[index].name,
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                                // trailing:
                                trailing: Container(
                                  width: 60,
                                  child: Row(
                                    children: [
                                      InkWell(
                                          onTap: () =>
                                              openBottomSheet(index: index),
                                          child: Container(
                                              padding: EdgeInsets.all(1),
                                              decoration: BoxDecoration(
                                                color: Colors.grey,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                // shape:BoxShape.circle,
                                              ),
                                              child: Icon(Icons.edit))),
                                      SizedBox(
                                        width: 5,
                                      ),
                                      InkWell(
                                          onTap: () {
                                            showModalBottomSheet(
                                                context: context,
                                                builder: (context) {
                                                  return Container(
                                                    height: height * 0.4,
                                                    width: double.infinity,
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          size: 100,
                                                          color: AppColors.primary,
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        Text(
                                                          'Delete Variant',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 5,
                                                        ),
                                                        Text(
                                                          'Are you sure you want to Delete this Variante',
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontSize: 12),
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        Container(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  10),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    CommonButton(
                                                                        bordercircular:
                                                                            5,
                                                                        height:
                                                                            40,
                                                                        width:
                                                                            30,
                                                                        bordercolor:
                                                                            Colors
                                                                                .grey,
                                                                        bgcolor:
                                                                            Colors
                                                                                .white,
                                                                        onTap:
                                                                            () {
                                                                          Navigator.pop(
                                                                              context);
                                                                        },
                                                                        child: Text(
                                                                            'Cancel')),
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    CommonButton(
                                                                        bordercircular:
                                                                            5,
                                                                        height:
                                                                            40,
                                                                        width:
                                                                            30,
                                                                        bordercolor:
                                                                            Colors
                                                                                .red,
                                                                        bgcolor:
                                                                            Colors
                                                                                .red,
                                                                        onTap:
                                                                            () {
                                                                          _delete(
                                                                              index);
                                                                        },
                                                                        child:
                                                                            Text(
                                                                          'Delete',
                                                                          style:
                                                                              GoogleFonts.poppins(color: Colors.white),
                                                                        )),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  );
                                                });
                                            // setState(() {
                                            //   variants.removeAt(index);
                                            // });
                                          },
                                          child: Container(
                                              padding: EdgeInsets.all(1),
                                              decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(5)),
                                              child: Icon(Icons.delete,
                                                  color: Colors.white)))
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                    ),*/
              Container(
                alignment: Alignment.center,
                child: CommonButton(
                    width: width * 0.5,
                    height: height * 0.06,
                    onTap: () => openBottomSheet(),

                    // showModalBottomSheet(context: context,
                    //     builder: (BuildContext context){
                    //       return showMOdel(isEditing);
                    //     });

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          child: Icon(Icons.add),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          'Add Variante',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                        )
                      ],
                    )),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget showMOdel() {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        height: height * 0.3,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              // color: Colors.red,
              width: width * 0.9,
              child: Text(
                editingVariante == null ? 'Add Variant' : 'Edit Variant',
                textScaler: TextScaler.linear(1),
                textAlign: TextAlign.start,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ),
            SizedBox(
              height: 25,
            ),
            Container(
              height: height * 0.05,
              child: TextField(
                controller: VariantController,
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
                  labelStyle: GoogleFonts.poppins(
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(),
                  labelText: "Variant Name (English)",
                ),
              ),
            ),
            SizedBox(
              height: 25,
            ),
            CommonButton(
                height: height * 0.06,
                width: width * 0.6,
                onTap: () {
                  _addOrEditVariante();
                },
                child: Center(
                    child: Text(
                      editingVariante == null ? 'Add' : 'update',
                      style: GoogleFonts.poppins(color: Colors.white),
                    )))
          ],
        ),
      ),
    );
  }
}
